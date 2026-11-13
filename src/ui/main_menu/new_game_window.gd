class_name NewGameWindow
extends PanelContainer
## "New game" in its own window (ROADMAP UI-2 part 3, owner's survey 2026-11-13): the options
## (NewGamePanel) on the left, on the right a small map of the world they make, drawn again at
## once whenever an option changes (the same generator and numbers the game will use) and a
## "Roll another" button for a new world number. The hand-made "Kingdom" is shown as it is.

signal start_requested(settings: GameSettings)
signal back_requested

## How long after the last change the world is made again (a dragged slider makes many changes).
const REDRAW_DELAY := 0.08

var panel: NewGamePanel
var preview: WorldPreview
var _caption: Label
var _reroll: Button
var _timer: Timer
## What the shown world was made from: a change of rulers or victory needs no new world.
var _shown_key: Array = []


func _init() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	add_child(row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.x = 470
	row.add_child(scroll)
	panel = NewGamePanel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.start_requested.connect(func(settings: GameSettings) -> void: start_requested.emit(settings))
	panel.back_requested.connect(func() -> void: back_requested.emit())
	scroll.add_child(panel)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 8)
	row.add_child(right)
	right.add_child(UiKit.title("ui.new_game.preview"))
	preview = WorldPreview.new()
	preview.pickable = false
	preview.font_size = UiKit.SMALL_FONT_SIZE
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(360, 260)
	right.add_child(preview)
	_caption = UiKit.label()
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_caption)
	var buttons := HBoxContainer.new()
	_reroll = UiKit.button("ui.new_game.random", panel.reroll)
	buttons.add_child(_reroll)
	var hint := UiKit.label("ui.new_game.preview_hint", false)
	hint.add_theme_color_override(&"font_color", UiKit.INK_SOFT)
	hint.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buttons.add_child(hint)
	right.add_child(buttons)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = REDRAW_DELAY
	_timer.timeout.connect(redraw)
	add_child(_timer)
	panel.options_changed.connect(_on_options_changed)


## Shows the window with the world of the current options.
func open() -> void:
	visible = true
	redraw()


func _on_options_changed() -> void:
	_reroll.disabled = not panel.is_generated()
	if is_inside_tree() and visible:
		_timer.start()


## Makes the world of the current options again (unless it is the one shown) and draws it.
func redraw() -> void:
	_timer.stop()
	var settings := panel.settings()
	var data: DataRegistry = Data.registry
	var key: Array = [settings.world_def, settings.world_seed, settings.province_count, settings.islands,
			settings.scenario == GameSettings.ISLANDS]
	if key == _shown_key:
		return
	_shown_key = key
	var world: WorldDef = WorldGenerator.geography(data, settings) if settings.is_generated() \
			else data.get_world(settings.world_def)
	preview.show_world(world, data)
	var islands := 0
	var coast := 0
	for id: StringName in world.provinces:
		var def := data.get_province(id)
		if def.island:
			islands += 1
		if def.coastal:
			coast += 1
	# (A generated world's name has its number in it.)
	var world_name := tr(world.name_key())
	_caption.text = tr("ui.new_game.preview_caption") % [world_name,
			tr_n("ui.new_game.preview_provinces", "ui.new_game.preview_provinces_plural", world.provinces.size()) \
					% world.provinces.size(),
			tr_n("ui.new_game.preview_islands", "ui.new_game.preview_islands_plural", islands) % islands,
			tr_n("ui.new_game.preview_coast", "ui.new_game.preview_coast_plural", coast) % coast]
