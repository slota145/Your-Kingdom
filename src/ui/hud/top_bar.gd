class_name TopBar
extends PanelContainer
## Population, workforce, game time, gold and speed with their icons on a wooden board, plus
## the buttons (world map, stocks, routes, speed, save/load, language, menu).

signal save_requested
signal load_requested
signal menu_requested
signal stocks_requested
signal world_requested
signal routes_requested

var province: ProvinceSim
var clock: SimClock
var treasury: Treasury

var _residents: Label
var _workers: Label
var _time: Label
var _gold: Label
var _speed: Label


func _init() -> void:
	# A wooden board with light text and icons (ROADMAP UI-1).
	theme = UiKit.board_theme()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	add_child(row)
	_residents = _stat(row, "people", "ui.hud.residents_tip")
	_workers = _stat(row, "workers", "ui.hud.workers_tip")
	_time = _stat(row, "time", "ui.hud.time_tip")
	_gold = _stat(row, "gold", "ui.hud.gold_tip")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_speed = UiKit.label("", false)
	row.add_child(_speed)
	row.add_child(UiKit.button("ui.hud.world", func() -> void: world_requested.emit()))
	row.add_child(UiKit.button("ui.hud.stocks", func() -> void: stocks_requested.emit()))
	row.add_child(UiKit.button("ui.hud.routes", func() -> void: routes_requested.emit()))
	row.add_child(UiKit.button("ui.hud.pause", Game.toggle_pause))
	row.add_child(UiKit.button("ui.hud.slower", func() -> void: Game.set_speed_index(Game.speed_index - 1)))
	row.add_child(UiKit.button("ui.hud.faster", func() -> void: Game.set_speed_index(Game.speed_index + 1)))
	row.add_child(UiKit.button("ui.hud.save", func() -> void: save_requested.emit()))
	row.add_child(UiKit.button("ui.hud.load", func() -> void: load_requested.emit()))
	row.add_child(UiKit.button("ui.hud.language", Loc.cycle_locale))
	row.add_child(UiKit.button("ui.hud.menu", func() -> void: menu_requested.emit()))


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
	_speed.text = tr("ui.hud.paused") if Game.paused else tr("ui.hud.speed") % int(Game.get_speed())
