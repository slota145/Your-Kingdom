class_name SailStep
extends TaskStep
## A worker sails his workplace's ship (M5, a fisherman in his boat).
##
## &"shoal": not aboard yet, he walks to the building where the boat is moored (his wharf, or
## the shipyard that launched it) and steps aboard; a boat away from home is first sailed
## home. At home he claims the nearest shoal with fish within Ships.SHOAL_RADIUS of the berth
## and sails onto it (blackboard "node", so the work steps face it and GatherStep takes from
## it). &"home": sails back to the berth and goes ashore at the entrance.
##
## While aboard the agent has vehicle Ships.ABOARD and moves with the ship (Ships.move_all);
## blackboard "_leg" is the trip under way.


func run(province: ProvinceSim, agent: Agent, def: StepDef) -> Status:
	var step := def as SailStepDef
	var bb := agent.task.bb
	var workplace := province.buildings.get_building(agent.workplace_id)
	if workplace == null or not workplace.def.has_berth():
		return failed(agent, &"no_workplace")
	var ship := Ships.ship_of(province, workplace)
	if agent.vehicle != Ships.ABOARD:
		if step.target == &"home":
			return Status.DONE   # already ashore
		if ship == null:
			return failed(agent, &"no_boat")
		if (ship.crew != 0 and ship.crew != agent.id) or not ship.is_moored():
			return failed(agent, &"boat_away")
		var dock := province.buildings.get_building(ship.dock_id)
		if dock == null:
			return failed(agent, &"boat_away")
		var status := Movement.walk(province, agent, dock.entrance_tile())
		if status == Status.FAILED:
			return failed(agent, &"no_path")
		if status != Status.DONE:
			return status
		Ships.board(ship, agent)
	if ship == null or ship.crew != agent.id:
		ship = Ships.ship_with_crew(province, agent)
		if ship == null:
			agent.vehicle = &""
			return failed(agent, &"no_boat")
	if bb.has("_leg"):
		match ship.path_state:
			ShipUnit.PathState.MOVING:
				return Status.RUNNING
			ShipUnit.PathState.FAILED:
				bb.erase("_leg")
				return _no_way(province, agent, ship, workplace, step)
		var leg := String(bb["_leg"])
		bb.erase("_leg")
		ship.clear_path()
		if leg == "shoal":
			return Status.DONE
		Ships.dock(ship, workplace)
	var home := workplace.berth_tile()
	if ship.dock_id != workplace.id:
		# Out at sea, or a new boat at the shipyard: home first.
		if not Ships.sail_to(province, ship, home):
			return _no_way(province, agent, ship, workplace, step)
		bb["_leg"] = "home"
		return Status.RUNNING
	if step.target == &"home":
		Ships.disembark(ship, agent, workplace)
		return Status.DONE
	var node := agent.claimed_node
	if node == Agent.NO_TILE or not province.resources.has_node(node, step.resource):
		node = province.resources.find_nearest(step.resource, home, Ships.SHOAL_RADIUS)
		if node == Agent.NO_TILE or not province.resources.claim(node, agent.id):
			Ships.disembark(ship, agent, workplace)
			return failed(agent, &"no_resource")
		agent.claimed_node = node
	if not Ships.sail_to(province, ship, node):
		province.resources.release(node, agent.id)
		agent.claimed_node = Agent.NO_TILE
		Ships.disembark(ship, agent, workplace)
		return failed(agent, &"no_resource")
	bb["node"] = SimCodec.vec2i(node)
	bb["_leg"] = "shoal"
	return Status.RUNNING


## No way by water (something was built across it): the boat is brought home anyway, so
## nobody is stranded at sea, and the trip ends there.
func _no_way(province: ProvinceSim, agent: Agent, ship: ShipUnit, workplace: BuildingState,
		step: SailStepDef) -> Status:
	Ships.dock(ship, workplace)
	Ships.disembark(ship, agent, workplace)
	if step.target == &"home":
		return Status.DONE
	return failed(agent, &"no_path")
