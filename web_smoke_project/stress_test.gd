extends Node3D
## Opt-in, bounded workload. Measurements are diagnostics for the named browser/host.

const PROFILES := {
    "representative": {"characters": 16, "rigids": 128, "grid": 65},
    "stress": {"characters": 32, "rigids": 512, "grid": 129},
}
const CYCLES := 6
const ACTIVE_SECONDS := 10.0

var _profile := "representative"
var _world: Node3D
var _characters: Array[CharacterBody3D] = []
var _rigids: Array[RigidBody3D] = []
var _frame_ms: Array[float] = []
var _physics_ms: Array[float] = []
var _query_ms: Array[float] = []
var _active := false
var _ticks := 0
var _failures: Array[String] = []
var _label: Label
var _records: Array[Dictionary] = []
var _last_report := 0
var _last_frame_usec := 0


static func web_profile() -> String:
    if not OS.has_feature("web"):
        return ""
    # Interface calls proxy to the browser thread; eval reads a worker's URL.
    var location: JavaScriptObject = JavaScriptBridge.get_interface("location")
    var query: String = str(location.search).trim_prefix("?")
    for argument in query.split("&"):
        var fields: PackedStringArray = argument.split("=", true, 1)
        if fields[0].uri_decode() == "box3d_stress":
            return fields[1].uri_decode() if fields.size() > 1 and not fields[1].is_empty() else "representative"
    return ""


func _ready() -> void:
    if OS.has_feature("web"):
        var requested: String = web_profile()
        if PROFILES.has(requested):
            _profile = requested
    elif "--stress" in OS.get_cmdline_user_args():
        _profile = "stress"
    var camera := Camera3D.new()
    camera.position = Vector3(0, 27, 31)
    camera.rotation_degrees.x = -40
    add_child(camera)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-65, -25, 0)
    add_child(light)
    var canvas := CanvasLayer.new()
    add_child(canvas)
    _label = Label.new()
    _label.position = Vector2(20, 16)
    _label.add_theme_color_override("font_color", Color.WHITE)
    _label.add_theme_color_override("font_shadow_color", Color.BLACK)
    _label.add_theme_constant_override("shadow_outline_size", 4)
    canvas.add_child(_label)
    if PhysicsServer3D.get_class() != &"Box3DPhysicsServer3D":
        _failures.append("Box3D server did not activate")
    # Exercises real GPU-buffer readback in worker-main hosts before physics setup.
    var probe := BoxMesh.new()
    var arrays := probe.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    for index in indices:
        if index < 0 or index >= vertices.size():
            _failures.append("GPU mesh readback returned an invalid index")
            break
    if indices.size() != 36 or probe.create_trimesh_shape() == null:
        _failures.append("GPU mesh readback did not create collision geometry")
    _run()


func _sample_height(x: float, z: float) -> float:
    return 0.12 * sin(x * 0.25) * cos(z * 0.2)


func _build_world() -> void:
    _world = Node3D.new()
    add_child(_world)
    var grid: int = PROFILES[_profile].grid
    var data := PackedFloat32Array()
    var vertices := PackedVector3Array()
    var indices := PackedInt32Array()
    var half := (grid - 1) * 0.5
    for z in grid:
        for x in grid:
            var height := _sample_height(x - half, z - half)
            data.append(height)
            vertices.append(Vector3(x - half, height, z - half))
            if x < grid - 1 and z < grid - 1:
                var a := z * grid + x
                # Godot rendering uses clockwise front faces; the collision grid
                # is constructed independently by HeightMapShape3D.
                indices.append_array(PackedInt32Array([a, a + 1, a + grid, a + 1, a + grid + 1, a + grid]))
    var terrain := HeightMapShape3D.new()
    terrain.map_width = grid
    terrain.map_depth = grid
    terrain.map_data = data
    for owner in 2:
        var floor_body := StaticBody3D.new()
        floor_body.collision_layer = 1
        floor_body.collision_mask = 0
        var collision := CollisionShape3D.new()
        collision.shape = terrain
        if owner == 1:
            floor_body.position.x = grid + 4
            collision.position.y = 0.2
            collision.rotation.y = 0.2
        floor_body.add_child(collision)
        _world.add_child(floor_body)
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var ground := MeshInstance3D.new()
    ground.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.16, 0.34, 0.22)
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ground.material_override = material
    _world.add_child(ground)
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.8
    var avatar_mesh := CapsuleMesh.new()
    avatar_mesh.radius = capsule.radius
    avatar_mesh.height = capsule.height
    for index in int(PROFILES[_profile].characters):
        var character := CharacterBody3D.new()
        character.collision_layer = 4
        character.collision_mask = 1
        character.position = Vector3((index % 8) * 2.2 - 8, 1.1, (index / 8) * 2.2 - 4)
        _attach(character, capsule, avatar_mesh)
        _world.add_child(character)
        _characters.append(character)
    var box := BoxShape3D.new()
    box.size = Vector3.ONE * 0.6
    var box_mesh := BoxMesh.new()
    box_mesh.size = box.size
    for index in int(PROFILES[_profile].rigids):
        var body := RigidBody3D.new()
        body.collision_layer = 2
        body.collision_mask = 3
        body.position = Vector3((index % 16) * 0.8 - 6, 2.0 + (index / 256) * 0.8, ((index / 16) % 16) * 0.8 - 6)
        _attach(body, box, box_mesh)
        _world.add_child(body)
        _rigids.append(body)


func _attach(body: CollisionObject3D, shape: Shape3D, mesh: Mesh) -> void:
    var collision := CollisionShape3D.new()
    collision.shape = shape
    body.add_child(collision)
    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    body.add_child(visual)


func _process(_delta: float) -> void:
    var now := Time.get_ticks_usec()
    # Engine delta is clamped during overload; retain the real frame gap.
    if _active and _last_frame_usec > 0:
        _frame_ms.append((now - _last_frame_usec) / 1000.0)
    _last_frame_usec = now


func _physics_process(_delta: float) -> void:
    if not _active:
        return
    var started := Time.get_ticks_usec()
    _ticks += 1
    for index in _characters.size():
        var character := _characters[index]
        character.velocity = Vector3(cos(_ticks * 0.01 + index) * 2.0, -2, sin(_ticks * 0.01 + index) * 2.0)
        character.move_and_slide()
        if not character.position.is_finite() or character.position.y < -0.4:
            if _failures.is_empty():
                _failures.append("character crossed terrain or became non-finite")
    _query_ms.append((Time.get_ticks_usec() - started) / 1000.0)
    _physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
    for index in _rigids.size():
        var body := _rigids[index]
        if not body.position.is_finite() or body.position.y < -0.5:
            if _failures.is_empty():
                _failures.append("rigid body crossed terrain or became non-finite")
        if _ticks % 120 == 0 and index % 8 == 0:
            body.apply_central_impulse(Vector3(0.1, 1.5, 0))
    if Time.get_ticks_msec() - _last_report >= 1000:
        _last_report = Time.get_ticks_msec()
        _publish({"phase": "active", "ticks": _ticks, "characters": _characters.size(), "rigids": _rigids.size()})


func _quantiles(values: Array[float]) -> Dictionary:
    values.sort()
    if values.is_empty():
        return {}
    return {"p50": values[int((values.size() - 1) * 0.5)], "p95": values[int((values.size() - 1) * 0.95)], "p99": values[int((values.size() - 1) * 0.99)], "max": values[-1], "samples": values.size()}


func _counts() -> Dictionary:
    return {"objects": Performance.get_monitor(Performance.OBJECT_COUNT), "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "godot_static_bytes": OS.get_static_memory_usage()}


func _publish(value: Dictionary) -> void:
    value["profile"] = _profile
    value["failures"] = _failures.duplicate()
    var detail := "characters=%d  rigid bodies=%d  ticks=%d" % [_characters.size(), _rigids.size(), _ticks]
    if value.get("phase") == "complete":
        detail = "%d construction / movement / cleanup cycles completed" % _records.size()
    _label.text = "Box3D Web workload: %s / %s\n%s\n%s" % [_profile, value.get("phase", ""), detail, "PASS so far" if _failures.is_empty() else "FAIL: " + str(_failures)]
    if OS.has_feature("web"):
        var browser: JavaScriptObject = JavaScriptBridge.get_interface("window")
        browser.__box3dWebStress = JavaScriptBridge.get_interface("JSON").parse(JSON.stringify(value))


func _run() -> void:
    for frame in 3:
        await get_tree().process_frame
    var baseline := _counts()
    _publish({"phase": "baseline", "counts": baseline})
    for cycle in CYCLES:
        var started := Time.get_ticks_usec()
        _build_world()
        var construction_ms := (Time.get_ticks_usec() - started) / 1000.0
        for frame in 3:
            await get_tree().physics_frame
        _frame_ms.clear()
        _physics_ms.clear()
        _query_ms.clear()
        _active = true
        # Scene timers use clamped simulation delta under severe overload.
        # Keep each workload interval bounded by elapsed wall time instead.
        var deadline := Time.get_ticks_msec() + int(ACTIVE_SECONDS * 1000.0)
        while Time.get_ticks_msec() < deadline:
            await get_tree().process_frame
        _active = false
        var record := {"cycle": cycle, "construction_ms": construction_ms, "frame_ms": _quantiles(_frame_ms), "engine_physics_monitor_ms": _quantiles(_physics_ms), "character_queries_ms": _quantiles(_query_ms), "loaded_counts": _counts()}
        _characters.clear()
        _rigids.clear()
        _world.free()
        _world = null
        for frame in 6:
            await get_tree().process_frame
        record["cleanup_counts"] = _counts()
        _records.append(record)
        _publish({"phase": "cleanup", "record": record})
        print("BOX3D_WEB_STRESS_CYCLE ", JSON.stringify(record))
        await get_tree().create_timer(0.5).timeout
    var result := {"phase": "complete", "ok": _failures.is_empty(), "backend": str(PhysicsServer3D.get_class()), "baseline_counts": baseline, "cycles": _records}
    _publish(result)
    print("BOX3D_WEB_STRESS_RESULT ", JSON.stringify(result))
    if not OS.has_feature("web"):
        get_tree().quit(0 if _failures.is_empty() else 1)
