class_name Carriers
extends RefCounted
## Transport tiers (GDD §5.2, M4b-3): a porter carries 1 unit; a storage porter with a
## handcart carries up to 3 for requests of 2 or more. Handcarts belong to a storage
## (bought in its panel for planks); a porter takes one while one of his storage is free.
## A carter of a stable drives a horse wagon with up to 6 units, on roads only, for requests
## of 4 or more over longer distances; he loads and unloads on the road in front of a door.

const HANDCART := &"handcart"
## Units on a handcart, and the least a request must still need to take one.
const HANDCART_LOAD := 3
const HANDCART_MIN := 2
## Price of one handcart.
const HANDCART_COST: Dictionary[StringName, int] = {&"planks": 3}
## Speed of a handcart off the road (on a road it keeps up with people on foot).
const HANDCART_OFFROAD_SPEED := 0.7
## Loading or unloading a vehicle takes this long per unit (1 s), visibly (M4b-3).
const HANDLING_TICKS_PER_UNIT := 10

const WAGON := &"wagon"
const CARTER_KIND := &"carter"
const WAGON_LOAD := 6
## Least a request must still need, and the least straight distance (tiles) between the two
## road stops, for a wagon to take it: short and small jobs stay with people on foot.
const WAGON_MIN := 4
const WAGON_MIN_TILES := 10
## A wagon is faster than people on foot on the same road.
const WAGON_SPEED := 1.3
## The settlers' wagon of an expedition (M6 part 2): loaded with the start kit, it drives
## off-road like a person (no stable, no carter's job), drawn as a loaded wagon.
const SETTLER_WAGON := &"settler_wagon"
## The wagon of a trade route (M6 part 3): drawn as a loaded horse wagon, drives off roads too.
const TRADE_WAGON := &"trade_wagon"


## Whether [param porter]'s storage has a handcart nobody is using.
static func has_free_handcart(province: ProvinceSim, porter: Agent) -> bool:
	var storage := province.buildings.get_building(porter.workplace_id)
	if storage == null or storage.carts <= 0:
		return false
	var used := 0
	for id: int in storage.workers:
		var worker := province.agents.get_agent(id)
		if worker != null and worker.vehicle == HANDCART:
			used += 1
	return used < storage.carts


## Movement cost multiplier of [param agent]'s vehicle on [param tile] (1 on foot).
static func speed_penalty(province: ProvinceSim, agent: Agent, tile: Vector2i) -> float:
	if agent.vehicle == HANDCART and not province.grid.has_road(tile):
		return 1.0 / HANDCART_OFFROAD_SPEED
	if agent.vehicle == WAGON or agent.vehicle == SETTLER_WAGON or agent.vehicle == TRADE_WAGON:
		return 1.0 / WAGON_SPEED
	return 1.0


## Where [param agent] goes to take from or bring to storage [param id]: into the building
## on foot or with a handcart, to the road in front of its door with a wagon.
static func stop_for(province: ProvinceSim, agent: Agent, id: int) -> Vector2i:
	if agent.vehicle == WAGON:
		return province.road_stop(id, agent.tile())
	return province.access_tile(id)


## Nearest storage building with room for [param amount] of [param good] and a road in front
## of a door (a wagon's destination when the request names none); 0 if none.
static func road_sink(province: ProvinceSim, good: StringName, amount: int, from: Vector2i,
		exclude: int) -> int:
	var best := 0
	var best_d := 1 << 30
	for building: BuildingState in province.buildings.all():
		if building.def.storage_slots == 0 or building.stock == null or building.id == exclude or not building.stock.can_accept(good, amount):
			continue
		var stop := province.road_stop(building.id, from)
		if stop == Agent.NO_TILE:
			continue
		var d := (stop - from).length_squared()
		if d < best_d:
			best_d = d
			best = building.id
	return best


## Loading or unloading [param amount] units onto [param agent]'s vehicle: true while it
## still takes time (the step waits, activity "load"). Instant on foot. Kept in the step's
## blackboard ("_handle"), so it restarts cleanly in the next step.
static func still_handling(agent: Agent, amount: int) -> bool:
	if agent.vehicle == &"":
		return false
	var bb := agent.task.bb
	if not bb.has("_handle"):
		bb["_handle"] = amount * HANDLING_TICKS_PER_UNIT
	bb["_handle"] = int(bb["_handle"]) - 1
	if int(bb["_handle"]) > 0:
		agent.activity = &"load"
		return true
	agent.activity = &"idle"
	return false


## Whether carter [param agent] can take a wagon job now: hands free, not mid-delivery, and
## either driving his wagon already or at his stable (where the wagons stand).
static func carter_ready(province: ProvinceSim, agent: Agent) -> bool:
	if agent.is_carrying() or agent.cooldown != 0:
		return false
	if agent.task != null and agent.task.kind != Task.KIND_PARK:
		return false
	var stable := province.buildings.get_building(agent.workplace_id)
	if stable == null or not stable.is_complete() or stable.paused:
		return false
	# The carter of a trading post drives only its merchant wagon on trade routes (M6 part 3).
	if stable.def.id == TradeRoute.TRADING_POST:
		return false
	return agent.vehicle == WAGON or province.building_entered_at(agent.tile()) == stable
