#include "box3d_filter_joint_impl_3d.hpp"

#include <box3d/box3d.h>

Box3DFilterJointImpl3D::Box3DFilterJointImpl3D(Box3DBodyImpl3D* p_body_a, Box3DBodyImpl3D* p_body_b) :
		Box3DJointImpl3D(p_body_a, p_body_b, Transform3D(), Transform3D()) {
	// Disabling collision between the pair is the whole point of this joint.
	set_collision_disabled(true);
}

b3JointId Box3DFilterJointImpl3D::_create_joint_id(
		b3WorldId p_world_id,
		b3BodyId p_body_a,
		b3BodyId p_body_b,
		b3Transform p_local_frame_a,
		b3Transform p_local_frame_b) {
	b3FilterJointDef def = b3DefaultFilterJointDef();
	def.base.bodyIdA = p_body_a;
	def.base.bodyIdB = p_body_b;
	def.base.localFrameA = p_local_frame_a;
	def.base.localFrameB = p_local_frame_b;
	return b3CreateFilterJoint(p_world_id, &def);
}
