class_name WorldMapScreen
extends Control
## The world map screen (ROADMAP M6, part 1): the parchment map of the provinces and, beside
## it, the panel of the province clicked: owner, people, stocks, rare resource, "Enter".
## Opened and closed with M (or Esc); the viewed province keeps living meanwhile (owner's
## decision 2026-11-06).

signal enter_requested(id: int)
signal closed

const STOCK_LINES := 6

var sim: Simulation

var _canvas: WorldMapCanvas
var _title: Label
var _name: Label
var _lines: Label
var _hint: Label
var _enter: Button
var _selected: int = 0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.14, 0.11, 0.08)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	_canvas = WorldMapCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.province_clicked.connect(select)
	row.add_child(_canvas)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = UiKit.PANEL_WIDTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.14, 0.10)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override(&"panel", style)
	row.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	_title = UiKit.title()
	box.add_child(_title)
	box.add_child(UiKit.label("ui.world.hint"))
	box.add_child(HSeparator.new())
	_name = UiKit.title()
	box.add_child(_name)
	_lines = UiKit.label()
	box.add_child(_lines)
	_hint = UiKit.label()
	_hint.add_theme_color_override(&"font_color", Color(0.8, 0.8, 0.75))
	box.add_child(_hint)
	_enter = UiKit.button("ui.world.enter", func() -> void: enter_requested.emit(_selected))
	box.add_child(_enter)
	box.add_child(UiKit.button("ui.world.back", func() -> void: closed.emit()))


func open(simulation: Simulation) -> void:
	sim = simulation
	_canvas.sim = sim
	visible = true
	select(sim.viewed_id)


func select(id: int) -> void:
	_selected = id
	_canvas.selected = id
	_refresh()


func _process(_delta: float) -> void:
	if visible and sim != null and Engine.get_process_frames() % 30 == 0:
		_refresh()


func _refresh() -> void:
	if sim == null:
		return
	var world_def := sim.data.get_world(sim.world.world_id)
	_title.text = tr(world_def.name_key()) if world_def != null else ""
	var def := sim.world.def_of(_selected, sim.data)
	if def == null:
		_name.text = ""
		_lines.text = ""
		_hint.text = ""
		_enter.visible = false
		return
	_name.text = tr(def.name_key())
	var owner := sim.world.owner_of(_selected)
	var lines := PackedStringArray()
	lines.append(tr("ui.world.owner") % tr("ui.world.owner_%s" % (owner if owner != &"" else &"none")))
	var province := sim.province_state(_selected)
	if province != null:
		lines.append(tr("ui.world.population") % _residents(province))
		if owner == ProvinceDef.OWNER_PLAYER:
			lines.append(tr("ui.world.stocks") % _stocks(province))
	lines.append(tr("ui.world.rare") % (tr("rare.%s.name" % def.rare_resource)
			if def.rare_resource != &"" else tr("ui.world.rare_none")))
	if def.island:
		lines.append(tr("ui.world.island"))
	lines.append(tr(def.desc_key()))
	_lines.text = "\n".join(lines)
	var expedition := sim.world.expedition_to(_selected)
	var waiting := expedition != null and expedition.state == Expedition.State.WAITING
	var can_enter := (province != null and owner == ProvinceDef.OWNER_PLAYER) or waiting
	_enter.visible = can_enter
	_enter.text = tr("ui.world.return") if _selected == sim.viewed_id \
			else tr("ui.world.land") if waiting else tr("ui.world.enter")
	if waiting:
		_hint.text = tr("ui.world.expedition_waiting")
	elif expedition != null and expedition.state == Expedition.State.TRAVELLING:
		var minutes := ceili((expedition.arrive_at - sim.clock.tick) / float(SimClock.TICKS_PER_SECOND) / 60.0)
		_hint.text = tr("ui.world.expedition_coming") % maxi(minutes, 1)
	elif can_enter:
		_hint.text = ""
	elif owner == ProvinceDef.OWNER_NEUTRAL:
		_hint.text = tr("ui.world.neutral_hint")
	else:
		_hint.text = tr("ui.world.empty_hint")


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
