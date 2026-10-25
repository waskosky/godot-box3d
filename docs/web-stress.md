# Desktop Web workload

The ordinary Web smoke remains the quick correctness gate. The same export also
contains an opt-in, bounded workload at `?box3d_stress=representative` or
`?box3d_stress=stress`:

| Profile | Characters | Rigid boxes | Shared heightmap grid |
| --- | ---: | ---: | ---: |
| representative | 16 | 128 | 65 × 65 |
| stress | 32 | 512 | 129 × 129 |

Each profile creates two terrain owners, including a transformed attachment,
walks characters, periodically wakes rigid bodies, then frees the complete world.
Six ten-second active periods exercise repeated construction and cleanup. GPU
buffer readback creates actual trimesh collision before the workload starts;
this also checks a worker-main host's context patch. Non-finite poses and bodies
crossing terrain fail the physics result.

After exporting the smoke project with matching artifacts, run:

```sh
python3 scripts/run_web_stress.py --dir build/web-smoke --headed \
  --output build/web-stress/representative.json
python3 scripts/run_web_stress.py --dir build/web-smoke --headed --profile stress \
  --output build/web-stress/stress.json
```

Install Playwright and its chosen browser first, as for `run_web_smoke.py`.
`--browser firefox` and `--browser webkit` use the same workload. A custom static
host must export the same scene with its matching embedded physics commit and
all required host patches, without the addon side module.

The report retains per-cycle real frame-gap and character-query p50/p95/p99,
terrain/world construction time, Godot object/resource counts, observable Wasm
capacity and browser JS heap samples, browser/OS identity and two screenshots.
Frame gaps use a monotonic clock rather than Godot's overload-clamped delta.
The cached engine physics-time monitor is retained separately; it is not a
timestamped per-step Box3D profiler.
The runner requires stable node/resource counts after first-cycle warm-up. Inspect
both screenshots. Keep generated reports and captures outside version control.

Record the exact source, artifact hashes, compiler and host state with results.
Compare otherwise identical candidates on an idle host. First-cycle startup and
warm-up remain visible. Wasm capacity is retained allocator capacity, not live
allocation: growth alone does not establish a leak, and a plateau cannot prove
the absence of one. Browser JS heap does not include all native/GPU memory.
An unavailable release-build memory/timing monitor is not a measured zero cost.

The result's `ok` covers bounded physics and cleanup only. Hardware timing is
eligible only for a headed browser with an identified hardware renderer. Choose
the target's frame/startup/memory budget before comparing performance; there is
no universal FPS assertion. This desktop workload does not establish physical
phone, multiplayer, whole-game or arbitrary large-terrain acceptance.
