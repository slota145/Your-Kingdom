class_name MilitaryBox
extends VBoxContainer
## Part of the building panel for M7 part 1:
## - a workshop with several work cycles (the blacksmith): what it makes, one toggle per
##   choice and "take turns" (owner's decision 2026-11-07),
## - a barracks: its soldiers by kind, recruits on their way and the pantry, and a
##   recruit button per kind of soldier (cost and gear in the tooltip; disabled with the
##   reason while it cannot be done).

signal command_requested(command: Command)

var _choice_row: HFlowContainer
var _choice_buttons: Array[Button] = []
var _choices_for: int = 0
var _barracks_box: VBoxContainer
var _barracks_label: Label
var _recruit_row: HFlowContainer
var _recruit_buttons: Dictionary[StringName, Button] = {}
var _building_id: int = 0
## Siege workshop (M7 part 2): what is in the works and the order buttons.
var _siege_box: VBoxContainer
var _siege_label: Label
var _siege_row: HFlowContainer
var _siege_buttons: Dictionary[StringName, Button] = {}


func _init() -> void:
	_choice_row = HFlowContainer.new()
	add_child(_choice_row)
	_barracks_box = VBoxContainer.new()
	add_child(_barracks_box)
	_barracks_label = UiKit.label()
	_barracks_box.add_child(_barracks_label)
	_barracks_box.add_child(UiKit.label("ui.barracks.recruit", false))
	_recruit_row = HFlowContainer.new()
	_barracks_box.add_child(_recruit_row)
	_siege_box = VBoxContainer.new()
	add_child(_siege_box)
	_siege_label = UiKit.label()
	_siege_box.add_child(_siege_label)
	_siege_row = HFlowContainer.new()
	_siege_box.add_child(_siege_row)
	_siege_row.add_child(UiKit.button("ui.siege.clear", func() -> void:
		command_requested.emit(OrderSiegeCommand.new(_building_id, &""))))


func refresh(province: ProvinceSim, b: BuildingState) -> void:
	_building_id = b.id
	_refresh_choices(province, b)
	_barracks_box.visible = b.def.soldier_beds > 0 and b.is_complete()
	if _barracks_box.visible:
		_refresh_barracks(province, b)
	_siege_box.visible = not b.def.siege_engines.is_empty() and b.is_complete()
	if _siege_box.visible:
		_refresh_siege(province, b)


func _refresh_siege(province: ProvinceSim, b: BuildingState) -> void:
	var lines := PackedStringArray()
	if b.siege_orders.is_empty():
		lines.append(tr("ui.siege.idle"))
	else:
		var unit := province.data.get_unit(b.siege_orders[0])
		lines.append(tr("ui.siege.working") % [tr(unit.name_key()), roundi(100.0 * SiegeWorks.progress(b, province))])
		if not SiegeWorks.has_materials(b, unit):
			lines.append(tr("ui.siege.waiting_materials") % UiKit.goods_list(unit.build_cost))
		elif SiegeWorks.crew_short(province, b, unit) > 0:
			lines.append(tr("ui.siege.waiting_crew") % unit.crew)
		if b.siege_orders.size() > 1:
			lines.append(tr("ui.siege.queued") % (b.siege_orders.size() - 1))
	_siege_label.text = "\n".join(lines)
	for id: StringName in b.def.siege_engines:
		var unit := province.data.get_unit(id)
		if unit == null:
			continue
		var button: Button = _siege_buttons.get(id)
		if button == null:
			var unit_id := id
			button = UiKit.button(unit.name_key(), func() -> void:
				command_requested.emit(OrderSiegeCommand.new(_building_id, unit_id)))
			_siege_row.add_child(button)
			_siege_row.move_child(button, _siege_row.get_child_count() - 2)
			_siege_buttons[id] = button
		button.disabled = SiegeWorks.order_error(province, b, unit) != &""
		button.tooltip_text = "\n".join([tr(unit.desc_key()),
				tr("ui.siege.needs") % [UiKit.goods_list(unit.build_cost), unit.crew]])


func _refresh_choices(province: ProvinceSim, b: BuildingState) -> void:
	_choice_row.visible = b.is_complete() and not b.def.recipe_choices.is_empty()
	if not _choice_row.visible:
		return
	if _choices_for != b.def.get_instance_id():
		_choices_for = b.def.get_instance_id()
		for child: Node in _choice_row.get_children():
			_choice_row.remove_child(child)
			child.queue_free()
		_choice_buttons.clear()
		_choice_row.add_child(UiKit.label("ui.workshop.makes", false))
		var group := ButtonGroup.new()
		for i: int in range(-1, b.def.recipe_choices.size()):
			var key := "ui.workshop.take_turns" if i < 0 else b.def.recipe_choices[i].name_key()
			var mode := i
			var button := UiKit.button(key, func() -> void:
				command_requested.emit(SetRecipeModeCommand.new(_building_id, mode)))
			button.toggle_mode = true
			button.button_group = group
			button.tooltip_text = "ui.workshop.take_turns_hint" if i < 0 else b.def.recipe_choices[i].desc_key()
			_choice_row.add_child(button)
			_choice_buttons.append(button)
	for i: int in _choice_buttons.size():
		_choice_buttons[i].set_pressed_no_signal(i - 1 == b.recipe_mode)


func _refresh_barracks(province: ProvinceSim, b: BuildingState) -> void:
	var counts: Dictionary[StringName, int] = {}
	for id: int in b.soldiers:
		var agent := province.agents.get_agent(id)
		if agent != null:
			counts[agent.kind] = counts.get(agent.kind, 0) + 1
	for unit_id: StringName in b.garrison:
		counts[unit_id] = counts.get(unit_id, 0) + 1
	var lines := PackedStringArray()
	lines.append(tr("ui.barracks.beds") % [Barracks.strength(b), b.def.soldier_beds])
	for unit: UnitDef in province.data.units():
		if counts.get(unit.id, 0) > 0:
			lines.append("  %s: %d" % [tr(unit.name_key()), counts[unit.id]])
	if not b.recruits.is_empty():
		lines.append(tr("ui.barracks.on_the_way") % b.recruits.size())
	var food := b.supply.totals() if b.supply != null else {}
	lines.append(tr("ui.barracks.pantry") % (UiKit.goods_list(food) if not food.is_empty() \
			else tr("ui.stockpile.empty")))
	_barracks_label.text = "\n".join(lines)
	for unit: UnitDef in province.data.units():
		if unit.siege != &"":
			continue   # built in a siege workshop (M7 part 2)
		var button: Button = _recruit_buttons.get(unit.id)
		if button == null:
			var unit_id := unit.id
			button = UiKit.button(unit.name_key(), func() -> void:
				command_requested.emit(RecruitCommand.new(_building_id, unit_id)))
			_recruit_row.add_child(button)
			_recruit_buttons[unit.id] = button
		var why := Barracks.recruit_error(province, b, unit)
		button.disabled = why != &""
		var tip := PackedStringArray([tr(unit.desc_key()),
				tr("ui.barracks.needs") % [UiKit.goods_list(unit.gear), unit.gold_cost]])
		var have := PackedStringArray()
		for good: StringName in Barracks.gear_goods(unit):
			have.append(LocFormat.good_count(good, _available(province, good)))
		tip.append(tr("ui.barracks.in_stock") % ", ".join(have))
		if why == &"needs_research":
			var research := province.research.needed_for_unit(province.data, unit.id)
			tip.append(tr("ui.build.needs_research") % tr("research.%s.name" % research))   # E4 part 3
		elif why != &"":
			tip.append(tr("ui.command_error.%s" % why))
		button.tooltip_text = "\n".join(tip)


## Units of [param good] recruits could take now: in the armoury, yards and herds.
static func _available(province: ProvinceSim, good: StringName) -> int:
	var sum := 0
	for building: BuildingState in province.buildings.all():
		for store: Stockpile in [building.stock, building.yard]:
			if store != null:
				sum += store.available(good)
		if building.def.herd_good == good and building.yard != null:
			sum -= mini(building.herd_keep, building.yard.available(good))
	return maxi(sum, 0)
