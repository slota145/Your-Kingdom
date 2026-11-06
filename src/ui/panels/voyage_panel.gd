class_name VoyagePanel
extends VBoxContainer
## The voyage plan of the port's cog (M5 part 3), part of the port's building panel: what the
## cog is doing, the goods to sell over the horizon and the order from the sea merchant's
## offer (steps of Voyage.PLAN_STEP units, each list within the hold), and the buttons to send
## it out or to cast off now. Reads the simulation state; changes go out as commands.

signal command_requested(command: Command)

var province: ProvinceSim
var ship_id: int = 0

var _status: Label
var _sell_title: Label
var _sell_rows: VBoxContainer
var _add_sell: OptionButton
var _order_title: Label
var _order_rows: VBoxContainer
var _start_button: Button
var _now_button: Button
## The plan lines shown (to rebuild the rows only when they change).
var _shown_sell: Array[StringName] = []
var _shown_for: int = -1
var _amount_labels: Dictionary[String, Label] = {}


func _init() -> void:
	add_child(HSeparator.new())
	add_child(UiKit.label("ui.voyage.title", false))
	_status = UiKit.label()
	add_child(_status)
	_sell_title = UiKit.label()
	add_child(_sell_title)
	_sell_rows = VBoxContainer.new()
	add_child(_sell_rows)
	_add_sell = OptionButton.new()
	_add_sell.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE + 2)
	_add_sell.item_selected.connect(_on_add_sell)
	add_child(_add_sell)
	_order_title = UiKit.label()
	add_child(_order_title)
	_order_rows = VBoxContainer.new()
	add_child(_order_rows)
	var buttons := HFlowContainer.new()
	add_child(buttons)
	_start_button = UiKit.button("ui.voyage.start", func() -> void:
		command_requested.emit(StartVoyageCommand.new(ship_id)))
	_start_button.tooltip_text = "ui.voyage.start_hint"
	buttons.add_child(_start_button)
	_now_button = UiKit.button("ui.voyage.now", func() -> void:
		command_requested.emit(StartVoyageCommand.new(ship_id, true)))
	_now_button.tooltip_text = "ui.voyage.now_hint"
	buttons.add_child(_now_button)


## The trading ship whose home is [param port], or null.
static func cog_of(source: ProvinceSim, port: BuildingState) -> ShipUnit:
	for ship: ShipUnit in source.ships.values():
		if ship.voyage != null and ship.home_id == port.id:
			return ship
	return null


## Shows the plan of the cog of [param port] (or that it has none).
func refresh(source: ProvinceSim, port: BuildingState) -> void:
	province = source
	var ship := cog_of(source, port)
	ship_id = ship.id if ship != null else 0
	for node: Control in [_sell_title, _sell_rows, _add_sell, _order_title, _order_rows,
			_start_button, _now_button]:
		node.visible = ship != null
	if ship == null:
		_status.text = tr("ui.voyage.no_cog")
		_shown_for = -1
		return
	var v := ship.voyage
	_status.text = _status_text(ship)
	var sell: Array[StringName] = []
	sell.assign(v.sell.keys())
	sell.sort()
	if _shown_for != ship.id or sell != _shown_sell:
		_build_rows(ship, sell)
	for good: StringName in sell:
		_amount_labels["s" + String(good)].text = str(v.sell[good])
	for good: StringName in _offer():
		_amount_labels["o" + String(good)].text = str(int(v.order.get(good, 0)))
	_sell_title.text = tr("ui.voyage.sell") % [Voyage.slots_needed(v.sell, ship.hold), ship.def.hold_slots]
	_order_title.text = tr("ui.voyage.order") % [Voyage.slots_needed(v.order, ship.hold),
			ship.def.hold_slots, v.order_cost(province)]
	_start_button.visible = v.state == Voyage.State.IDLE
	_start_button.disabled = v.sell.is_empty() and v.order.is_empty()
	_now_button.visible = v.state == Voyage.State.LOADING and not v.depart_now


func _status_text(ship: ShipUnit) -> String:
	var v := ship.voyage
	var lines := PackedStringArray()
	match v.state:
		Voyage.State.IDLE:
			lines.append(tr("ui.voyage.state.idle"))
		Voyage.State.TO_BERTH:
			lines.append(tr("ui.voyage.state.to_berth"))
		Voyage.State.LOADING:
			lines.append(tr("ui.voyage.state.loading") % UiKit.goods_list(ship.hold.totals()))
		Voyage.State.OUTBOUND:
			lines.append(tr("ui.voyage.state.outbound"))
		Voyage.State.AWAY:
			var minutes := ceili(maxi(v.back_at - province.tick, 0) / float(SimClock.TICKS_PER_SECOND) / 60.0)
			lines.append(tr("ui.voyage.state.away") % maxi(minutes, 1))
		Voyage.State.INBOUND:
			lines.append(tr("ui.voyage.state.inbound") % v.earned)
		Voyage.State.UNLOADING:
			lines.append(tr("ui.voyage.state.unloading") % UiKit.goods_list(ship.hold.totals()))
	if v.last_sold > 0 or v.last_bought > 0:
		lines.append(tr("ui.voyage.last") % [v.last_sold, v.last_earned, v.last_bought, v.last_spent])
	return "\n".join(lines)


func _offer() -> Array[StringName]:
	var goods: Array[StringName] = []
	goods.assign(SeaMerchant.OFFER.keys())
	goods.sort()
	return goods


func _build_rows(ship: ShipUnit, sell: Array[StringName]) -> void:
	_shown_for = ship.id
	_shown_sell = sell
	_amount_labels.clear()
	for box: Container in [_sell_rows, _order_rows]:
		for child: Node in box.get_children():
			box.remove_child(child)
			child.queue_free()
	for good: StringName in sell:
		_sell_rows.add_child(_row(good, false, tr("ui.voyage.sell_price") % Voyage.sale_price(province, good)))
	for good: StringName in _offer():
		_order_rows.add_child(_row(good, true, tr("ui.stocks.buy_price") % SeaMerchant.sell_price(province, good)))
	_add_sell.clear()
	_add_sell.add_item(tr("ui.voyage.add_good"))
	var goods: Array[StringName] = []
	for def: GoodDef in province.data.goods():
		if Voyage.can_sell(province, def.id) and not sell.has(def.id) and province.kingdom_stock(def.id) > 0:
			goods.append(def.id)
	for good: StringName in goods:
		_add_sell.add_item(tr(province.data.get_good(good).name_key()))
		_add_sell.set_item_metadata(_add_sell.item_count - 1, String(good))


func _row(good: StringName, order: bool, price: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name := UiKit.label(tr(province.data.get_good(good).name_key()), false)
	name.custom_minimum_size.x = 120
	row.add_child(name)
	row.add_child(UiKit.button("−", func() -> void: _change(good, order, -Voyage.PLAN_STEP)))
	var amount := UiKit.label("0", false)
	amount.custom_minimum_size.x = 36
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(amount)
	_amount_labels[("o" if order else "s") + String(good)] = amount
	row.add_child(UiKit.button("+", func() -> void: _change(good, order, Voyage.PLAN_STEP)))
	row.add_child(UiKit.label(price, false))
	return row


func _change(good: StringName, order: bool, step: int) -> void:
	var ship := province.ships.get(ship_id) as ShipUnit
	if ship == null:
		return
	var plan := ship.voyage.order if order else ship.voyage.sell
	command_requested.emit(SetVoyagePlanCommand.new(ship_id, good, maxi(int(plan.get(good, 0)) + step, 0), order))


func _on_add_sell(index: int) -> void:
	if index <= 0:
		return
	var good := StringName(String(_add_sell.get_item_metadata(index)))
	_add_sell.select(0)
	command_requested.emit(SetVoyagePlanCommand.new(ship_id, good, Voyage.PLAN_STEP))
