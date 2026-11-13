class_name WorldPreview
extends Control
## The world on parchment, drawn from its provinces (M8 part 1, start picker; UI-2 part 3, the
## live preview of "New game"): sea, land, borders and names. Provinces outside [member allowed]
## are dimmed (an empty list dims none). With [member pickable] a click on an allowed province
## emits [signal picked]. Drag to move, the wheel to zoom.

signal picked(id: StringName)

const SEA := Color(0.60, 0.70, 0.66)
const LAND := Color(0.82, 0.75, 0.55)
const DIM := Color(0.62, 0.58, 0.48)
const BORDER := Color(0.42, 0.29, 0.17)
const SELECTED := Color(0.72, 0.16, 0.14, 0.55)
const INK := Color(0.25, 0.17, 0.10)

var world: WorldDef
var data: DataRegistry
var allowed: Array[StringName] = []
var selected: StringName = &""
var pickable := true
## Size of the province names.
var font_size := 14
var zoom := 1.0
var pan := Vector2.ZERO
var _press := Vector2.INF
var _dragging := false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


## Shows [param new_world] whole (zoom and drag start over).
func show_world(new_world: WorldDef, registry: DataRegistry) -> void:
	world = new_world
	data = registry
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()


func fit() -> Transform2D:
	if world == null:
		return Transform2D.IDENTITY
	var s := minf((size.x - 20.0) / world.size.x, (size.y - 20.0) / world.size.y) * zoom
	return Transform2D(0.0, Vector2(s, s), 0.0, (size - world.size * s) / 2.0 + pan)


func is_lit(id: StringName) -> bool:
	return allowed.is_empty() or allowed.has(id)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	if button != null and button.pressed and (button.button_index == MOUSE_BUTTON_WHEEL_UP \
			or button.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var before := fit().affine_inverse() * button.position
		zoom = clampf(zoom * (1.15 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 1.0, 4.0)
		pan = Vector2.ZERO if zoom <= 1.001 else pan + button.position - fit() * before
		queue_redraw()
		accept_event()
	elif button != null and (button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_MIDDLE):
		if button.pressed:
			_press = button.position
			_dragging = false
		else:
			if not _dragging and pickable and button.button_index == MOUSE_BUTTON_LEFT and world != null:
				var local := fit().affine_inverse() * button.position
				for id: StringName in world.provinces:
					if is_lit(id) and Geometry2D.is_point_in_polygon(local, data.get_province(id).outline):
						picked.emit(id)
			_press = Vector2.INF
			_dragging = false
	elif motion != null and _press != Vector2.INF and (_dragging or motion.position.distance_to(_press) > 6.0):
		_dragging = true
		if zoom > 1.001:
			pan += motion.relative
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SEA)
	if world == null:
		return
	var f := fit()
	draw_set_transform_matrix(f)
	var width := 1.5 / maxf(f.get_scale().x, 0.01)
	for id: StringName in world.provinces:
		var def := data.get_province(id)
		draw_colored_polygon(def.outline, LAND if is_lit(id) else DIM)
		if id == selected:
			draw_colored_polygon(def.outline, SELECTED)
		var ring := def.outline.duplicate()
		ring.append(ring[0])
		draw_polyline(ring, BORDER, width)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# Names stay inside the picture and off each other (UI-2 part 3): each tries its place, then
	# a line lower or higher; a name with no free room shows when the map is zoomed in.
	var font := get_theme_default_font()
	var taken: Array[Rect2] = []
	var line := font_size + 2.0
	for id: StringName in world.provinces:
		var def := data.get_province(id)
		var text := tr(def.name_key())
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		var at := f * def.world_pos
		for dy: float in [0.0, line, -line]:
			var rect := Rect2(clampf(at.x - w / 2.0, 2.0, size.x - w - 2.0), at.y + dy - line / 2.0, w, line)
			if taken.any(func(r: Rect2) -> bool: return r.grow(1.0).intersects(rect)):
				continue
			taken.append(rect)
			draw_string(font, Vector2(rect.position.x, rect.end.y - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
					INK if is_lit(id) else Color(INK, 0.45))
			break
