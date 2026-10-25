# Release qualification

Freeze a downstream `main` commit for a release candidate, or qualify a named
`integration/next` candidate before promotion. Keep that commit,
Godot/godot-cpp/Box3D pins, compiler, host patch hashes and artifact SHA-256 values
together. Experiments may follow the branch; deployed artifacts use immutable
pins and retain the previous qualified version for rollback.

## Behavioral acceptance

Run `scripts/run_headless_tests.sh` with the supported Godot version and require
backend activation, all physics regressions, and no unexpected errors or leaked
Box3D RIDs. Native CI also covers the minimum Godot version and UBSan; its ASan
job is a compile/link check, not an ASan runtime receipt.

Build the Web side module and matching templates, export `web_smoke_project`,
then run `scripts/run_web_smoke.py` in Chromium, Firefox and WebKit. Require all
physics checks, including direct-query geometry/options, and inspect the final
frame. The bundle manifest must name the clean candidate and contain every
required artifact; keep the included support documentation with the package.

A static worker host needs its own source-built template containing the same
physics commit. Apply the [readback patch](web-worker-readback.md) when its
stated context ownership matches the host. Export the same smoke scene without
a side module and validate it again. A matching Linux/native authority artifact
is required before an embedding application's coordinated physics pin changes.
Updating the Web client alone is not a whole-deployment acceptance check.

## Device, startup and sustained budgets

Name the exact Android phone/Chrome and iPhone/Safari versions being supported.
Desktop WebKit and mobile viewport emulation do not replace those devices.
Run the actual game/controller through scene reloads and background/resume.

For each named scene/device, record a budget before measuring:

| Measurement | Evidence to retain |
|---|---|
| Cold/warm startup | Download, compile, first useful frame, responsive input |
| Sustained pacing | Target FPS, frame/physics p50/p95/p99 and long frames |
| Lifetime | Baseline/peak/post-cleanup memory over repeated scene/body churn |
| Terrain | Grid size, shared/transformed owners, construction time and memory |
| Physics | Body/contact/query counts, finite transforms, support and CCD failures |

Start with a bounded 60-second desktop run and 20 reloads to catch obvious
failures; then qualify a 30-minute run on representative physical devices.
Warm-up and retained Wasm capacity must be distinguished from persistent growth
after equivalent cleanup cycles. The smoke scene's character-query timing is
only a diagnostic, not a whole-frame or total-native-memory measurement.

A long test timeout can distinguish slow startup from a permanent failure, but
does not relax the startup budget. The previously observed slow Firefox start
still needs a cold/warm, otherwise-idle-host measurement.

## Scope

Use unit-scale collision transforms and convex moving bodies. Explicitly retain
the documented concave sensor-visitor, dynamic concave, one-sided physical mesh,
non-uniform scaling, soft-body and unmapped-joint restrictions. Promote only the
feature/profile/device set for which evidence exists; add a small physics
reproduction when a named consumer finds another gap.
