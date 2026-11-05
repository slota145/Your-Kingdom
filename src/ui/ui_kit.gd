class_name UiKit
extends RefCounted
## Small helpers shared by the game UI: one theme, labels and buttons built in code.

const FONT_SIZE := 24
const SMALL_FONT_SIZE := 16
const PANEL_WIDTH := 340.0


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_SIZE
	return t


static func label(text: String = "", wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = PANEL_WIDTH - 24.0
	return l


static func title(text: String = "") -> Label:
	var l := label(text)
	l.add_theme_color_override(&"font_color", Color(0.95, 0.82, 0.5))
	return l


static func button(key: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = key
	b.pressed.connect(on_pressed)
	return b


## "4 logs, 2 sacks of flour" from a goods dictionary.
static func goods_list(goods: Dictionary) -> String:
	var parts := PackedStringArray()
	var keys: Array = goods.keys()
	keys.sort()
	for good: Variant in keys:
		parts.append(LocFormat.good_count(StringName(good), int(goods[good])))
	return ", ".join(parts)
