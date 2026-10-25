extends Node3D

const EXPECTED_ENGINE := "Box3D Physics"
const WebWorkload = preload("res://stress_test.gd")

class MovingPlatform extends AnimatableBody3D:
    var frames := 0
    var stopped_position := Vector3.ZERO

    func _physics_process(delta: float) -> void:
        if frames < 120:
            var target := transform
            target.origin.x += 0.6 * delta
            transform = target
        elif frames == 122:
            stopped_position = position
        frames += 1

var _body: RigidBody3D
var _area_entered := false
var _door: RigidBody3D
var _initial_door_rotation := 0.0
var _characters: Array[CharacterBody3D] = []
var _loads: Array[RigidBody3D] = []
var _character_support_ok := true
var _terrain: Array[Dictionary] = []
var _terrain_ok := true
var _platform: MovingPlatform
var _platform_rider: CharacterBody3D
var _platform_grounded := 0
var _platform_ok := true
var _physics_usec := 0
var _physics_frames := 0
var _status_label: Label
var _result_lines: Array[String] = []


func _ready() -> void:
    if OS.has_feature("web") and not WebWorkload.web_profile().is_empty():
        set_physics_process(false)
        add_child(WebWorkload.new())
        return
    _create_status_ui()
    _append_status("Godot Box3D Web smoke test")
    _append_status("Platform: %s" % OS.get_name())
    _append_status("Requested backend: %s" % ProjectSettings.get_setting("physics/3d/physics_engine", ""))
    _append_status("Extension class registered: %s" % ClassDB.class_exists(&"Box3DPhysicsServer3D"))
    _append_status("Active backend: %s" % PhysicsServer3D.get_class())

    _create_camera_and_light()
    _create_ground()
    _create_falling_body_and_area()
    _create_hinge_door()
    _create_character_supports()
    _create_terrain_characters()
    _create_moving_platform()
    _create_query_targets()
    _run_checks()


func _box_collision(size: Vector3) -> CollisionShape3D:
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    return collision


func _create_character_supports() -> void:
    for index in 2:
        var character := CharacterBody3D.new()
        character.position = Vector3(-4.0 + index * 7.0, 0.5, 3.0)
        character.add_child(_box_collision(Vector3(2, 1, 2)))
        add_child(character)
        _characters.append(character)

        var load_body := RigidBody3D.new()
        load_body.position = character.position + Vector3(0, 1.3, 0)
        load_body.add_child(_box_collision(Vector3(0.4, 0.4, 0.4)))
        add_child(load_body)
        _loads.append(load_body)


func _physics_process(_delta: float) -> void:
    var started := Time.get_ticks_usec()
    for index in _characters.size():
        var character := _characters[index]
        character.velocity = Vector3(index * 0.15, -0.5, 0)
        character.move_and_slide()
        if absf(character.position.y - 0.5) > 0.15:
            _character_support_ok = false
    for fixture in _terrain:
        var character: CharacterBody3D = fixture.body
        character.velocity = Vector3(1.0, -1.0, 0.0)
        character.move_and_slide()
        var expected_y: float = fixture.floor.position.y + (0.5 if fixture.kind == 2 else 0.75)
        if fixture.kind == 0:
            expected_y = -0.25 + 0.25 / cos(PI / 6.0) + tan(PI / 6.0) * (character.position.x - fixture.floor.position.x) + 0.2 / cos(PI / 6.0) + 0.3
        if absf(character.position.y - expected_y) > 0.045:
            _terrain_ok = false
        fixture.max_height_error = maxf(fixture.max_height_error, absf(character.position.y - expected_y))
        if character.is_on_floor():
            fixture.grounded += 1
    _platform_rider.velocity = Vector3(0, -1, 0)
    _platform_rider.move_and_slide()
    if _platform_rider.is_on_floor():
        _platform_grounded += 1
    if absf(_platform_rider.position.y - 2.5) > 0.03:
        _platform_ok = false
    _physics_usec += Time.get_ticks_usec() - started
    _physics_frames += 1


func _create_moving_platform() -> void:
    _platform = MovingPlatform.new()
    _platform.position = Vector3(0, 1.5, 5)
    _platform.collision_layer = 16
    _platform.add_child(_box_collision(Vector3(4, 1, 2)))
    var visual := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(4, 1, 2)
    visual.mesh = mesh
    _platform.add_child(visual)
    add_child(_platform)
    _platform_rider = CharacterBody3D.new()
    _platform_rider.collision_layer = 0
    _platform_rider.collision_mask = 16
    _platform_rider.position = Vector3(0, 2.5, 5)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.2
    capsule.height = 1.0
    collision.shape = capsule
    _platform_rider.add_child(collision)
    var rider_visual := MeshInstance3D.new()
    var rider_mesh := CapsuleMesh.new()
    rider_mesh.radius = capsule.radius
    rider_mesh.height = capsule.height
    rider_visual.mesh = rider_mesh
    _platform_rider.add_child(rider_visual)
    add_child(_platform_rider)


func _create_query_targets() -> void:
    for index in 2:
        var body := StaticBody3D.new()
        body.position.x = 30.0 + index * 10.0
        body.collision_layer = 32
        body.collision_mask = 0
        if index == 0:
            body.add_child(_box_collision(Vector3.ONE))
        else:
            var collision := CollisionShape3D.new()
            var mesh := BoxMesh.new()
            mesh.size = Vector3.ONE
            var shape := mesh.create_trimesh_shape()
            shape.backface_collision = true
            collision.shape = shape
            body.add_child(collision)
        add_child(body)


func _check_direct_queries() -> bool:
    var state := get_world_3d().direct_space_state
    var query := PhysicsShapeQueryParameters3D.new()
    query.collision_mask = 32
    var box := BoxShape3D.new()
    box.size = Vector3.ONE
    query.shape = box
    query.transform.origin = Vector3(30.6, 0, 0)
    var pairs := state.collide_shape(query)
    var ok := pairs.size() >= 2 and (pairs[1] - pairs[0]).distance_to(Vector3(0.4, 0, 0)) < 0.02
    var sphere := SphereShape3D.new()
    sphere.radius = 0.25
    query.shape = sphere
    query.transform.origin.x = 40.6
    pairs = state.collide_shape(query)
    ok = ok and pairs.size() >= 2 and (pairs[1] - pairs[0]).distance_to(Vector3(0.15, 0, 0)) < 0.02
    query.transform.origin.x = 30.6
    var rest := state.get_rest_info(query)
    ok = ok and rest.get("normal", Vector3.ZERO).distance_to(Vector3.RIGHT) < 0.01
    query.transform.origin.x = 32.0
    query.motion = Vector3(-3, 0, 0)
    ok = ok and state.get_rest_info(query).is_empty()
    query.motion = Vector3.ZERO
    query.transform.origin.x = 30.8
    query.margin = 0.1
    ok = ok and not state.intersect_shape(query).is_empty()
    query.transform.origin.x = 32.0
    query.motion = Vector3(-2, 0, 0)
    ok = ok and absf(state.cast_motion(query)[0] - 0.575) < 0.001
    var ray := PhysicsRayQueryParameters3D.create(Vector3(30, 0, 0), Vector3(32, 0, 0), 32)
    ray.hit_from_inside = false
    ok = ok and state.intersect_ray(ray).is_empty()
    ray.from.x = 40.0
    ray.to.x = 42.0
    ray.hit_back_faces = true
    var hit := state.intersect_ray(ray)
    ok = ok and hit.get("face_index", -1) >= 0 and hit.get("normal", Vector3.ZERO).distance_to(Vector3.LEFT) < 0.01
    return ok


func _create_terrain_characters() -> void:
    for index in 3:
        var floor_body := StaticBody3D.new()
        floor_body.collision_layer = 2 << index
        # Godot pair filtering accepts either body's mask. Only each terrain
        # character should interact with these floors, not the hinge/load demo.
        floor_body.collision_mask = 0
        floor_body.position = Vector3(-4.0 + index * 4.0, -0.25, -2.5)
        var collision := CollisionShape3D.new()
        var mesh := BoxMesh.new()
        mesh.size = Vector3(6, 0.5, 3)
        if index == 0:
            var box := BoxShape3D.new()
            box.size = mesh.size
            collision.shape = box
            floor_body.rotation.z = PI / 6.0
        elif index == 1:
            collision.shape = mesh.create_trimesh_shape()
        else:
            var heightmap := HeightMapShape3D.new()
            heightmap.map_width = 9
            heightmap.map_depth = 9
            var data := PackedFloat32Array()
            data.resize(81)
            data.fill(0.0)
            heightmap.map_data = data
            collision.shape = heightmap
            floor_body.position.y = 0.0
        floor_body.add_child(collision)
        var visual := MeshInstance3D.new()
        visual.mesh = mesh
        floor_body.add_child(visual)
        add_child(floor_body)
        var character := CharacterBody3D.new()
        character.collision_layer = 0
        character.collision_mask = floor_body.collision_layer
        var capsule := CapsuleShape3D.new()
        capsule.radius = 0.2
        capsule.height = 1.0
        var solid := CollisionShape3D.new()
        solid.shape = capsule
        character.add_child(solid)
        # Cross the centered heightmap's negative half, not just the native
        # corner-origin grid's old positive-coordinate overlap.
        character.position = floor_body.position + Vector3(-1.5 if index == 2 else -1.0, 0.48 if index == 2 else 0.73, -0.5 if index == 2 else 0.5)
        if index == 0:
            character.position.y = -0.25 + 0.25 / cos(PI / 6.0) - tan(PI / 6.0) + 0.2 / cos(PI / 6.0) + 0.3 - 0.02
        var actor_mesh := MeshInstance3D.new()
        var capsule_mesh := CapsuleMesh.new()
        capsule_mesh.radius = capsule.radius
        capsule_mesh.height = capsule.height
        actor_mesh.mesh = capsule_mesh
        character.add_child(actor_mesh)
        add_child(character)
        _terrain.append({"body": character, "floor": floor_body, "kind": index, "start": character.position.x, "grounded": 0, "max_height_error": 0.0})


func _create_status_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var panel := ColorRect.new()
    panel.position = Vector2(16, 16)
    panel.size = Vector2(700, 400)
    panel.color = Color(0.02, 0.02, 0.02, 0.82)
    layer.add_child(panel)

    _status_label = Label.new()
    _status_label.position = Vector2(16, 12)
    _status_label.size = Vector2(668, 376)
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(_status_label)


func _append_status(line: String) -> void:
    _result_lines.append(line)
    _status_label.text = "\n".join(_result_lines)
    print(line)


func _create_camera_and_light() -> void:
    var camera := Camera3D.new()
    camera.position = Vector3(0, 5, 12)
    camera.rotation_degrees = Vector3(-18, 0, 0)
    add_child(camera)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-50, -30, 0)
    light.shadow_enabled = true
    add_child(light)


func _create_ground() -> void:
    var ground := StaticBody3D.new()
    ground.position = Vector3(0, -0.5, 0)

    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(12, 1, 12)
    collision.shape = shape
    ground.add_child(collision)

    var mesh := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = shape.size
    mesh.mesh = box_mesh
    ground.add_child(mesh)
    add_child(ground)


func _create_falling_body_and_area() -> void:
    var area := Area3D.new()
    area.position = Vector3(0, 2.5, 0)
    area.body_entered.connect(func(_entered_body: Node3D) -> void: _area_entered = true)

    var area_collision := CollisionShape3D.new()
    var area_shape := BoxShape3D.new()
    area_shape.size = Vector3(3, 1, 3)
    area_collision.shape = area_shape
    area.add_child(area_collision)
    add_child(area)

    _body = RigidBody3D.new()
    _body.position = Vector3(0, 6, 0)

    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 0.5
    collision.shape = shape
    _body.add_child(collision)

    var mesh := MeshInstance3D.new()
    var sphere_mesh := SphereMesh.new()
    sphere_mesh.radius = 0.5
    sphere_mesh.height = 1.0
    mesh.mesh = sphere_mesh
    _body.add_child(mesh)
    add_child(_body)


func _create_hinge_door() -> void:
    var anchor := StaticBody3D.new()
    anchor.name = "HingeAnchor"
    anchor.position = Vector3(3, 1.5, 0)

    var anchor_collision := CollisionShape3D.new()
    var anchor_shape := BoxShape3D.new()
    anchor_shape.size = Vector3(0.2, 3, 0.2)
    anchor_collision.shape = anchor_shape
    anchor.add_child(anchor_collision)
    add_child(anchor)

    _door = RigidBody3D.new()
    _door.name = "HingeDoor"
    _door.position = Vector3(4, 1.5, 0)
    _door.gravity_scale = 0.0
    _door.can_sleep = false

    var door_collision := CollisionShape3D.new()
    var door_shape := BoxShape3D.new()
    door_shape.size = Vector3(2, 3, 0.15)
    door_collision.shape = door_shape
    _door.add_child(door_collision)

    var door_mesh := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = door_shape.size
    door_mesh.mesh = box_mesh
    _door.add_child(door_mesh)
    add_child(_door)

    var hinge := HingeJoint3D.new()
    hinge.position = Vector3(3, 1.5, 0)
    hinge.node_a = NodePath("../HingeAnchor")
    hinge.node_b = NodePath("../HingeDoor")
    add_child(hinge)

    _initial_door_rotation = _door.rotation.z
    _door.apply_torque_impulse(Vector3(0, 0, 4.0))


func _run_checks() -> void:
    for _frame in 180:
        await get_tree().physics_frame

    var character := CharacterBody3D.new()
    character.position = Vector3(-3.0, 1.6, 0.0)
    var body_collision := CollisionShape3D.new()
    var body_shape := CapsuleShape3D.new()
    body_shape.radius = 0.25
    body_shape.height = 0.5
    body_collision.shape = body_shape
    character.add_child(body_collision)
    var ray_collision := CollisionShape3D.new()
    ray_collision.rotation.x = PI / 2.0
    var ray_shape := SeparationRayShape3D.new()
    ray_shape.length = 1.5
    ray_collision.shape = ray_shape
    character.add_child(ray_collision)
    add_child(character)
    await get_tree().physics_frame

    var motion_parameters := PhysicsTestMotionParameters3D.new()
    motion_parameters.from = character.global_transform
    motion_parameters.motion = Vector3(0.0, -0.25, 0.0)
    motion_parameters.margin = 0.001
    motion_parameters.collide_separation_ray = true
    var ray_result := PhysicsTestMotionResult3D.new()
    var ray_hit := PhysicsServer3D.body_test_motion(character.get_rid(), motion_parameters, ray_result)
    var ray_ok := (
        ray_hit
        and ray_result.get_collision_count() == 1
        and ray_result.get_collision_local_shape() == 1
        and ray_result.get_collision_normal().dot(Vector3.UP) > 0.99
        and absf(ray_result.get_collision_unsafe_fraction() - 0.4) < 0.03
    )

    var failures: Array[String] = []
    if PhysicsServer3D.get_class() != "Box3DPhysicsServer3D":
        failures.append("Box3D was requested but is not the active physics server")
    var direct_queries_ok := _check_direct_queries()
    if not direct_queries_ok:
        failures.append("Direct queries returned incorrect contact geometry, margins or ray options")
    for fixture in _terrain:
        print("Terrain %d: progress=%.3f grounded=%d height_error=%.4f" % [fixture.kind, fixture.body.position.x - fixture.start, fixture.grounded, fixture.max_height_error])
        if fixture.body.position.x - fixture.start < 0.5 or fixture.grounded < 170:
            _terrain_ok = false
    if not _terrain_ok:
        failures.append("Character slope/terrain movement lost support or stalled")
    print("Animated platform: x=%.3f rider_x=%.3f grounded=%d stopped_velocity=%s" % [_platform.position.x, _platform_rider.position.x, _platform_grounded, _platform_rider.get_platform_velocity()])
    _platform_ok = _platform_ok and (
        absf(_platform.position.x - 1.2) < 0.04
        and absf(_platform_rider.position.x - _platform.position.x) < 0.05
        and _platform.position.distance_to(_platform.stopped_position) < 0.001
        and _platform_rider.get_platform_velocity().length() < 0.03
        and _platform_grounded >= 170
    )
    if not _platform_ok:
        failures.append("Animated platform did not carry its character or stop cleanly")
    motion_parameters.from.origin.y = 1.4
    motion_parameters.motion = Vector3.ZERO
    motion_parameters.collide_separation_ray = false
    motion_parameters.recovery_as_collision = true
    var embedded_result := PhysicsTestMotionResult3D.new()
    var embedded_ok := PhysicsServer3D.body_test_motion(character.get_rid(), motion_parameters, embedded_result) and embedded_result.get_travel().y > 0.09
    if not embedded_ok:
        failures.append("Embedded separation ray did not recover without casting")
    var requested_backend: String = ProjectSettings.get_setting("physics/3d/physics_engine", "")
    if requested_backend != EXPECTED_ENGINE:
        failures.append("Project physics backend is not Box3D")
    if not ClassDB.class_exists(&"Box3DPhysicsServer3D"):
        failures.append("Box3D extension class is not registered")
    if _body.global_position.y >= 5.0 or _body.global_position.y <= -3.0:
        failures.append("Falling body did not contact the ground correctly")
    if not _area_entered:
        failures.append("Area body_entered signal did not fire")
    if absf(_door.rotation.z - _initial_door_rotation) < 0.02:
        failures.append("Hinge-connected body did not rotate")
    if not ray_ok:
        failures.append("SeparationRayShape3D motion query did not snap to the floor")
    for index in _characters.size():
        if absf(_loads[index].position.y - (_characters[index].position.y + 0.7)) > 0.06:
            _character_support_ok = false
        if absf(_loads[index].position.x - _characters[index].position.x) > 0.8:
            _character_support_ok = false
    if not _character_support_ok:
        failures.append("A rigid load lost support or drove a character into the floor")

    _append_status("Body Y after 180 frames: %.3f" % _body.global_position.y)
    _append_status("Area event received: %s" % _area_entered)
    _append_status("Door rotation delta: %.3f" % absf(_door.rotation.z - _initial_door_rotation))
    _append_status("Separation ray motion query: %s" % ("PASS" if ray_ok else "FAIL"))
    _append_status("Idle/moving character rigid-load support: %s" % ("PASS" if _character_support_ok else "FAIL"))
    _append_status("Slope/terrain character movement: %s" % ("PASS" if _terrain_ok else "FAIL"))
    _append_status("Separation ray recovery without casting: %s" % ("PASS" if embedded_ok else "FAIL"))
    _append_status("Animated platform character support: %s" % ("PASS" if _platform_ok else "FAIL"))
    _append_status("Direct query geometry/options: %s" % ("PASS" if direct_queries_ok else "FAIL"))
    _append_status("Six character queries: %.1f us/frame average" % (float(_physics_usec) / maxi(_physics_frames, 1)))

    if failures.is_empty():
        _append_status("RESULT: PASS")
    else:
        for failure in failures:
            _append_status("FAIL: %s" % failure)
        _append_status("RESULT: FAIL")
