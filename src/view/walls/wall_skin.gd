class_name WallSkin
extends RefCounted
## The stone of the walls (M7 part 2): face and crown samples cut from the PixelLab repaint of
## the walls prototype by tools/make_wall_skin.gd (ART_SPEC §10.15). Loaded once.

const DIR := "res://assets/walls/stone/"

## A texture whose u (and v for tops) repeat every [member period] grid units, starting at
## grid coordinate [member origin].
class Sample:
	extends RefCounted
	var texture: Texture2D
	var origin: Vector2
	var period: Vector2
	var height: float

## Lit face (normal +y), dark face (normal +x), crown top.
var lit: Sample
var dark: Sample
var top: Sample
var merlon_color: Color
var outline: Color

static var _shared: WallSkin = null


## The skin, or null when its files are missing (the walls are then drawn in flat colours).
static func shared() -> WallSkin:
	if _shared == null and FileAccess.file_exists(DIR + "skin.json"):
		_shared = WallSkin.new()
		_shared._load()
	return _shared


func _load() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "skin.json"))
	lit = _sample("lit", meta)
	dark = _sample("dark", meta)
	top = _sample("top", meta)
	var m: Array = meta["merlon"]
	merlon_color = Color(m[0], m[1], m[2])
	var o: Array = meta["outline"]
	outline = Color(o[0], o[1], o[2])


func _sample(name: String, meta: Dictionary) -> Sample:
	var d: Dictionary = meta[name]
	var s := Sample.new()
	s.texture = load(DIR + name + ".png") as Texture2D
	s.origin = Vector2(d["origin"][0], d["origin"][1])
	s.period = Vector2(d["period"][0], d["period"][1])
	s.height = float(d["height"])
	return s
