class_name BenchGraph
extends Control

## Rolling plot of physics step time with the frame budget drawn as a reference line.

const BUDGET_MS: float = 16.66
const HEADROOM: float = 1.5
const LINE_COLOR: Color = Color(0.35, 0.8, 0.95)
const BUDGET_COLOR: Color = Color(0.95, 0.4, 0.35)
const GRID_COLOR: Color = Color(1.0, 1.0, 1.0, 0.12)

var samples: PackedFloat32Array = PackedFloat32Array()


func _draw() -> void:
	var rect: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, rect), Color(0, 0, 0, 0.28))

	var ceiling: float = BUDGET_MS * HEADROOM
	for sample in samples:
		ceiling = maxf(ceiling, sample)

	var budget_y: float = rect.y - (BUDGET_MS / ceiling) * rect.y
	draw_line(Vector2(0.0, budget_y), Vector2(rect.x, budget_y), BUDGET_COLOR, 1.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(4.0, maxf(12.0, budget_y - 4.0)),
		"%.2f ms" % BUDGET_MS,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		BUDGET_COLOR,
	)

	if samples.size() < 2:
		return

	var step_x: float = rect.x / float(maxi(samples.size() - 1, 1))
	var points: PackedVector2Array = PackedVector2Array()
	for i in samples.size():
		points.append(Vector2(i * step_x, rect.y - (samples[i] / ceiling) * rect.y))
	draw_polyline(points, LINE_COLOR, 1.5)
