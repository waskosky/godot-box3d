---
title: Web preview qualification
---

# Web preview qualification

Consistency candidate: `9a4c0daa603753888e469ec6cf2717b0b4693a9a`.
The [static workflow](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40746990330), [native build and physics suite](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40746980906), and [ordinary Web pipeline](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40746981088) retain separate qualification evidence. Ordinary Web CI does not qualify static embedding.

## Consistency refresh (2026-10-28)

The refresh aligns ray and Viewport-picking regressions with the focused
upstream candidates while preserving the fork's Box3D pin and heightmap mesh
fallback. Internal recovery rays retain initial hits; public shape casts
explicitly ignore initial overlaps. A no-hit `cast_motion()` now returns
`[1.0, 1.0]` rather than an empty result. Native checks also verify that ignoring
an initial overlap does not hide an obstacle farther along the path. The Web
scene covers unobstructed and initially overlapping shape casts in its existing
direct-query check.

All 41 native tests passed locally on Godot 4.7/macOS and in CI on Linux,
Windows and macOS, plus the Godot 4.3 compatibility and UBSan runs. The combined
ASan/UBSan build also passed (build coverage, not an ASan runtime claim).
Ordinary Web CI passed all ten Chromium smoke checks in 5.642 seconds and
produced its package; its captured result text and scene geometry were inspected.

Static Web CI restored the engine compilation cache, rebuilt the matching
archives/hosts, and passed all four smoke runs under Xvfb/software GL:

| Target | Browser | Physics smoke | Seconds to physics PASS |
|---|---|---|---:|
| Release | Chromium | All ten checks pass | 5.469 |
| Release | Firefox | All ten checks pass | 5.418 |
| Debug | Chromium | All ten checks pass | 4.277 |
| Debug | Firefox | All ten checks pass | 4.868 |

Both Release workloads completed six construction/movement/cleanup cycles with
the active `Box3DPhysicsServer3D`, no captured errors and stable cleanup counts
of seven nodes and three resources. First active workload was observed at
1.693 seconds in Chromium and 2.879 seconds in Firefox. Both reports explicitly
mark `hardware_timing_eligible=false`; these are CI observations, not device
performance budgets.

All four smoke frames and both workload loaded/final pairs were inspected.
The final workload frames show completed cleanup with readable text. Missing
glyphs recur in Release Firefox and Debug Chromium smoke captures, while the
other two smoke captures are readable. This is not isolated to Firefox and
does not establish hardware visual acceptance. Capture timing versus a
rendering defect still needs a controlled comparison.

The retained manifest identifies clean source `9a4c0da`, the original Box3D
repository and unchanged dependency pins. The bundle checksum and enclosed
artifact hashes were verified. Tested template SHA-256 values are:

- Release: `fdfcef88cd7976157f5868136c2bfd4e49f6c949b9b0cb03d0b7fdde739c36e2`
- Debug: `4caecb6e0ad75d8e0d1cd11b64be5db90035514b411c3900d6cb102079018996`

The exported `smoke_test.gd` hash is
`61a2548d39d89971f39af896ed9859317ec59cd94d3fe53029a9fc1351428415`;
the unchanged workload fixture retains the hash recorded below. Documentation
follow-ups do not replace this exact tested source/artifact identity.

## Earlier automated static results (2026-10-25)

Automation source: `ddcb1659b9adc707f83fb5fd821da85e20f5f5fd`.
The earlier [static workflow](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40242243192), [native build and physics suite](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40242243167), and [ordinary Web pipeline](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40242243207) retain that source's separate qualification evidence.

The initial [Linux static run](https://github.com/waskosky/godot-box3d-embedded/actions/runs/40237979182) built both hosts and passed Release Chromium's ten checks. Headless Firefox could not create a WebGL2 context (`AllowWebgl2:false`), so it never started Godot. The retry uses headed browsers under Xvfb with an explicit Mesa software-rendering configuration. Its results remain ineligible for hardware timing claims.

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

## Local follow-up (2026-10-28)

This diagnostic reused the earlier `18fc237` static single-worker export, not
the newer consistency candidate. Playwright 1.61.0 was retained on the same
macOS host. Firefox, Chromium and WebKit all timed out launching a blank headed
browser within 15 seconds, before any Godot or physics code loaded. The browser
session issue remains unresolved; unrelated host processes were left alone.

Headless Firefox 151 passed all ten smoke checks in 47.675 seconds. A capture
taken three seconds after completion had readable text and visible scene
geometry. The workload's loaded/final captures also had readable text, but its
final capture was an incomplete cleanup state, not a completed six-cycle run.
These local captures do not reproduce the earlier Linux software-GL glyph
artifacts, and do not establish whether those artifacts were persistent or
capture-timing related.

The unchanged 180-second workload deadline was exceeded again. First active
workload was observed at 83.932 seconds, with one-minute host load averages
of 14.1 at start and 24.4 at finish. No physics assertion failure was observed
before timeout, but partial progress is not a passing workload result. The
Intel-family renderer identification does not make this contended, headless
run hardware-timing eligible. Startup, frame pacing and visual acceptance
still need an idle host with a working headed browser.

## Interpretation and remaining gates

The local runs do not establish the frame-pacing budget. After the first cycle, worst per-cycle frame p95 ranged from about 252–349 ms in the ordinary Chromium runs and 271–744 ms in static Chromium runs. The renderers, host contention and screenshot overhead preclude a hardware capacity claim. Increasing physics workers did not produce a dependable improvement in this environment.

Page scheduling was better in the single-worker static observations: fresh-context active timer p99 was about 286 ms versus 535 ms for ordinary Chromium, and 36 ms versus 162 ms for ordinary Firefox. These are limited, contended observations; a 20 ms page timer is not an input-to-display latency test. The Firefox static workload remained incomplete, and startup was not consistently improved by static embedding.

Retain raw JSON, export manifests, template hashes and screenshots with these results. The local Release template SHA-256 was `c19dfcbceb3fdc2bf7bd7055b56a64abde4196bf87d9373c58f60ee49ca9bf34`. CI builds have their own manifests and hashes; do not substitute this local artifact for a CI-built host.

The next performance investigation should profile Firefox startup and long frames on an otherwise idle host with a working headed browser, measuring compilation, rendering, page input and actual physics work separately. The current observations do not isolate a Box3D solver defect or certify a leak-free process. Wasm capacity and browser heap samples do not include all live native/GPU allocation.

Physical Android/Chrome and iPhone/Safari, WebKit, background/resume, application-specific controllers/terrain, and sustained performance/memory budgets remain separate gates. Follow [release qualification](release-qualification.md) before changing an application's immutable deployment pin.
