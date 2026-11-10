class_name RoutesWindow
extends PanelContainer
## "Trade routes" (ROADMAP M6 part 3, owner's decision 2026-11-06: a window of its own, opened
## from the top bar and from the world map). Lists every route of the kingdom: from, to, the
## vehicle and what it is doing, and up to 3 goods, each with the units of a run and the
## threshold ("while B has less than N"); a route can be paused or removed. Below, a new route:
## from, to, by sea or by land, a free cog or the merchant wagon of a trading post of A, and its first good.
## To a neutral settlement the new route takes its whole demand instead of one good (review fix
## 2026-11-07: "Send goods" on the world map opens this window with the settlement chosen).
## Reads the simulation; changes go out as commands.

signal command_requested(command: Command)
signal closed

const REFRESH := 0.5
const AMOUNT_STEP_SEA := 5
const AMOUNT_STEP_LAND := 1
const BELOW_STEP := 5

var sim: Simulation

var _list: VBoxContainer
var _empty: Label
var _from: OptionButton
var _to: OptionButton
var _way: OptionButton
var _vehicle: OptionButton
var _good: OptionButton
## What a route to a settlement will take (its demand), instead of the good choice.
var _demand: Label
var _demand_lines: Array[Dictionary] = []
var _create: Button
var _note: Label
var _timer: float = 0.0
## What the list shows (rebuilt only when routes or their goods change).
var _shown: String = ""
var _state_labels: Dictionary[int, Label] = {}


func _init() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiKit.title("ui.routes.title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.button("ui.close", func() -> void: closed.emit()))
	var hint := UiKit.label("ui.routes.hint")
	hint.custom_minimum_size.x = 760.0
	hint.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	box.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(800, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_list)
	_empty = UiKit.label("ui.routes.none")
	box.add_child(_empty)
	box.add_child(HSeparator.new())
	box.add_child(UiKit.label("ui.routes.new", false))
	var row := HFlowContainer.new()
	box.add_child(row)
	_from = _option(row, func(_i: int) -> void: _fill_new(false))
	row.add_child(UiKit.label("→", false))
	_to = _option(row, func(_i: int) -> void: _fill_new(false))
	_way = _option(row, func(_i: int) -> void: _fill_new(false))
	_vehicle = _option(row, func(_i: int) -> void: _check_new())
	_good = _option(row, func(_i: int) -> void: _check_new())
	_demand = UiKit.label("", false)
	row.add_child(_demand)
	_create = UiKit.button("ui.routes.create", _create_route)
	row.add_child(_create)
	_note = UiKit.label()
	_note.add_theme_color_override(&"font_color", UiKit.BAD)
	box.add_child(_note)


func _option(parent: Control, on_selected: Callable) -> OptionButton:
	var option := OptionButton.new()
	option.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE + 2)
	option.item_selected.connect(on_selected)
	parent.add_child(option)
	return option


func open(simulation: Simulation, from: int = 0, to: int = 0) -> void:
	sim = simulation
	visible = true
	_shown = ""
	_note.text = ""
	_fill_new(true, from, to)
	_refresh()


func _process(delta: float) -> void:
	if not visible or sim == null:
		return
	_timer += delta
	if _timer >= REFRESH:
		_timer = 0.0
		_refresh()


func _refresh() -> void:
	var signature := _signature()
	if signature != _shown:
		_shown = signature
		_build_list()
	for id: int in _state_labels:
		var route := sim.world.routes.get(id) as TradeRoute
		if route != null:
			_state_labels[id].text = _state_text(route)
	_empty.visible = _route_ids().is_empty()


func _signature() -> String:
	var parts := PackedStringArray()
	for id: int in _route_ids():
		var route := sim.world.routes[id] as TradeRoute
		parts.append(str(route.to_dict().get("lines")) + str(route.paused) + str(route.closing))
	return ";".join(parts)


## The player's routes (the AI rulers' run on their own, M8 part 3).
func _route_ids() -> Array[int]:
	var ids: Array[int] = []
	for id: int in sim.world.routes:
		if sim.world.owner_of(sim.world.routes[id].from) == ProvinceDef.OWNER_PLAYER:
			ids.append(id)
	ids.sort()
	return ids


func _province_name(id: int) -> String:
	var def := sim.world.def_of(id, sim.data)
	return tr(def.name_key()) if def != null else str(id)


func _small(text: String) -> Label:
	var l := UiKit.label(text, false)
	l.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	return l


# --- The list ------------------------------------------------------------------------------

func _build_list() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_state_labels.clear()
	for id: int in _route_ids():
		_list.add_child(_route_box(sim.world.routes[id] as TradeRoute))


func _route_box(route: TradeRoute) -> Control:
	var box := VBoxContainer.new()
	var head := HBoxContainer.new()
	box.add_child(head)
	var name := UiKit.label(tr("ui.routes.route") % [_province_name(route.from), _province_name(route.to),
			tr("ui.routes.by_sea") if route.by_sea else tr("ui.routes.by_land")], false)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	if not route.one_off:
		var pause := UiKit.button("ui.routes.resume" if route.paused else "ui.routes.pause", func() -> void:
			_set_lines(route, route.lines, not route.paused))
		head.add_child(pause)
		var remove := UiKit.button("ui.routes.remove", func() -> void:
			command_requested.emit(RemoveTradeRouteCommand.new(route.id))
			_shown = "")
		remove.disabled = route.closing
		head.add_child(remove)
	var state := _small("")
	state.add_theme_color_override(&"font_color", UiKit.INK_SOFT)
	box.add_child(state)
	_state_labels[route.id] = state
	for i: int in route.lines.size():
		box.add_child(_line_row(route, i))
	if not route.one_off and not route.closing and route.lines.size() < TradeRoute.MAX_LINES:
		var add := OptionButton.new()
		add.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE + 2)
		_fill_goods(add, route.from, _goods_of(route))
		add.item_selected.connect(func(index: int) -> void:
			if index <= 0:
				return
			var lines := route.lines.duplicate()
			lines.append(TradeRoute.line(StringName(String(add.get_item_metadata(index))),
					_default_amount(route.by_sea), TradeRoute.DEFAULT_BELOW))
			_set_lines(route, lines, route.paused))
		box.add_child(add)
	box.add_child(HSeparator.new())
	return box


func _goods_of(route: TradeRoute) -> Array[StringName]:
	var goods: Array[StringName] = []
	for entry: Dictionary in route.lines:
		goods.append(entry["good"])
	return goods


func _line_row(route: TradeRoute, index: int) -> Control:
	var entry := route.lines[index]
	var good: StringName = entry["good"]
	var row := HBoxContainer.new()
	var name := UiKit.label(tr(sim.data.get_good(good).name_key()), false)
	name.custom_minimum_size.x = 150
	row.add_child(name)
	var editable := not route.one_off and not route.closing
	var step := AMOUNT_STEP_SEA if route.by_sea else AMOUNT_STEP_LAND
	row.add_child(_small(tr("ui.routes.amount")))
	_stepper(row, int(entry["amount"]), editable, func(delta: int) -> void:
		_change(route, index, "amount", delta * step, 1))
	if not route.one_off:
		row.add_child(_small(tr("ui.routes.below")))
		_stepper(row, int(entry["below"]), editable, func(delta: int) -> void:
			_change(route, index, "below", delta * BELOW_STEP, 0))
		var b := sim.province_state(route.to)
		if b != null:
			row.add_child(_small(tr("ui.routes.has") % b.stored(good)))
	if editable and route.lines.size() > 1:
		row.add_child(UiKit.button("×", func() -> void:
			var lines := route.lines.duplicate()
			lines.remove_at(index)
			_set_lines(route, lines, route.paused)))
	return row


func _stepper(row: HBoxContainer, value: int, editable: bool, on_step: Callable) -> void:
	if editable:
		row.add_child(UiKit.button("−", func() -> void: on_step.call(-1)))
	var amount := UiKit.label(str(value), false)
	amount.custom_minimum_size.x = 44
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(amount)
	if editable:
		row.add_child(UiKit.button("+", func() -> void: on_step.call(1)))


func _change(route: TradeRoute, index: int, key: String, delta: int, least: int) -> void:
	var lines: Array[Dictionary] = []
	for entry: Dictionary in route.lines:
		lines.append(entry.duplicate())
	lines[index][key] = maxi(int(lines[index][key]) + delta, least)
	_set_lines(route, lines, route.paused)


func _set_lines(route: TradeRoute, lines: Array, paused: bool) -> void:
	var typed: Array[Dictionary] = []
	for entry: Variant in lines:
		typed.append((entry as Dictionary).duplicate())
	command_requested.emit(SetTradeRouteCommand.new(route.id, typed, paused))
	_shown = ""
	_refresh()


func _state_text(route: TradeRoute) -> String:
	var text := ""
	var minutes := maxi(ceili((route.arrive_at - sim.clock.tick) / float(SimClock.TICKS_PER_SECOND) / 60.0), 1)
	match route.state:
		TradeRoute.State.WAITING:
			if route.paused:
				text = tr("ui.routes.state.paused")
			elif not TradeRoutes.vehicle_ready(sim, route) and not _vehicle_exists(route):
				text = tr("ui.routes.state.no_vehicle")
			else:
				text = tr("ui.routes.state.waiting")
		TradeRoute.State.LOADING:
			text = tr("ui.routes.state.loading") % _province_name(route.from)
		TradeRoute.State.TRAVELLING:
			text = tr("ui.routes.state.travelling") % [UiKit.goods_list(route.cargo),
					_province_name(route.to), minutes]
		TradeRoute.State.UNLOADING:
			text = tr("ui.routes.state.unloading") % _province_name(route.to)
		TradeRoute.State.RETURNING:
			text = tr("ui.routes.state.returning") % minutes
	text += "  ·  " + tr("ui.routes.done") % [route.runs, route.delivered]
	if route.closing:
		text += "  ·  " + tr("ui.routes.closing")
	return text


func _vehicle_exists(route: TradeRoute) -> bool:
	return TradeRoutes.cog(sim, route) != null if route.by_sea else TradeRoutes.depot(sim, route) != null


# --- A new route ---------------------------------------------------------------------------

func _player_provinces() -> Array[int]:
	var ids: Array[int] = []
	for id: int in sim.runtime_ids():
		if sim.world.owner_of(id) == ProvinceDef.OWNER_PLAYER:
			ids.append(id)
	return ids


## Fills the new route's choices; [param reset] chooses [param from] (or the viewed province)
## and [param to].
func _fill_new(reset: bool, from: int = 0, to: int = 0) -> void:
	var from_id := _selected(_from)
	var to_id := _selected(_to)
	var sea := _way.get_selected_id() == 1
	if reset:
		from_id = from if from != 0 else sim.viewed_id
		to_id = to
	var provinces := _player_provinces()
	_fill(_from, provinces, from_id)
	from_id = _selected(_from)
	var targets: Array[int] = []
	# Neutral settlements asking for goods are destinations too (M6 part 3).
	for id: int in sim.runtime_ids():
		if not provinces.has(id) and sim.world.settlements.has(id):
			provinces.append(id)
	for id: int in provinces:
		if id != from_id and (CreateTradeRouteCommand.route_error(sim, from_id, id, true) == &"" \
				or CreateTradeRouteCommand.route_error(sim, from_id, id, false) == &""):
			targets.append(id)
	_fill(_to, targets, to_id)
	to_id = _selected(_to)
	_way.clear()
	if to_id != 0 and CreateTradeRouteCommand.route_error(sim, from_id, to_id, false) == &"":
		_way.add_item(tr("ui.routes.by_land"), 0)
	if to_id != 0 and CreateTradeRouteCommand.route_error(sim, from_id, to_id, true) == &"":
		_way.add_item(tr("ui.routes.by_sea"), 1)
	for i: int in _way.item_count:
		if (_way.get_item_id(i) == 1) == sea:
			_way.select(i)
	sea = _way.get_selected_id() == 1
	_vehicle.clear()
	if _way.item_count > 0:
		for vehicle: int in CreateTradeRouteCommand.free_vehicles(sim, from_id, sea):
			_vehicle.add_item(_vehicle_name(from_id, sea, vehicle), vehicle)
	_fill_goods(_good, from_id, [])
	_demand_lines = TradeRoutes.demand_lines(sim, to_id)
	var demand := {}
	for entry: Dictionary in _demand_lines:
		demand[entry["good"]] = entry["amount"]
	_demand.text = tr("ui.routes.demand") % UiKit.goods_list(demand) if not demand.is_empty() else ""
	_demand.visible = not demand.is_empty()
	_good.visible = demand.is_empty()
	_check_new()


func _fill(option: OptionButton, ids: Array[int], keep: int) -> void:
	option.clear()
	for id: int in ids:
		option.add_item(_province_name(id), id)
		if id == keep:
			option.select(option.item_count - 1)


func _selected(option: OptionButton) -> int:
	return option.get_selected_id() if option.item_count > 0 and option.selected >= 0 else 0


func _vehicle_name(from: int, sea: bool, vehicle: int) -> String:
	var province := sim.province_state(from)
	if sea:
		var ship := province.ships.get(vehicle) as ShipUnit
		return tr(ship.def.name_key()) if ship != null else ""
	return tr("ui.routes.merchant_wagon")


## Goods province [param from] has that can go on a route, without [param skip]; the first
## item is a prompt.
func _fill_goods(option: OptionButton, from: int, skip: Array[StringName]) -> void:
	option.clear()
	option.add_item(tr("ui.routes.add_good"))
	var province := sim.province_state(from)
	if province == null:
		return
	for def: GoodDef in sim.data.goods():
		if def.is_live() or skip.has(def.id) or province.kingdom_stock(def.id) <= 0:
			continue
		option.add_item(tr(def.name_key()))
		option.set_item_metadata(option.item_count - 1, String(def.id))


func _check_new() -> void:
	_vehicle.visible = _vehicle.item_count > 0
	var ok := _vehicle.item_count > 0 and (_good.selected > 0 or not _demand_lines.is_empty())
	_create.disabled = not ok
	if _to.item_count == 0:
		_note.text = tr("ui.routes.no_target")
	elif _vehicle.item_count == 0:
		_note.text = tr("ui.routes.no_cog") if _way.get_selected_id() == 1 else tr("ui.routes.no_trading_post")
	else:
		_note.text = ""


static func _default_amount(sea: bool) -> int:
	return TradeRoute.DEFAULT_AMOUNT if sea else TradeRoute.WAGON_LOAD


func _create_route() -> void:
	if (_good.selected <= 0 and _demand_lines.is_empty()) or _vehicle.item_count == 0:
		return
	var sea := _way.get_selected_id() == 1
	var lines: Array[Dictionary] = _demand_lines.duplicate(true)
	if lines.is_empty():
		lines = [TradeRoute.line(StringName(String(_good.get_item_metadata(_good.selected))),
				_default_amount(sea), TradeRoute.DEFAULT_BELOW)]
	var command := CreateTradeRouteCommand.new(_selected(_from), _selected(_to), sea,
			_vehicle.get_selected_id(), lines)
	var error := command.validate(sim)
	if error != &"":
		_note.text = tr("ui.command_error.%s" % error)
		return
	command_requested.emit(command)
	_shown = ""
	_fill_new(false)
	_refresh()
