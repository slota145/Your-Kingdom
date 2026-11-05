class_name BuildingPanel
extends PanelContainer
## The selected building: what it is, what its people are doing right now ("Baker: bakes
## bread (60%)", "Waits for flour"), construction progress, household needs, stored goods.

signal demolish_requested(building_id: int)
signal add_fields_requested(farm_id: int)
signal closed

const REFRESH := 0.25

var province: ProvinceSim
var building_id: int = 0

var _title: Label
var _body: Label
var _stock: StockpilePanel
var _fields_button: Button
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
	var buttons := HFlowContainer.new()
	box.add_child(buttons)
	_fields_button = UiKit.button("ui.building.add_fields", func() -> void: add_fields_requested.emit(building_id))
	buttons.add_child(_fields_button)
	buttons.add_child(UiKit.button("ui.building.demolish", func() -> void: demolish_requested.emit(building_id)))
	buttons.add_child(UiKit.button("ui.close", func() -> void: closed.emit()))


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
	_body.text = "\n".join(lines)
	_stock.visible = b.stock != null
	_stock.stock = b.stock
	_fields_button.visible = b.is_complete() and b.def.max_fields > 0


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
	for need: NeedDef in b.level_def().needs:
		var ok: bool = house.satisfied.get(need.id, false)
		lines.append("%s: %s" % [tr(need.name_key()), tr("ui.need.ok" if ok else "ui.need.missing")])
	if house.unmet_seconds >= Population.WARN_AFTER:
		lines.append(tr("ui.house.declining"))
	elif house.level < b.def.house_levels.size() and house.met_seconds > 0 and b.site_id == 0:
		lines.append(tr("ui.house.upgrade_in") % maxi(Population.UPGRADE_AFTER - house.met_seconds, 0))
	return lines
