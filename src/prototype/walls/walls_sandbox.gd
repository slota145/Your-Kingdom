extends Node2D
## WALLS PROTOTYPE: block model of stone walls - thick walls, battlements, diagonal
## variants, gates and guards on the crown (docs/IDEAS.md). Debug texts are English and
## hardcoded on purpose (prototype-only, see CLAUDE.md).
##
## Controls: WASD/arrows/middle-drag pan, wheel or 1-4 zoom, LMB drag = wall line,
## Shift+LMB drag = filled rectangle (thick wall), RMB drag = erase, G = gate on hovered
## wall, V = diagonal variant (stairs / chamfer / straight), B = battlements, T = tall
## walls, F = grid, Space = pause, Esc = back to menu.
##
## Screenshots: -- --shot=<png> [--cam=X,Y] [--zoom=N] [--diag=0|1|2] [--plain] [--tall]

const Model := preload("res://src/prototype/walls/block_wall_model.gd")
const View := preload("res://src/prototype/walls/block_wall_view.gd")
const DIAGONAL_VARIANTS: Array[float] = [0.0, 0.5, 1.0]
const DIAGONAL_NAMES: PackedStringArray = ["stairs", "chamfer 1/2", "straight (wedge 1)"]
const GUARD_SPEED := 0.9
const SHOT_FRAMES := 90

@export var map_size: Vector2i = Vector2i(64, 64)
@export var agent_count: int = 70

var model: Model = Model.new()
var nav: NavGrid
var crowd: ProtoCrowd
var camera: GameCamera
var terrain: TerrainLayer
var world: Node2D
var wall_view: View
var crowd_view: ProtoCrowdView

var _overlay: _TileOverlay
var _hud: Label
var _guards: Array[_Guard] = []
var _nav_solid: Dictionary[Vector2i, bool] = {}
var _accumulator: float = 0.0
var _time: float = 0.0
var _paused: bool = false
var _diag_index: int = 2
var _drag_start: Vector2i = Vector2i(-1, -1)
var _drag_erase: bool = false
var _drag_rect: bool = false
var _shot_path: String = ""
var _frames: int = 0


class _TileOverlay:
	extends Node2D
	var tiles: Array[Vector2i] = []
	var color: Color = Color(1, 1, 0.5, 0.45)

	func _draw() -> void:
		for t: Vector2i in tiles:
			var c := IsoMath.tile_center_screen(t)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16), c + Vector2(32, 0),
					c + Vector2(0, 16), c + Vector2(-32, 0)]), color)


## A person patrolling back and forth along crown tiles. The node sits at the sort point;
## the sprite is lifted by the wall height.
class _Guard:
	extends Node2D
	var route: Array[Vector2i] = []
	var progress: float = 0.0
	var direction: float = 1.0
	var pause: float = 0.0
	var facing: int = 0
	var sprite: AgentSprite

	func _init(tiles: Array[Vector2i], start: float, tint: Color) -> void:
		route = tiles
		progress = start
		sprite = AgentSprite.new()
		sprite.modulate = tint
		add_child(sprite)

	func step(delta: float, model: Model, time: float) -> void:
		var walking := route.size() > 1 and pause <= 0.0
		var from := _point(progress)
		if walking:
			progress += direction * GUARD_SPEED * delta
			var last := float(route.size() - 1)
			if progress <= 0.0 or progress >= last:
				progress = clampf(progress, 0.0, last)
				direction = -direction
				pause = 1.5
		else:
			pause -= delta
		var p := _point(progress)
		if walking and p != from:
			facing = maxi(IsoMath.screen_dir(p - from), 0)
		var screen := IsoMath.grid_to_screen(p)
		position = Vector2(screen.x, model.crown_sort_key(p))
		sprite.position = Vector2(0, screen.y - position.y - model.height)
		var anim := &"walk" if walking else &"idle"
		sprite.show_state(CharacterVisual.get_visual(&"peasant"), anim, facing, time, "", &"")

	func _point(t: float) -> Vector2:
		var i := clampi(floori(t), 0, route.size() - 1)
		var j := mini(i + 1, route.size() - 1)
		return IsoMath.tile_center(route[i]).lerp(IsoMath.tile_center(route[j]), t - i)


func _ready() -> void:
	InputSetup.ensure_defaults()
	nav = NavGrid.new(map_size)
	terrain = TerrainLayer.new()
	add_child(terrain)
	terrain.setup(map_size)
	_overlay = _TileOverlay.new()
	add_child(_overlay)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	wall_view = View.new()
	world.add_child(wall_view)

	_build_showcase()
	_apply_args()
	_rebuild_walls()

	crowd = ProtoCrowd.new(nav, Rect2i(Vector2i(2, 2), map_size - Vector2i(4, 4)))
	crowd.spawn(agent_count, [&"peasant"])
	crowd_view = ProtoCrowdView.new()
	world.add_child(crowd_view)
	_add_guards()

	camera = GameCamera.new()
	add_child(camera)
	camera.bounds = Rect2(IsoMath.grid_to_screen(Vector2(0, map_size.y)).x, 0,
			map_size.x * IsoMath.HALF_W * 2.0, map_size.y * IsoMath.HALF_H * 2.0)
	camera.position = IsoMath.grid_to_screen(Vector2(27, 27))
	camera.make_current()
	_apply_camera_args()

	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(8, 8)
	_hud.add_theme_font_size_override(&"font_size", 16)
	_hud.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override(&"outline_size", 4)
	layer.add_child(_hud)


func _apply_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--diag="):
			_diag_index = clampi(int(arg.trim_prefix("--diag=")), 0, 2)
		elif arg == "--plain":
			model.battlements = false
		elif arg == "--tall":
			model.height = Model.TALL_HEIGHT
	model.wedge_leg = DIAGONAL_VARIANTS[_diag_index]


func _apply_camera_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cam="):
			var xy := arg.trim_prefix("--cam=").split(",")
			camera.position = IsoMath.grid_to_screen(Vector2(float(xy[0]), float(xy[1])))
		elif arg.begins_with("--zoom="):
			camera.set_zoom_index(int(arg.trim_prefix("--zoom=")) - 1)


func _process(delta: float) -> void:
	_time += delta
	if not _paused:
		_accumulator += delta
		var ticks := 0
		while _accumulator >= ProtoCrowd.TICK and ticks < 4:
			crowd.tick()
			_accumulator -= ProtoCrowd.TICK
			ticks += 1
		for guard: _Guard in _guards:
			guard.step(delta, model, _time)
	var alpha := clampf(_accumulator / ProtoCrowd.TICK, 0.0, 1.0)
	crowd_view.update_view(crowd, alpha, camera.visible_world_rect(), _time)
	_update_hover()
	_update_hud()
	if _shot_path != "":
		_frames += 1
		if _frames == SHOT_FRAMES:
			_hud.visible = false
		elif _frames == SHOT_FRAMES + 2:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_tree().change_scene_to_file("res://src/main/main.tscn")
	elif event.is_action_pressed(&"toggle_grid"):
		terrain.show_grid = not terrain.show_grid
	elif event.is_action_pressed(&"toggle_pause"):
		_paused = not _paused
	elif event.is_action_pressed(&"toggle_gate"):
		var tile := _hovered_tile()
		if model.is_wall(tile):
			model.walls[tile] = not model.is_gate(tile)
			_rebuild_walls()
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_V:
				_diag_index = (_diag_index + 1) % DIAGONAL_VARIANTS.size()
				model.wedge_leg = DIAGONAL_VARIANTS[_diag_index]
				_rebuild_walls()
			KEY_B:
				model.battlements = not model.battlements
				_rebuild_walls()
			KEY_T:
				model.height = Model.HEIGHT if model.height != Model.HEIGHT else Model.TALL_HEIGHT
				_rebuild_walls()
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if mb.pressed:
			_drag_start = _hovered_tile()
			_drag_erase = mb.button_index == MOUSE_BUTTON_RIGHT
			_drag_rect = mb.shift_pressed
		elif _drag_start.x >= 0:
			for tile: Vector2i in _drag_tiles(_drag_start, _hovered_tile()):
				if not nav.is_inside(tile):
					continue
				if _drag_erase:
					model.walls.erase(tile)
				elif not model.is_wall(tile):
					model.walls[tile] = false
			_drag_start = Vector2i(-1, -1)
			_rebuild_walls()


func _rebuild_walls() -> void:
	wall_view.rebuild(model)
	var blocked := model.blocked_tiles()
	for tile: Vector2i in _nav_solid:
		if not blocked.has(tile):
			nav.set_solid(tile, false)
	for tile: Vector2i in blocked:
		if nav.is_inside(tile):
			nav.set_solid(tile, true)
	_nav_solid = blocked
	if crowd != null:
		crowd.on_nav_changed()


func _drag_tiles(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if _drag_rect:
		for x: int in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			for y: int in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
				tiles.append(Vector2i(x, y))
		return tiles
	var d := b - a
	var ax := absi(d.x)
	var ay := absi(d.y)
	var step := Vector2i(signi(d.x), signi(d.y))
	var length := maxi(ax, ay)
	if ax > 2 * ay:
		step.y = 0
	elif ay > 2 * ax:
		step.x = 0
	else:
		length = roundi((ax + ay) / 2.0)
	for i: int in length + 1:
		tiles.append(a + step * i)
	return tiles


func _hovered_tile() -> Vector2i:
	return IsoMath.tile_at_screen(get_global_mouse_position())


func _update_hover() -> void:
	var hovered := _hovered_tile()
	var tiles: Array[Vector2i] = [hovered]
	if _drag_start.x >= 0:
		tiles = _drag_tiles(_drag_start, hovered)
	_overlay.color = Color(1, 0.4, 0.3, 0.45) if _drag_erase and _drag_start.x >= 0 else Color(1, 1, 0.5, 0.45)
	if tiles != _overlay.tiles:
		_overlay.tiles = tiles
		_overlay.queue_redraw()


func _update_hud() -> void:
	_hud.text = "FPS %d | zoom %.1fx | tile %s | wall nodes %d | %s\n" % [
		Engine.get_frames_per_second(), camera.zoom_factor(), _hovered_tile(),
		wall_view.get_child_count(), "PAUSED" if _paused else ""]
	_hud.text += "diagonals: %s (V) | battlements: %s (B) | height: %d px (T)\n" % [
		DIAGONAL_NAMES[_diag_index], "on" if model.battlements else "off", int(model.height)]
	_hud.text += "LMB drag wall | Shift+LMB rectangle | RMB erase | G gate | F grid | Space pause | Esc menu"


# --- Scene content -------------------------------------------------------------------

func _rect(from: Vector2i, to: Vector2i) -> void:
	for x: int in range(from.x, to.x + 1):
		for y: int in range(from.y, to.y + 1):
			model.walls[Vector2i(x, y)] = false


func _line(start: Vector2i, step: Vector2i, n: int) -> void:
	for i: int in n:
		model.walls[start + step * i] = false


func _build_showcase() -> void:
	# Castle ring, 2 tiles thick, with a 2-deep gate on the front side.
	_rect(Vector2i(20, 20), Vector2i(33, 21))
	_rect(Vector2i(20, 30), Vector2i(33, 31))
	_rect(Vector2i(20, 22), Vector2i(21, 29))
	_rect(Vector2i(32, 22), Vector2i(33, 29))
	model.walls[Vector2i(26, 30)] = true
	model.walls[Vector2i(26, 31)] = true
	# Single wall joining the ring (T junction), with a gate, turning into a diagonal.
	_line(Vector2i(34, 25), Vector2i(1, 0), 10)
	model.walls[Vector2i(39, 25)] = true
	_line(Vector2i(44, 26), Vector2i(1, 1), 7)
	# Diagonal running screen-horizontal, single and double thick.
	_line(Vector2i(36, 44), Vector2i(1, -1), 8)
	_line(Vector2i(37, 44), Vector2i(1, -1), 8)
	_line(Vector2i(24, 44), Vector2i(1, -1), 8)
	# Diagonal running screen-vertical, double thick, and a 3-thick straight wall.
	_line(Vector2i(8, 30), Vector2i(1, 1), 8)
	_line(Vector2i(9, 30), Vector2i(1, 1), 8)
	_rect(Vector2i(6, 20), Vector2i(14, 22))


func _add_guards() -> void:
	var blue := Color(0.6, 0.75, 1.0)
	var red := Color(1.0, 0.65, 0.6)
	_add_guard(_route(Vector2i(21, 31), Vector2i(1, 0), 12), 0.0, blue)    # front, outer row
	_add_guard(_route(Vector2i(22, 30), Vector2i(1, 0), 10), 4.0, red)     # front, inner row
	_add_guard(_route(Vector2i(33, 21), Vector2i(0, 1), 10), 2.0, blue)    # right side
	_add_guard(_route(Vector2i(32, 22), Vector2i(0, 1), 8), 6.0, red)
	_add_guard(_route(Vector2i(22, 20), Vector2i(1, 0), 10), 3.0, blue)    # back side
	_add_guard(_route(Vector2i(34, 25), Vector2i(1, 0), 10), 1.0, red)     # single wall
	_add_guard(_route(Vector2i(44, 26), Vector2i(1, 1), 7), 2.0, blue)     # diagonal
	_add_guard(_route(Vector2i(36, 44), Vector2i(1, -1), 8), 3.0, red)     # thick diagonal
	_add_guard([Vector2i(26, 31)], 0.0, blue)                             # over the gate
	_add_guard([Vector2i(20, 31)], 0.0, red)                              # corner


func _route(start: Vector2i, step: Vector2i, n: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for i: int in n:
		tiles.append(start + step * i)
	return tiles


func _add_guard(route: Array[Vector2i], start: float, tint: Color) -> void:
	var guard := _Guard.new(route, start, tint)
	world.add_child(guard)
	_guards.append(guard)
