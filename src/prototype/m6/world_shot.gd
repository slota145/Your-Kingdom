extends Node
## M6 prototype: starts a new game in the world, optionally settles Willow Vale (simplified
## mode), opens the world map with a province selected and saves a screenshot.
## Run (cloud): xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 \
##   res://src/prototype/m6/world_shot.tscn -- --out=/tmp/world.png [--select=<province id>] [--settle]
##   [--expeditions] (a cog on its way to Gull Isle, a wagon to Willow Vale, one waiting at
##   Amber Coast, all made up for the picture)

const GAME_SCENE := "res://src/main/game_scene.tscn"
const SETTLE_FRAMES := 10
const SHOT_FRAMES := 30

var _game: Node2D
var _frames: int = 0
var _out: String = ""
var _select: StringName = &""
var _settle: bool = false
var _expeditions: bool = false


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--select="):
			_select = StringName(arg.trim_prefix("--select="))
		elif arg == "--settle":
			_settle = true
		elif arg == "--expeditions":
			_expeditions = true
	Game.start_request = {"world": "kingdom"}
	_game = (load(GAME_SCENE) as PackedScene).instantiate() as Node2D
	add_child(_game)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == SETTLE_FRAMES:
		var sim: Simulation = _game.get("sim")
		if _settle:
			sim.open_province(sim.world.id_of(&"willow_vale"), sim.data.get_map(&"riverlands"))
		if _expeditions:
			var plan := [[&"gull_isle", true, Expedition.State.TRAVELLING, 0.55],
					[&"willow_vale", false, Expedition.State.TRAVELLING, 0.4],
					[&"amber_coast", true, Expedition.State.WAITING, 1.0]]
			for i: int in plan.size():
				var e := Expedition.new()
				e.id = 900 + i
				e.from = sim.viewed_id
				e.to = sim.world.id_of(plan[i][0])
				e.by_sea = plan[i][1]
				e.state = plan[i][2]
				e.depart_at = sim.clock.tick - roundi(1000 * plan[i][3])
				e.arrive_at = e.depart_at + 1000
				sim.world.expeditions[e.id] = e
		_game.call("_toggle_world_map")
		if _select != &"":
			(_game.get("_world_map") as WorldMapScreen).select(sim.world.id_of(_select))
	elif _frames == SHOT_FRAMES and not _out.is_empty():
		get_viewport().get_texture().get_image().save_png(_out)
		get_tree().quit()
