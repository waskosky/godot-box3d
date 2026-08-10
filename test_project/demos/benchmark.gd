class_name BenchmarkDemo
extends DemoBase

## Deterministic spawn benchmark. Every body is placed on a fixed lattice from a fixed seed,
## so a run is identical on any physics backend and the only variable is the backend itself.

enum State { IDLE, RUNNING, FINISHED }

## Boxes only: spheres roll out of the stack and turn the tower into a pile.
const BOX_SCENE: PackedScene = preload("res://demos/bench_box.tscn")
const BUDGET_MS: float = 16.66
const RUN_SECONDS: float = 60.0
const BODY_CAP: int = 4096
const LATTICE_COLUMNS: int = 6
const LATTICE_ROWS: int = 6
const SPAWN_SPACING: float = 0.62
const BASE_HEIGHT: float = 1.0
## Each layer is laid a little above the settled stack, so the tower grows like Jenga.
const LAYER_HEIGHT: float = 0.62
const DROP_CLEARANCE: float = 1.4
const SPAWN_INTERVAL: float = 0.5
const GRAPH_SAMPLES: int = 240
const RNG_SEED: int = 20260805

@export var spawn_root: Node3D
@export var graph: BenchGraph
@export var batch_size: SpinBox
@export var start_button: Button
@export var export_button: Button
@export var readout: Label

var _state: State = State.IDLE
var _layer: int = 0
var _spawn_timer: float = 0.0
var _elapsed: float = 0.0
var _budget_body_count: int = 0
var _peak_step_ms: float = 0.0
var _samples: PackedFloat32Array = PackedFloat32Array()
var _counts: PackedInt32Array = PackedInt32Array()
var _frame_ms: PackedFloat32Array = PackedFloat32Array()
var _fps: PackedFloat32Array = PackedFloat32Array()
var _active: PackedInt32Array = PackedInt32Array()
var _pairs: PackedInt32Array = PackedInt32Array()
var _islands: PackedInt32Array = PackedInt32Array()
var _memory_mb: PackedFloat32Array = PackedFloat32Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _autostart: bool = false


func _ready() -> void:
	super._ready()
	Engine.time_scale = 5.0
	start_button.pressed.connect(_on_start_pressed)
	export_button.pressed.connect(_on_export_pressed)
	_reset()
	_apply_cli_args()


func _physics_process(delta: float) -> void:
	var step_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var body_count: int = spawn_root.get_child_count()

	if _state == State.RUNNING:
		_elapsed += delta
		_record(step_ms, body_count)
		# Keep spawning past the budget so the graph shows the whole curve, not just the knee.
		if step_ms > BUDGET_MS and _budget_body_count == 0 and body_count > 0:
			_budget_body_count = body_count
		if body_count >= BODY_CAP or _elapsed >= RUN_SECONDS:
			_finish()
		else:
			_spawn_timer += delta
			if _spawn_timer >= SPAWN_INTERVAL:
				_spawn_timer -= SPAWN_INTERVAL
				_spawn_layer()

	_peak_step_ms = maxf(_peak_step_ms, step_ms)
	_update_readout(step_ms, body_count)
	graph.samples = _samples.slice(maxi(_samples.size() - GRAPH_SAMPLES, 0))
	graph.queue_redraw()


## Keeps the full run for the CSV; the graph only draws the last GRAPH_SAMPLES of it.
func _record(step_ms: float, body_count: int) -> void:
	_samples.append(step_ms)
	_counts.append(body_count)
	_frame_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_fps.append(Engine.get_frames_per_second())
	_active.append(int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)))
	_pairs.append(int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)))
	_islands.append(int(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)))
	_memory_mb.append(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)


# Fixed lattice from a fixed seed: identical placement on every backend and every run.
func _spawn_layer() -> void:
	var count: int = mini(int(batch_size.value), BODY_CAP - spawn_root.get_child_count())
	for i in count:
		var body: RigidBody3D = BOX_SCENE.instantiate()
		spawn_root.add_child(body)
		var column: int = i % LATTICE_COLUMNS
		var row: int = floori(i / float(LATTICE_COLUMNS)) % LATTICE_ROWS
		var stack: int = floori(i / float(LATTICE_COLUMNS * LATTICE_ROWS))
		# Alternate each layer 90 degrees so the tower interlocks like Jenga.
		var offset_x: float = (column - (LATTICE_COLUMNS - 1) * 0.5) * SPAWN_SPACING
		var offset_z: float = (row - (LATTICE_ROWS - 1) * 0.5) * SPAWN_SPACING
		if _layer % 2 == 1:
			var swap: float = offset_x
			offset_x = offset_z
			offset_z = swap
		body.global_position = Vector3(
			offset_x + _rng.randf_range(-0.01, 0.01),
			_tower_height() + DROP_CLEARANCE + (stack * LAYER_HEIGHT),
			offset_z + _rng.randf_range(-0.01, 0.01),
		)
	_layer += 1


## Rises one layer per drop, so the tower grows without rescanning every body.
func _tower_height() -> float:
	return BASE_HEIGHT + _layer * LAYER_HEIGHT


func _update_readout(step_ms: float, body_count: int) -> void:
	var memory_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	readout.text = "\n".join([
		"Backend      %s" % ProjectSettings.get_setting("physics/3d/physics_engine", "DEFAULT"),
		"Bodies       %d" % body_count,
		"FPS          %.1f" % Engine.get_frames_per_second(),
		"Physics      %.2f ms  (peak %.2f)" % [step_ms, _peak_step_ms],
		"Memory       %.1f MB" % memory_mb,
		"Elapsed      %s" % _elapsed_text(),
		"Budget       %s" % _budget_text(),
	])


func _elapsed_text() -> String:
	if _state == State.RUNNING:
		return "%.1fs of %.0fs" % [_elapsed, RUN_SECONDS]
	if _state == State.FINISHED:
		return "stopped at %.1fs" % _elapsed
	return "not started"


func _budget_text() -> String:
	if _budget_body_count > 0:
		return "%d bodies exceeded %.2f ms" % [_budget_body_count, BUDGET_MS]
	if _state == State.RUNNING:
		return "under %.2f ms" % BUDGET_MS
	return "not started"


func _on_start_pressed() -> void:
	if _state == State.RUNNING:
		_finish()
		return
	_reset()
	_state = State.RUNNING
	start_button.text = "Stop"


func _finish() -> void:
	_state = State.FINISHED
	start_button.text = "Run again"
	if _autostart:
		_on_export_pressed()
		get_tree().quit()


func _on_export_pressed() -> void:
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var backend: String = str(
		ProjectSettings.get_setting("physics/3d/physics_engine", "DEFAULT")
	).replace(" ", "_").replace("(", "").replace(")", "")
	var base: String = "user://benchmark_%s_%s" % [backend, stamp]

	# Headless and dummy renderers have no viewport texture; the CSV still matters.
	var viewport_texture: ViewportTexture = get_viewport().get_texture()
	if viewport_texture != null:
		var image: Image = viewport_texture.get_image()
		if image != null:
			image.save_png("%s.png" % base)

	var report: FileAccess = FileAccess.open("%s.csv" % base, FileAccess.WRITE)
	report.store_line("backend,%s" % backend)
	report.store_line("budget_ms,%.2f" % BUDGET_MS)
	report.store_line("bodies_over_budget,%d" % _budget_body_count)
	report.store_line("peak_step_ms,%.3f" % _peak_step_ms)
	report.store_line("elapsed_s,%.2f" % _elapsed)
	report.store_line("final_bodies,%d" % spawn_root.get_child_count())
	report.store_line("frame,time_s,bodies,step_ms,frame_ms,fps,active,pairs,islands,memory_mb")
	for i in _samples.size():
		report.store_line("%d,%.4f,%d,%.3f,%.3f,%.1f,%d,%d,%d,%.2f" % [
			i,
			i / float(Engine.physics_ticks_per_second),
			_counts[i],
			_samples[i],
			_frame_ms[i],
			_fps[i],
			_active[i],
			_pairs[i],
			_islands[i],
			_memory_mb[i],
		])
	report.close()

	set_status("Exported to %s" % ProjectSettings.globalize_path("%s.png" % base))


func _apply_cli_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--bench-autostart":
			_autostart = true
		elif arg.begins_with("--bench-batch="):
			batch_size.value = float(arg.get_slice("=", 1))
	if _autostart:
		_on_start_pressed()


func _reset() -> void:
	for child in spawn_root.get_children():
		child.queue_free()
	_state = State.IDLE
	_layer = 0
	_spawn_timer = 0.0
	_elapsed = 0.0
	_budget_body_count = 0
	_peak_step_ms = 0.0
	_samples.clear()
	_counts.clear()
	_frame_ms.clear()
	_fps.clear()
	_active.clear()
	_pairs.clear()
	_islands.clear()
	_memory_mb.clear()
	_rng.seed = RNG_SEED
	start_button.text = "Start benchmark"


func restart() -> void:
	_reset()
