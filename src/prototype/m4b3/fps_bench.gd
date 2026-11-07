extends Node
## M4b-3 FPS measurement on the owner's laptop (ROADMAP M4b-3, ARCHITECTURE §9.3): loads the
## big city fixture in the real game scene, runs it at 4x and measures frame times for 20 s at
## each of three zoom levels over the town centre (after a short warm-up). Prints the result
## and quits. Needs a window and a GPU (not for the cloud).
##   "$GODOT" --path . res://src/prototype/m4b3/fps_bench.tscn [-- --seconds=20 --speed=4 --out=<file.txt>]
## Frames in the first 2 s after each camera jump are not counted. "Frames over 33 ms" are
## stutters a player can see.

const GAME_SCENE := "res://src/main/game_scene.tscn"
const BigCityScript := preload("res://tests/support/big_city.gd")
const CENTRE := Vector2i(80, 72)
## Zoom indices of GameCamera.ZOOM_STEPS (0.5, 1, 2): far, normal, close.
const ZOOMS: Array[int] = [0, 1, 2]
const WARM_UP_SECONDS := 3.0
const SETTLE_SECONDS := 2.0
## Frames longer than this count as a visible stutter.
const HITCH_SECONDS := 1.0 / 30.0

var _game: Node2D
var _seconds: float = 20.0
var _out: String = ""
## Index into Game.SPEEDS (--speed=1|2|4, default 4x).
var _speed_index: int = Game.SPEEDS.size() - 1
var _phase: int = -1
var _phase_time: float = 0.0
var _frames := PackedFloat32Array()
var _agents_sum: int = 0
var _lines: PackedStringArray = []


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			_seconds = float(arg.get_slice("=", 1))
		elif arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--speed="):
			_speed_index = Game.SPEEDS.find(float(arg.get_slice("=", 1)))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_game = (load(GAME_SCENE) as PackedScene).instantiate() as Node2D
	add_child(_game)
	# The fixture is plain JSON (saves are compressed), so it is swapped in after the start.
	_game.call("_start", BigCityScript.load_fixture(Data.registry))
	_lines.append("FPS bench: big city, speed %.0fx, vsync off, %d s per zoom, window %s" % [
		Game.SPEEDS[_speed_index], int(_seconds), str(DisplayServer.window_get_size())])
	_lines.append("GPU: %s" % RenderingServer.get_video_adapter_name())


func _process(delta: float) -> void:
	_phase_time += delta
	if _phase == -1:
		if _phase_time < WARM_UP_SECONDS:
			return
		Game.paused = false
		Game.set_speed_index(_speed_index)
		_next_phase()
		return
	if _phase_time < SETTLE_SECONDS:
		return   # the first moments after a camera jump build the new view
	_frames.append(delta)
	var sim: Simulation = _game.get("sim")
	_agents_sum += sim.province.agents.count()
	if _phase_time >= _seconds:
		_report()
		_next_phase()


func _next_phase() -> void:
	_phase += 1
	_phase_time = 0.0
	_frames.clear()
	_agents_sum = 0
	if _phase >= ZOOMS.size():
		var text := "\n".join(_lines)
		print(text)
		if not _out.is_empty():
			var file := FileAccess.open(_out, FileAccess.WRITE)
			file.store_string(text + "\n")
		get_tree().quit()
		return
	var camera: GameCamera = _game.get("camera")
	camera.position = IsoMath.tile_center_screen(CENTRE)
	camera.set_zoom_index(ZOOMS[_phase])


func _report() -> void:
	var count := _frames.size()
	if count == 0:
		return
	var total := 0.0
	var hitches := 0
	for d: float in _frames:
		total += d
		if d > HITCH_SECONDS:
			hitches += 1
	var sorted := _frames.duplicate()
	sorted.sort()
	var worst_1 := 0.0
	var n := maxi(1, count / 100)
	for i: int in n:
		worst_1 += sorted[count - 1 - i]
	worst_1 /= n
	_lines.append("zoom %.1fx: avg %.0f FPS, 1%% low %.0f FPS, worst frame %.1f ms, %d frames over 33 ms in %.0f s, %d characters" % [
		GameCamera.ZOOM_STEPS[ZOOMS[_phase]], count / total, 1.0 / worst_1,
		sorted[count - 1] * 1000.0, hitches, total, _agents_sum / count])
