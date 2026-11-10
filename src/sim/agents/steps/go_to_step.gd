class_name GoToStep
extends TaskStep
## Walks to the workplace entrance, or claims a resource node and walks next to it.


func run(province: ProvinceSim, agent: Agent, def: StepDef) -> Status:
	var step := def as GoToStepDef
	var bb := agent.task.bb
	var workplace := province.buildings.get_building(agent.workplace_id)
	if workplace == null:
		return failed(agent, &"no_workplace")
	if step.target == &"workplace":
		return Movement.walk(province, agent, workplace.entrance_tile())
	if step.target == &"shore":
		if not bb.has("stand"):
			var shore := province.find_shore(workplace, agent.tile())
			if shore == Agent.NO_TILE:
				return failed(agent, &"no_resource")
			bb["stand"] = SimCodec.vec2i(shore)
			# Work steps face "node": the angler looks at the water.
			bb["node"] = SimCodec.vec2i(province.shore_water(shore, workplace.def.needs_terrain_near))
		return Movement.walk(province, agent, SimCodec.to_vec2i(bb["stand"]))
	if step.target == &"pen":
		# The keeper walks into the pen (Z1): a pen tile of the workplace, another each time.
		if not bb.has("stand"):
			var pens := province.fields.tiles_of(workplace.id)
			if pens.is_empty():
				return failed(agent, &"no_pen")
			# Nothing to shear without a flock (Z1 part 2).
			if workplace.def.herd_work and workplace.yard != null \
					and workplace.yard.total(workplace.def.herd_good) == 0:
				return failed(agent, &"no_animals")
			var tile := pens[(agent.id + province.tick / SimClock.TICKS_PER_SECOND) % pens.size()]
			bb["stand"] = SimCodec.vec2i(tile)
		return Movement.walk(province, agent, SimCodec.to_vec2i(bb["stand"]))
	if step.target == &"plant_spot":
		if not bb.has("stand"):
			var spot := province.find_plant_spot(workplace, step.resource, agent.tile())
			if spot == Agent.NO_TILE:
				return failed(agent, &"no_plant_spot")
			bb["plant"] = true
			bb["node"] = SimCodec.vec2i(spot)
			bb["stand"] = SimCodec.vec2i(province.approach_tile(spot, agent.tile()))
		return Movement.walk(province, agent, SimCodec.to_vec2i(bb["stand"]))
	if not bb.has("stand"):
		var node := agent.claimed_node
		if node == Agent.NO_TILE or not province.resources.has_node(node, step.resource):
			node = province.resources.find_nearest(step.resource, workplace.entrance_tile(),
					workplace.def.work_radius)
		if node == Agent.NO_TILE:
			return failed(agent, &"no_resource")
		var stand := province.approach_tile(node, agent.tile())
		if stand == Agent.NO_TILE or not province.resources.claim(node, agent.id):
			return failed(agent, &"no_resource")
		agent.claimed_node = node
		bb["node"] = SimCodec.vec2i(node)
		bb["stand"] = SimCodec.vec2i(stand)
	return Movement.walk(province, agent, SimCodec.to_vec2i(bb["stand"]))
