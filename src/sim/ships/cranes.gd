class_name Cranes
extends RefCounted
## Cargo cranes (N1 part 2, GDD §5.4): a crane stands on the quay by the berth of a port or a
## mooring; its operator treads the wheel and lifts CRANE_LOAD units at a time between that
## berth's quay yard and the moored ship. The dockers keep carrying over the gangway beside
## it: both take the same transport requests (ARCHITECTURE §5.2), so a load is never carried
## twice. Static helpers over ProvinceSim state, like Harbour.
##
## One lift: the hook is made fast at the source (HOOK_TICKS), swings over (SWING_TICKS),
## is let down and unhooked at the destination (HOOK_TICKS), when the goods change hands, and
## swings back empty (SWING_TICKS). Progress lives in the operator's task blackboard, so a
## save in the middle resumes there; until the goods change hands they stay reserved where
## they lay, so an interrupted lift loses nothing.

const OPERATOR_KIND := &"crane_operator"
## Units lifted at a time (ROADMAP N1: 3).
const CRANE_LOAD := 3
## Making the load fast to the hook, or letting it down and unhooking it.
const HOOK_TICKS := 8
## The jib swinging between the quay yard and the ship.
const SWING_TICKS := 13
## A whole lift, there and back.
const CYCLE_TICKS := 2 * HOOK_TICKS + 2 * SWING_TICKS
## Tick of the lift at which the goods change hands (unhooked at the destination).
const HANDOVER_TICK := 2 * HOOK_TICKS + SWING_TICKS
## How often an idle operator looks for cargo (0.5 s).
const LOOK_TICKS := 5


## The harbour building (port or mooring) whose berth the crane [param crane] stands by: the
## nearest berth within the crane's reach of its footprint, then the lowest id; null if none.
## [param finished_only]: only finished ones (the crane at work, not when placing it).
static func berth_building(province: ProvinceSim, def: BuildingDef, origin: Vector2i,
		finished_only: bool = true) -> BuildingState:
	var best: BuildingState = null
	var best_d := 1 << 30
	var area := Rect2i(origin, def.footprint)
	for building: BuildingState in province.buildings.all():
		if not building.def.is_port() or (finished_only and not building.is_complete()):
			continue
		var d := _distance(area, building.berth_tile())
		if d <= def.crane_reach and (d < best_d or (d == best_d and building.id < best.id)):
			best_d = d
			best = building
	return best


## Chebyshev distance from [param tile] to the nearest tile of [param area] (0 inside).
static func _distance(area: Rect2i, tile: Vector2i) -> int:
	var dx := maxi(maxi(area.position.x - tile.x, tile.x - (area.end.x - 1)), 0)
	var dy := maxi(maxi(area.position.y - tile.y, tile.y - (area.end.y - 1)), 0)
	return maxi(dx, dy)


## The ship moored at the berth of [param port], or null.
static func moored_ship(province: ProvinceSim, port: BuildingState) -> ShipUnit:
	var ship := Harbour.berth_holder(province, port)
	if ship == null or Harbour.port_of(province, ship.id) != port:
		return null
	return ship


## Takes one lift of cargo for the operator [param agent] at the berth of [param port]: the
## first open request between its quay yard and the moored ship. Reserves up to CRANE_LOAD
## units at both ends and marks them in flight. False when there is nothing to lift.
static func take_load(province: ProvinceSim, agent: Agent, port: BuildingState) -> bool:
	var ship := moored_ship(province, port)
	if ship == null:
		return false
	for request: TransportRequest in province.jobs.all():
		if request.unassigned() <= 0 or request.retry_at > province.tick:
			continue
		if not ((request.source_id == port.id and request.dest_id == ship.id) \
				or (request.source_id == ship.id and request.dest_id == port.id)):
			continue
		var source := province.storage(request.source_id)
		var dest := province.storage(request.dest_id)
		if source == null or dest == null:
			continue
		var load := mini(CRANE_LOAD, request.unassigned())
		while load > 0:
			if source.can_supply(request.good, load) and dest.can_accept(request.good, load):
				break
			load -= 1
		if load <= 0:
			continue
		var bb := agent.task.bb
		bb["_src"] = request.source_id
		bb["_dst"] = request.dest_id
		bb["_res"] = source.reserve_out(request.good, load, agent.id)
		bb["_res_in"] = dest.reserve_in(request.good, load, agent.id)
		bb["_req"] = request.id
		bb["_load"] = load
		bb["_lift"] = 0
		bb["_out"] = 1 if request.source_id == port.id else 0
		bb["good"] = String(request.good)
		request.in_flight += load
		return true
	return false


## The goods of the lift change hands: out of the source, into the destination. False when
## either end is gone (the ship cast off, the port was pulled down).
static func hand_over(province: ProvinceSim, agent: Agent) -> bool:
	var bb := agent.task.bb
	var source := province.storage(int(bb["_src"]))
	var dest := province.storage(int(bb["_dst"]))
	if source == null or dest == null or not source.has_reservation(int(bb["_res"])) \
			or not dest.has_reservation(int(bb["_res_in"])):
		return false
	var good := StringName(String(bb["good"]))
	var taken := source.commit(int(bb["_res"]))
	var stored := dest.commit(int(bb["_res_in"]))
	assert(taken == stored, "crane lift changed amount")
	province.jobs.on_completed(int(bb["_req"]), int(bb["_load"]))
	province.events.emit(&"good_taken", {"agent": agent.id, "storage": int(bb["_src"]),
			"good": good, "amount": taken})
	province.events.emit(&"good_stored", {"agent": agent.id, "storage": int(bb["_dst"]),
			"good": good, "amount": stored})
	bb.erase("_req")
	bb.erase("_src")
	bb.erase("_dst")
	bb.erase("_res")
	bb.erase("_res_in")
	return true


## The lift of [param agent] is broken off (his task fails): the request gets its units back.
## The reservations are released with everything else the agent holds.
static func abort(province: ProvinceSim, agent: Agent) -> void:
	if agent.task == null or not agent.task.bb.has("_req"):
		return
	province.jobs.on_failed(province, int(agent.task.bb["_req"]), int(agent.task.bb.get("_load", 1)))
	agent.task.bb.erase("_req")


## How far the lift of the operator [param agent] has come: -1 when he is not lifting, else
## 0..1 over the whole cycle (view: the hook and the load).
static func lift_progress(agent: Agent) -> float:
	if agent.task == null or not agent.task.bb.has("_lift"):
		return -1.0
	return clampf(float(int(agent.task.bb["_lift"])) / CYCLE_TICKS, 0.0, 1.0)
