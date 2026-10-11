---
title: Behavior differences
---

# Behavior differences

Places where this backend behaves differently from Godot's built-in physics.
Some are Box3D design restrictions; others are adapter limitations or deliberate
integration choices. Adapter limitations can be improved without changing the
underlying engine. See [Character motion recovery](character-motion.md) for the
current recovery policy.

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

## `collide_shape()` currently reports contact points without penetration depth

This adapter currently implements this query using GJK witness points, which do
not provide penetration depth. Box3D also exposes penetration manifolds; the
character overlap-recovery path uses them, but `collide_shape()` has not yet
been migrated. This is an adapter gap, not an inherent Box3D limitation.

For a genuinely overlapping pair, both returned points are the same witness point, so the pair's separation reads as zero. Godot's built-in physics returns two points whose distance is the penetration depth.

Whether shapes overlap, which bodies they are, `max_results`, and `collision_mask` all behave normally. Use it to answer "is anything here, and roughly where" rather than "how deep".

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
