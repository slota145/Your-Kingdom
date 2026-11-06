class_name ShipBuildStep
extends TaskStep
## The shipwright at the slipway (M5, GDD §5.4): starts the current stage of the ship being
## built when its materials have been delivered (using them up) and works it off. Ends when
## the stage is done; after the last one the ship is launched. Fails with &"no_order" when
## nothing is ordered and &"no_material" while a stage waits for deliveries.


func run(province: ProvinceSim, agent: Agent, _def: StepDef) -> Status:
	var step := _def as ShipBuildStepDef
	var bb := agent.task.bb
	var shipyard := province.buildings.get_building(agent.workplace_id)
	if shipyard == null:
		return failed(agent, &"no_workplace")
	var build := Ships.build_at(province, shipyard)
	if build == null:
		return failed(agent, &"no_order")
	if not build.stage_started:
		var missing := build.missing_good()
		if missing != &"":
			bb["good"] = String(missing)
			return failed(agent, &"no_material")
		Ships.start_stage(province, build)
	if not bb.has("_faced"):
		bb["_faced"] = 1
		var slip := shipyard.def.water_tiles_at(shipyard.origin, shipyard.orientation)
		var center := Vector2(slip[0]) + Vector2(0.5, 0.5) if not slip.is_empty() \
				else Vector2(shipyard.origin) + Vector2(shipyard.def.footprint) / 2.0
		var dir := IsoMath.screen_dir(center - agent.pos)
		if dir >= 0:
			agent.facing = dir
	agent.activity = step.activity
	build.work_left -= 1
	if build.work_left <= 0:
		Ships.finish_stage(province, build)
		agent.activity = &"idle"
		return Status.DONE
	return Status.RUNNING
