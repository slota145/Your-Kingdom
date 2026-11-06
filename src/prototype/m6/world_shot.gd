extends Node
## M6 prototype: starts a new game in the world, optionally settles Willow Vale (simplified
## mode), opens the world map with a province selected and saves a screenshot.
## Run (cloud): xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 \
##   res://src/prototype/m6/world_shot.tscn -- --out=/tmp/world.png [--select=<province id>] [--settle]

const GAME_SCENE := "res://src/main/game_scene.tscn"
const SETTLE_FRAMES := 10
const SHOT_FRAMES := 30

var _game: Node2D
var _frames: int = 0
var _out: String = ""
var _select: StringName = &""
var _settle: bool = false


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--select="):
			_select = StringName(arg.trim_prefix("--select="))
		elif arg == "--settle":
			_settle = true
	Game.start_request = {"world": "kingdom"}
	_game = (load(GAME_SCENE) as PackedScene).instantiate() as Node2D
	add_child(_game)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == SETTLE_FRAMES:
		var sim: Simulation = _game.get("sim")
		if _settle:
			sim.open_province(sim.world.id_of(&"willow_vale"), sim.data.get_map(&"riverlands"))
		_game.call("_toggle_world_map")
		if _select != &"":
			(_game.get("_world_map") as WorldMapScreen).select(sim.world.id_of(_select))
	elif _frames == SHOT_FRAMES and not _out.is_empty():
		get_viewport().get_texture().get_image().save_png(_out)
		get_tree().quit()
