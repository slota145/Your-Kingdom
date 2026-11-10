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

## An AI ruler's town is only looked at (M8 part 3): no buttons but "Close".
var read_only: bool = false
var _close_button: Button
var province: ProvinceSim
var treasury: Treasury
## The world (the town hall's expedition of settlers, M6 part 2).
var sim: Simulation
var building_id: int = 0

var _title: Label
var _body: Label
var _stock: StockpilePanel
var _fields_button: Button
var _priority_row: Container
var _pause_button: Button
var _look_button: Button
## "Upgrade now" on a house (E1).
var _upgrade_button: Button
var _turn_button: Button
var _plant_button: Button
var _plant_clear_button: Button
## Market: a "buy" button per animal the merchant sells (Merchant.ANIMALS, Z1 part 2).
var _animal_buttons: Dictionary[StringName, Button] = {}
var _trade_button: Button
var _expedition: ExpeditionBox
var _priority_buttons: Array[Button] = []
var _reserve_box: Container
var _reserve_label: Label
var _reserve_slider: HSlider
var _cart_row: HFlowContainer
var _cart_label: Label
var _cart_button: Button
var _keep_box: VBoxContainer
## Herd (Z1): the breeding reserve slider.
var _herd_box: VBoxContainer
var _herd_label: Label
var _herd_slider: HSlider
## Input goods the keep sliders are built for, and a slider per good.
var _keep_goods: Array[StringName] = []
var _keep_sliders: Dictionary[StringName, HSlider] = {}
var _tax_box: Container
var _tax_label: Label
var _tax_slider: HSlider
## Icons of what the building needs and makes, or of a house's needs (P2 part 3).
var _icons: VBoxContainer
var _icons_key: String = ""
## Shipyard (M5): order buttons and the queue with a cancel button per order.
var _ship_box: VBoxContainer
var _ship_orders: HFlowContainer
var _ship_queue: VBoxContainer
var _ship_queue_shown: Array[StringName] = []
var _ship_shown_for: int = 0
## Port (M5 part 3): the voyage plan of its cog.
var _voyage: VoyagePanel
## M7: a blacksmith's choice, a barracks' soldiers and recruitment.
var _military: MilitaryBox
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
	_icons = VBoxContainer.new()
	box.add_child(_icons)
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
	for animal: StringName in Merchant.ANIMALS:
		var button := UiKit.button("", func() -> void: command_requested.emit(BuyAnimalCommand.new(animal)))
		buttons.add_child(button)
		_animal_buttons[animal] = button
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
	_upgrade_button = UiKit.button("ui.house.upgrade_now", func() -> void:
		command_requested.emit(UpgradeHouseCommand.new(building_id)))
	buttons.add_child(_upgrade_button)
	_turn_button = UiKit.button("ui.building.turn", func() -> void:
		command_requested.emit(RotateBuildingCommand.new(building_id)))
	_turn_button.tooltip_text = "ui.building.turn_hint"
	buttons.add_child(_turn_button)
	buttons.add_child(UiKit.button("ui.building.demolish", func() -> void: demolish_requested.emit(building_id)))
	_close_button = UiKit.button("ui.close", func() -> void: closed.emit())
	buttons.add_child(_close_button)


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
	_herd_box = VBoxContainer.new()
	box.add_child(_herd_box)
	_herd_label = UiKit.label()
	_herd_box.add_child(_herd_label)
	_herd_slider = HSlider.new()
	_herd_slider.min_value = SetHerdKeepCommand.MIN_KEEP
	_herd_slider.step = 1
	_herd_slider.custom_minimum_size.x = UiKit.PANEL_WIDTH - 24.0
	_herd_slider.tooltip_text = "ui.herd.keep_hint"
	_herd_slider.value_changed.connect(func(value: float) -> void:
		_herd_label.text = tr("ui.herd.keep") % int(value)
		command_requested.emit(SetHerdKeepCommand.new(building_id, int(value))))
	_herd_box.add_child(_herd_slider)
	_tax_box = VBoxContainer.new()
	box.add_child(_tax_box)
	_tax_label = UiKit.label()
	_tax_box.add_child(_tax_label)
	# One tax for the whole town, five rates (P2 part 3): a slider in the town hall's and every
	# house's panel.
	_tax_slider = HSlider.new()
	_tax_slider.min_value = Treasury.TaxRate.NONE
	_tax_slider.max_value = Treasury.TaxRate.VERY_HIGH
	_tax_slider.step = 1
	_tax_slider.tick_count = Treasury.RATE_KEYS.size()
	_tax_slider.ticks_on_borders = true
	_tax_slider.custom_minimum_size.x = 200
	_tax_slider.tooltip_text = "ui.tax.slider_hint"
	_tax_slider.value_changed.connect(func(value: float) -> void:
		command_requested.emit(SetTaxRateCommand.new(int(value))))
	_tax_box.add_child(_tax_slider)
	_tax_box.add_child(UiKit.label("ui.tax.hint"))
	_ship_box = VBoxContainer.new()
	box.add_child(_ship_box)
	_ship_orders = HFlowContainer.new()
	_ship_box.add_child(_ship_orders)
	_ship_queue = VBoxContainer.new()
	_ship_box.add_child(_ship_queue)
	_military = MilitaryBox.new()
	_military.command_requested.connect(func(command: Command) -> void: command_requested.emit(command))
	box.add_child(_military)
	_voyage = VoyagePanel.new()
	_voyage.command_requested.connect(func(command: Command) -> void: command_requested.emit(command))
	box.add_child(_voyage)
	_expedition = ExpeditionBox.new()
	_expedition.command_requested.connect(func(command: Command) -> void: command_requested.emit(command))
	box.add_child(_expedition)


func show_building(source: ProvinceSim, id: int) -> void:
	province = source
	building_id = id
	visible = true
	_timer = REFRESH
	_refresh()
	if read_only:
		UiKit.lock_buttons(self, _close_button)


func _process(delta: float) -> void:
	if not visible or province == null:
		return
	_timer += delta
	if _timer >= REFRESH:
		_refresh()
		if read_only:
			UiKit.lock_buttons(self, _close_button)
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
		elif b.def.has_pens():
			lines.append(tr("ui.building.pens") % [b.pens, b.def.max_pens, b.herd_room()])
		elif b.def.has_hives():
			lines.append(tr("ui.building.hives") % [b.hives, b.def.max_hives])
			if b.hives == 0:
				lines.append(tr("ui.building.no_hives"))
		if b.paused:
			lines.append(tr("ui.building.paused"))
		if b.def.service_radius > 0:
			lines.append(tr("ui.building.service_range"))
			if b.def.service_needs_supply and not b.provides_service(province.tick):
				lines.append(tr("ui.building.stalls_empty" if not b.def.stall_goods.is_empty() 						else "ui.building.service_needs_supply"))
		if b.house != null:
			lines.append_array(_house_lines(b))
		elif b.supply != null and b.def.stall_goods.is_empty() and b.def.soldier_beds == 0:
			var inputs := b.supply.totals()
			lines.append(tr("ui.building.inputs") % (UiKit.goods_list(inputs) if not inputs.is_empty() \
					else tr("ui.stockpile.empty")))
		if not b.def.stall_goods.is_empty() and b.supply != null:
			lines.append_array(_market_lines(b))
		if b.def.herd_good != &"" and b.yard != null:
			var herd := b.yard.total(b.def.herd_good)
			var animal := tr(province.data.get_good(b.def.herd_good).name_key())
			lines.append(tr("ui.building.herd") % [animal, herd, b.herd_room(), b.herd_keep])
			if b.def.has_pens() and b.pens == 0:
				lines.append(tr("ui.building.no_pens") % b.def.pen_animals)
			elif herd > b.herd_room():
				lines.append(tr("ui.building.herd_crowded"))
			elif herd < 2:
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
		if b.def.crane_reach > 0 and b.is_complete():
			lines.append_array(_crane_lines(b))
	_body.text = "\n".join(lines)
	_stock.visible = b.stock != null
	_stock.stock = b.stock
	_fields_button.visible = b.def.field_limit() > 0 and (b.is_complete() or b.def.has_tiles())
	_fields_button.text = tr("ui.building.add_hives" if b.def.has_hives() \
			else "ui.building.add_pens" if b.def.has_pens() else "ui.building.add_fields")
	_herd_box.visible = b.is_complete() and b.def.herd_good != &"" and b.yard != null
	if _herd_box.visible:
		_herd_slider.max_value = maxi(b.herd_room(), SetHerdKeepCommand.MIN_KEEP)
		if not _herd_slider.has_focus():
			_herd_slider.set_value_no_signal(b.herd_keep)
		_herd_label.text = tr("ui.herd.keep") % int(_herd_slider.value)
	var market := b.is_complete() and not b.def.stall_goods.is_empty()
	_trade_button.visible = market
	for animal: StringName in _animal_buttons:
		var button := _animal_buttons[animal]
		# Pigs always (as before); sheep and horses once the town keeps them.
		button.visible = market and province.merchant.is_trading() \
				and (animal == Merchant.PIG or not province.yard_buildings(animal).is_empty())
		if not button.visible:
			continue
		button.text = tr("ui.market.buy_%s" % animal) % [Merchant.animal_price(animal), province.merchant.left(animal)]
		var why := province.merchant.animal_error(province, animal)
		button.disabled = why != &""
		button.tooltip_text = tr("ui.command_error.%s" % why) if why != &"" \
				else tr("ui.market.buy_%s_hint" % animal)
	_plant_button.visible = b.def.plants_trees()
	_plant_clear_button.visible = b.def.plants_trees() and not b.plant_area.is_empty()
	_pause_button.visible = b.is_complete() and b.def.recipe != null
	_pause_button.text = tr("ui.building.resume" if b.paused else "ui.building.pause")
	var visual := BuildingVisualDef.for_building(b.def.id)
	_turn_button.visible = b.def.footprint.x == b.def.footprint.y and not b.def.is_on_water()
	_look_button.visible = b.house != null and visual != null and visual.look_count(b.house.level) > 1
	_upgrade_button.visible = b.house != null and b.is_complete() \
			and b.house.level < b.def.house_levels.size() and b.site_id == 0
	if _upgrade_button.visible:
		var why := Population.upgrade_blocker(province, b)
		_upgrade_button.disabled = why != &""
		_upgrade_button.tooltip_text = tr("ui.command_error.%s" % why) if why != &"" \
				else tr("ui.house.upgrade_now_hint")
	_refresh_settings(b)
	_refresh_icons(b)


## The icon rows (P2 part 3): a workshop's goods in and out, a house's needs met or not.
func _refresh_icons(b: BuildingState) -> void:
	var rows: Array[Array] = []
	if b.is_complete() and b.house != null:
		var needs: Array = []
		for need: NeedDef in b.level_def().needs:
			needs.append([need, bool(b.house.satisfied.get(need.id, false))])
		rows.append(["ui.house.needs", needs])
	elif b.is_complete():
		var flow := goods_flow(b.def, province.data)
		if not flow[0].is_empty():
			rows.append(["ui.building.needs_goods", flow[0]])
		if not flow[1].is_empty():
			rows.append(["ui.building.makes_goods", flow[1]])
	var key := str(rows)
	if key == _icons_key:
		return
	_icons_key = key
	for child: Node in _icons.get_children():
		child.queue_free()
	for row: Array in rows:
		_icons.add_child(UiKit.label(row[0]))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override(&"h_separation", 3)
		flow.add_theme_constant_override(&"v_separation", 3)
		_icons.add_child(flow)
		for item: Variant in row[1]:
			if item is Array:
				flow.add_child(_need_icon(item[0], item[1]))
			else:
				flow.add_child(IconSlot.good(item, tr("good.%s.name" % item)))


func _need_icon(need: NeedDef, ok: bool) -> Control:
	var state := IconSlot.State.OK if ok else IconSlot.State.MISSING
	var tip := "%s: %s" % [tr(need.name_key()), tr("ui.need.ok" if ok else "ui.need.missing")]
	if need.kind == "service":
		var def := province.data.get_building(need.service)
		return IconSlot.make(BuildMenu.icon_for(def) if def != null else null, tip, state)
	return IconSlot.good(need.goods[0] if not need.goods.is_empty() else &"", tip, state)


## [goods it needs, goods it makes] of a building, read from its recipe: what its worker
## fetches or uses up, and what he produces, harvests or gathers.
static func goods_flow(def: BuildingDef, data: DataRegistry) -> Array:
	var needs: Array[StringName] = []
	var makes: Array[StringName] = []
	if def.recipe != null:
		for step: StepDef in def.recipe.steps:
			if step is FetchStepDef and (step as FetchStepDef).good != &"":
				_add(needs, (step as FetchStepDef).good)
			elif step is ProduceStepDef:
				var produce := step as ProduceStepDef
				for good: StringName in produce.consume:
					_add(needs, good)
				if produce.output != &"":
					_add(makes, produce.output)
			elif step is ServeStepDef:
				for good: StringName in (step as ServeStepDef).consume:
					_add(needs, good)
			elif step is FieldStepDef:
				_add(makes, (step as FieldStepDef).harvest_good)
			elif step is GoToStepDef and (step as GoToStepDef).resource != &"":
				var node := data.get_resource_node((step as GoToStepDef).resource)
				if node != null and node.good != &"":
					_add(makes, node.good)
			elif step is SailStepDef:
				var node := data.get_resource_node((step as SailStepDef).resource)
				if node != null and node.good != &"":
					_add(makes, node.good)
	if def.herd_good != &"":
		_add(makes, def.herd_good)
	return [needs, makes]


static func _add(list: Array[StringName], good: StringName) -> void:
	if not list.has(good):
		list.append(good)


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
	_military.refresh(province, b)
	_expedition.visible = b.def.id == TOWN_HALL and b.is_complete() and sim != null
	if _expedition.visible:
		_expedition.show_for(sim, sim.viewed_id)
	_voyage.visible = b.def.is_port() and b.is_complete()
	if _voyage.visible:
		_voyage.sim = sim
		_voyage.refresh(province, b)
	# The pioneer camp has the town hall's tax rate until a town hall stands (M5 part 3).
	_tax_box.visible = (b.def.id == TOWN_HALL or b.def.id == &"pioneer_camp" or b.house != null) \
			and b.is_complete() and treasury != null
	if _tax_box.visible:
		_tax_label.text = tr("ui.tax.title") % tr("ui.tax.%s" % Treasury.RATE_KEYS[treasury.tax_rate])
		_tax_slider.set_value_no_signal(treasury.tax_rate)


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
		var per_minute := house.residents * Population.tax_per_minute(province, b) * house.happiness / 100.0 \
				* treasury.rate_factor()
		lines.append(tr("ui.house.tax") % per_minute)
		if house.level > 1 and not province.has_seat():
			lines.append(tr("ui.house.no_seat"))
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
	if Harbour.crews_for(province, b).is_empty():
		lines.append(tr("ui.port.no_dockers"))
	if b.def.uses_port_storage:
		var store := Harbour.yard(province, b)
		lines.append(tr("ui.port.yard_store") % tr(store.def.name_key()) if store != null \
				else tr("ui.port.no_yard_store"))
	var trader := province.sea_merchant
	if trader.state == SeaMerchant.State.AWAY:
		var minutes := ceili(maxi(trader.next_visit - province.tick, 0) / float(SimClock.TICKS_PER_SECOND) / 60.0)
		lines.append(tr("ui.port.next_merchant") % maxi(minutes, 1))
	return lines


## Cargo crane (N1 part 2): which berth it serves, the ship there, what it lifts now.
func _crane_lines(b: BuildingState) -> PackedStringArray:
	var lines := PackedStringArray()
	var port := Cranes.berth_building(province, b.def, b.origin)
	if port == null:
		lines.append(tr("ui.crane.no_berth"))
		return lines
	lines.append(tr("ui.crane.serves") % tr("building.%s.name" % port.def.id))
	var ship := Cranes.moored_ship(province, port)
	lines.append(tr("ui.port.berth_moored") % tr(ship.def.name_key()) if ship != null \
			else tr("ui.crane.no_ship"))
	for id: int in b.workers:
		var operator := province.agents.get_agent(id)
		if operator != null and Cranes.lift_progress(operator) >= 0.0:
			var bb := operator.task.bb
			lines.append(tr("ui.crane.lifting") % UiKit.goods_list(
					{StringName(String(bb.get("good", ""))): int(bb.get("_load", 0))}))
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
