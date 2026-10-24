# Character motion recovery

`body_test_motion` uses Box3D's contact manifolds to recover initial overlaps
before casting the requested motion. Sphere, capsule, box, cylinder and convex
query shapes work against primitive/hull, trimesh, heightfield and world-boundary
fixtures. Compound attachments, their local transforms and disabled shape slots
are preserved. Terrain recovery only visits triangles in the query's local
bounding box; bounding boxes do not determine penetration direction or depth.

Recovery solves contact planes together. Movable obstacles have bounded pushes,
and static/kinematic supporting surfaces take precedence when contacts compete.
Higher `collision_priority` takes precedence within the same class of contacts.
This is an adapter recovery policy, not a change to Box3D's rigid-body solver or
a promise of bit-for-bit parity with GodotPhysics3D. A body trapped in a gap
smaller than itself cannot satisfy both surfaces; recovery remains bounded but
does not guarantee escape from impossible overlaps.

Motion casts report a hit when shapes would touch, rather than merely approach within Box3D's linear slop. Near-surface movement still detects the floor, and coplanar seams do not snag a sliding character.

Motion queries are read-only: they do not move the character or collider, apply
forces, or wake a rigid body. Per-call body/object exclusions apply to both
recovery and casting. `recovery_as_collision=false` suppresses recovery-only
collision reporting, not the recovery displacement itself.
Recovery contacts are checked again at the end of the requested movement, with
native slop allowance. A floor left behind by a jump does not remain a reported
supporting contact.

An embedded `SeparationRayShape3D` endpoint is also recovered when
`collide_separation_ray=false`; that flag gates the requested-motion cast for
non-sliding rays, not initial-overlap recovery.

Transform-driven kinematic bodies with a state-sync callback, including `AnimatableBody3D`, queue their
next physics-step target instead of teleporting each animation update. Motion
collisions report their linear/angular velocity so grounded characters ride
them. Initial placement is immediate, and stopped animations clear target-driven
velocity instead of drifting. Explicit velocity-driven kinematic bodies retain
their separate velocity path.
Character transforms apply immediately when Godot publishes them; explicitly
synchronized movement remains visible to subsequent character queries.

The regressions exercise geometric normals and bounded displacement for five
convex shapes, a large query margin, compound floor/wall contacts, priority in a
too-narrow passage, rigid loads on stationary/moving characters, and actual
`move_and_slide` grounding across slopes and terrain seams. A separate regression
checks animated platform carry, stopping, and small linear/angular targets.
Transition checks cover 43/47-degree slopes around a 45-degree floor limit,
descending steps, rough rotated heightmaps, falling through hole boundaries and
jumping from moving/rotating platforms with inherited velocity.
These are behavioral checks, not exact cross-engine trajectory comparisons.

These fixes address adapter behavior. They do not add dynamic concave bodies,
sensor visits by concave bodies; those remain separate Box3D restrictions.
Concave query shapes remain an adapter limitation. Non-uniform collision-shape scaling is not certified by
this milestone; use dimensions on the shape resource and unit-scale body
transforms.
