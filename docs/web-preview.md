---
title: Web preview qualification
---

# Web preview qualification

Automation candidate: `ddcb1659b9adc707f83fb5fd821da85e20f5f5fd`.
The [static workflow](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40242243192), [native build and physics suite](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40242243167), and [ordinary Web pipeline](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40242243207) retain separate qualification evidence. Consult each run's result; ordinary Web CI does not qualify static embedding.

The earlier [Linux static run](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40237979182) built both hosts and passed Release Chromium's ten checks. Headless Firefox could not create a WebGL2 context (`AllowWebgl2:false`), so it never started Godot. The retry uses headed browsers under Xvfb with an explicit Mesa software-rendering configuration. Its results remain ineligible for hardware timing claims.

## Automated static results

The retry passed on source `ddcb165`. Both compiled templates, their matching static archives, dependency versions and build flags are recorded in the retained `BUILD_MANIFEST.json`. Engine compilation was restored from the previously saved cache; both targets still ran their archive build and SCons dependency checks.

| Target | Browser | Physics smoke | Seconds to physics PASS |
|---|---|---|---:|
| Release | Chromium | All ten checks pass | 7.369 |
| Release | Firefox | All ten checks pass | 9.531 |
| Debug | Chromium | All ten checks pass | 7.497 |
| Debug | Firefox | All ten checks pass | 6.641 |

Both Release workloads completed all six construction/movement/cleanup cycles, reported the active `Box3DPhysicsServer3D`, and retained stable node/resource cleanup counts. Neither captured an engine/browser error. First active workload was observed at 3.102 seconds in Chromium and 4.647 seconds in Firefox; these are single CI observations, not device startup budgets.

All four smoke frames and both workload loaded/final frames were inspected. Three-dimensional geometry and completed workload cleanup were visible. Firefox's software-rendered captures showed incomplete text/glyph updates despite passing console checks; those captures do not establish visual acceptance on target hardware. A persistent rendering defect versus capture timing still needs investigation on a settled, hardware-rendered frame.

The tested CI template hashes are:

- Release: `973eb4f48852cf30a88ada03346e7b6c118a053d0e7f32f09bf06a198b91e08d`
- Debug: `61fd4c2312584f41e9d3056b4b53f500f7fd08f1b3b6ead555e2f3ef6b0b9c29`

These results qualify bounded physics behavior and cleanup under the stated software-GL configuration. They do not replace the local observations below or establish hardware frame pacing, total live memory, visual correctness, or mobile acceptance.

## Workload routing

The first standalone worker-main workload attempt ran the ordinary smoke instead of the requested workload. In this host, `JavaScriptBridge.eval()` reads the worker's URL and globals. The workload flag belongs to the browser page.

The candidate reads page query parameters and publishes status through Godot's proxied `JavaScriptBridge.get_interface()` objects. The runner still requires the full six-cycle result and stable cleanup; an ordinary smoke PASS cannot satisfy that check. Physics construction and assertions were unchanged by this routing fix. Export manifests retain these fixture hashes:

- `smoke_test.gd`: `a763c33812e8a48b68266c8b5cf7c21e57b8afe636ab95333d68d25b292445da`
- `stress_test.gd`: `1c56d4da45325e67b6a7a50bd1907b384d2ea516553fa6adb60b3055895920bb`

## Local comparison (2026-10-25)

These exports used source `18fc237e80b87f55bc41b2573b6f615adcb032ae`. The later automation candidate changes CI display configuration and runner options; its C++ physics adapter and fixture assertions are unchanged.

The representative workload creates 16 characters, 128 rigid bodies and two 65 × 65 terrain owners. Each run requests six ten-second active periods with world construction and cleanup between them. The same scene and assertions were exported for both host profiles; only the requested physics worker count differs.

The host was macOS 15.7.1, x86_64, with four physical/eight logical CPU cores and Playwright 1.61.0. Chromium 149 used SwiftShader; Firefox 151 reported an Intel-family renderer. The host had competing activity, with observed one-minute load averages from 7.8 to 26.0. Headed browsers could not launch even a blank page. All measurements below are headless and have `hardware_timing_eligible=false`.

Before measuring, provisional desktop goals were recorded: first active workload within 10 seconds for a fresh context and five seconds after warm-up; frame p95 within 20 ms and p99 within 33.4 ms; active page-timer p99 within 50 ms. Functional acceptance separately requires all six cycles and stable post-warm-up cleanup.

| Browser | Profile | Workers requested | Fresh first active (s) | Warm first active (s) | Workload result |
|---|---|---:|---:|---:|---|
| Chromium | Ordinary extension | 1 | 4.136 | 3.417 | Both runs pass 6/6 cycles and cleanup |
| Chromium | Static worker-main | 1 | 4.327 | 2.706 | Both runs pass 6/6 cycles and cleanup |
| Chromium | Static worker-main | 4 | 4.505 | — | Passes 6/6 cycles and cleanup |
| Chromium | Static worker-main | 8 | 4.280 | — | Passes 6/6 cycles and cleanup |
| Firefox | Ordinary extension | 1 | 51.059 | 52.589 | Timeouts after 5/6 and 4/6 cycles |
| Firefox | Static worker-main | 1 | 70.190 | 47.438 | Both time out after 4/6 cycles |
| Firefox | Static worker-main | 4 | 69.161 | — | Timeout after 3/6 cycles |
| Firefox | Static worker-main | 8 | 51.229 | — | Timeout after 5/6 cycles |

All six Chromium runs completed with no captured engine/browser errors and stable node/resource cleanup after the first-cycle warm-up. All six Firefox runs exceeded the unchanged 180-second limit. No physics failure was reported before those timeouts, but partial cycles do not pass lifetime acceptance. Selected loaded and final frames were inspected, including a Chromium completion and Firefox's incomplete cleanup state.

Fresh means a new browser context, not a flushed operating-system cache. Warm means the unchanged ten-check smoke first passed in the same browser context, followed by workload navigation. Each startup cell is one observation, and first active is a polled workload state rather than first useful frame or isolated compilation time.

## Interpretation and remaining gates

The local runs do not establish the frame-pacing budget. After the first cycle, worst per-cycle frame p95 ranged from about 252–349 ms in the ordinary Chromium runs and 271–744 ms in static Chromium runs. The renderers, host contention and screenshot overhead preclude a hardware capacity claim. Increasing physics workers did not produce a dependable improvement in this environment.

Page scheduling was better in the single-worker static observations: fresh-context active timer p99 was about 286 ms versus 535 ms for ordinary Chromium, and 36 ms versus 162 ms for ordinary Firefox. These are limited, contended observations; a 20 ms page timer is not an input-to-display latency test. The Firefox static workload remained incomplete, and startup was not consistently improved by static embedding.

Retain raw JSON, export manifests, template hashes and screenshots with these results. The local Release template SHA-256 was `c19dfcbceb3fdc2bf7bd7055b56a64abde4196bf87d9373c58f60ee49ca9bf34`. CI builds have their own manifests and hashes; do not substitute this local artifact for a CI-built host.

The next performance investigation should profile Firefox startup and long frames on an otherwise idle host with a working headed browser, measuring compilation, rendering, page input and actual physics work separately. The current observations do not isolate a Box3D solver defect or certify a leak-free process. Wasm capacity and browser heap samples do not include all live native/GPU allocation.

Physical Android/Chrome and iPhone/Safari, WebKit, background/resume, application-specific controllers/terrain, and sustained performance/memory budgets remain separate gates. Follow [release qualification](release-qualification.md) before changing an application's immutable deployment pin.
