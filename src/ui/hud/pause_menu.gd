class_name PauseMenu
extends Control
## The pause menu (UI-2 part 1, owner 2026-11-13): Esc, or the "Menu" button of the top bar,
## opens it over the dimmed game, which stands still while it is open. Back to the game, quick
## save and load, the language, the main menu, quitting.

signal resumed
signal save_requested
signal load_requested
signal main_menu_requested
signal quit_requested

const DIM := Color(0.05, 0.03, 0.02, 0.55)

var _language: Button


func _init() -> void:
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	centre.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	box.custom_minimum_size.x = 300
	panel.add_child(box)
	var heading := UiKit.title("ui.pause.title")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.custom_minimum_size.x = 0
	box.add_child(heading)
	box.add_child(UiKit.button("ui.pause.resume", func() -> void: resumed.emit()))
	box.add_child(UiKit.button("ui.pause.save", func() -> void: save_requested.emit()))
	box.add_child(UiKit.button("ui.pause.load", func() -> void: load_requested.emit()))
	_language = UiKit.button("ui.hud.language", Loc.cycle_locale)
	_language.tooltip_text = "ui.pause.language_tip"
	box.add_child(_language)
	box.add_child(UiKit.button("ui.pause.main_menu", func() -> void: main_menu_requested.emit()))
	box.add_child(UiKit.button("ui.pause.quit", func() -> void: quit_requested.emit()))
	var hint := UiKit.label("ui.pause.hint", false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	hint.add_theme_color_override(&"font_color", UiKit.INK_SOFT)
	box.add_child(hint)

