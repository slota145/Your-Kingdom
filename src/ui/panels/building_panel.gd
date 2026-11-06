class_name BuildingPanel
extends PanelContainer
## The selected building: what it is, what its people are doing right now ("Baker: bakes
## bread (60%)", "Waits for flour"), construction progress, household needs, stored goods.
## Settings: work priority (workplaces), the wood reserve (storages), taxes (town hall), and
## for workshops how much of each input the province keeps for building (one value per good).

signal demolish_requested(building_id: int)
signal add_fields_requested(farm_id: int)
signal plant_area_requested(building_id: int)
## The market's "Kingdom stocks and trade" button.
signal stocks_requested
## A setting changed by the player; the game scene executes the command.
signal command_requested(command: Command)
signal closed

const TOWN_HALL := &"town_hall"

const REFRESH := 0.25

var province: ProvinceSim
var treasury: Treasury
var building_id: int = 0

var _title: Label
var _body: Label
var _stock: StockpilePanel
var _fields_button: Button
var _priority_row: Container
var _pause_button: Button
var _look_button: Button
var _turn_button: Button
var _plant_button: Button
var _plant_clear_button: Button
var _pig_button: Button
var _trade_button: Button
var _priority_buttons: Array[Button] = []
var _reserve_box: Container
var _reserve_label: Label
var _reserve_slider: HSlider
var _cart_row: HFlowContainer
var _cart_label: Label
var _cart_button: Button
var _keep_box: VBoxContainer
## Input goods the keep sliders are built for, and a slider per good.
var _keep_goods: Array[StringName] = []
var _keep_sliders: Dictionary[StringName, HSlider] = {}
var _tax_box: Container
var _tax_label: Label
## Shipyard (M5): order buttons and the queue with a cancel button per order.
var _ship_box: VBoxContainer
var _ship_orders: HFlowContainer
var _ship_queue: VBoxContainer
var _ship_queue_shown: Array[StringName] = []
var _ship_shown_for: int = 0
## Port (M5 part 3): the voyage plan of its cog.
var _voyage: VoyagePanel
var _timer: float = 0.0


## Room kept below the panel (build bar) when it is taller than the screen.
const BOTTOM_MARGIN := 150.0

## Scrolls the panel when it does not fit on the screen (a port with its voyage plan, M5 part 3).
var _scroll: ScrollContainer
var _box: VBoxContainer


func _init() -> void:
	custom_minimum_size.x = UiKit.PANEL_WIDTH
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box = box
	_scroll.add_child(box)
	_title = UiKit.title()
	box.add_child(_title)
	_body = UiKit.label()
	box.add_child(_body)
	_stock = StockpilePanel.new()
	box.add_child(_stock)
	_build_settings(box)
	var buttons := HFlowContainer.new()
	box.add_child(buttons)
	_fields_button = UiKit.button("ui.building.add_fields", func() -> void: add_fields_requested.emit(building_id))
	buttons.add_child(_fields_button)
	_plant_button = UiKit.button("ui.building.plant_area", func() -> void: plant_area_requested.emit(building_id))
	_plant_button.tooltip_text = "ui.building.plant_area_hint"
	buttons.add_child(_plant_button)
	_plant_clear_button = UiKit.button("ui.building.plant_area_clear", func() -> void:
		var none: Array[Vector2i] = []
		command_requested.emit(SetPlantAreaCommand.new(building_id, none)))
	buttons.add_child(_plant_clear_button)
	_pig_button = UiKit.button("", func() -> void: command_requested.emit(BuyPigCommand.new()))
	_pig_button.tooltip_text = "ui.market.buy_pig_hint"
	buttons.add_child(_pig_button)
	_trade_button = UiKit.button("ui.market.trade", func() -> void: stocks_requested.emit())
	buttons.add_child(_trade_button)
	_pause_button = UiKit.button("ui.building.pause", func() -> void:
		var b := province.buildings.get_building(building_id)
		if b != null:
			command_requested.emit(SetPausedCommand.new(building_id, not b.paused)))
	_pause_button.tooltip_text = "ui.building.pause_hint"
	buttons.add_child(_pause_button)
	_look_button = UiKit.button("ui.building.change_look", func() -> void:
		var b := province.buildings.get_building(building_id)
		var visual := BuildingVisualDef.for_building(b.def.id) if b != null else null
		if visual != null and b.house != null:
			command_requested.emit(SetLookCommand.new(building_id, b.look % visual.look_count(b.house.level) + 1)))
	_look_button.tooltip_text = "ui.building.change_look_hint"
	buttons.add_child(_look_button)
	_turn_button = UiKit.button("ui.building.turn", func() -> void:
		command_requested.emit(RotateBuildingCommand.new(building_id)))
	_turn_button.tooltip_text = "ui.building.turn_hint"
	buttons.add_child(_turn_button)
	buttons.add_child(UiKit.button("ui.building.demolish", func() -> void: demolish_requested.emit(building_id)))
	buttons.add_child(UiKit.button("ui.close", func() -> void: closed.emit()))


func _build_settings(box: VBoxContainer) -> void:
	_priority_row = HFlowContainer.new()
	box.add_child(_priority_row)
	var priority_label := UiKit.label("ui.priority.title", false)
	priority_label.tooltip_text = "ui.priority.hint"
	priority_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_priority_row.add_child(priority_label)
	var group := ButtonGroup.new()
	for p: int in [BuildingState.Priority.HIGH, BuildingState.Priority.NORMAL, BuildingState.Priority.LOW]:
		var key := "ui.priority.%s" % ["high", "normal", "low"][p]
		var b := UiKit.button(key, func() -> void:
			command_requested.emit(SetPriorityCommand.new(building_id, p)))
		b.toggle_mode = true
		b.button_group = group
		b.tooltip_text = "ui.priority.hint"
		_priority_row.add_child(b)
		_priority_buttons.append(b)
	_reserve_box = VBoxContainer.new()
	box.add_child(_reserve_box)
	_reserve_label = UiKit.label()
	_reserve_box.add_child(_reserve_label)
	_reserve_slider = HSlider.new()
	_reserve_slider.min_value = 0
	_reserve_slider.max_value = BuildingState.MAX_RESERVE
	_reserve_slider.step = 1
	_reserve_slider.custom_minimum_size.x = UiKit.PANEL_WIDTH - 24.0
	_reserve_slider.value_changed.connect(func(value: float) -> void:
		_reserve_label.text = tr("ui.reserve.wood") % int(value)
		command_requested.emit(SetReserveCommand.new(building_id, &"wood", int(value))))
	_reserve_box.add_child(_reserve_slider)
	_cart_row = HFlowContainer.new()
	box.add_child(_cart_row)
	_cart_label = UiKit.label()
	_cart_row.add_child(_cart_label)
	_cart_button = UiKit.button("ui.carts.buy", func() -> void:
		command_requested.emit(BuyCartCommand.new(building_id)))
	_cart_button.tooltip_text = "ui.carts.hint"
	_cart_row.add_child(_cart_button)
	_keep_box = VBoxContainer.new()
	box.add_child(_keep_box)
	_tax_box = VBoxContainer.new()
	box.add_child(_tax_box)
	_tax_label = UiKit.label()
	_tax_box.add_child(_tax_label)
	var rates := HFlowContainer.new()
	_tax_box.add_child(rates)
	for rate: int in [Treasury.TaxRate.LOW, Treasury.TaxRate.NORMAL, Treasury.TaxRate.HIGH]:
		var b := UiKit.button("ui.tax.%s" % ["low", "normal", "high"][rate], func() -> void:
			command_requested.emit(SetTaxRateCommand.new(rate)))
		b.tooltip_text = "ui.tax.hint"
		rates.add_child(b)
	_tax_box.add_child(UiKit.label("ui.tax.hint"))
	_ship_box = VBoxContainer.new()
	box.add_child(_ship_box)
	_ship_orders = HFlowContainer.new()
	_ship_box.add_child(_ship_orders)
	_ship_queue = VBoxContainer.new()
	_ship_box.add_child(_ship_queue)
	_voyage = VoyagePanel.new()
	_voyage.command_requested.connect(func(command: Command) -> void: command_requested.emit(command))
	box.add_child(_voyage)


func show_building(source: ProvinceSim, id: int) -> void:
	province = source
	building_id = id
	visible = true
	_timer = REFRESH
	_refresh()


func _process(delta: float) -> void:
	if not visible or province == null:
		return
	_timer += delta
	if _timer >= REFRESH:
		_refresh()
	var room := maxf(get_viewport_rect().size.y - position.y - BOTTOM_MARGIN, 120.0)
	_scroll.custom_minimum_size = Vector2(UiKit.PANEL_WIDTH, minf(_box.get_combined_minimum_size().y, room))


func _refresh() -> void:
	_timer = 0.0
	var b := province.buildings.get_building(building_id)
	if b == null:
		closed.emit()
		return
	var name_key := b.level_def().name_key() if b.house != null else b.def.name_key()
	_title.text = tr(name_key)
	var lines := PackedStringArray()
	var site := province.sites.get(b.site_id) as ConstructionSite
	if site != null:
		lines.append(_site_text(site))
	if b.is_complete():
		for id: int in b.workers:
			var agent := province.agents.get_agent(id)
			if agent != null:
				lines.append(AgentDescriber.describe(province, agent))
		var missing := b.def.worker_count() - b.workers.size()
		if missing > 0:
			lines.append(tr("ui.building.no_workers") % missing)
		if b.def.max_fields > 0:
			lines.append(tr("ui.building.fields") % [province.fields.tiles_of(b.id).size(), b.def.max_fields])
		if b.paused:
			lines.append(tr("ui.building.paused"))
		if b.def.service_radius > 0:
			lines.append(tr("ui.building.service_range"))
			if b.def.service_needs_supply and not b.provides_service(province.tick):
				lines.append(tr("ui.building.stalls_empty" if not b.def.stall_goods.is_empty() 						else "ui.building.service_needs_supply"))
		if b.house != null:
			lines.append_array(_house_lines(b))
		elif b.supply != null and b.def.stall_goods.is_empty():
			var inputs := b.supply.totals()
			lines.append(tr("ui.building.inputs") % (UiKit.goods_list(inputs) if not inputs.is_empty() \
					else tr("ui.stockpile.empty")))
		if not b.def.stall_goods.is_empty() and b.supply != null:
			lines.append_array(_market_lines(b))
		if b.def.herd_good != &"" and b.yard != null:
			var herd := b.yard.total(b.def.herd_good)
			lines.append(tr("ui.building.herd") % [herd, b.def.herd_capacity, b.def.herd_keep])
			if herd < 2:
				lines.append(tr("ui.building.herd_too_small"))
		elif b.yard != null:
			var piled := b.yard.totals()
			lines.append(tr("ui.building.yard") % (UiKit.goods_list(piled) if not piled.is_empty() \
					else tr("ui.stockpile.empty")))
		if not b.def.ship_kinds.is_empty():
			lines.append_array(_shipyard_lines(b))
		if b.def.uses_ship != &"":
			lines.append(_boat_line(b))
		if b.def.is_port() and b.is_complete():
			lines.append_array(_port_lines(b))
	_body.text = "\n".join(lines)
	_stock.visible = b.stock != null
	_stock.stock = b.stock
	_fields_button.visible = b.is_complete() and b.def.max_fields > 0
	var market := b.is_complete() and not b.def.stall_goods.is_empty()
	_trade_button.visible = market
	_pig_button.visible = market and province.merchant.is_trading()
	if _pig_button.visible:
		_pig_button.text = tr("ui.market.buy_pig") % [Merchant.PIG_PRICE, province.merchant.pigs_left]
		var why := province.merchant.pig_error(province)
		_pig_button.disabled = why != &""
		_pig_button.tooltip_text = tr("ui.command_error.%s" % why) if why != &"" else tr("ui.market.buy_pig_hint")
	_plant_button.visible = b.def.plants_trees()
	_plant_clear_button.visible = b.def.plants_trees() and not b.plant_area.is_empty()
	_pause_button.visible = b.is_complete() and b.def.recipe != null
	_pause_button.text = tr("ui.building.resume" if b.paused else "ui.building.pause")
	var visual := BuildingVisualDef.for_building(b.def.id)
	_turn_button.visible = b.def.footprint.x == b.def.footprint.y and not b.def.is_on_water()
	_look_button.visible = b.house != null and visual != null and visual.look_count(b.house.level) > 1
	_refresh_settings(b)


func _refresh_settings(b: BuildingState) -> void:
	_priority_row.visible = b.is_complete() and b.def.worker_count() > 0
	for p: int in _priority_buttons.size():
		_priority_buttons[p].set_pressed_no_signal(p == b.priority)
	_reserve_box.visible = b.stock != null and b.def.storage_slots > 0
	if _reserve_box.visible:
		var reserve := int(b.reserves.get(&"wood", 0))
		if not _reserve_slider.has_focus():
			_reserve_slider.set_value_no_signal(reserve)
		_reserve_label.text = tr("ui.reserve.wood") % int(_reserve_slider.value)
	_cart_row.visible = b.def.max_carts > 0 and b.is_complete()
	if _cart_row.visible:
		_cart_label.text = tr("ui.carts.count") % [b.carts, b.def.max_carts]
		_cart_button.disabled = b.carts >= b.def.max_carts \
				or province.stored(&"planks") < int(Carriers.HANDCART_COST[&"planks"])
	_refresh_keep(b)
	_refresh_ships(b)
	_voyage.visible = b.def.is_port() and b.is_complete()
	if _voyage.visible:
		_voyage.refresh(province, b)
	# The pioneer camp has the town hall's tax rate until a town hall stands (M5 part 3).
	_tax_box.visible = (b.def.id == TOWN_HALL or b.def.id == &"pioneer_camp") and b.is_complete() and treasury != null
	if _tax_box.visible:
		_tax_label.text = tr("ui.tax.title") % tr("ui.tax.%s" % ["low", "normal", "high"][treasury.tax_rate])


## Goods a workshop fetches from storages (its recipe inputs).
static func _input_goods(b: BuildingState) -> Array[StringName]:
	var goods: Array[StringName] = []
	if not b.is_complete() or b.def.recipe == null:
		return goods
	for step: StepDef in b.def.recipe.steps:
		var fetch := step as FetchStepDef
		if fetch != null and fetch.good != &"" and not goods.has(fetch.good):
			goods.append(fetch.good)
	return goods


func _refresh_keep(b: BuildingState) -> void:
	var goods := _input_goods(b)
	if goods != _keep_goods:
		_build_keep_rows(goods)
	_keep_box.visible = not goods.is_empty()
	for good: StringName in goods:
		var slider := _keep_sliders[good]
		if not slider.has_focus():
			slider.set_value_no_signal(int(province.keep_for_building.get(good, 0)))
		_keep_label(good).text = _keep_text(good, int(slider.value))


func _build_keep_rows(goods: Array[StringName]) -> void:
	for child: Node in _keep_box.get_children():
		_keep_box.remove_child(child)
		child.queue_free()
	_keep_goods = goods
	_keep_sliders.clear()
	for good: StringName in goods:
		var label := UiKit.label()
		label.name = String(good)
		_keep_box.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = SetKeepForBuildingCommand.MAX_KEEP
		slider.step = 1
		slider.custom_minimum_size.x = UiKit.PANEL_WIDTH - 24.0
		slider.tooltip_text = "ui.keep.hint"
		slider.value_changed.connect(func(value: float) -> void:
			label.text = _keep_text(good, int(value))
			command_requested.emit(SetKeepForBuildingCommand.new(good, int(value))))
		_keep_box.add_child(slider)
		_keep_sliders[good] = slider
	if not goods.is_empty():
		_keep_box.add_child(UiKit.label("ui.keep.hint"))


func _keep_label(good: StringName) -> Label:
	return _keep_box.get_node(NodePath(String(good))) as Label


func _keep_text(good: StringName, amount: int) -> String:
	return tr("ui.keep.for_building") % [tr(province.data.get_good(good).name_key()), amount]


## Market: what is on the stalls and where the travelling merchant is.
func _market_lines(b: BuildingState) -> PackedStringArray:
	var lines := PackedStringArray()
	var stalls := b.supply.totals()
	lines.append(tr("ui.market.stalls") % (UiKit.goods_list(stalls) if not stalls.is_empty() 			else tr("ui.stockpile.empty")))
	var merchant := province.merchant
	match merchant.state:
		Merchant.State.AWAY:
			var minutes := ceili(maxf(merchant.next_visit - province.tick, 0) / 600.0)
			lines.append(tr("ui.market.merchant_due") % maxi(minutes, 1))
		Merchant.State.COMING:
			lines.append(tr("ui.market.merchant_coming"))
		Merchant.State.TRADING:
			var seconds := maxi(roundi((merchant.leave_at - province.tick) / 10.0), 0)
			lines.append(tr("ui.market.merchant_here") % [seconds, merchant.earned])
			if merchant.sell_above.is_empty():
				lines.append(tr("ui.market.nothing_for_sale"))
		Merchant.State.LEAVING:
			lines.append(tr("ui.market.merchant_leaving") % merchant.earned)
	return lines


func _site_text(site: ConstructionSite) -> String:
	var head := tr("ui.building.upgrading") if site.kind == ConstructionSite.KIND_UPGRADE \
			else tr("ui.building.site_phase") % [site.phase, site.phase_count()]
	if site.phase_started:
		return "%s (%d%%)" % [head, roundi(site.progress() * 100.0)]
	var have := {}
	var need := site.current_cost()
	for good: StringName in need:
		have[good] = mini(site.stock.total(good), int(need[good]))
	return "%s\n%s" % [head, tr("ui.building.materials") % [UiKit.goods_list(have), UiKit.goods_list(need)]]


func _house_lines(b: BuildingState) -> PackedStringArray:
	var lines := PackedStringArray()
	var house := b.house
	lines.append(tr("ui.house.residents") % [house.residents, b.capacity()])
	lines.append(tr("ui.house.happiness") % roundi(house.happiness))
	if treasury != null:
		var per_minute := house.residents * b.level_def().tax_per_minute * house.happiness / 100.0 \
				* treasury.rate_factor()
		lines.append(tr("ui.house.tax") % per_minute)
	for need: NeedDef in b.level_def().needs:
		var ok: bool = house.satisfied.get(need.id, false)
		lines.append("%s: %s" % [tr(need.name_key()), tr("ui.need.ok" if ok else "ui.need.missing")])
	if house.unmet_seconds >= Population.WARN_AFTER:
		lines.append(tr("ui.house.declining") % roundi(Population.LEAVE_BELOW))
	elif house.level < b.def.house_levels.size() and house.met_seconds > 0 and b.site_id == 0:
		if house.met_seconds >= Population.UPGRADE_AFTER and not Population.next_level_available(province, b):
			lines.append(tr("ui.house.upgrade_waits") % b.def.house_levels[house.level].supply_units)
		else:
			lines.append(tr("ui.house.upgrade_in") % maxi(Population.UPGRADE_AFTER - house.met_seconds, 0))
	return lines


## Shipyard (M5): the ship on the slipway, its stage and materials.
func _shipyard_lines(b: BuildingState) -> PackedStringArray:
	var lines := PackedStringArray()
	var build := Ships.build_at(province, b)
	if build == null:
		lines.append(tr("ui.shipyard.idle"))
		return lines
	var ship_name := tr("ship.%s.name" % build.ship)
	var head := tr("ui.shipyard.building") % [ship_name, build.stage + 1, build.stage_count(),
			tr("ui.shipyard.stage.%d" % mini(build.stage, 3))]
	if build.stage_started:
		lines.append("%s (%d%%)" % [head, roundi(build.progress() * 100.0)])
	else:
		var have := {}
		var need := build.current_cost()
		for good: StringName in need:
			have[good] = mini(build.stock.total(good), int(need[good]))
		lines.append(head)
		lines.append(tr("ui.building.materials") % [UiKit.goods_list(have), UiKit.goods_list(need)])
	return lines


## Port (M5 part 2): who is at the berth, the dockers, when the sea merchant comes.
func _port_lines(b: BuildingState) -> PackedStringArray:
	var lines := PackedStringArray()
	var ship := Harbour.berth_holder(province, b)
	if ship == null:
		lines.append(tr("ui.port.berth_free"))
	elif ship.is_moored() and ship.dock_id == b.id:
		lines.append(tr("ui.port.berth_moored") % tr(ship.def.name_key()))
	else:
		lines.append(tr("ui.port.berth_coming") % tr(ship.def.name_key()))
	if b.workers.is_empty():
		lines.append(tr("ui.port.no_dockers"))
	var trader := province.sea_merchant
	if trader.state == SeaMerchant.State.AWAY:
		var minutes := ceili(maxi(trader.next_visit - province.tick, 0) / float(SimClock.TICKS_PER_SECOND) / 60.0)
		lines.append(tr("ui.port.next_merchant") % maxi(minutes, 1))
	return lines


## Fishing wharf (M5): where its boat is.
func _boat_line(b: BuildingState) -> String:
	var ship := Ships.ship_of(province, b)
	if ship == null:
		return tr("ui.wharf.no_boat")
	if ship.crew != 0:
		return tr("ui.wharf.boat_out")
	if ship.dock_id == b.id:
		return tr("ui.wharf.boat_home")
	if ship.dock_id != 0:
		return tr("ui.wharf.boat_at_shipyard")
	return tr("ui.wharf.boat_coming")


func _refresh_ships(b: BuildingState) -> void:
	_ship_box.visible = b.is_complete() and not b.def.ship_kinds.is_empty()
	if not _ship_box.visible:
		return
	if _ship_shown_for != b.id or _ship_queue_shown != b.ship_orders:
		_build_ship_rows(b)
	for child: Node in _ship_orders.get_children():
		if child is Button:
			(child as Button).disabled = b.ship_orders.size() >= Ships.MAX_ORDERS


func _build_ship_rows(b: BuildingState) -> void:
	_ship_shown_for = b.id
	_ship_queue_shown = b.ship_orders.duplicate()
	for box: Container in [_ship_orders, _ship_queue]:
		for child: Node in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_ship_orders.add_child(UiKit.label("ui.shipyard.order", false))
	for kind: StringName in b.def.ship_kinds:
		var def := province.data.get_ship(kind)
		var button := UiKit.button(def.name_key(), func() -> void:
			command_requested.emit(OrderShipCommand.new(building_id, kind)))
		button.tooltip_text = "\n".join([tr(def.desc_key()), tr("ui.build.cost") % UiKit.goods_list(def.build_cost)])
		_ship_orders.add_child(button)
	if b.ship_orders.is_empty():
		_ship_queue.add_child(UiKit.label("ui.shipyard.queue_empty"))
		return
	_ship_queue.add_child(UiKit.label("ui.shipyard.queue"))
	for i: int in b.ship_orders.size():
		var row := HBoxContainer.new()
		_ship_queue.add_child(row)
		var label := UiKit.label()
		label.text = tr("ui.shipyard.queue_item") % [i + 1, tr("ship.%s.name" % b.ship_orders[i])]
		row.add_child(label)
		row.add_child(UiKit.button("ui.shipyard.cancel", func() -> void:
			command_requested.emit(CancelShipOrderCommand.new(building_id, i))))
