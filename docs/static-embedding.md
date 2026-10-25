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

Copy `web_smoke_project` into an ignored build directory, change that copy's Web preset to the settings above, exclude its addon, and export with the freshly built custom ZIP. Keep the scene and physics assertions unchanged. Then run:

```sh
.venv/bin/python -m pip install playwright==1.61.0
.venv/bin/python -m playwright install chromium
.venv/bin/python scripts/run_web_smoke.py --dir /path/to/export \
  --browser chromium --screenshot build/static-smoke-chromium.png
```

Require active `Box3DPhysicsServer3D`, extension registration, rigid settling, areas, hinges, terrain/mesh geometry, separation rays, character support, animated platforms, and direct queries. The mesh checks exercise the readback path used when creating collision geometry. Inspect the final frame. Repeat in the other browsers the host intends to support; a longer timeout diagnoses slow startup but does not establish an acceptable loading budget.

Retain the source commit, dependency pins, compiler version, host build flags, patch and archive hashes, template hash, and browser results together. A successful archive build alone does not qualify the host. Keep the previous template until the new candidate passes the host's acceptance checks. Applications with a native authority must coordinate the matching physics revision separately.

The [release qualification guide](release-qualification.md) covers startup, sustained frame pacing, memory, physical devices, and host acceptance beyond this focused smoke test. The [worker readback record](web-worker-readback.md) distinguishes earlier host-specific evidence from the current candidate.
