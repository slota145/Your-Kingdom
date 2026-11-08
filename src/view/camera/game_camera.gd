class_name GameCamera
extends Camera2D
## Fixed isometric camera: pan (keys, screen edge, middle-drag) and stepped zoom (wheel,
## 1-4). Zoom steps are relative to the integer canvas scale chosen from the window size,
## so world pixels always land on whole screen pixels (ART_SPEC §3.3).

const ZOOM_STEPS: PackedFloat32Array = [0.5, 1.0, 2.0, 3.0]
const PAN_SPEED := 900.0
const EDGE_MARGIN := 6.0

@export var edge_pan: bool = false
@export var zoom_index: int = 1
## Digit keys that select a group of soldiers now (the game scene keeps it up to date).
var taken_digits: Dictionary[int, bool] = {}

var bounds: Rect2 = Rect2(-1e6, -1e6, 2e6, 2e6)

var _dragging: bool = false


func _ready() -> void:
	InputSetup.ensure_defaults()
	_apply_zoom(zoom_index, get_viewport().get_visible_rect().size * 0.5)


func zoom_factor() -> float:
	return ZOOM_STEPS[zoom_index]


func set_zoom_index(index: int, screen_anchor: Vector2 = Vector2(-1, -1)) -> void:
	if screen_anchor.x < 0:
		screen_anchor = get_viewport().get_visible_rect().size * 0.5
	_apply_zoom(index, screen_anchor)


## Visible world rectangle.
func visible_world_rect() -> Rect2:
	var size := get_viewport().get_visible_rect().size / zoom
	return Rect2(get_screen_center_position() - size * 0.5, size)


func _process(delta: float) -> void:
	var dir := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
	if edge_pan and get_window().has_focus():
		var mouse := get_viewport().get_mouse_position()
		var size := get_viewport().get_visible_rect().size
		if mouse.x < EDGE_MARGIN: dir.x = -1.0
		elif mouse.x > size.x - EDGE_MARGIN: dir.x = 1.0
		if mouse.y < EDGE_MARGIN: dir.y = -1.0
		elif mouse.y > size.y - EDGE_MARGIN: dir.y = 1.0
	if dir != Vector2.ZERO:
		position += dir * PAN_SPEED * delta / zoom.x
		_clamp()


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_apply_zoom(zoom_index + 1, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_apply_zoom(zoom_index - 1, mb.position)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		position -= motion.relative / zoom.x
		_clamp()
		return
	for i: int in ZOOM_STEPS.size():
		# A digit with a group of soldiers on it selects the group instead (M7 part 2).
		if event.is_action_pressed(StringName("camera_zoom_%d" % (i + 1))) and not taken_digits.has(i + 1) \
				and not (event is InputEventWithModifiers and (event as InputEventWithModifiers).ctrl_pressed):
			set_zoom_index(i)


## Keeps the world point under [param screen_anchor] fixed while zooming.
func _apply_zoom(index: int, screen_anchor: Vector2) -> void:
	index = clampi(index, 0, ZOOM_STEPS.size() - 1)
	# Computed from the camera's own state: the canvas transform lags one frame behind.
	var from_center := screen_anchor - get_viewport().get_visible_rect().size * 0.5
	var anchored_world := position + from_center / zoom.x
	zoom_index = index
	zoom = Vector2.ONE * ZOOM_STEPS[index]
	position = anchored_world - from_center / zoom.x
	_clamp()


func _clamp() -> void:
	position = position.clamp(bounds.position, bounds.end)
