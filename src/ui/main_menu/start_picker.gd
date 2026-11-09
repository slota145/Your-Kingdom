class_name StartPicker
extends PanelContainer
## The second step of "New game" (M8 part 1, owner's survey 2026-11-09): the generated world
## on parchment; the player clicks the province he wants to start in (in Colonization one on
## the coast or an island, the others are dimmed), or lets chance choose. The AI rulers get
## their provinces only after this, as far from him as can be. Drag to move, the wheel to zoom.

signal start_requested(settings: GameSettings)
signal back_requested

var _settings: GameSettings
var _preview: _Preview
var _title: Label
var _choice: Label
var _start: Button


class _Preview:
	extends Control
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
	var zoom := 1.0
	var pan := Vector2.ZERO
	var _press := Vector2.INF
	var _dragging := false

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		resized.connect(queue_redraw)

	func fit() -> Transform2D:
		if world == null:
			return Transform2D.IDENTITY
		var s := minf((size.x - 20.0) / world.size.x, (size.y - 20.0) / world.size.y) * zoom
		return Transform2D(0.0, Vector2(s, s), 0.0, (size - world.size * s) / 2.0 + pan)

	func _gui_input(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		var motion := event as InputEventMouseMotion
		if button != null and button.pressed and (button.button_index == MOUSE_BUTTON_WHEEL_UP \
				or button.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var before := fit().affine_inverse() * button.position
			zoom = clampf(zoom * (1.15 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 1.0, 4.0)
			pan = Vector2.ZERO if zoom <= 1.001 else pan + button.position - fit() * before
			queue_redraw()
		elif button != null and (button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_MIDDLE):
			if button.pressed:
				_press = button.position
				_dragging = false
			else:
				if not _dragging and button.button_index == MOUSE_BUTTON_LEFT:
					var local := fit().affine_inverse() * button.position
					for id: StringName in world.provinces:
						if allowed.has(id) and Geometry2D.is_point_in_polygon(local, data.get_province(id).outline):
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
			draw_colored_polygon(def.outline, LAND if allowed.has(id) else DIM)
			if id == selected:
				draw_colored_polygon(def.outline, SELECTED)
			var ring := def.outline.duplicate()
			ring.append(ring[0])
			draw_polyline(ring, BORDER, width)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var font := get_theme_default_font()
		for id: StringName in world.provinces:
			var def := data.get_province(id)
			var text := tr(def.name_key())
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
			draw_string(font, f * def.world_pos - Vector2(w / 2.0, -5.0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14,
					INK if allowed.has(id) else Color(INK, 0.45))


func _init() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	add_child(box)
	_title = UiKit.title("ui.new_game.pick_start")
	box.add_child(_title)
	box.add_child(UiKit.label("ui.new_game.pick_hint"))
	_preview = _Preview.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(640, 420)
	_preview.picked.connect(_pick)
	box.add_child(_preview)
	_choice = UiKit.label()
	box.add_child(_choice)
	var buttons := HBoxContainer.new()
	buttons.add_child(UiKit.button("ui.new_game.random_start", func() -> void:
		if not _preview.allowed.is_empty():
			_pick(_preview.allowed[randi_range(0, _preview.allowed.size() - 1)])))
	_start = UiKit.button("ui.new_game.start", func() -> void:
		_settings.start = String(_preview.selected)
		start_requested.emit(_settings))
	buttons.add_child(_start)
	buttons.add_child(UiKit.button("ui.new_game.back", func() -> void: back_requested.emit()))
	box.add_child(buttons)


## Shows the world of [param settings] (made now, without owners) to choose the start in.
func open(settings: GameSettings) -> void:
	_settings = settings
	var data: DataRegistry = Data.registry
	var world := WorldGenerator.geography(data, settings)
	_preview.world = world
	_preview.data = data
	_preview.allowed = WorldGenerator.start_choices(data, world, settings)
	_preview.zoom = 1.0
	_preview.pan = Vector2.ZERO
	_pick(&"")
	visible = true


func _pick(id: StringName) -> void:
	_preview.selected = id
	_preview.queue_redraw()
	_start.disabled = id == &""
	if id == &"":
		_choice.text = tr("ui.new_game.no_start")
		return
	var def := Data.registry.get_province(id)
	_choice.text = tr("ui.new_game.start_at") % [tr(def.name_key()),
			tr("ui.new_game.island") if def.island else tr("world.template.%s" % def.template)]
