# Worker-main WebGL buffer readback

This is an optional Godot host patch, not a Box3D physics change. The ordinary
dynamic, single-threaded Web profile is unaffected and does not need it.

It targets Godot 4.7 / Emscripten 4.0.20 worker-main templates that proxy WebGL
onto the browser's main thread. It is not certification of hosts that transfer
an `OffscreenCanvas` rendering context into a worker; qualify that different
ownership mode separately before adopting this patch.

## Reproduction and cause

A freshly generated `BoxMesh` can render while `surface_get_arrays()` returns
invalid index values and `create_trimesh_shape()` fails with `index >= vc`.
This reproduces before physics runs, including with an older Box3D integration.
It must not be mistaken for missing trimesh collision support.

Godot's `godot_webgl2_glGetBufferSubData` wrapper proxies onto the browser's main
thread, then asks native thread-local state for its current WebGL context. With
the game running on a pthread, that native handle can be zero even though the
main thread's JavaScript `GL.currentContext` is valid. The wrapper silently
leaves the destination unfilled. The patch retains synchronous proxying and
uses the active JavaScript context instead. Removing the proxy is not the fix.

## Apply to a host-owned template

From a clean Godot 4.7 source checkout:

```sh
git -C /path/to/godot apply --check /path/to/godot-box3d/patches/godot-4.7/web-worker-readback.patch
git -C /path/to/godot apply /path/to/godot-box3d/patches/godot-4.7/web-worker-readback.patch
```

Rebuild the exact host template with matching Box3D/godot-cpp static archives.
Include the patch hash in the host's immutable build receipt/cache key. Never
replace a previously validated cached template in place or repin a deployment
from an archive build alone.

## Validate

First run a minimal scene with no physics bodies:

```gdscript
var mesh := BoxMesh.new()
var arrays := mesh.surface_get_arrays(0)
for index in arrays[Mesh.ARRAY_INDEX]:
    assert(index >= 0 and index < arrays[Mesh.ARRAY_VERTEX].size())
assert(mesh.create_trimesh_shape() != null)
```

Then export the unmodified `web_smoke_project` from `integration/next` with the
patched worker-main/static template and no addon side module. Require backend/class registration, terrain
grounding, rigid-load support, animated platform carry, separation rays, areas
and hinge movement in Chromium, Firefox and desktop WebKit. Keep physical-device,
render-context fallback and sustained performance/memory acceptance separate.

## Diagnostic status (2026-10-11)

- Both older and current static templates reproduced invalid mesh indices before
  physics ran. Native and dynamic/no-thread exports did not.
- Instrumentation confirmed a zero native thread-local handle alongside a valid
  main-thread JavaScript context. Selecting that JS context restored the minimal
  mesh's 24 vertices, in-range indices and 36 triangle vertices.
- Changing only the generated JS wrapper, with the same compiled wasm and
  unchanged smoke fixtures/assertions, passed the full static physics scene in
  Chromium and desktop WebKit. Their final frames were inspected.
- Firefox static acceptance is still open: the patched full scene stalled before
  completing, and an attempted screenshot timed out. Dynamic/no-thread Firefox
  already passed. Do not broaden the supported profile from the two successes.
- The source patch applies cleanly to pinned Godot `5b4e0cb0f`. Rebuild and verify
  an immutable host template from that source patch before deployment; the JS
  diagnostic is not that final producer receipt or physical-device proof.
