---
title: Static Web embedding
---

# Static Box3D in a worker-main Web template

This downstream profile links the existing Godot extension and godot-cpp into a custom Godot Web template. A small engine module registers `godot_box3d_main` through Godot's function-based GDExtension loader before physics-server initialization. The ordinary [Web extension profile](../WEB_QUICKSTART.md) remains available as a development and rollback path.

The purpose is to run the application main loop in a worker while the browser owns its page UI on the main thread. Godot 4.7 disables `proxy_to_pthread` when dynamic linking is enabled. Static embedding lets this host use `threads=yes dlink_enabled=no proxy_to_pthread=yes`. It does not imply that all multithreading requires static linking, or guarantee a startup or frame-rate improvement.

## Build the release archives

Use a separate checkout/build directory for this profile: the pinned godot-cpp generates architecture-dependent wrappers. Requirements are Git, Python 3, a C/C++ toolchain, and enough space to compile Godot. From a clean fork checkout:

```sh
scripts/setup_python_build_env.sh
scripts/bootstrap_dependencies.sh
scripts/setup_web_toolchain.sh
source .deps/emsdk/emsdk_env.sh
MAX_JOBS=4 scripts/build_web_static.sh
```

The two inputs are:

```text
bin/web/static/libgodot-box3d-static.web.template_release.wasm32.a
bin/web/static/libgodot-cpp.web.template_release.wasm32.a
```

Use the exact source revisions in [dependencies.lock](../dependencies.lock). Existing dependency checkouts and edits are preserved; explicitly save and update a checkout if its revision differs from the pin. These archives use the godot-cpp 4.3 API exposed by the adapter; the custom host uses the pinned Godot 4.7 engine and Emscripten 4.0.20. Keep single precision, wasm32, SIMD and thread settings consistent. Do not reuse archives from another dependency tuple.

## Build the host template

The following commands assume an initialized fork checkout and the active SDK from above. Use a separate Godot checkout so an existing host build stays available for rollback:

```sh
BOX3D_DIR="$PWD"
source dependencies.lock
git clone --filter=blob:none --no-checkout "$GODOT_ENGINE_REPOSITORY" .deps/godot-worker-main
git -C .deps/godot-worker-main checkout --detach "$GODOT_ENGINE_REF"
GODOT_SRC="$BOX3D_DIR/.deps/godot-worker-main"
git -C "$GODOT_SRC" apply --check "$BOX3D_DIR/patches/godot-4.7/web-worker-readback.patch"
git -C "$GODOT_SRC" apply "$BOX3D_DIR/patches/godot-4.7/web-worker-readback.patch"
.venv/bin/scons -C "$GODOT_SRC" -j4 \
  platform=web target=template_release arch=wasm32 precision=single \
  threads=yes dlink_enabled=no proxy_to_pthread=yes \
  custom_modules="$BOX3D_DIR/examples/godot_static" \
  box3d_archive_dir="$BOX3D_DIR/bin/web/static"
```

The output is `$GODOT_SRC/bin/godot.web.template_release.wasm32.zip`. The example's [SCsub](../examples/godot_static/box3d_static/SCsub) accepts `box3d_archive_dir` so the module can also be copied into another host build. Its [registration code](../examples/godot_static/box3d_static/register_types.cpp) leaves extension initialization and shutdown with Godot's extension manager.

The patch is for worker-main hosts that synchronously proxy WebGL onto the browser's main thread. It preserves that proxy and selects the JavaScript context owned by that thread when reading mesh buffers. Read [the reproduction and scope](web-worker-readback.md) before applying it to a different rendering arrangement. Hosts using a worker-owned `OffscreenCanvas` need separate qualification.

For a Debug export, first build the matching archives with `GODOT_BOX3D_STATIC_TARGET=template_debug MAX_JOBS=4 scripts/build_web_static.sh`, then repeat the Godot command with `target=template_debug`. Keep both sets of archives; the example selects the one matching the template target.

## Export a project

Select **Box3D Physics**, use the Compatibility renderer, and configure a Web preset with:

- **Thread Support** enabled.
- **Extensions Support** disabled.
- The release custom-template path pointing to the ZIP built above; use the matching Debug ZIP for debug exports.

The editor still needs its ordinary native addon. In the exported static project, exclude `addons/godot-box3d/*`; the template already contains the backend. Do not load a second addon copy. The example uses the extension identifier `libgodot://box3d` and registers the same `Box3D Physics` backend used by the normal addon.

Serve over HTTPS, or HTTP on localhost, with `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`. Verify `crossOriginIsolated` and `SharedArrayBuffer` availability. Cross-origin assets must satisfy the corresponding CORS/CORP requirements. For local testing:

```sh
python3 scripts/serve_web_export.py /path/to/export --port 8060
```

## Validate the exact candidate

Copy `web_smoke_project` into an ignored build directory, change that copy's Web preset to the settings above, exclude its addon, and export with the freshly built custom ZIP. Keep the scene and physics assertions unchanged. The fixture's bundled descriptor is Web-only: use `--recovery-mode` for a headless export, or install your matching native addon before importing it in the editor. Then run:

```sh
.venv/bin/python -m pip install playwright==1.61.0
.venv/bin/python -m playwright install chromium
.venv/bin/python scripts/run_web_smoke.py --dir /path/to/export \
  --browser chromium --screenshot build/static-smoke-chromium.png
```

Require active `Box3DPhysicsServer3D`, extension registration, rigid settling, areas, hinges, terrain/mesh geometry, separation rays, character support, animated platforms, and direct queries. The mesh checks exercise the readback path used when creating collision geometry. Inspect the final frame. Repeat in the other browsers the host intends to support; a longer timeout diagnoses slow startup but does not establish an acceptable loading budget.

Retain the source commit, dependency pins, compiler version, host build flags, patch and archive hashes, template hash, and browser results together. A successful archive build alone does not qualify the host. Keep the previous template until the new candidate passes the host's acceptance checks. Applications with a native authority must coordinate the matching physics revision separately.

The [release qualification guide](release-qualification.md) covers startup, sustained frame pacing, memory, physical devices, and host acceptance beyond this focused smoke test. The [worker readback record](web-worker-readback.md) distinguishes earlier host-specific evidence from the current candidate.

## Recorded validation (2026-10-25)

The standalone example was built from [source commit `83b5d55`](https://github.com/waskosky/godot-box3d/commit/83b5d55ce50b91dd43119f573b45228c843d49fe), using [that commit's dependency pins](https://github.com/waskosky/godot-box3d/blob/83b5d55ce50b91dd43119f573b45228c843d49fe/dependencies.lock). The physics adapter source is unchanged from the previously validated integration baseline `e7f81af`; this candidate adds the generic host module and downstream documentation/build support.

Fresh archives and a fresh Godot source build used Emscripten 4.0.20, SCons 4.8.1, all default engine modules, `target=template_release arch=wasm32 precision=single threads=yes dlink_enabled=no proxy_to_pthread=yes`, and the included readback patch. The host was macOS 15.7.1, x86_64, with Playwright 1.61.0.

| Build artifact | SHA-256 |
|---|---|
| Box3D binding archive | `8f75344bf78edb78440880b62b2a173e8dfd7d2bb2a114145f4f09255edf51ff` |
| godot-cpp archive | `44543aeaf9f5f3f69a6002803ad475601f25702e89848af2e59303f140c7f09d` |
| Readback patch | `3e2efb2e07db23cd5f429dec3b68b7e8a53659cf10f1ca523bd148a1de342eae` |
| Release template ZIP | `c19dfcbceb3fdc2bf7bd7055b56a64abde4196bf87d9373c58f60ee49ca9bf34` |
| Exported application Wasm | `1a35c51e104b2f6501f4026808325018169610e175aa829ed3af8fbd422b4b17` |

The smoke project had a matching native addon installed for a normal editor import. The static Web preset excluded that addon and disabled extension support. Import and export completed without reported errors; the export contains one application Wasm and no Box3D side module. The generated JavaScript includes the worker-main entry path. The scene and its assertions were unchanged (`smoke_test.gd` SHA-256 `9cc45b49d4efff149425a3575ea4450fd14883221084f4ab7c41e479129fdf8f`).

| Browser | Physics result | Seconds to physics PASS |
|---|---|---|
| Chromium | All 10 required checks pass; final frame inspected | 7.090 |
| Firefox | All 10 required checks pass; final frame inspected | 33.694 |
| Desktop WebKit | Unqualified: browser launch timed out before project navigation | — |

The two passing runs captured no engine/browser errors during the smoke and a two-second post-PASS observation. Existing warnings about ignored hinge parameters and browser graphics/Wasm behavior remain. The times include the scene's simulation and are not first-frame startup or sustained performance measurements. Firefox used an explicitly recorded 180-second diagnostic timeout.

WebKit's default cached build 2311 declares a macOS 26.2 minimum and could not launch on this host. A separate blank-page check also timed out using cached build 2359, whose declared minimum is 15.4. No WebKit physics result was obtained. Restore a working browser installation before repeating that gate.

This record qualifies the standalone Release example functionally on Chromium and Firefox. Debug exports, WebKit/Safari, physical mobile devices, startup budgets, and sustained performance/memory acceptance remain separate gates. These hashes identify this build; embedding applications must qualify their own exact templates and any additional host changes before deployment.
