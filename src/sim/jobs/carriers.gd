class_name Carriers
extends RefCounted
## Transport tiers (GDD §5.2, M4b-3): a porter carries 1 unit; a storage porter with a
## handcart carries up to 3 for requests of 2 or more. Handcarts belong to a storage
## (bought in its panel for planks); a porter takes one while one of his storage is free.

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
	return 1.0


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
