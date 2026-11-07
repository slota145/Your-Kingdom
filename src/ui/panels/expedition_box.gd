class_name ExpeditionBox
extends VBoxContainer
## The expedition of settlers of one province (ROADMAP M6 part 2, owner's decision
## 2026-11-06), shown in the town hall's panel and in the world map's province panel: what it
## costs, "Land expedition" / "Sea expedition" (only the kind is chosen), how the gathering
## goes, how to send it from the world map once it is ready, and "Disband".

signal command_requested(command: Command)

var sim: Simulation
var province_id: int = 0

var _cost: Label
var _status: Label
var _buttons: HBoxContainer
var _land: Button
var _sea: Button
var _disband: Button
var _why: Label


func _init() -> void:
	add_theme_constant_override(&"separation", 6)
	add_child(UiKit.title("ui.expedition.title"))
	_cost = UiKit.label("")
	_cost.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	add_child(_cost)
	_status = UiKit.label("")
	_status.add_theme_color_override(&"font_color", UiKit.HEADING)
	add_child(_status)
	_buttons = HBoxContainer.new()
	add_child(_buttons)
	_land = UiKit.button("ui.expedition.prepare_land", func() -> void:
		command_requested.emit(PrepareExpeditionCommand.new(province_id, false)))
	_buttons.add_child(_land)
	_sea = UiKit.button("ui.expedition.prepare_sea", func() -> void:
		command_requested.emit(PrepareExpeditionCommand.new(province_id, true)))
	_buttons.add_child(_sea)
	_disband = UiKit.button("ui.expedition.disband", func() -> void:
		command_requested.emit(DisbandExpeditionCommand.new(province_id)))
	_disband.tooltip_text = "ui.expedition.disband_hint"
	add_child(_disband)
	_why = UiKit.label("")
	_why.add_theme_font_size_override(&"font_size", UiKit.SMALL_FONT_SIZE)
	_why.add_theme_color_override(&"font_color", UiKit.INK_SOFT)
	add_child(_why)


## Shows the expedition of [param id]; hidden where there can be none (a single-province game,
## an empty or foreign province).
func show_for(simulation: Simulation, id: int) -> void:
	sim = simulation
	province_id = id
	var province := sim.province_state(id) if sim != null else null
	visible = province != null and not sim.world.is_single() \
			and sim.world.owner_of(id) == ProvinceDef.OWNER_PLAYER
	if not visible:
		return
	_cost.text = tr("ui.expedition.cost") % [Departure.COST, Departure.SETTLERS.size(),
			UiKit.goods_list(Departure.KIT)]
	var departure := province.departure
	_buttons.visible = departure == null
	_disband.visible = departure != null and departure.can_disband()
	_status.text = status_text(sim, province)
	_status.visible = not _status.text.is_empty()
	_why.text = ""
	if departure == null:
		var reasons := PackedStringArray()
		for sea: bool in [false, true]:
			var error := PrepareExpeditionCommand.error_for(sim, id, sea)
			(_sea if sea else _land).disabled = error != &""
			var reason := tr("ui.command_error.%s" % error) if error != &"" else ""
			if not reason.is_empty() and not reasons.has(reason):
				reasons.append(reason)
		_why.text = " ".join(reasons)
	_why.visible = not _why.text.is_empty()


## "The land expedition is gathering…", "…is ready…", "…sets out for…"; empty without one.
static func status_text(simulation: Simulation, province: ProvinceSim) -> String:
	var departure := province.departure
	if departure == null:
		return ""
	var kind := TranslationServer.translate("ui.expedition.kind_sea" if departure.by_sea else "ui.expedition.kind_land")
	if departure.is_sent():
		var target := simulation.world.def_of(departure.target, simulation.data)
		return TranslationServer.translate("ui.expedition.leaving") % [kind,
				TranslationServer.translate(target.name_key()) if target != null else ""]
	if departure.is_ready():
		return TranslationServer.translate("ui.expedition.ready") % kind
	var loaded := 0
	if departure.by_sea:
		var cog := province.ships.get(departure.ship_id) as ShipUnit
		loaded = cog.hold.total_amount() if cog != null else 0
	elif departure.wagon != null:
		loaded = departure.wagon.total_amount()
	var kit := 0
	for good: StringName in Departure.KIT:
		kit += Departure.KIT[good]
	return TranslationServer.translate("ui.expedition.gathering") % [kind, departure.boarded,
			Departure.SETTLERS.size(), loaded, kit]
