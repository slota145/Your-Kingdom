extends Node2D
## M1 PROTOTYPE: readability, depth sorting, 8-direction walls and performance test scene.
## Debug texts here are English and hardcoded on purpose (prototype-only, see CLAUDE.md).
##
## Controls: WASD/arrows/middle-drag pan, wheel or 1-4 zoom, LMB drag = draw wall,
## RMB drag = erase, G = gate on hovered wall, H = lower buildings, F = grid,
## M = mirror comparison, Space = pause, Esc = back to menu.
##
## Run with "-- --bench" to execute the automated benchmark, print results and quit.

const BUILDINGS_SMALL_MAP: Array = [
	["hall_box", Vector2i(12, 12)], ["hut_box", Vector2i(20, 12)], ["hut_box", Vector2i(12, 20)],
	["workshop_box", Vector2i(18, 19)], ["hut_box", Vector2i(23, 16)], ["hut_box", Vector2i(8, 30)],
]

@export var map_size: Vector2i = Vector2i(64, 64)
@export var agent_count: int = 120
@export var benchmark: bool = false

var nav: NavGrid
var crowd: ProtoCrowd
var camera: GameCamera
var terrain: TerrainLayer
var world: Node2D
var walls: WallLayer
var crowd_view: ProtoCrowdView
var buildings: Array[BuildingView] = []

var _overlay: _TileOverlay
var _hud: Label
var _accumulator: float = 0.0
var _time: float = 0.0
var _paused: bool = false
var _lowered: bool = false
var _mirror_compare: bool = false
var _drag_start: Vector2i = Vector2i(-1, -1)
var _drag_erase: bool = false
var _tick_usec_avg: float = 0.0
var _bench: _Bench


## Highlights the hovered tile and the wall line being drawn.
class _TileOverlay:
	extends Node2D
	var tiles: Array[Vector2i] = []
	var color: Color = Color(1, 1, 0.5, 0.45)

	func _draw() -> void:
		for t: Vector2i in tiles:
			var c := IsoMath.tile_center_screen(t)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16), c + Vector2(32, 0),
					c + Vector2(0, 16), c + Vector2(-32, 0)]), color)


func _ready() -> void:
	InputSetup.ensure_defaults()
	if "--bench" in OS.get_cmdline_user_args():
		benchmark = true
	if benchmark:
		map_size = Vector2i(192, 192)
		agent_count = 500
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--agents="):
			agent_count = int(arg.trim_prefix("--agents="))
	nav = NavGrid.new(map_size)

	terrain = TerrainLayer.new()
	add_child(terrain)
	terrain.setup(map_size)
	_overlay = _TileOverlay.new()
	add_child(_overlay)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	walls = WallLayer.new()
	world.add_child(walls)

	if benchmark:
		_build_benchmark_town()
	else:
		for entry: Array in BUILDINGS_SMALL_MAP:
			_add_building(entry[0], entry[1])
		_build_wall_showcase()

	var walk_area := Rect2i(Vector2i.ZERO, map_size)
	if benchmark:
		walk_area = Rect2i(map_size / 2 - Vector2i(24, 24), Vector2i(48, 48))
	crowd = ProtoCrowd.new(nav, walk_area)
	crowd.spawn(agent_count, [&"peasant"])
	crowd_view = ProtoCrowdView.new()
	world.add_child(crowd_view)

	camera = GameCamera.new()
	add_child(camera)
	camera.bounds = Rect2(IsoMath.grid_to_screen(Vector2(0, map_size.y)).x, 0,
			map_size.x * IsoMath.HALF_W * 2.0, map_size.y * IsoMath.HALF_H * 2.0)
	camera.position = IsoMath.grid_to_screen(Vector2(walk_area.get_center()) if benchmark else Vector2(26, 20))
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(8, 8)
	_hud.add_theme_font_size_override(&"font_size", 16)
	_hud.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override(&"outline_size", 4)
	layer.add_child(_hud)

	if benchmark:
		_bench = _Bench.new(self)
	_apply_debug_args()


## Screenshot automation: -- --cam=X,Y (grid) --zoom=N (1-4) --lowered --mirror --grid
func _apply_debug_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cam="):
			var xy := arg.trim_prefix("--cam=").split(",")
			camera.position = IsoMath.grid_to_screen(Vector2(float(xy[0]), float(xy[1])))
		elif arg.begins_with("--zoom="):
			camera.set_zoom_index(int(arg.trim_prefix("--zoom=")) - 1)
		elif arg == "--lowered":
			_lowered = true
			for b: BuildingView in buildings:
				b.set_lowered(true)
		elif arg == "--mirror":
			_mirror_compare = true
			for i: int in crowd.count:
				crowd.character[i] = &"peasant_mirror" if i % 2 == 1 else &"peasant"
		elif arg == "--grid":
			terrain.show_grid = true


func _process(delta: float) -> void:
	_time += delta
	if not _paused:
		_accumulator += delta
		var ticks := 0
		while _accumulator >= ProtoCrowd.TICK and ticks < 4:
			crowd.tick()
			_tick_usec_avg = lerpf(_tick_usec_avg, crowd.last_tick_usec, 0.1)
			_accumulator -= ProtoCrowd.TICK
			ticks += 1
			if _bench != null:
				_bench.on_tick(crowd.last_tick_usec)
	var alpha := clampf(_accumulator / ProtoCrowd.TICK, 0.0, 1.0)
	crowd_view.update_view(crowd, alpha, camera.visible_world_rect(), _time)
	_update_hover()
	_update_hud()
	if _bench != null:
		_bench.on_frame(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_tree().change_scene_to_file("res://src/main/main.tscn")
	elif event.is_action_pressed(&"toggle_grid"):
		terrain.show_grid = not terrain.show_grid
	elif event.is_action_pressed(&"toggle_lower_buildings"):
		_lowered = not _lowered
		for b: BuildingView in buildings:
			b.set_lowered(_lowered)
	elif event.is_action_pressed(&"toggle_pause"):
		_paused = not _paused
	elif event.is_action_pressed(&"toggle_mirror_compare"):
		_mirror_compare = not _mirror_compare
		for i: int in crowd.count:
			crowd.character[i] = &"peasant_mirror" if _mirror_compare and i % 2 == 1 else &"peasant"
	elif event.is_action_pressed(&"toggle_gate"):
		var tile := _hovered_tile()
		if walls.has_wall(tile):
			_set_wall(tile, true, not walls.is_gate(tile))
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if mb.pressed:
			_drag_start = _hovered_tile()
			_drag_erase = mb.button_index == MOUSE_BUTTON_RIGHT
		elif _drag_start.x >= 0:
			for tile: Vector2i in _wall_line(_drag_start, _hovered_tile()):
				if _drag_erase:
					_set_wall(tile, false)
				elif not _building_at(tile) and not walls.has_wall(tile):
					_set_wall(tile, true)
			_drag_start = Vector2i(-1, -1)
			crowd.on_nav_changed()


func _set_wall(tile: Vector2i, present: bool, gate: bool = false) -> void:
	if not nav.is_inside(tile):
		return
	walls.set_wall(tile, present, gate)
	nav.set_solid(tile, present and not gate)


## Tiles of a wall dragged from [param a] to [param b], snapped to one of 8 grid directions.
func _wall_line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
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
	var tiles: Array[Vector2i] = []
	for i: int in length + 1:
		tiles.append(a + step * i)
	return tiles


func _hovered_tile() -> Vector2i:
	return IsoMath.tile_at_screen(get_global_mouse_position())


func _building_at(tile: Vector2i) -> bool:
	for b: BuildingView in buildings:
		if b.get_tile_rect().has_point(tile):
			return true
	return false


func _update_hover() -> void:
	var mouse := get_global_mouse_position()
	var hovered := _hovered_tile()
	for b: BuildingView in buildings:
		# Fade when the cursor is over the art but the hovered ground is behind the building.
		var over := b.get_screen_rect().has_point(mouse)
		var r := b.get_tile_rect()
		var behind := hovered.x < r.end.x and hovered.y < r.end.y and not r.has_point(hovered)
		b.set_faded(over and (behind or r.has_point(hovered)))
	var tiles: Array[Vector2i] = [hovered]
	if _drag_start.x >= 0:
		tiles = _wall_line(_drag_start, hovered)
	_overlay.color = Color(1, 0.4, 0.3, 0.45) if _drag_erase and _drag_start.x >= 0 else Color(1, 1, 0.5, 0.45)
	if tiles != _overlay.tiles:
		_overlay.tiles = tiles
		_overlay.queue_redraw()


func _update_hud() -> void:
	var scale := get_viewport().get_final_transform().x.x
	_hud.text = "FPS %d | tick %.2f ms | view %.2f ms | people %d visible / %d\n" % [
		Engine.get_frames_per_second(), _tick_usec_avg / 1000.0,
		crowd_view.last_update_usec / 1000.0, crowd_view.visible_count, crowd.count]
	_hud.text += "zoom %.1fx (canvas scale %.0f, art px = %.1f screen px) | tile %s | %s%s%s\n" % [
		camera.zoom_factor(), scale, camera.zoom_factor() * scale, _hovered_tile(),
		"PAUSED " if _paused else "", "LOWERED " if _lowered else "",
		"MIRROR-COMPARE (odd people use 5-dir mirrored sheets)" if _mirror_compare else ""]
	if not benchmark:
		_hud.text += "LMB drag wall | RMB drag erase | G gate | H lower | F grid | M mirror | Space pause | Esc menu"


# --- Scene content -------------------------------------------------------------------

func _add_building(art_id: String, tile: Vector2i) -> void:
	var b := BuildingView.new()
	world.add_child(b)
	b.setup(art_id, tile)
	buildings.append(b)
	nav.set_solid_rect(b.get_tile_rect(), true)


func _line(start: Vector2i, step: Vector2i, n: int) -> void:
	for i: int in n:
		_set_wall(start + step * i, true)


func _build_wall_showcase() -> void:
	_line(Vector2i(34, 6), Vector2i(1, 0), 11)      # straight along grid x
	_line(Vector2i(34, 7), Vector2i(0, 1), 9)       # straight along grid y, 90 deg corner
	_line(Vector2i(46, 8), Vector2i(1, 1), 7)       # diagonal (screen vertical)
	_line(Vector2i(36, 26), Vector2i(1, 0), 5)      # 45 deg corner into...
	_line(Vector2i(41, 25), Vector2i(1, -1), 6)     # ...diagonal (screen horizontal)
	_line(Vector2i(44, 32), Vector2i(1, 0), 7)      # T junction
	_line(Vector2i(47, 33), Vector2i(0, 1), 3)
	_line(Vector2i(54, 18), Vector2i(1, 0), 7)      # cross
	_line(Vector2i(57, 15), Vector2i(0, 1), 3)
	_line(Vector2i(57, 19), Vector2i(0, 1), 3)
	_line(Vector2i(50, 40), Vector2i(1, 1), 7)      # diagonal cross
	_line(Vector2i(50, 46), Vector2i(1, -1), 3)
	_line(Vector2i(54, 42), Vector2i(1, -1), 3)
	_set_wall(Vector2i(39, 6), true, true)          # gates
	_set_wall(Vector2i(34, 11), true, true)


func _build_benchmark_town() -> void:
	var center := map_size / 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var arts := ["hall_box", "hut_box", "hut_box", "workshop_box"]
	var placed := 0
	while placed < 20:
		var tile := center + Vector2i(rng.randi_range(-22, 18), rng.randi_range(-22, 18))
		var art: String = arts[placed % arts.size()]
		var size := Vector2i(4, 4) if art == "hall_box" else (Vector2i(3, 2) if art == "workshop_box" else Vector2i(2, 2))
		var rect := Rect2i(tile, size).grow(1)
		var free := true
		for b: BuildingView in buildings:
			if b.get_tile_rect().intersects(rect):
				free = false
		if free:
			_add_building(art, tile)
			placed += 1
	_line(center + Vector2i(-26, -26), Vector2i(1, 0), 52)
	_line(center + Vector2i(-26, -25), Vector2i(0, 1), 51)
	_line(center + Vector2i(-20, 26), Vector2i(1, -1), 12)


# --- Benchmark -----------------------------------------------------------------------

class _Bench:
	extends RefCounted
	const WARMUP := 1.5
	const MEASURE := 5.0
	var scene: Node2D
	var step: int = 0
	var phase_time: float = 0.0
	var frame_times: PackedFloat32Array = PackedFloat32Array()
	var tick_times: PackedFloat32Array = PackedFloat32Array()
	var visible: PackedInt32Array = PackedInt32Array()
	var results: Array[Dictionary] = []

	func _init(owner: Node2D) -> void:
		scene = owner
		scene.camera.set_zoom_index(0)

	func on_tick(usec: int) -> void:
		if phase_time >= WARMUP:
			tick_times.append(usec / 1000.0)

	func on_frame(delta: float) -> void:
		phase_time += delta
		if phase_time < WARMUP:
			return
		frame_times.append(delta * 1000.0)
		visible.append(scene.crowd_view.visible_count)
		if phase_time < WARMUP + MEASURE:
			return
		results.append(_summary())
		step += 1
		if step >= GameCamera.ZOOM_STEPS.size():
			_finish()
			return
		scene.camera.set_zoom_index(step)
		phase_time = 0.0
		frame_times = PackedFloat32Array()
		tick_times = PackedFloat32Array()
		visible = PackedInt32Array()

	func _summary() -> Dictionary:
		var sorted := frame_times.duplicate()
		sorted.sort()
		var total := 0.0
		for t: float in frame_times:
			total += t
		var tick_total := 0.0
		var tick_max := 0.0
		for t: float in tick_times:
			tick_total += t
			tick_max = maxf(tick_max, t)
		var vis_total := 0
		for v: int in visible:
			vis_total += v
		return {
			"zoom": GameCamera.ZOOM_STEPS[step],
			"avg_fps": 1000.0 / (total / frame_times.size()),
			"p99_frame_ms": sorted[int(sorted.size() * 0.99)],
			"avg_tick_ms": tick_total / maxi(1, tick_times.size()),
			"max_tick_ms": tick_max,
			"avg_visible": vis_total / maxi(1, visible.size()),
		}

	func _finish() -> void:
		var report := {
			"renderer": RenderingServer.get_current_rendering_method(),
			"gpu": RenderingServer.get_video_adapter_name(),
			"window": DisplayServer.window_get_size(),
			"people": scene.crowd.count,
			"results": results,
		}
		print("BENCH_RESULT ", JSON.stringify(report))
		scene.get_tree().quit()
