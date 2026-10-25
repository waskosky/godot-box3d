# Worker-main WebGL buffer readback

This is an optional Godot host patch, not a Box3D physics change. The ordinary
dynamic, single-threaded Web profile is unaffected and does not need it.

The [standalone host validation record](static-embedding.md#recorded-validation-2026-10-25) covers a newer downstream candidate. The diagnostic history below retains the source revision and limits of the earlier host-specific build.

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

Follow [static embedding](static-embedding.md) for the reusable host module and build recipe.
Then export the unmodified `web_smoke_project` from the candidate commit with the
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
- A fresh source build retaining the same host patches and static archives
  passed the unchanged full scene in Chromium, Firefox and desktop WebKit. No
  exported JavaScript modification was used; all final frames were inspected.
  This runtime qualification used Box3D integration commit
  `2f928a87ec4cfc17d78fbaac12196826fd744091`, not later terrain candidates.
- Firefox initially exceeded the short test window. A timed observation reached
  scene setup around 97 seconds after launch; the unmodified scene passed with
  `--timeout 180`. This is functional evidence, not acceptable cold-start latency.
  Do not change the ordinary no-thread smoke default to hide that host cost.
- The source patch applies cleanly to pinned Godot `5b4e0cb0f`. The locally
  rebuilt host template SHA-256 was
  `d8e9dded57027a5f42c509435a8a440906dc1b0e4685e96a63d0fa2f8e0b411a`;
  its readback patch SHA-256 was
  `3e2efb2e07db23cd5f429dec3b68b7e8a53659cf10f1ca523bd148a1de342eae`.
  These identify one host-specific build, not a portable release for every host.
- The supported default remains dynamic/no-thread Web. Before repinning a host,
  rebuild and qualify its exact latest physics source, include all host patches,
  archive/module hashes and compiler flags in its immutable receipt, and check
  startup budgets and physical devices. No deployment pin was changed here.
