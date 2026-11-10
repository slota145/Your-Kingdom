class_name ResultWindow
extends PanelContainer
## The end of a sandbox game (ROADMAP M8 part 1): victory or defeat, why, and the choice to
## play on or go back to the main menu.

signal continue_requested
signal menu_requested

var _title: Label
var _text: Label


func _init() -> void:
	custom_minimum_size = Vector2(460, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	add_child(box)
	_title = UiKit.title()
	_title.add_theme_font_size_override(&"font_size", 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_text = UiKit.label()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(UiKit.button("ui.result.continue", func() -> void: continue_requested.emit()))
	buttons.add_child(UiKit.button("ui.result.menu", func() -> void: menu_requested.emit()))
	box.add_child(buttons)


## Shows the end of the game: [param won], by [param victory] (GameSettings.VICTORY_*).
## [param winner]: the ruler who won the gold race instead of the player (M8 part 5), or &"".
func show_result(won: bool, victory: StringName, winner: StringName = &"") -> void:
	_title.text = tr("ui.result.won_title" if won else "ui.result.lost_title")
	if won:
		_text.text = tr("ui.result.won_%s" % victory)
	elif winner != &"":
		_text.text = tr("ui.result.lost_gold") % tr("ruler.%s.name" % winner)
	else:
		_text.text = tr("ui.result.lost")
	visible = true
