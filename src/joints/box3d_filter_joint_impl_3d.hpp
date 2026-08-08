#pragma once

#include "box3d_joint_impl_3d.hpp"

// Backs a per-pair collision exception. Box3D's filter joint exists purely to stop two
// bodies colliding, so this is never exposed as a Godot joint RID.
class Box3DFilterJointImpl3D final : public Box3DJointImpl3D {
public:
	Box3DFilterJointImpl3D(Box3DBodyImpl3D* p_body_a, Box3DBodyImpl3D* p_body_b);

protected:
	b3JointId _create_joint_id(
			b3WorldId p_world_id,
			b3BodyId p_body_a,
			b3BodyId p_body_b,
			b3Transform p_local_frame_a,
			b3Transform p_local_frame_b) override;
};
