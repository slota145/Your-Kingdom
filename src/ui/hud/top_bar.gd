class_name TopBar
extends PanelContainer
## Population, workforce and gold with their icons on a wooden board; in the middle the clock
## with pause and the three speeds as icon buttons (owner's request 2026-11-07); on the right
## the buttons (world map, stocks, routes, save/load, language, menu).

signal save_requested
signal load_requested
signal menu_requested
signal stocks_requested
signal world_requested
signal routes_requested
## "Research" (E4 part 2).
signal research_requested
## The "Contentment" button: faces over every house on or off (E2 part 3).
signal moods_toggled(on: bool)

var province: ProvinceSim
var clock: SimClock
var treasury: Treasury

var _residents: Label
var _workers: Label
var _time: Label
var _gold: Label
## Start protection left (review fix 2026-11-07); hidden when over.
var _grace: Label
## Pause and the three speeds (owner's request 2026-11-07): the active one stays pressed.
var _pause: Button
var _speeds: Array[Button] = []


func _init() -> void:
	# A wooden board with light text and icons (ROADMAP UI-1).
	theme = UiKit.board_theme()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	add_child(row)
	_residents = _stat(row, "people", "ui.hud.residents_tip")
	_workers = _stat(row, "workers", "ui.hud.workers_tip")
	_gold = _stat(row, "gold", "ui.hud.gold_tip")
	_grace = UiKit.label("", false)
	_grace.tooltip_text = "ui.hud.grace_tip"
	_grace.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(_grace)
	row.add_child(_spacer())
	# The clock and the time controls in the middle of the board.
	_time = _stat(row, "time", "ui.hud.time_tip")
	_pause = _time_button(row, "pause", "ui.hud.pause_tip", func() -> void: Game.toggle_pause())
	for i: int in Game.SPEEDS.size():
		var tip := tr("ui.hud.speed_tip") % int(Game.SPEEDS[i])
		_speeds.append(_time_button(row, "speed_%d" % (i + 1), tip, func() -> void:
			Game.set_speed_index(i)
			if Game.paused:
				Game.toggle_pause()))
	row.add_child(_spacer())
	row.add_child(UiKit.button("ui.hud.world", func() -> void: world_requested.emit()))
	row.add_child(UiKit.button("ui.hud.stocks", func() -> void: stocks_requested.emit()))
	row.add_child(UiKit.button("ui.hud.routes", func() -> void: routes_requested.emit()))
	row.add_child(UiKit.button("ui.hud.research", func() -> void: research_requested.emit()))
	var moods := UiKit.button("ui.hud.moods", func() -> void: pass)
	moods.toggle_mode = true
	moods.tooltip_text = "ui.hud.moods_tip"
	moods.toggled.connect(func(on: bool) -> void: moods_toggled.emit(on))
	row.add_child(moods)
	row.add_child(UiKit.button("ui.hud.save", func() -> void: save_requested.emit()))
	row.add_child(UiKit.button("ui.hud.load", func() -> void: load_requested.emit()))
	row.add_child(UiKit.button("ui.hud.language", Loc.cycle_locale))
	row.add_child(UiKit.button("ui.hud.menu", func() -> void: menu_requested.emit()))


static func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


## A wooden button with a time icon (pause, 1x, 2x, 4x); [method _process] keeps the active
## one pressed.
func _time_button(row: HBoxContainer, icon: String, tip: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.icon = load(UiKit.UI_ART + "icon_%s.png" % icon) as Texture2D
	b.tooltip_text = tip
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(44, 0)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(on_pressed)
	row.add_child(b)
	return b


## An icon and its number, with a tooltip saying what it counts.
func _stat(row: HBoxContainer, icon: String, tip: String) -> Label:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	box.tooltip_text = tip
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var picture := UiKit.icon(icon)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(picture)
	var value := UiKit.label("", false)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(value)
	row.add_child(box)
	return value


func _process(_delta: float) -> void:
	if province == null:
		return
	var residents := 0
	for b: BuildingState in province.buildings.all():
		if b.house != null:
			residents += b.house.residents
	var employed := 0
	for agent: Agent in province.agents.all():
		if agent.workplace_id != 0:
			employed += 1
	var seconds := int(clock.seconds())
	_residents.text = str(residents)
	_workers.text = tr("ui.hud.workers") % [employed, Population.workforce(province)]
	_time.text = tr("ui.hud.time") % [seconds / 60, seconds % 60]
	_gold.text = str(treasury.gold) if treasury != null else ""
	_gold.add_theme_color_override(&"font_color", UiKit.GOLD)
	var grace := ceili(province.grace_seconds_left())
	_grace.visible = grace > 0
	if grace > 0:
		_grace.text = tr("ui.hud.grace") % [grace / 60, grace % 60]
	_pause.set_pressed_no_signal(Game.paused)
	for i: int in _speeds.size():
		_speeds[i].set_pressed_no_signal(not Game.paused and Game.speed_index == i)
