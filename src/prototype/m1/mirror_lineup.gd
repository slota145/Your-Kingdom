extends Node2D
## M1 PROTOTYPE: the same person in all 8 directions, drawn (top row) vs. mirrored from 5
## directions (bottom row), at 3x. The tool is held in the right hand, so mirroring moves
## it to the left hand on the W-side directions. Debug texts hardcoded (prototype-only).

const DIR_NAMES: PackedStringArray = ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const ROWS: Array = [
	[&"peasant", &"walk", "", &"", "8 directions drawn (tool)"],
	[&"peasant_mirror", &"walk", "", &"", "5 drawn + 3 mirrored (tool)"],
	[&"peasant", &"walk_carry_sack", "sack", &"flour", "8 drawn (flour sack)"],
	[&"peasant_mirror", &"walk_carry_sack", "sack", &"flour", "5 + mirrored (flour sack)"],
]
const ZOOM := 3.0

var _sprites: Array[AgentSprite] = []
var _time: float = 0.0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.36, 0.55, 0.25)
	bg.size = Vector2(4000, 4000)
	bg.position = Vector2(-100, -100)
	add_child(bg)
	for r: int in ROWS.size():
		var label := Label.new()
		label.text = ROWS[r][4]
		label.position = Vector2(12, 40 + r * 200)
		label.add_theme_font_size_override(&"font_size", 18)
		add_child(label)
		for d: int in IsoMath.DIR_COUNT:
			var sprite := AgentSprite.new()
			sprite.scale = Vector2.ONE * ZOOM
			sprite.position = Vector2(260 + d * 160, 200 + r * 200)
			add_child(sprite)
			_sprites.append(sprite)
			if r == 0:
				var dir_label := Label.new()
				dir_label.text = DIR_NAMES[d]
				dir_label.position = Vector2(245 + d * 160, 4)
				dir_label.add_theme_font_size_override(&"font_size", 18)
				add_child(dir_label)


func _process(delta: float) -> void:
	_time += delta
	for r: int in ROWS.size():
		var row: Array = ROWS[r]
		for d: int in IsoMath.DIR_COUNT:
			_sprites[r * IsoMath.DIR_COUNT + d].show_state(CharacterVisual.get_visual(row[0]),
					row[1], d, _time, row[2], row[3])
