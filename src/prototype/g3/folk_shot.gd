extends Node2D
## G3 PROTOTYPE: a townsperson drawn by the game's own AgentSprite, every clip (idle, walk,
## each carry walk with a real good, each work move) in all 8 directions, for review shots.
## Debug texts hardcoded (prototype-only).
## Run: xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 src/prototype/g3/folk_shot.tscn --
##      --shot=<png> --id=<porter|farmer|builder> [--time=<seconds>] [--zoom=2]

const DIR_NAMES: PackedStringArray = ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const CARRIED: Dictionary[String, StringName] = {"sack": &"flour", "barrel": &"beer", "log": &"wood",
		"basket": &"bread", "bundle": &"wool", "crate": &"chainmail", "stone": &"stone"}

var _id: StringName = &"porter"
var _shot := ""
var _time := 0.3
var _zoom := 2.0
var _rows: Array = []   # [anim, carry category, good]


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
		elif arg.begins_with("--id="):
			_id = StringName(arg.trim_prefix("--id="))
		elif arg.begins_with("--time="):
			_time = float(arg.trim_prefix("--time="))
		elif arg.begins_with("--zoom="):
			_zoom = float(arg.trim_prefix("--zoom="))
	var visual := CharacterVisual.get_visual(_id)
	_rows = [[&"idle", "", &""], [&"walk", "", &""]]
	for category: String in CARRIED:
		_rows.append([StringName("walk_carry_" + category), category, CARRIED[category]])
	var works: Array = visual.animations.keys().filter(func(a: StringName) -> bool: return String(a).begins_with("work_"))
	works.sort()
	for anim: StringName in works:
		_rows.append([anim, "", &""])
	var cell := 64.0 * _zoom + 8.0
	var bg := ColorRect.new()
	bg.color = Color(0.36, 0.5, 0.25)
	bg.size = Vector2(160 + cell * 8, 40 + cell * _rows.size())
	add_child(bg)
	get_window().size = Vector2i(bg.size)
	for r: int in _rows.size():
		var label := Label.new()
		label.text = String(_rows[r][0]).trim_prefix("walk_carry_").trim_prefix("work_")
		label.position = Vector2(8, 40 + r * cell + cell * 0.4)
		add_child(label)
		for d: int in IsoMath.DIR_COUNT:
			if r == 0:
				var dir_label := Label.new()
				dir_label.text = DIR_NAMES[d]
				dir_label.position = Vector2(160 + d * cell + cell * 0.4, 8)
				add_child(dir_label)
			var sprite := AgentSprite.new()
			sprite.scale = Vector2.ONE * _zoom
			sprite.position = Vector2(160 + d * cell + cell * 0.5, 40 + r * cell + 58.0 * _zoom)
			add_child(sprite)
			sprite.show_state(visual, _rows[r][0], d, _time, _rows[r][1], _rows[r][2])
	_save.call_deferred()


func _save() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot)
	print("saved ", _shot)
	get_tree().quit()
