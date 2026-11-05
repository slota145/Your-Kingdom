class_name TopBar
extends PanelContainer
## Population, workforce, game time and speed, plus save/load, language and menu buttons.

signal save_requested
signal load_requested
signal menu_requested
signal stocks_requested

var province: ProvinceSim
var clock: SimClock
var treasury: Treasury

var _stats: Label
var _speed: Label


func _init() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	add_child(row)
	_stats = UiKit.label("", false)
	row.add_child(_stats)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_speed = UiKit.label("", false)
	row.add_child(_speed)
	row.add_child(UiKit.button("ui.hud.stocks", func() -> void: stocks_requested.emit()))
	row.add_child(UiKit.button("ui.hud.pause", Game.toggle_pause))
	row.add_child(UiKit.button("ui.hud.slower", func() -> void: Game.set_speed_index(Game.speed_index - 1)))
	row.add_child(UiKit.button("ui.hud.faster", func() -> void: Game.set_speed_index(Game.speed_index + 1)))
	row.add_child(UiKit.button("ui.hud.save", func() -> void: save_requested.emit()))
	row.add_child(UiKit.button("ui.hud.load", func() -> void: load_requested.emit()))
	row.add_child(UiKit.button("ui.hud.language", Loc.cycle_locale))
	row.add_child(UiKit.button("ui.hud.menu", func() -> void: menu_requested.emit()))


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
	_stats.text = tr("ui.hud.stats") % [residents, employed, Population.workforce(province),
			seconds / 60, seconds % 60]
	if treasury != null:
		_stats.text += "  ·  " + tr("ui.hud.gold") % treasury.gold
	_speed.text = tr("ui.hud.paused") if Game.paused else tr("ui.hud.speed") % int(Game.get_speed())
