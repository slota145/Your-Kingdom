class_name SiegeWorks
extends RefCounted
## Siege workshops (M7 part 2, owner's decision 2026-11-08): the player orders a ram or a
## ladderman; porters bring the planks (and iron) into the workshop, and once they are all
## there the engine is put together. Its crew are free residents (a ram 4, a ladder 1): they
## leave their houses like recruits and come out of the workshop with it, under the player's
## orders.

const MATERIALS: Array[StringName] = [&"planks", &"iron"]
## Units of each material the workshop store holds.
const STORE_UNITS := 24
## Most engines waiting in one workshop's list.
const MAX_ORDERS := 6


## Once a second per workshop (like the barracks).
static func update(province: ProvinceSim) -> void:
	var slot := province.tick % Population.UPDATE_TICKS
	for building: BuildingState in province.buildings.all():
		if not building.def.siege_engines.is_empty() and building.is_complete() \
				and building.id % Population.UPDATE_TICKS == slot:
			_update_workshop(province, building)


static func order_error(province: ProvinceSim, workshop: BuildingState, unit: UnitDef) -> StringName:
	if workshop == null or workshop.def.siege_engines.is_empty():
		return &"not_siege_workshop"
	if unit == null or not workshop.def.siege_engines.has(unit.id):
		return &"unknown_unit"
	if not workshop.is_complete():
		return &"not_finished"
	if workshop.siege_orders.size() >= MAX_ORDERS:
		return &"too_many_orders"
	return &""


static func _update_workshop(province: ProvinceSim, workshop: BuildingState) -> void:
	var unit := province.data.get_unit(workshop.siege_orders[0]) if not workshop.siege_orders.is_empty() else null
	for good: StringName in MATERIALS:
		var wanted := 0
		if unit != null:
			wanted = int(unit.build_cost.get(good, 0)) - workshop.supply.total(good) \
					- province.jobs.in_flight(good, 0, workshop.id)
			wanted = maxi(wanted, 0)
		province.jobs.set_amount(good, 0, workshop.id, wanted)
	if unit == null or not has_materials(workshop, unit):
		return
	if crew_short(province, workshop, unit) > 0:
		return   # waiting for free residents to man it
	workshop.siege_work += Population.UPDATE_TICKS
	if workshop.siege_work < SimClock.seconds_to_ticks(unit.build_time):
		return
	_finish(province, workshop, unit)


static func has_materials(workshop: BuildingState, unit: UnitDef) -> bool:
	for good: StringName in unit.build_cost:
		if workshop.supply.available(good) < unit.build_cost[good]:
			return false
	return true


## How many residents are still missing for the crew of [param unit].
static func crew_short(province: ProvinceSim, workshop: BuildingState, unit: UnitDef) -> int:
	var free := 0
	var employed: Dictionary[int, int] = {}
	for agent: Agent in province.agents.all():
		if agent.home_id != 0 and agent.workplace_id != 0:
			employed[agent.home_id] = employed.get(agent.home_id, 0) + 1
	for building: BuildingState in province.buildings.all():
		if building.house != null and building.house.residents > 0:
			free += maxi(building.house.workforce() - employed.get(building.id, 0), 0)
	return maxi(unit.crew - free, 0)


## Fraction of the engine in the works that is done (the view shows it rising).
static func progress(workshop: BuildingState, province: ProvinceSim) -> float:
	if workshop.siege_orders.is_empty():
		return 0.0
	var unit := province.data.get_unit(workshop.siege_orders[0])
	return clampf(float(workshop.siege_work) / maxf(SimClock.seconds_to_ticks(unit.build_time), 1.0), 0.0, 1.0)


static func _finish(province: ProvinceSim, workshop: BuildingState, unit: UnitDef) -> void:
	for good: StringName in unit.build_cost:
		workshop.supply.remove(good, unit.build_cost[good])
		province.ledger.used(good, unit.build_cost[good], province.tick)
	for k: int in unit.crew:
		var home := Barracks.free_resident_house(province, workshop)
		if home != null:
			home.house.residents -= 1
	workshop.siege_orders.pop_front()
	workshop.siege_work = 0
	var door := province.door_tile(workshop)
	var agent := province.spawn_agent(unit.id, door if door != Agent.NO_TILE else workshop.entrance_tile())
	agent.combat = CombatState.new(unit.combat.hp)
	agent.combat.unit = unit.id
	Troops.take_command(agent)
	agent.combat.order = CombatState.Order.MOVE
	agent.combat.post = agent.pos
	agent.combat.goal = agent.pos
	agent.combat.stance = CombatState.Stance.HOLD
	province.events.emit(&"siege_engine_built", {"agent": agent.id, "unit": unit.id, "building": workshop.id})
