class_name WorldMapScreen
extends Control
## The world map screen (ROADMAP M6, part 1): the parchment map of the provinces and, beside
## it, the panel of the province clicked: owner, people, stocks, rare resource, "Enter".
## Opened and closed with M (or Esc); the viewed province keeps living meanwhile (owner's
## decision 2026-11-06).
## Expeditions of settlers (M6 part 2, owner's decision 2026-11-06): the panel of the player's
## province prepares one (by land or by sea); a ready one stands by its town on the map, a
## click selects it and a right click on a province sends it there.
## Neutral settlements (M6 part 3, owner's decision 2026-11-06): their panel lists the demand
## (gold and goods with what was given, and the time left); gold is paid here, goods come by a
## trade route or a voyage "to my province".

signal enter_requested(id: int)
## Prepare, send or disband an expedition; the game scene executes it.
signal command_requested(command: Command)
signal closed
## Open the trade routes window with routes from province [param from].
signal routes_requested(from: int)
## "Send goods" to the neutral settlement [param to]: the routes window with its demand.
signal goods_requested(to: int)
## "Enter and fight" with army [param army] at its settlement (M7 part 3).
signal army_enter_requested(army: int)

const STOCK_LINES := 6

var sim: Simulation

var _canvas: WorldMapCanvas
var _title: Label
var _name: Label
var _lines: Label
var _hint: Label
var _enter: Button
var _expedition: ExpeditionBox
var _routes: Button
var _fleet_out: Button
var _demand: Label
var _pay: Button
var _send_goods: Button
var _army: WorldArmyBox
var _report: Label
## The answer to the last right click (why it cannot go there), shown until another click.
var _send_note: String = ""
var _selected: int = 0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.26, 0.16, 0.09)   # dark wood around the parchment map
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	_canvas = WorldMapCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.province_clicked.connect(select)
	_canvas.expedition_clicked.connect(_expedition_clicked)
	_canvas.send_requested.connect(_send)
	_canvas.army_clicked.connect(_army_clicked)
	_canvas.army_send_requested.connect(_send_army)
	_canvas.army_spot_requested.connect(func(id: int, spot: Vector2) -> void:
		_order_army(SendArmyCommand.to_spot(id, spot)))
	_canvas.army_chase_requested.connect(func(id: int, enemy: int) -> void:
		_order_army(SendArmyCommand.after(id, enemy)))
	row.add_child(_canvas)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = UiKit.PANEL_WIDTH
	row.add_child(panel)
	# Scrolls when the province's panel with its expedition does not fit on the screen.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_title = UiKit.title()
	box.add_child(_title)
	box.add_child(UiKit.label("ui.world.hint"))
	box.add_child(HSeparator.new())
	_army = WorldArmyBox.new()
	_army.command_requested.connect(func(command: Command) -> void:
		command_requested.emit(command)
		_refresh())
	_army.enter_requested.connect(func(army: int) -> void: army_enter_requested.emit(army))
	box.add_child(_army)
	_report = UiKit.label()
	_report.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	box.add_child(_report)
	_name = UiKit.title()
	box.add_child(_name)
	_lines = UiKit.label()
	box.add_child(_lines)
	_hint = UiKit.label()
	_hint.add_theme_color_override(&"font_color", UiKit.INK_SOFT)
	box.add_child(_hint)
	_enter = UiKit.button("ui.world.enter", func() -> void: enter_requested.emit(_selected))
	box.add_child(_enter)
	_demand = UiKit.label()
	box.add_child(_demand)
	_pay = UiKit.button("ui.world.pay", func() -> void:
		command_requested.emit(PaySettlementCommand.new(_selected))
		_refresh())
	box.add_child(_pay)
	_send_goods = UiKit.button("ui.world.send_goods", func() -> void: goods_requested.emit(_selected))
	box.add_child(_send_goods)
	box.add_child(HSeparator.new())
	_expedition = ExpeditionBox.new()
	_expedition.command_requested.connect(func(command: Command) -> void:
		command_requested.emit(command)
		_refresh())
	box.add_child(_expedition)
	_routes = UiKit.button("ui.world.routes", func() -> void: routes_requested.emit(_selected))
	box.add_child(_routes)
	_fleet_out = UiKit.button("ui.world.fleet_out", func() -> void:
		command_requested.emit(FleetOutCommand.new(_selected))
		_refresh())
	_fleet_out.tooltip_text = "ui.world.fleet_out_tip"
	box.add_child(_fleet_out)
	box.add_child(UiKit.button("ui.world.back", func() -> void: closed.emit()))


func open(simulation: Simulation) -> void:
	sim = simulation
	_canvas.sim = sim
	visible = true
	select(sim.viewed_id)


func select(id: int) -> void:
	_selected = id
	_canvas.selected = id
	if _canvas.army_selected != 0:
		var army := sim.world.armies.get(_canvas.army_selected) as Army if sim != null else null
		if army == null or army.at != id:
			_canvas.army_selected = 0
	_send_note = ""
	_refresh()


## The ready expedition of province [param from] is selected: its province's panel says what
## to do next.
func _expedition_clicked(from: int) -> void:
	select(from)
	_send_note = tr("ui.world.expedition_selected")
	_refresh()


## The player's army [param id] is selected: the panel of its province shows it.
func _army_clicked(id: int) -> void:
	var army := sim.world.armies.get(id) as Army
	if army == null:
		return
	if army.at != 0:
		_selected = army.at
		_canvas.selected = army.at
	_send_note = tr("ui.world.army_selected")
	_refresh()


## Right click on the town of [param to] with army [param id] selected.
func _send_army(id: int, to: int) -> void:
	_order_army(SendArmyCommand.new(id, to))


## An order for the selected army (M8 part 2): to a town, a spot or after an enemy army.
func _order_army(command: SendArmyCommand) -> void:
	var error := command.validate(sim)
	if error != &"":
		_send_note = tr("ui.command_error.%s" % error)
		_refresh()
		return
	command_requested.emit(command)
	_send_note = ""
	_refresh()


## A sea battle (M8 part 2) plays out on the map.
func show_sea_fight(at: Vector2) -> void:
	_canvas.show_sea_fight(at)


## Right click on [param to] with the expedition of [param from] selected.
func _send(from: int, to: int) -> void:
	var error := SendExpeditionCommand.error_for(sim, from, to)
	if error != &"":
		_send_note = tr("ui.command_error.%s" % error)
		_refresh()
		return
	command_requested.emit(SendExpeditionCommand.new(from, to))
	_canvas.expedition_from = 0
	select(from)


func _process(_delta: float) -> void:
	if visible and sim != null and Engine.get_process_frames() % 30 == 0:
		_refresh()


func _refresh() -> void:
	if sim == null:
		return
	var world_def := sim.data.get_world(sim.world.world_id)
	_title.text = tr(world_def.name_key()) if world_def != null else ""
	# The goal of a sandbox game (M8 part 1).
	var goal := Victory.progress(sim)
	if goal[1] > 0:
		_title.text += "  ·  " + tr("ui.world.goal") % [tr("ui.victory.%s" % sim.world.settings.victory), goal[0], goal[1]]
	# The Invasion from the sea (M8 part 5): when the next wave sets out.
	var wave_in := Invasion.seconds_to_next(sim)
	if sim.world.settings != null and sim.world.settings.victory == GameSettings.VICTORY_ENDLESS:
		_title.text += "  ·  " + tr("ui.world.endless") % [Victory.survived(sim)[0], Victory.elapsed_minutes(sim)]
	if wave_in >= 0:
		_title.text += "  ·  " + tr("ui.world.next_wave") % [sim.world.invasion.wave + 1, wave_in / 60, wave_in % 60]
	var def := sim.world.def_of(_selected, sim.data)
	_expedition.show_for(sim, _selected)
	_army.show_for(sim, _canvas.army_selected)
	_report.text = WorldArmyBox.report_text(sim, _selected)
	_report.visible = not _report.text.is_empty()
	_routes.visible = sim.world.owner_of(_selected) == ProvinceDef.OWNER_PLAYER and sim.runtimes.has(_selected)
	var fleet_error := Fleets.fleet_out_error(sim, _selected)
	_fleet_out.visible = _routes.visible and fleet_error != &"no_coast"
	_fleet_out.disabled = fleet_error != &""
	_fleet_out.text = tr("ui.world.fleet_out") % Fleets.free_warships(sim, _selected).size()
	_refresh_demand()
	if def == null:
		_name.text = ""
		_lines.text = ""
		_hint.text = ""
		_enter.visible = false
		_expedition.visible = false
		return
	_name.text = tr(def.name_key())
	var owner := sim.world.owner_of(_selected)
	var lines := PackedStringArray()
	var owner_name := tr("ruler.%s.name" % owner) if Rulers.is_ruler(owner) \
			else tr("ui.world.owner_%s" % (owner if owner != &"" else &"none"))
	lines.append(tr("ui.world.owner") % owner_name)
	var province := sim.province_state(_selected)
	if province != null:
		lines.append(tr("ui.world.population") % _residents(province))
		if owner == ProvinceDef.OWNER_PLAYER:
			lines.append(tr("ui.world.stocks") % _stocks(province))
	lines.append(tr("ui.world.rare") % (tr("rare.%s.name" % def.rare_resource)
			if def.rare_resource != &"" else tr("ui.world.rare_none")))
	var traits := PackedStringArray()
	for t: StringName in def.all_traits():
		traits.append(tr("trait.%s.name" % t))
	if not traits.is_empty():
		lines.append(tr("ui.world.traits") % ", ".join(traits))
	if def.island:
		lines.append(tr("ui.world.island"))
	if Rulers.is_ruler(owner) and province != null:
		lines.append_array(_ruler_lines(owner, province))
	var routes := sim.world.routes_of(_selected).size()
	if routes > 0:
		lines.append(tr("ui.world.routes_count") % routes)
	lines.append(tr(def.desc_key()))
	_lines.text = "\n".join(lines)
	var expedition := sim.world.expedition_to(_selected, ProvinceDef.OWNER_PLAYER)
	var waiting := expedition != null and expedition.state == Expedition.State.WAITING
	var visit := province != null and Rulers.is_ruler(owner)
	var can_enter := (province != null and owner == ProvinceDef.OWNER_PLAYER) or waiting or visit
	_enter.visible = can_enter
	_enter.text = tr("ui.world.return") if _selected == sim.viewed_id \
			else tr("ui.world.land") if waiting else tr("ui.world.visit") if visit else tr("ui.world.enter")
	if waiting:
		_hint.text = tr("ui.world.expedition_waiting")
	elif expedition != null and expedition.state == Expedition.State.TRAVELLING:
		var minutes := ceili((expedition.arrive_at - sim.clock.tick) / float(SimClock.TICKS_PER_SECOND) / 60.0)
		_hint.text = tr("ui.world.expedition_coming") % maxi(minutes, 1)
	elif visit:
		_hint.text = tr("ui.world.visit_hint")
	elif can_enter:
		_hint.text = ""
	elif sim.world.camp != null and sim.world.camp.province == _selected:
		_hint.text = tr("ui.world.camp_hint") % sim.world.camp.gold
	elif owner == ProvinceDef.OWNER_NEUTRAL:
		_hint.text = tr("ui.world.neutral_hint")
	else:
		_hint.text = tr("ui.world.empty_hint")
	if not _send_note.is_empty():
		_hint.text = _send_note if _hint.text.is_empty() else _send_note + "\n" + _hint.text


## The demand of the selected neutral settlement.
func _refresh_demand() -> void:
	var s := sim.world.settlements.get(_selected) as NeutralSettlement \
			if sim.world.owner_of(_selected) == ProvinceDef.OWNER_NEUTRAL else null
	_demand.visible = s != null
	_pay.visible = s != null and s.state == NeutralSettlement.State.ASKING and s.gold_missing() > 0
	_send_goods.visible = s != null and s.state == NeutralSettlement.State.ASKING and not s.goods.is_empty()
	if s == null:
		return
	var minutes := maxi(ceili((s.until - sim.clock.tick) / float(SimClock.TICKS_PER_SECOND) / 60.0), 1)
	var lines := PackedStringArray()
	if s.state == NeutralSettlement.State.RESTING:
		lines.append(tr("ui.world.demand_resting") % minutes)
	else:
		lines.append(tr("ui.world.demand_title") % minutes)
		lines.append(tr("ui.world.demand_gold") % [s.gold_paid, s.gold])
		var goods: Array[StringName] = []
		goods.assign(s.goods.keys())
		goods.sort()
		for good: StringName in goods:
			lines.append(tr("ui.world.demand_good") % [tr(sim.data.get_good(good).name_key()),
					int(s.delivered.get(good, 0)), s.goods[good]])
		var rivals: Array[StringName] = []
		rivals.assign(s.rivals.keys())
		rivals.sort()
		for rival: StringName in rivals:
			lines.append(tr("ui.world.demand_rival") % [tr("ruler.%s.name" % rival),
					s.gold - s.gold_missing(rival), s.gold])
		lines.append(tr("ui.world.demand_hint"))
	_demand.text = "\n".join(lines)
	_pay.text = tr("ui.world.pay") % mini(s.gold_missing(), sim.treasury.gold)
	_pay.disabled = sim.treasury.gold <= 0


## What the panel tells about AI ruler [param owner] (M8 part 3, owner's survey 2026-11-10):
## his provinces, people and gold, what he builds, where his settlers go, what he buys, and
## how far along the plan of growth the selected province is.
func _ruler_lines(owner: StringName, province: ProvinceSim) -> PackedStringArray:
	var lines := PackedStringArray()
	var held := Rulers.provinces_of(sim.world, owner)
	var people := 0
	var building: Array[String] = []
	for id: int in held:
		var p := sim.province_state(id)
		if p == null:
			continue
		people += _residents(p)
		for b: BuildingState in p.buildings.all():
			var name := tr(b.def.name_key())
			if b.under_construction and building.size() < 3 and not building.has(name):
				building.append(name)
	var ruler := sim.world.rulers.get(owner) as RulerState
	lines.append(tr("ui.ruler.summary") % [held.size(), people, ruler.treasury.gold if ruler != null else 0])
	lines.append(tr("ui.ruler.building") % ", ".join(building) if not building.is_empty()
			else tr("ui.ruler.building_none"))
	var progress := RulerPlanner.plan_progress(province)
	lines.append(tr("ui.ruler.plan") % [progress.x * 100 / maxi(progress.y, 1)])
	lines.append(tr("ui.ruler.army") % RulerWar.strength(sim, owner))
	if ruler != null and sim.world.armies.has(ruler.campaign) and ruler.war_target != 0:
		lines.append(tr("ui.ruler.campaign") % _province_name(ruler.war_target))
	elif ruler != null and ruler.next_war > sim.clock.tick and ruler.war_target == 0 \
			and sim.clock.tick < RulerWar.first_ticks(RulerWar.level(sim)):
		lines.append(tr("ui.ruler.campaign_soon") % maxi(ceili((ruler.next_war - sim.clock.tick)
				/ float(SimClock.TICKS_PER_SECOND) / 60.0), 1))
	for e: Expedition in sim.world.expeditions.values():
		if e.owner == owner and e.state == Expedition.State.TRAVELLING:
			lines.append(tr("ui.ruler.expedition") % _province_name(e.to))
	for id: int in held:
		var p := sim.province_state(id)
		if p != null and p.departure != null and not p.departure.is_sent():
			lines.append(tr("ui.ruler.gathering"))
	for route: TradeRoute in sim.world.routes.values():
		if sim.world.owner_of(route.from) == owner and sim.world.settlements.has(route.to):
			lines.append(tr("ui.ruler.buying") % _province_name(route.to))
	return lines


func _province_name(id: int) -> String:
	var def := sim.world.def_of(id, sim.data)
	return tr(def.name_key()) if def != null else ""


static func _residents(province: ProvinceSim) -> int:
	var sum := 0
	for b: BuildingState in province.buildings.all():
		if b.house != null:
			sum += b.house.residents
	return sum


## The province's largest stocks, "40 logs, 12 loaves…".
func _stocks(province: ProvinceSim) -> String:
	var amounts: Dictionary[StringName, int] = {}
	for good: GoodDef in sim.data.goods():
		var n := province.kingdom_stock(good.id)
		if n > 0:
			amounts[good.id] = n
	var goods: Array[StringName] = []
	goods.assign(amounts.keys())
	goods.sort_custom(func(a: StringName, b: StringName) -> bool:
		return amounts[a] > amounts[b] or (amounts[a] == amounts[b] and a < b))
	var top := {}
	for good: StringName in goods.slice(0, STOCK_LINES):
		top[good] = amounts[good]
	return UiKit.goods_list(top) if not top.is_empty() else tr("ui.world.no_stocks")
