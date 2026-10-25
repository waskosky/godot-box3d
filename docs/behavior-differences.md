---
title: Behavior differences
---

# Behavior differences

Places where the underlying engine or current adapter behaves differently from Godot's built-in physics.

How `CharacterBody3D` recovers from overlaps is covered separately in [Character motion recovery]({{ '/character-motion/' | relative_url }}).

## Separation rays are query-only

`SeparationRayShape3D` participates in direct shape queries and in `body_test_motion`, including `CharacterBody3D` floor snap and `slide_on_slope`. It does not create a Box3D fixture, so attaching one to a `RigidBody3D` or `Area3D` does not add ordinary contacts or monitoring events.

This keeps the zero-width ray from changing body mass or generating regular collision response. Use it for character motion, which is its intended Godot use; use a finite convex shape when a simulated body or area needs contacts.

An embedded ray endpoint still participates in overlap recovery when
`collide_separation_ray` is false. That flag only gates the requested-motion
cast for non-sliding rays; `slide_on_slope` rays also participate in casting.

## `Area3D` does not detect trimesh or heightmap bodies

In Box3D a concave shape (`ConcavePolygonShape3D`) or `HeightMapShape3D` can never act as a sensor *visitor*, by design, since testing an arbitrary mesh against a sensor is too expensive.

So an `Area3D` silently ignores a body whose shape is a trimesh or heightmap: no `body_entered` or `body_exited` fires for it. Godot's built-in physics and Jolt both report such a body on the first physics frame.

If you need a body to be detected by an area, give it a convex shape. A trimesh may still be used *as* an `Area3D`'s own shape to detect convex bodies passing through it.

## Direct query contacts and rays

`collide_shape()` uses native contact manifolds for convex queries against live
primitive, mesh and heightmap fixtures. It returns world-space pairs with the
query-surface point first and target-surface point second. Overlapping pairs
encode the penetration vector; positive-distance contacts within a query margin
use closest surface points. Result caps, collision masks and exclusions apply.

`get_rest_info()` selects the deepest contact, reports a target-surface point and
outward normal, and includes angular motion in the target's contact velocity.
It checks the supplied pose and ignores `motion`. These queries are read-only.
`cast_motion()` honors margin and backs its safe fraction off by native linear
slop; safe and unsafe fractions need not be identical.

Ray queries honor `hit_from_inside`. Concave ray hits report the original input
triangle index, rather than the reordered native BVH index. A backface ray hit
requires both `hit_back_faces` and the concave resource's `backface_collision`;
heightmap rays use the query's backface flag. This ray support does not make
Box3D's simulated concave fixtures two-sided: their physical contacts and
character recovery remain one-sided.

## Shape queries need a convex query shape

`intersect_shape`, `cast_motion`, `collide_shape`, `rest_info`, and `body_test_motion` build a point-cloud proxy of the shape being queried *with*. Trimesh, heightmap, and world-boundary shapes have no finite point cloud.

Passing one of those as the query shape returns no results. They work normally as targets in the world.
This is the current query adapter's support boundary, not a claim that Box3D
cannot collide a convex body with those fixtures. Separation rays have their own
query-only implementation.

## Friction and restitution combine differently

Box3D uses `sqrt(a * b)` for friction and `max(a, b)` for restitution. Godot's built-in physics uses `min(a, b)` and a clamped sum.

Materials tuned against Godot's defaults will not feel the same, so a port usually needs its friction values revisited.

## Ignored joint parameters

Godot's joint API exposes parameters Box3D has no equivalent for, including `HingeJoint3D`'s `LIMIT_RELAXATION` and `LIMIT_SOFTNESS`, `PinJoint3D`'s `IMPULSE_CLAMP`, and most of `SliderJoint3D`'s per-axis tuning (Box3D's prismatic joint is a pure 1-DOF slider).

Setting one logs a warning and is ignored, rather than silently mapping onto something that behaves differently.
