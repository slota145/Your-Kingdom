class_name WorldArmyBox
extends VBoxContainer
## The selected army on the world map (M7 part 3): its men, bread, where it is and goes, and
## what it can do: at a neutral settlement fight in the province's view or let the battle be
## decided at once (with the chances), in the player's province go into the barracks.

signal command_requested(command: Command)
## "Enter and fight" at a settlement: the game scene executes it and shows the province.
signal enter_requested(army: int)

var sim: Simulation
var army_id: int = 0

var _title: Label
var _body: Label
var _enter: Button
var _auto: Button
var _disband: Button


func _init() -> void:
	add_theme_constant_override(&"separation", 6)
	_title = UiKit.title()
	add_child(_title)
	_body = UiKit.label()
	add_child(_body)
	_enter = UiKit.button("ui.world.army_enter", func() -> void: enter_requested.emit(army_id))
	_enter.tooltip_text = "ui.world.army_enter_tip"
	add_child(_enter)
	_auto = UiKit.button("ui.world.army_auto", func() -> void:
		command_requested.emit(ArmySiegeCommand.new(army_id, ArmySiegeCommand.AUTO)))
	_auto.tooltip_text = "ui.world.army_auto_tip"
	add_child(_auto)
	_disband = UiKit.button("ui.world.army_disband", func() -> void:
		command_requested.emit(DisbandArmyCommand.new(army_id)))
	add_child(_disband)


func show_for(simulation: Simulation, id: int) -> void:
	sim = simulation
	army_id = id
	var army := sim.world.armies.get(id) as Army if sim != null else null
	visible = army != null
	if army == null:
		return
	if army.is_fleet():
		_title.text = tr_n("ui.world.fleet_title", "ui.world.fleet_title_plural", army.ships) % army.ships
	else:
		_title.text = tr_n("ui.world.army_title", "ui.world.army_title_plural", army.men()) % army.men()
	var lines := PackedStringArray()
	if army.is_fleet():
		var kinds: Array[StringName] = []
		kinds.assign(army.fleet.keys())
		kinds.sort()
		for ship: StringName in kinds:
			var def := sim.data.get_ship(ship)
			lines.append("%s: %d" % [tr(def.name_key()) if def != null else String(ship), army.fleet[ship]])
	var units: Array[StringName] = []
	units.assign(army.units.keys())
	units.sort()
	for unit: StringName in units:
		lines.append("%s: %d" % [AgentDescriber.kind_name(unit), army.units[unit]])
	lines.append(_where(army))
	var per_minute := army.men() * Army.FOOD_PER_MAN_MINUTE
	if army.food <= 0.0 and army.men() > 0:
		lines.append(tr("ui.world.army_hungry"))
	elif per_minute > 0.0:
		lines.append(tr("ui.world.army_food") % [floori(army.food), ceili(army.food / per_minute)])
	if army.ships > 0 and not army.is_fleet():
		lines.append(tr("ui.world.army_ships") % army.ships)
	lines.append(tr("ui.world.fleet_hint") if army.is_fleet() else tr("ui.world.army_hint"))
	_body.text = "\n".join(lines)
	var at_siege := Armies.siege_error(sim, army) == &""
	_enter.visible = at_siege
	_auto.visible = at_siege
	if at_siege:
		_auto.text = tr("ui.world.army_auto") % roundi(100.0 * Armies.siege_chances(sim, army, army.at))
	_disband.visible = army.state == Army.State.IDLE and sim.world.owner_of(army.at) == ProvinceDef.OWNER_PLAYER
	_disband.disabled = Armies.disband_error(sim, army) != &""
	_disband.tooltip_text = "" if not _disband.disabled else "ui.command_error.%s" % Armies.disband_error(sim, army)


func _where(army: Army) -> String:
	var name := _name(army.at)
	match army.state:
		Army.State.MOVING:
			var minutes := maxi(ceili(ArmyOrders.seconds_left(sim, army) / 60.0), 1)
			if army.chase != 0:
				return tr("ui.world.army_chasing") % minutes
			if army.target != 0 and army.ashore == Vector2.INF:
				return tr("ui.world.army_moving") % [_name(army.target), minutes]
			if army.ashore != Vector2.INF:
				return tr("ui.world.fleet_landing") % minutes
			return tr("ui.world.army_moving_spot") % minutes
		Army.State.WAITING:
			return tr("ui.world.army_waiting") % name
		Army.State.INSIDE:
			return tr("ui.world.army_inside") % name
		Army.State.ENGAGED:
			return tr("ui.world.army_engaged")
	if army.by_sea:
		return tr("ui.world.fleet_idle")
	return tr("ui.world.army_idle") % name if army.at != 0 else tr("ui.world.army_idle_field")


func _name(id: int) -> String:
	var def := sim.world.def_of(id, sim.data)
	return tr(def.name_key()) if def != null else ""


## The report of the newest battle in province [param id] ("" when there was none).
static func report_text(sim: Simulation, id: int) -> String:
	for k: int in range(sim.world.reports.size() - 1, -1, -1):
		var entry: Dictionary = sim.world.reports[k]
		if int(entry["province"]) != id:
			continue
		var result := BattleResult.from_dict(entry["result"])
		var mine := String(entry["attacker"]) == String(ProvinceDef.OWNER_PLAYER)
		var won := result.a_won() == mine
		var lines := PackedStringArray()
		lines.append(TranslationServer.translate("ui.world.report_%d" % int(entry["kind"])) + " — "
				+ TranslationServer.translate("ui.world.report_won" if won else "ui.world.report_lost"))
		for phase: Dictionary in result.report:
			lines.append(TranslationServer.translate("ui.world.report_phase_%d" % int(phase["phase"]))
					% [int(phase["a"]) if mine else int(phase["b"]), int(phase["b"]) if mine else int(phase["a"])])
		var lost_mine := _sum(result.lost_a if mine else result.lost_b)
		var lost_theirs := _sum(result.lost_b if mine else result.lost_a)
		lines.append(TranslationServer.translate("ui.world.report_losses") % [lost_mine, lost_theirs])
		return "\n".join(lines)
	return ""


static func _sum(units: Dictionary[StringName, int]) -> int:
	var total := 0
	for unit: StringName in units:
		total += units[unit]
	return total
