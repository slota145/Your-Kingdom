class_name UiKit
extends RefCounted
## Small helpers shared by the game UI: one theme ("parchment and wood", ROADMAP UI-1), labels
## and buttons built in code, and the colours of text on parchment and on wood.

const FONT_SIZE := 24
const SMALL_FONT_SIZE := 16
const PANEL_WIDTH := 340.0

## The "parchment and wood" style (ROADMAP UI-1, owner's decision 2026-11-07). Art in
## assets/ui/ (tools/generate_ui.gd), one art pixel = 2x2 screen pixels.
const UI_ART := "res://assets/ui/"
## Text on parchment: ink, faded ink for hints, red-brown headings.
const INK := Color(0.24, 0.15, 0.08)
const INK_SOFT := Color(0.42, 0.31, 0.2)
const HEADING := Color(0.55, 0.14, 0.08)
## Good and bad numbers on parchment (balances, warnings).
const GOOD := Color(0.16, 0.43, 0.1)
const BAD := Color(0.68, 0.12, 0.07)
## Text on wood (buttons, bars) and over the town (notes).
const LIGHT := Color(0.97, 0.91, 0.76)
const LIGHT_SOFT := Color(0.86, 0.78, 0.62)
const GOLD := Color(0.98, 0.8, 0.36)
## Nine-patch margins of the art (screen pixels).
const PANEL_MARGIN := 12
const BUTTON_MARGIN := 6

static var _theme: Theme
static var _board_theme: Theme


## The game's theme: parchment panels in wooden frames, wooden buttons, ink on parchment.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = FONT_SIZE
	var panel := _texture_box("panel.png", PANEL_MARGIN, 16, 14)
	for type: StringName in [&"PanelContainer", &"Panel"]:
		t.set_stylebox(&"panel", type, panel)
	t.set_color(&"font_color", &"Label", INK)
	for type: StringName in [&"Button", &"OptionButton", &"MenuButton"]:
		t.set_stylebox(&"normal", type, _texture_box("button_normal.png", BUTTON_MARGIN, 12, 5))
		t.set_stylebox(&"hover", type, _texture_box("button_hover.png", BUTTON_MARGIN, 12, 5))
		t.set_stylebox(&"pressed", type, _texture_box("button_pressed.png", BUTTON_MARGIN, 12, 5, 2))
		t.set_stylebox(&"disabled", type, _texture_box("button_disabled.png", BUTTON_MARGIN, 12, 5))
		t.set_stylebox(&"focus", type, StyleBoxEmpty.new())
		t.set_color(&"font_color", type, LIGHT)
		t.set_color(&"font_hover_color", type, Color.WHITE)
		t.set_color(&"font_pressed_color", type, LIGHT_SOFT)
		t.set_color(&"font_focus_color", type, LIGHT)
		t.set_color(&"font_hover_pressed_color", type, LIGHT)
		t.set_color(&"font_disabled_color", type, Color(0.78, 0.74, 0.68))
	# Tick boxes stay plain ink on parchment.
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed"]:
		t.set_stylebox(state, &"CheckBox", StyleBoxEmpty.new())
	for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color",
			&"font_hover_pressed_color"]:
		t.set_color(c, &"CheckBox", INK)
	t.set_stylebox(&"panel", &"TooltipPanel", _texture_box("tooltip.png", 2, 10, 6))
	t.set_color(&"font_color", &"TooltipLabel", INK)
	var line := StyleBoxLine.new()
	line.color = Color(0.42, 0.27, 0.15)
	line.thickness = 2
	t.set_stylebox(&"separator", &"HSeparator", line)
	var vline := StyleBoxLine.new()
	vline.color = line.color
	vline.thickness = 2
	vline.vertical = true
	t.set_stylebox(&"separator", &"VSeparator", vline)
	# Drop-down lists, scroll bars and text fields in the same woods and parchment.
	t.set_stylebox(&"panel", &"PopupMenu", _texture_box("tooltip.png", 2, 10, 6))
	t.set_stylebox(&"hover", &"PopupMenu", _flat(Color(0.56, 0.38, 0.22)))
	t.set_color(&"font_color", &"PopupMenu", INK)
	t.set_color(&"font_hover_color", &"PopupMenu", LIGHT)
	t.set_color(&"font_disabled_color", &"PopupMenu", INK_SOFT)
	t.set_stylebox(&"normal", &"LineEdit", _texture_box("panel_inset.png", PANEL_MARGIN, 10, 6))
	t.set_color(&"font_color", &"LineEdit", INK)
	for bar: StringName in [&"VScrollBar", &"HScrollBar"]:
		t.set_stylebox(&"scroll", bar, _flat(Color(0.84, 0.75, 0.56)))
		t.set_stylebox(&"grabber", bar, _flat(Color(0.42, 0.27, 0.15)))
		t.set_stylebox(&"grabber_highlight", bar, _flat(Color(0.56, 0.38, 0.22)))
		t.set_stylebox(&"grabber_pressed", bar, _flat(Color(0.26, 0.16, 0.09)))
	_theme = t
	return t


## The theme of the wooden bars (top bar, build menu): a board of planks, light text.
static func board_theme() -> Theme:
	if _board_theme != null:
		return _board_theme
	var t := Theme.new()
	var board := StyleBoxTexture.new()
	board.texture = load(UI_ART + "board.png") as Texture2D
	board.texture_margin_top = 4
	board.texture_margin_bottom = 4
	board.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	board.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	board.content_margin_left = 12
	board.content_margin_right = 12
	board.content_margin_top = 6
	board.content_margin_bottom = 6
	for type: StringName in [&"PanelContainer", &"Panel"]:
		t.set_stylebox(&"panel", type, board)
	t.set_color(&"font_color", &"Label", LIGHT)
	t.set_color(&"font_outline_color", &"Label", Color(0.14, 0.08, 0.05))
	t.set_constant(&"outline_size", &"Label", 4)
	# Smaller buttons on the boards: the top bar fits 1280 px with all its buttons.
	t.set_font_size(&"font_size", &"Button", 20)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state, &"Button", _texture_box("button_%s.png" % state, BUTTON_MARGIN, 8, 4,
				2 if state == "pressed" else 0))
	t.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	# The active time control (a pressed icon button) shines gold.
	t.set_color(&"icon_pressed_color", &"Button", GOLD)
	t.set_color(&"icon_hover_pressed_color", &"Button", GOLD)
	_board_theme = t
	return t


## An icon of the UI art (gold, people, workers, time) at its pixel size.
static func icon(name: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(UI_ART + "icon_%s.png" % name) as Texture2D
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


static func _texture_box(file: String, margin: int, content_h: float, content_v: float,
		shift: float = 0.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(UI_ART + file) as Texture2D
	box.texture_margin_left = margin
	box.texture_margin_right = margin
	box.texture_margin_top = margin
	box.texture_margin_bottom = margin
	box.content_margin_left = content_h
	box.content_margin_right = content_h
	box.content_margin_top = content_v + shift
	box.content_margin_bottom = content_v - shift
	# The middle and the edges repeat (parchment fibres and wood grain stay pixel-sized).
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return box


static func _flat(colour: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	return box


static func label(text: String = "", wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = PANEL_WIDTH - 24.0
	return l


static func title(text: String = "") -> Label:
	var l := label(text)
	l.add_theme_color_override(&"font_color", HEADING)
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
