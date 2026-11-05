extends Node
## M4A SCREENSHOTS (prototype): plays the start map with the automatic player (SliceBot) for
## a while, opens the result in the real game scene, selects a building and saves a
## screenshot. For checking the new buildings and panels in the cloud.
##
## Run: godot --path . res://src/prototype/m4a/town_shot.tscn -- --shot=<png>
##      [--minutes=N] [--select=<building id>] [--zoom=N]

const GAME_SCENE := "res://src/main/game_scene.tscn"
const SAVE_PATH := "user://m4a_shot.sav"
const SETTLE_FRAMES := 10
const SHOT_FRAMES := 40

var _game: Node2D
var _frames: int = 0
var _shot_path: String = ""
var _select: StringName = &""
var _zoom: int = 1


func _ready() -> void:
	var minutes := 40
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--minutes="):
			minutes = int(arg.trim_prefix("--minutes="))
		elif arg.begins_with("--select="):
			_select = StringName(arg.trim_prefix("--select="))
		elif arg.begins_with("--zoom="):
			_zoom = int(arg.trim_prefix("--zoom="))
	var sim := Simulation.from_map(Data.registry, Data.registry.get_map(&"riverlands"))
	SliceBot.new(sim).run(minutes * 60)
	SaveService.save_simulation(SAVE_PATH, sim)
	Game.start_request = {"load": SAVE_PATH}
	_game = (load(GAME_SCENE) as PackedScene).instantiate() as Node2D
	add_child(_game)
	Game.paused = true


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == SETTLE_FRAMES:
		_arrange()
	elif _frames == SHOT_FRAMES and not _shot_path.is_empty():
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


func _arrange() -> void:
	var sim: Simulation = _game.get("sim")
	var camera: GameCamera = _game.get("camera")
	camera.set_zoom_index(_zoom)
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == _select:
			camera.position = IsoMath.tile_center_screen(b.entrance_tile())
			var panel: BuildingPanel = _game.get("_building_panel")
			panel.show_building(sim.province, b.id)
			return
