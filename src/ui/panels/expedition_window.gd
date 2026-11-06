class_name ExpeditionWindow
extends PanelContainer
## "Expedition of settlers" (ROADMAP M6 part 2), opened from the town hall: what it costs, the
## expedition getting ready here (settlers, kit loaded), and every empty province it can go to,
## by sea or by land, with the journey time or why it cannot go there now.

signal command_requested(command: Command)
signal closed

const REFRESH := 0.5

var sim: Simulation

var _status: Label
var _rows: VBoxContainer
var _timer: float = 0.0


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.11, 0.09, 0.97)
	style.set_content_margin_all(12.0)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override(&"panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiKit.title("ui.expedition.title")
	title.custom_minimum_size.x = 0
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiKit.button("ui.close", func() -> void: closed.emit()))
	var cost := UiKit.label("")
	cost.custom_minimum_size.x = 620.0
	cost.text = tr("ui.expedition.cost") % [Departure.COST, Departure.SETTLERS.size(),
			UiKit.goods_list(Departure.KIT)]
	cost.set_meta(&"cost", true)
	box.add_child(cost)
	_status = UiKit.label("")
	_status.custom_minimum_size.x = 620.0
	_status.add_theme_color_override(&"font_color", Color(0.95, 0.82, 0.5))
	box.add_child(_status)
	box.add_child(HSeparator.new())
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 8)
	box.add_child(_rows)


func open(simulation: Simulation) -> void:
	sim = simulation
	visible = true
	_refresh()


func _process(delta: float) -> void:
	if not visible or sim == null:
		return
	_timer += delta
	if _timer >= REFRESH:
		_timer = 0.0
		_refresh()


func _refresh() -> void:
	_status.text = _status_text()
	for child: Node in _rows.get_children():
		child.queue_free()
	var any := false
	for id: int in sim.world.ids():
		var def := sim.world.def_of(id, sim.data)
		if def == null or id == sim.viewed_id or sim.world.owner_of(id) != ProvinceDef.OWNER_NONE:
			continue
		any = true
		_rows.add_child(_row(id, def))
	if not any:
		_rows.add_child(UiKit.label("ui.expedition.none_left"))


func _status_text() -> String:
	var departure := sim.province.departure
	if departure == null:
		return ""
	var target := sim.world.def_of(departure.target, sim.data)
	var name := tr(target.name_key()) if target != null else ""
	if departure.is_leaving():
		return tr("ui.expedition.leaving") % name
	var loaded := 0
	if departure.by_sea:
		var cog := sim.province.ships.get(departure.ship_id) as ShipUnit
		loaded = cog.hold.total_amount() if cog != null else 0
	elif departure.wagon != null:
		loaded = departure.wagon.total_amount()
	var kit := 0
	for good: StringName in Departure.KIT:
		kit += Departure.KIT[good]
	return tr("ui.expedition.gathering") % [name, departure.boarded, Departure.SETTLERS.size(), loaded, kit]


## One empty province: its name, a button by sea and one by land (with the journey time), and
## why it cannot go now.
func _row(id: int, def: ProvinceDef) -> Control:
	var box := VBoxContainer.new()
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)
	box.add_child(line)
	var name := UiKit.label(tr(def.name_key()), false)
	name.custom_minimum_size.x = 240.0
	line.add_child(name)
	var reasons := PackedStringArray()
	for sea: bool in [true, false]:
		var seconds := sim.world.travel_seconds(sim.viewed_id, id, sea, sim.data)
		if seconds < 0.0:
			continue
		var error := SendExpeditionCommand.error_for(sim, id, sea)
		var button := UiKit.button("", func() -> void:
			command_requested.emit(SendExpeditionCommand.new(id, sea)))
		button.text = tr("ui.expedition.by_sea" if sea else "ui.expedition.by_land") % ceili(seconds / 60.0)
		button.disabled = error != &""
		line.add_child(button)
		if error != &"" and not reasons.has(tr("ui.command_error.%s" % error)):
			reasons.append(tr("ui.command_error.%s" % error))
	if line.get_child_count() == 1:
		reasons.append(tr("ui.expedition.unreachable"))
	if not reasons.is_empty():
		var why := UiKit.label(" · ".join(reasons))
		why.custom_minimum_size.x = 620.0
		why.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
		why.add_theme_color_override(&"font_color", Color(0.75, 0.72, 0.65))
		box.add_child(why)
	return box
