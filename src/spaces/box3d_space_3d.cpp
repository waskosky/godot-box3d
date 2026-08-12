#include "box3d_space_3d.hpp"

#include "../misc/box3d_globals.hpp"
#include "../misc/type_conversions.hpp"
#include "../objects/box3d_area_impl_3d.hpp"
#include "../objects/box3d_body_impl_3d.hpp"
#include "../objects/box3d_physics_direct_body_state_3d.hpp"
#include "../objects/box3d_shaped_object_impl_3d.hpp"
#include "../servers/box3d_physics_server_3d.hpp"
#include "box3d_physics_direct_space_state_3d.hpp"

#include <box3d/box3d.h>

namespace {
constexpr int SUB_STEP_COUNT = 4;
} // namespace

Box3DSpace3D::Box3DSpace3D() {
	b3WorldDef def = b3DefaultWorldDef();
	// With no task callbacks set, any count above 1 engages Box3D's internal scheduler.
	def.workerCount = box3d_worker_count();
	world_id = b3CreateWorld(&def);

	direct_state = memnew(Box3DPhysicsDirectSpaceState3D);
	direct_state->set_space(this);
}

Box3DSpace3D::~Box3DSpace3D() {
	if (direct_state != nullptr) {
		memdelete(direct_state);
		direct_state = nullptr;
	}
	if (B3_IS_NON_NULL(world_id)) {
		b3DestroyWorld(world_id);
		world_id = b3_nullWorldId;
	}
}

double Box3DSpace3D::get_param(PhysicsServer3D::SpaceParameter p_param) const {
	switch (p_param) {
		case PhysicsServer3D::SPACE_PARAM_CONTACT_RECYCLE_RADIUS:
			return b3World_GetContactRecycleDistance(world_id);
		case PhysicsServer3D::SPACE_PARAM_CONTACT_MAX_SEPARATION:
			return 0.0;
		case PhysicsServer3D::SPACE_PARAM_CONTACT_MAX_ALLOWED_PENETRATION:
			return 0.0;
		case PhysicsServer3D::SPACE_PARAM_CONTACT_DEFAULT_BIAS:
			return 0.0;
		case PhysicsServer3D::SPACE_PARAM_BODY_LINEAR_VELOCITY_SLEEP_THRESHOLD:
			return 0.05;
		case PhysicsServer3D::SPACE_PARAM_BODY_ANGULAR_VELOCITY_SLEEP_THRESHOLD:
			return 0.05;
		case PhysicsServer3D::SPACE_PARAM_BODY_TIME_TO_SLEEP:
			return 0.5;
		case PhysicsServer3D::SPACE_PARAM_SOLVER_ITERATIONS:
			return SUB_STEP_COUNT;
		default:
			return 0.0;
	}
}

void Box3DSpace3D::set_param(PhysicsServer3D::SpaceParameter p_param, double p_value) {
	switch (p_param) {
		case PhysicsServer3D::SPACE_PARAM_CONTACT_RECYCLE_RADIUS:
			b3World_SetContactRecycleDistance(world_id, (float)p_value);
			break;
		default:
			// No direct Box3D equivalent for the remaining space parameters.
			break;
	}
}

void Box3DSpace3D::set_default_area(Box3DAreaImpl3D* p_area) {
	default_area = p_area;
}

void Box3DSpace3D::unregister_body(Box3DBodyImpl3D* p_body) {
	if (!bodies.erase(p_body)) {
		return;
	}
	_remove_object_from_overlaps(p_body);
}

void Box3DSpace3D::unregister_area(Box3DAreaImpl3D* p_area) {
	if (!areas.erase(p_area)) {
		return;
	}

	// Queue exits to the area being detached before dropping its own overlap map. Other
	// areas that monitored it are handled by _remove_object_from_overlaps below.
	const HashMap<Box3DShapedObjectImpl3D*, int32_t> overlaps_copy(p_area->get_overlaps());
	for (const KeyValue<Box3DShapedObjectImpl3D*, int32_t>& entry : overlaps_copy) {
		_queue_area_event(p_area, entry.key, PhysicsServer3D::AREA_BODY_REMOVED);
	}
	p_area->clear_overlaps();
	_remove_object_from_overlaps(p_area);
}

void Box3DSpace3D::_remove_object_from_overlaps(Box3DShapedObjectImpl3D* p_object) {
	for (Box3DAreaImpl3D* area : areas) {
		if (area->remove_overlap_object(p_object)) {
			_queue_area_event(area, p_object, PhysicsServer3D::AREA_BODY_REMOVED);
		}
	}
}

void Box3DSpace3D::remove_shape_overlaps(b3ShapeId p_shape_id) {
	if (!b3Shape_IsValid(p_shape_id)) {
		return;
	}

	if (b3Shape_IsSensor(p_shape_id)) {
		const b3BodyId sensor_body_id = b3Shape_GetBody(p_shape_id);
		auto* area = dynamic_cast<Box3DAreaImpl3D*>(
				static_cast<Box3DShapedObjectImpl3D*>(b3Body_GetUserData(sensor_body_id)));
		if (area == nullptr) {
			return;
		}

		const int capacity = b3Shape_GetSensorCapacity(p_shape_id);
		if (capacity <= 0) {
			return;
		}
		LocalVector<b3ShapeId> visitors;
		visitors.resize(capacity);
		const int count = b3Shape_GetSensorData(p_shape_id, visitors.ptr(), capacity);
		for (int i = 0; i < count; i++) {
			if (!b3Shape_IsValid(visitors[i])) {
				continue;
			}
			const b3BodyId visitor_body_id = b3Shape_GetBody(visitors[i]);
			auto* other = static_cast<Box3DShapedObjectImpl3D*>(b3Body_GetUserData(visitor_body_id));
			if (other != nullptr && other != area && area->remove_overlap(other)) {
				_queue_area_event(area, other, PhysicsServer3D::AREA_BODY_REMOVED);
			}
		}
		return;
	}

	const b3BodyId visitor_body_id = b3Shape_GetBody(p_shape_id);
	auto* visitor = static_cast<Box3DShapedObjectImpl3D*>(b3Body_GetUserData(visitor_body_id));
	if (visitor == nullptr) {
		return;
	}
	for (Box3DAreaImpl3D* area : areas) {
		for (int32_t i = 0; i < area->get_shape_count(); i++) {
			if (!area->has_shape_id(i)) {
				continue;
			}
			const b3ShapeId sensor_shape_id = area->get_shape_id(i);
			const int capacity = b3Shape_GetSensorCapacity(sensor_shape_id);
			if (capacity <= 0) {
				continue;
			}
			LocalVector<b3ShapeId> visitors;
			visitors.resize(capacity);
			const int count = b3Shape_GetSensorData(sensor_shape_id, visitors.ptr(), capacity);
			for (int j = 0; j < count; j++) {
				if (B3_ID_EQUALS(visitors[j], p_shape_id) && area->remove_overlap(visitor)) {
					_queue_area_event(area, visitor, PhysicsServer3D::AREA_BODY_REMOVED);
				}
			}
		}
	}
}

void Box3DSpace3D::step(float p_step) {
	last_step = p_step;

	if (default_area != nullptr) {
		b3World_SetGravity(world_id, godot_to_b3(default_area->compute_gravity(Vector3())));
	}

	_apply_area_overrides();

	for (Box3DBodyImpl3D* body : bodies) {
		body->pre_step();
	}

	b3World_Step(world_id, p_step, SUB_STEP_COUNT);

	_pull_body_events();
	_pull_sensor_events();

	// Manifold pointers are only valid until the next step, so cache contacts now.
	for (Box3DBodyImpl3D* body : bodies) {
		body->refresh_contacts();
	}

	// Drained only so Box3D's per-step event bookkeeping stays consistent; joint events are unused.
	b3World_GetContactEvents(world_id);
	b3World_GetJointEvents(world_id);
}

// Godot walks areas highest priority first, so a REPLACE there wins; ties stay stable.
struct AreaPriorityComparator {
	bool operator()(Box3DAreaImpl3D* p_a, Box3DAreaImpl3D* p_b) const {
		if (p_a->get_priority() != p_b->get_priority()) {
			return p_a->get_priority() > p_b->get_priority();
		}
		return p_a->get_rid().get_id() > p_b->get_rid().get_id();
	}
};

Box3DSpace3D::AreaOverrides Box3DSpace3D::compute_area_overrides(Box3DBodyImpl3D* p_body) const {
	AreaOverrides result;
	result.linear_damp = p_body->get_linear_damping();
	result.angular_damp = p_body->get_angular_damping();

	LocalVector<Box3DAreaImpl3D*> overlapping;
	for (Box3DAreaImpl3D* area : areas) {
		if (area->get_gravity_mode() == PhysicsServer3D::AREA_SPACE_OVERRIDE_DISABLED &&
				area->get_linear_damp_mode() == PhysicsServer3D::AREA_SPACE_OVERRIDE_DISABLED &&
				area->get_angular_damp_mode() == PhysicsServer3D::AREA_SPACE_OVERRIDE_DISABLED) {
			continue;
		}
		if (area->get_overlaps().has(p_body)) {
			overlapping.push_back(area);
		}
	}
	if (overlapping.is_empty()) {
		return result;
	}
	overlapping.sort_custom<AreaPriorityComparator>();

	bool gravity_done = false;
	bool linear_done = false;
	bool angular_done = false;

	for (Box3DAreaImpl3D* area : overlapping) {
		const PhysicsServer3D::AreaSpaceOverrideMode gravity_mode = area->get_gravity_mode();
		if (!gravity_done && gravity_mode != PhysicsServer3D::AREA_SPACE_OVERRIDE_DISABLED) {
			const Vector3 gravity = area->compute_gravity(p_body->get_transform().origin);
			result.affects_gravity = true;
			switch (gravity_mode) {
				case PhysicsServer3D::AREA_SPACE_OVERRIDE_COMBINE:
					result.gravity += gravity;
					break;
				case PhysicsServer3D::AREA_SPACE_OVERRIDE_COMBINE_REPLACE:
					result.gravity += gravity;
					result.replaces_world_gravity = true;
					gravity_done = true;
					break;
				case PhysicsServer3D::AREA_SPACE_OVERRIDE_REPLACE:
					result.gravity = gravity;
					result.replaces_world_gravity = true;
					gravity_done = true;
					break;
				case PhysicsServer3D::AREA_SPACE_OVERRIDE_REPLACE_COMBINE:
					result.gravity = gravity;
					result.replaces_world_gravity = true;
					break;
				default:
					break;
			}
		}

		const PhysicsServer3D::AreaSpaceOverrideMode linear_mode = area->get_linear_damp_mode();
		if (!linear_done && linear_mode != PhysicsServer3D::AREA_SPACE_OVERRIDE_DISABLED) {
			const real_t damp = area->get_linear_damp();
			switch (linear_mode) {
				case PhysicsServer3D::AREA_SPACE_OVERRIDE_COMBINE:
					result.linear_damp += damp;
					break;
				case PhysicsServer3D::AREA_SPACE_OVERRIDE_COMBINE_REPLACE:
					result.linear_damp += damp;
					linear_done = true;
					break;
				case PhysicsServer3D::AREA_SPACE_OVERRIDE_REPLACE:
					result.linear_damp = damp;
					linear_done = true;
					break;
				case PhysicsServer3D::AREA_SPACE_OVERRIDE_REPLACE_COMBINE:
					result.linear_damp = damp;
					break;
				default:
					break;
			}
		}

		const PhysicsServer3D::AreaSpaceOverrideMode angular_mode = area->get_angular_damp_mode();
		if (!angular_done && angular_mode != PhysicsServer3D::AREA_SPACE_OVERRIDE_DISABLED) {
			const real_t damp = area->get_angular_damp();
			switch (angular_mode) {
				case PhysicsServer3D::AREA_SPACE_OVERRIDE_COMBINE:
					result.angular_damp += damp;
					break;
				case PhysicsServer3D::AREA_SPACE_OVERRIDE_COMBINE_REPLACE:
					result.angular_damp += damp;
					angular_done = true;
					break;
				case PhysicsServer3D::AREA_SPACE_OVERRIDE_REPLACE:
					result.angular_damp = damp;
					angular_done = true;
					break;
				case PhysicsServer3D::AREA_SPACE_OVERRIDE_REPLACE_COMBINE:
					result.angular_damp = damp;
					break;
				default:
					break;
			}
		}
	}

	return result;
}

void Box3DSpace3D::_apply_area_overrides() {
	for (Box3DBodyImpl3D* body : bodies) {
		if (!body->has_body_id() || body->is_omitting_force_integration()) {
			continue;
		}

		const AreaOverrides overrides = compute_area_overrides(body);

		b3Body_SetLinearDamping(body->get_body_id(), (float)overrides.linear_damp);
		b3Body_SetAngularDamping(body->get_body_id(), (float)overrides.angular_damp);

		if (!overrides.affects_gravity) {
			b3Body_SetGravityScale(body->get_body_id(), (float)body->get_gravity_scale());
			continue;
		}

		// Box3D has no per-body gravity vector, so contribute the area gravity as an
		// equivalent velocity delta. A force would divide by mass and damp differently.
		const float world_scale = overrides.replaces_world_gravity ? 0.0f : (float)body->get_gravity_scale();
		b3Body_SetGravityScale(body->get_body_id(), world_scale);
		const Vector3 delta = overrides.gravity * body->get_gravity_scale() * last_step;
		const b3Vec3 velocity = b3Body_GetLinearVelocity(body->get_body_id());
		b3Body_SetLinearVelocity(body->get_body_id(), b3Add(velocity, godot_to_b3(delta)));
	}
}

void Box3DSpace3D::_pull_body_events() {
	// event.userData is set to the raw C++ object pointer at body creation time (see
	// Box3DBodyImpl3D::_create_body_id / Box3DAreaImpl3D::_create_body_id), but both
	// regular bodies AND area-backing kinematic bodies generate move events (areas move
	// too). The two are sibling classes under Box3DShapedObjectImpl3D, not related to
	// each other, so a blind static_cast<Box3DBodyImpl3D*> on an area's userData produces
	// a garbage pointer and crashes. dynamic_cast safely yields nullptr for area bodies.
	const b3BodyEvents events = b3World_GetBodyEvents(world_id);
	for (int i = 0; i < events.moveCount; i++) {
		const b3BodyMoveEvent& event = events.moveEvents[i];
		auto* body = dynamic_cast<Box3DBodyImpl3D*>(static_cast<Box3DShapedObjectImpl3D*>(event.userData));
		if (body == nullptr || !body->get_state_sync_callback().is_valid()) {
			continue;
		}
		body->set_needs_state_sync(true);
	}
}

void Box3DSpace3D::_pull_sensor_events() {
	const b3SensorEvents events = b3World_GetSensorEvents(world_id);

	for (int i = 0; i < events.beginCount; i++) {
		const b3SensorBeginTouchEvent& event = events.beginEvents[i];
		if (!b3Shape_IsValid(event.sensorShapeId) || !b3Shape_IsValid(event.visitorShapeId)) {
			continue;
		}
		const b3BodyId sensor_body_id = b3Shape_GetBody(event.sensorShapeId);
		const b3BodyId visitor_body_id = b3Shape_GetBody(event.visitorShapeId);
		auto* area = static_cast<Box3DAreaImpl3D*>(b3Body_GetUserData(sensor_body_id));
		auto* other = static_cast<Box3DShapedObjectImpl3D*>(b3Body_GetUserData(visitor_body_id));
		if (area == nullptr || other == nullptr || other == area) {
			continue;
		}

		if (area->add_overlap(other)) {
			_queue_area_event(area, other, PhysicsServer3D::AREA_BODY_ADDED);
		}
	}

	for (int i = 0; i < events.endCount; i++) {
		const b3SensorEndTouchEvent& event = events.endEvents[i];
		if (!b3Shape_IsValid(event.sensorShapeId)) {
			continue;
		}
		const b3BodyId sensor_body_id = b3Shape_GetBody(event.sensorShapeId);
		auto* area = static_cast<Box3DAreaImpl3D*>(b3Body_GetUserData(sensor_body_id));
		if (area == nullptr) {
			continue;
		}

		Box3DShapedObjectImpl3D* other = nullptr;
		if (b3Shape_IsValid(event.visitorShapeId)) {
			const b3BodyId visitor_body_id = b3Shape_GetBody(event.visitorShapeId);
			other = static_cast<Box3DShapedObjectImpl3D*>(b3Body_GetUserData(visitor_body_id));
		}
		if (other == nullptr || other == area) {
			continue;
		}

		if (area->remove_overlap(other)) {
			_queue_area_event(area, other, PhysicsServer3D::AREA_BODY_REMOVED);
		}
	}
}

void Box3DSpace3D::_queue_area_event(
		Box3DAreaImpl3D* p_area,
		Box3DShapedObjectImpl3D* p_other,
		PhysicsServer3D::AreaBodyStatus p_status) {
	auto* other_body = dynamic_cast<Box3DBodyImpl3D*>(p_other);
	auto* other_area = dynamic_cast<Box3DAreaImpl3D*>(p_other);

	PendingAreaEvent event;
	event.area_rid = p_area->get_rid();
	event.status = p_status;
	event.other_rid = p_other->get_rid();
	event.other_instance_id = p_other->get_instance_id();
	event.other_is_area = other_area != nullptr;

	if (other_body != nullptr && p_area->has_body_monitor_callback()) {
		pending_area_events.push_back(event);
	} else if (other_area != nullptr && p_area->has_area_monitor_callback()) {
		pending_area_events.push_back(event);
	}
}

// Mirrors GodotBody3D::call_queries: force integration then state sync, back to back, so a
// node that applies forces from its state-sync callback has them picked up by the next step.
void Box3DSpace3D::_call_body_queries() {
	LocalVector<RID> body_rids;
	body_rids.reserve(bodies.size());
	for (Box3DBodyImpl3D* body : bodies) {
		body_rids.push_back(body->get_rid());
	}

	// Callbacks may detach or free bodies, so re-resolve each RID instead of holding a
	// pointer across the call.
	for (const RID& body_rid : body_rids) {
		Box3DBodyImpl3D* body = Box3DPhysicsServer3D::get_singleton()->get_body(body_rid);
		if (body == nullptr || body->get_space() != this) {
			continue;
		}

		const Callable integration_callback = body->get_force_integration_callback();
		if (integration_callback.is_valid()) {
			const Variant userdata = body->get_force_integration_userdata();
			Array arguments;
			if (userdata.get_type() == Variant::NIL) {
				arguments.resize(1);
				arguments[0] = body->get_direct_state_or_null();
			} else {
				arguments.resize(2);
				arguments[0] = body->get_direct_state_or_null();
				arguments[1] = userdata;
			}
			integration_callback.callv(arguments);
		}

		body = Box3DPhysicsServer3D::get_singleton()->get_body(body_rid);
		if (body == nullptr || body->get_space() != this) {
			continue;
		}
		// Godot syncs every awake body, not just ones Box3D reported as moved: nodes like
		// VehicleBody3D drive themselves from this callback and would never start moving.
		if (body->is_sleeping() && !body->needs_state_sync()) {
			continue;
		}
		const Callable sync_callback = body->get_state_sync_callback();
		if (sync_callback.is_valid()) {
			Array arguments;
			arguments.resize(1);
			arguments[0] = body->get_direct_state_or_null();
			sync_callback.callv(arguments);
		}
		body->set_needs_state_sync(false);
	}
}

void Box3DSpace3D::flush_queries() {
	flushing_queries = true;

	_call_body_queries();

	// Callbacks may detach/free more objects and enqueue follow-up exits. Iterate a copy so
	// those mutations cannot relocate the vector underneath this loop; they run next flush.
	const LocalVector<PendingAreaEvent> events(pending_area_events);
	pending_area_events.clear();
	for (const PendingAreaEvent& event : events) {
		Box3DAreaImpl3D* area = Box3DPhysicsServer3D::get_singleton()->get_area(event.area_rid);
		if (area == nullptr || area->get_space() != this) {
			continue;
		}
		const Callable callback = event.other_is_area
				? area->get_area_monitor_callback()
				: area->get_body_monitor_callback();
		if (!callback.is_valid()) {
			continue;
		}
		// A previous callback in this batch may have freed the object. Its exit is still
		// meaningful to an already-tracking Area3D, but a stale enter must not resurrect it.
		if (event.status == PhysicsServer3D::AREA_BODY_ADDED) {
			const bool other_exists = event.other_is_area
					? Box3DPhysicsServer3D::get_singleton()->get_area(event.other_rid) != nullptr
					: Box3DPhysicsServer3D::get_singleton()->get_body(event.other_rid) != nullptr;
			if (!other_exists) {
				continue;
			}
		}
		Array arguments;
		arguments.resize(5);
		arguments[0] = event.status;
		arguments[1] = event.other_rid;
		arguments[2] = event.other_instance_id;
		arguments[3] = 0;
		arguments[4] = 0;
		callback.callv(arguments);
	}

	flushing_queries = false;
}
