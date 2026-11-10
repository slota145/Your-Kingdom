extends Node
## UI-1 prototype: opens the main menu (or a game scene) and saves a screenshot.
## Run (cloud): xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 \
##   res://src/prototype/ui/menu_shot.tscn -- --out=/tmp/menu.png [--frames=60] [--open=maps|tools|new_game_panel [--scenario=0..3]]
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
	if _frames == 5 and _open != "":
		_menu.get("_" + _open).set("visible", true)
		if _open == "start_picker":
			var settings := GameSettings.new()
			settings.world_seed = 7
			settings.province_count = 30
			settings.islands = 6
			(_menu.get("_start_picker") as StartPicker).open(settings)
		if _open == "new_game_panel":
			_menu.get("_menu_box").set("visible", false)   # as the "New game" button does (M8)
			if _scenario >= 0:
				var panel := _menu.get("_new_game_panel") as NewGamePanel
				panel._scenario.selected = _scenario
				panel._refresh()
	if _frames == 30:
		var b: Control = _menu.get_child(0)
		print("backdrop size ", b.size, " scale ", b.get("_scale"), " menu ", _menu.size)
	if _frames == _wait and not _out.is_empty():
		get_viewport().get_texture().get_image().save_png(_out)
		get_tree().quit()
