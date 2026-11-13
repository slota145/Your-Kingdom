extends Node
## UI-1 prototype: opens the main menu (or a game scene) and saves a screenshot.
## Run (cloud): xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 \
##   res://src/prototype/ui/menu_shot.tscn -- --out=/tmp/menu.png [--frames=60] [--open=maps|tools|new_game_panel [--scenario=0..3]]
##   UI-2 part 3, the "New game" window with its live preview: --open=new_game_panel
##   [--scenario=0..3] [--seed=<n>] [--provinces=9..60] [--islands=0..] [--kingdom] [--reroll] [--archipelago]
##   [--shift=x,y]  holds the backdrop layers as if the mouse were at x,y (-1..1, 1 = the
##   right or bottom edge): the review fix 2026-11-07 check that the picture's edges never show.

var _frames: int = 0
var _wait: int = 60
var _out: String = ""
var _open: String = ""
var _menu: Control
var _shift: Vector2 = Vector2.INF
## --scenario=<0..3> (M8 part 5): the scenario chosen in the "New game" panel.
var _scenario: int = -1
## UI-2 part 3: the world options set in the "New game" window (-1 = as they are).
var _seed: int = -1
var _provinces: int = -1
var _islands: int = -1
var _kingdom := false
var _reroll := false
var _archipelago := false


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--frames="):
			_wait = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--open="):
			_open = arg.trim_prefix("--open=")
		elif arg.begins_with("--scenario="):
			_scenario = int(arg.trim_prefix("--scenario="))
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--provinces="):
			_provinces = int(arg.trim_prefix("--provinces="))
		elif arg.begins_with("--islands="):
			_islands = int(arg.trim_prefix("--islands="))
		elif arg == "--kingdom":
			_kingdom = true
		elif arg == "--archipelago":
			_archipelago = true
		elif arg == "--reroll":
			_reroll = true
		elif arg.begins_with("--shift="):
			var parts := arg.trim_prefix("--shift=").split(",")
			_shift = Vector2(float(parts[0]), float(parts[1]))
	# Runs after the backdrop, so the held shift wins over the real mouse.
	process_priority = 10
	_menu = (load("res://src/main/main.tscn") as PackedScene).instantiate() as Control
	add_child(_menu)


func _process(_delta: float) -> void:
	_frames += 1
	if _shift != Vector2.INF:
		_menu.get_child(0).set("_mouse", _shift)
	if _frames == 5 and _open != "" and _open != "new_game_panel":
		_menu.get("_" + _open).set("visible", true)
		if _open == "start_picker":
			var settings := GameSettings.new()
			settings.world_seed = 7
			settings.province_count = 30
			settings.islands = 6
			(_menu.get("_start_picker") as StartPicker).open(settings)
	if _frames == 5 and _open == "new_game_panel":
		_menu.call("open_new_game")   # as the "New game" button does
		var window := _menu.get("_new_game_window") as NewGameWindow
		var panel := window.panel
		if _scenario >= 0:
			panel._scenario.selected = _scenario
		if _kingdom:
			panel._world.selected = 1
		if _seed > 0:
			panel._seed.value = _seed
		if _provinces > 0:
			panel._provinces.value = _provinces
		if _islands >= 0:
			panel._islands.value = _islands
		if _archipelago:
			panel._shape.selected = 1
		if _reroll:
			panel.reroll()
		panel._refresh()
		window.redraw()
	if _frames == 30:
		var b: Control = _menu.get_child(0)
		print("backdrop size ", b.size, " scale ", b.get("_scale"), " menu ", _menu.size)
	if _frames == _wait and not _out.is_empty():
		get_viewport().get_texture().get_image().save_png(_out)
		get_tree().quit()
