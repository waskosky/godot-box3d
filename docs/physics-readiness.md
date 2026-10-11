# Physics readiness

This is a validated development milestone, not production certification.
`integration/next` combines independent candidates for downstream testing;
upstream pull requests remain based directly on upstream `main`.

## Behavioral coverage

The native suite exercises actual Godot bodies and queries, including:

- Geometric recovery for sphere/capsule/box/cylinder/convex shapes against
  primitives, slopes, trimeshes, heightmap resources and world boundaries.
- Centered heightmap bounds, non-flat heights/cell diagonals, body/attachment
  rotations, rigid support and NaN holes. The [heightmap adapter](heightmap-geometry.md)
  uses a static mesh fallback, not Box3D's compressed native heightfield path.
- Compound shape indices/transforms, disabled slots, competing floor/wall
  normals, collision priority and per-call body/object exclusions.
- Read-only motion queries, margin shells, separation-ray recovery/casting,
  grounded terrain traversal and rigid loads on idle/moving characters.
- Animated kinematic platform carry, clean stops and small linear/angular
  targets; motion collisions report the platform's velocity.
- CCD against a thin wall, rotated off-center impulse/inertia, sleep/wake,
  sustained finite states and repeated body creation/removal.

Run the complete native suite with a matching Godot executable:

```sh
GODOT_BIN=/path/to/godot JOBS=4 scripts/run_headless_tests.sh
```

The [Web smoke scene](../WEB_QUICKSTART.md#verify-the-included-smoke-project)
checks live character slopes/terrain, loads and platform movement as well as
rigid settling, areas, hinges and separation rays. Run the same release export
in Chromium, Firefox and WebKit. Its small character-query timing is diagnostic:
it is not a device-performance or memory-growth qualification.

## Remaining acceptance gates

1. Test physical Android and iPhone/Safari devices, including repeated scene
   reloads and background/resume. Desktop WebKit is only a browser sanity check.
2. Qualify sustained frame pacing, memory and body/contact churn on named
   representative scenes and devices under explicit, unchanged budgets.
3. Validate each embedding host's exact static template and matching native
   authority before changing its immutable dependency pin. The static archives
   alone are not runtime or whole-deployment proof.
   The [optional worker-host readback patch](web-worker-readback.md) has recorded
   desktop coverage on its stated source commit; it does not certify a newer
   physics pin, mobile devices or the host's Firefox cold-start budget.
4. Extend character traversal to rough/rotated heightmaps and holes, slopes near
   the floor-angle limit, stairs/ledge transitions and platform detach/jump.
   The heightmap geometry checks validate surface placement, not every character
   transition or the memory/construction cost of large terrain meshes.
5. Address remaining adapter/API gaps for a named consumer, especially
   `collide_shape()` penetration-depth pairs. Keep unsupported dynamic concave
   bodies, concave sensor visitors, non-uniform scaling, soft bodies and unmapped
   joint parameters explicit; do not imply support from unrelated passing tests.

Keep regressions focused on observable physics behavior. Add a small reproduction
for each new failure rather than expanding a generic test framework or declaring
all Godot/Box3D behavior equivalent.
