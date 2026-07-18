#pragma once

#include <godot_cpp/classes/physics_direct_space_state3d_extension.hpp>
#include <godot_cpp/templates/hash_set.hpp>
#include <godot_cpp/variant/rid.hpp>

#include <box3d/types.h>

using namespace godot;

// Builds a b3QueryFilter (direct 32-bit zero-extended layer/mask pass-through, per the
// plan) plus a side-channel RID exclude-set, since Box3D's own filter has no native
// per-query RID-exclude list. Callers check should_exclude() from inside their
// b3*ResultFcn/b3CastResultFcn callback alongside whatever the callback itself needs.
struct Box3DQueryFilter3D {
	b3QueryFilter filter = b3DefaultQueryFilter();
	HashSet<RID> exclude;
	const PhysicsDirectSpaceState3DExtension* direct_state = nullptr;
	bool collide_with_bodies = true;
	bool collide_with_areas = false;
	bool pick_ray = false;
	bool body_test_motion = false;

	Box3DQueryFilter3D() = default;

	Box3DQueryFilter3D(uint32_t p_collision_mask, bool p_collide_with_bodies, bool p_collide_with_areas) :
			collide_with_bodies(p_collide_with_bodies), collide_with_areas(p_collide_with_areas) {
		filter = b3DefaultQueryFilter();
		filter.maskBits = (uint64_t)p_collision_mask;
	}

	bool should_exclude(const RID& p_rid) const {
		return exclude.has(p_rid) || (direct_state != nullptr && direct_state->is_body_excluded_from_query(p_rid));
	}
};
