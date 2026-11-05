class_name BuildingPanel
extends PanelContainer
## The selected building: what it is, what its people are doing right now ("Baker: bakes
## bread (60%)", "Waits for flour"), construction progress, household needs, stored goods.
## Settings: work priority (workplaces), the wood reserve (storages), taxes (town hall), and
## for workshops how much of each input the province keeps for building (one value per good).

signal demolish_requested(building_id: int)
signal add_fields_requested(farm_id: int)
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
var _priority_buttons: Array[Button] = []
var _reserve_box: Container
var _reserve_label: Label
var _reserve_slider: HSlider
var _keep_box: VBoxContainer
## Input goods the keep sliders are built for, and a slider per good.
var _keep_goods: Array[StringName] = []
var _keep_sliders: Dictionary[StringName, HSlider] = {}
var _tax_box: Container
var _tax_label: Label
var _timer: float = 0.0


func _init() -> void:
	custom_minimum_size.x = UiKit.PANEL_WIDTH
	var box := VBoxContainer.new()
	add_child(box)
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
		if b.def.service_radius > 0:
			lines.append(tr("ui.building.service_range"))
		if b.house != null:
			lines.append_array(_house_lines(b))
		elif b.supply != null:
			var inputs := b.supply.totals()
			lines.append(tr("ui.building.inputs") % (UiKit.goods_list(inputs) if not inputs.is_empty() \
					else tr("ui.stockpile.empty")))
	_body.text = "\n".join(lines)
	_stock.visible = b.stock != null
	_stock.stock = b.stock
	_fields_button.visible = b.is_complete() and b.def.max_fields > 0
	_refresh_settings(b)


func _refresh_settings(b: BuildingState) -> void:
	_priority_row.visible = b.is_complete() and b.def.worker_count() > 0
	for p: int in _priority_buttons.size():
		_priority_buttons[p].set_pressed_no_signal(p == b.priority)
	_reserve_box.visible = b.stock != null
	if b.stock != null:
		var reserve := int(b.reserves.get(&"wood", 0))
		if not _reserve_slider.has_focus():
			_reserve_slider.set_value_no_signal(reserve)
		_reserve_label.text = tr("ui.reserve.wood") % int(_reserve_slider.value)
	_refresh_keep(b)
	_tax_box.visible = b.def.id == TOWN_HALL and b.is_complete() and treasury != null
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
