class_name Cursors
extends RefCounted
## The mouse cursors (UI-4 part 1, owner's survey 2026-11-23; art from SpriteKiln,
## tools/spritekiln/gen_cursors.py): an ordinary gauntlet, and in the province with soldiers
## selected a spear with a pennant, a sword over an enemy, a hammer over what can be broken, an
## anchor over a warship to board, a "no way" sign where they cannot go. 32 px below an
## interface scale of 125%, 48 px from it. The hardware cursor: changed only when it changes.

const POINTER := &"pointer"
const COMMAND := &"command"
const ATTACK := &"attack"
const BREAK := &"break"
const BOARD := &"board"
const BLOCKED := &"blocked"
const ALL: Array[StringName] = [POINTER, COMMAND, ATTACK, BREAK, BOARD, BLOCKED]
const ART := "res://assets/ui/cursors/"
## From this interface scale the bigger cursors.
const BIG_FROM := 1.25

static var _current: String = ""
static var _hotspots: Dictionary = {}


## The picture name of [param kind] at [param ui_scale] ("attack_48").
static func art_name(kind: StringName, ui_scale: float) -> String:
	return "%s_%d" % [kind, 48 if ui_scale >= BIG_FROM else 32]


## Where the click lands in the picture of [param name].
static func hotspot(name: String) -> Vector2:
	if _hotspots.is_empty():
		var file := FileAccess.open(ART + "cursors.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_hotspots = parsed
	var spot: Array = _hotspots.get(name, [0, 0])
	return Vector2(float(spot[0]), float(spot[1]))


## Shows [param kind] (cheap when it is shown already).
static func show(kind: StringName) -> void:
	var name := art_name(kind, Options.ui_scale())
	if name == _current:
		return
	var texture := load(ART + name + ".png") as Texture2D
	if texture == null:
		return
	_current = name
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, hotspot(name))


## The cursor now shown ("" before the first).
static func current() -> String:
	return _current
