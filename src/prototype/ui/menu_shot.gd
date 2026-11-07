extends Node
## UI-1 prototype: opens the main menu (or a game scene) and saves a screenshot.
## Run (cloud): xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 \
##   res://src/prototype/ui/menu_shot.tscn -- --out=/tmp/menu.png [--frames=60] [--open=maps|tools]

var _frames: int = 0
var _wait: int = 60
var _out: String = ""
var _open: String = ""
var _menu: Control


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--frames="):
			_wait = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--open="):
			_open = arg.trim_prefix("--open=")
	_menu = (load("res://src/main/main.tscn") as PackedScene).instantiate() as Control
	add_child(_menu)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 5 and _open != "":
		_menu.get("_" + _open).set("visible", true)
	if _frames == 30:
		var b: Control = _menu.get_child(0)
		print("backdrop size ", b.size, " scale ", b.get("_scale"), " menu ", _menu.size)
	if _frames == _wait and not _out.is_empty():
		get_viewport().get_texture().get_image().save_png(_out)
		get_tree().quit()
