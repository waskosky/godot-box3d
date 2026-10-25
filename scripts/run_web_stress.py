#!/usr/bin/env python3
"""Run the opt-in physics workload and retain bounded browser/memory evidence."""
from __future__ import annotations

import argparse
import functools
import json
import os
import platform
import threading
import time
from pathlib import Path

from run_web_smoke import SmokeHandler, required_checks


PAGE_TIMING = """() => {
    const gaps = {startup: [], active: []};
    let previous = performance.now();
    setInterval(() => {
        const now = performance.now();
        const phase = window.__box3dWebStress?.phase;
        const bucket = phase === 'active' ? 'active' : (!phase || phase === 'baseline' ? 'startup' : null);
        if (bucket && gaps[bucket].length < 12000) gaps[bucket].push(now - previous);
        previous = now;
    }, 20);
    const quantiles = (values) => {
        values.sort((a, b) => a - b);
        const at = (q) => values[Math.floor((values.length - 1) * q)] ?? null;
        return {samples: values.length, p50: at(.5), p95: at(.95), p99: at(.99), max: at(1)};
    };
    window.__box3dPageTiming = () => ({
        page_timer_gap_ms: {startup: quantiles([...gaps.startup]), active: quantiles([...gaps.active])},
        resources: performance.getEntriesByType('resource')
            .filter(r => /\\.(wasm|pck)$/.test(new URL(r.name).pathname))
            .map(r => ({name: new URL(r.name).pathname.split('/').pop(),
                start_ms: r.startTime, duration_ms: r.duration, transfer_bytes: r.transferSize,
                encoded_bytes: r.encodedBodySize}))
    });
} """


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--profile", choices=("representative", "stress"), default="representative")
    parser.add_argument("--browser", choices=("chromium", "firefox", "webkit"), default="chromium")
    parser.add_argument("--browser-executable", default="")
    parser.add_argument("--browser-arg", action="append", default=[], help="Explicit Chromium launch flag; retained in the report.")
    parser.add_argument("--headed", action="store_true")
    parser.add_argument("--warmup", action="store_true", help="First pass the ordinary smoke in the same browser context to warm caches.")
    parser.add_argument("--timeout", type=float, default=180)
    args = parser.parse_args()
    from http.server import ThreadingHTTPServer
    from playwright.sync_api import sync_playwright

    server = ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(SmokeHandler, directory=str(args.dir.resolve())))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    errors: list[str] = []
    samples: list[dict] = []
    lines: list[str] = []
    result: dict = {}
    report: dict = {"browser": args.browser, "headed": args.headed, "host": platform.platform(), "profile": args.profile, "browser_args": args.browser_arg,
                    "software_gl": os.environ.get("LIBGL_ALWAYS_SOFTWARE") == "1",
                    "cache_state": "warm-after-smoke" if args.warmup else "fresh-browser-context",
                    "host_cpu_count": os.cpu_count(), "host_load_average_start": os.getloadavg() if hasattr(os, "getloadavg") else None}
    manifest = args.dir / "EXPORT_MANIFEST.json"
    if manifest.is_file():
        report["export"] = json.loads(manifest.read_text())
    try:
        with sync_playwright() as playwright:
            options: dict = {"headless": not args.headed, "timeout": 30000}
            if args.browser == "firefox" and report["software_gl"]:
                options["firefox_user_prefs"] = {"webgl.force-enabled": True}
            if args.browser_executable:
                options["executable_path"] = args.browser_executable
            if args.browser == "chromium":
                options["args"] = ["--disable-background-timer-throttling", "--disable-renderer-backgrounding", "--disable-backgrounding-occluded-windows", *args.browser_arg]
            browser = getattr(playwright, args.browser).launch(**options)
            report["browser_version"] = browser.version
            page = browser.new_page(viewport={"width": 1280, "height": 720})
            page.add_init_script(f"({PAGE_TIMING})()")
            page.on("pageerror", lambda error: errors.append(str(error)))

            def console(message: object) -> None:
                line = message.text
                if line.startswith("BOX3D_WEB_STRESS_RESULT "):
                    result.update(json.loads(line.split(" ", 1)[1]))
                if message.type == "error" and any(marker in line for marker in ("ERROR:", "Aborted(", "Assertion failed", "RESULT: FAIL")):
                    errors.append(line)
                if len(lines) < 100:
                    lines.append(line)

            page.on("console", console)
            if args.warmup:
                warmup_started = time.monotonic()
                page.goto(f"http://127.0.0.1:{server.server_port}/index.html", wait_until="domcontentloaded", timeout=int(args.timeout * 1000))
                while "RESULT: PASS" not in lines and not errors and time.monotonic() - warmup_started < args.timeout:
                    page.wait_for_timeout(100)
                if not all(required_checks(lines).values()) or errors:
                    raise RuntimeError("Cache warm-up did not pass the unchanged physics smoke")
                report["warmup_seconds_to_physics_pass"] = round(time.monotonic() - warmup_started, 3)
                lines.clear()
            started = time.monotonic()
            response = page.goto(f"http://127.0.0.1:{server.server_port}/index.html?box3d_stress={args.profile}", wait_until="domcontentloaded", timeout=int(args.timeout * 1000))
            first_active = None
            while not result and not errors and time.monotonic() - started < args.timeout:
                snapshot = page.evaluate("""() => {
                    let bytes = null;
                    try { bytes = engine.rtenv.HEAPU8.buffer.byteLength; } catch (_) {}
                    return {state: window.__box3dWebStress || null, wasm_capacity_bytes: bytes,
                      js_used_bytes: performance.memory ? performance.memory.usedJSHeapSize : null};
                }""")
                snapshot["seconds"] = round(time.monotonic() - started, 3)
                samples.append(snapshot)
                if snapshot["state"] and snapshot["state"].get("phase") == "active" and first_active is None:
                    first_active = snapshot["seconds"]
                    page.screenshot(path=str(args.output.with_suffix(".loaded.png")))
                page.wait_for_timeout(500)
            report["seconds_to_first_active_observation"] = first_active
            report["elapsed_seconds"] = round(time.monotonic() - started, 3)
            if not result and not errors:
                errors.append(f"workload did not complete within {args.timeout:g} seconds")
            report["graphics"] = page.evaluate("""() => {
                const canvas = document.querySelector('canvas');
                const gl = canvas && canvas.getContext('webgl2');
                if (!gl) return {renderer: null};
                const debug = gl.getExtension('WEBGL_debug_renderer_info');
                return {renderer: debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER),
                        vendor: debug ? gl.getParameter(debug.UNMASKED_VENDOR_WEBGL) : gl.getParameter(gl.VENDOR)};
            }""")
            report.update(page.evaluate("() => window.__box3dPageTiming()"))
            renderer = str(report["graphics"].get("renderer", "")).lower()
            report["hardware_timing_eligible"] = bool(args.headed and not report["software_gl"] and renderer and not any(x in renderer for x in ("swiftshader", "llvmpipe", "software", "lavapipe")))
            page.screenshot(path=str(args.output.with_suffix(".final.png")))
            report["http_ok"] = bool(response and response.ok)
            browser.close()
    except Exception as exc:
        errors.append(f"{type(exc).__name__}: {exc}")
    finally:
        server.shutdown()
        server.server_close()
    cleanup = [cycle["cleanup_counts"] for cycle in result.get("cycles", [])]
    # Ignore first-cycle resource warm-up; subsequent cleanups must release the same objects.
    stable = len(cleanup) == 6 and all(all(row[key] == cleanup[1][key] for key in ("nodes", "resources")) for row in cleanup[2:])
    report.update({"physics": result, "cleanup_nodes_resources_stable": stable, "samples": samples, "errors": errors, "console": lines})
    report["host_load_average_end"] = os.getloadavg() if hasattr(os, "getloadavg") else None
    report["ok"] = bool(report.get("http_ok") and result.get("ok") and stable and not errors)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({key: value for key, value in report.items() if key not in ("samples", "console", "physics")}, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
