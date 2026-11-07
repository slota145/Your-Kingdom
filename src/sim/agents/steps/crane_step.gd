class_name CraneStep
extends TaskStep
## The crane operator at work (N1 part 2, Cranes): waits at the wheel for a ship at his
## crane's berth, then makes one lift of up to Cranes.CRANE_LOAD units between the quay yard
## and the ship, treading the wheel. DONE after the jib has swung back; the recipe then starts
## over. Fails with &"no_berth" when the crane stands by no finished port or mooring, with
## &"no_ship" when no ship lies at its berth and with &"no_cargo" when there has been nothing
## to lift for a while (the task then starts over after a short rest, TaskRunner.RETRY_TICKS).


func run(province: ProvinceSim, agent: Agent, def: StepDef) -> Status:
	var step := def as CraneStepDef
	var bb := agent.task.bb
	var crane := province.buildings.get_building(agent.workplace_id)
	if crane == null:
		return failed(agent, &"no_workplace")
	if not bb.has("_lift"):
		var port := Cranes.berth_building(province, crane.def, crane.origin)
		if port == null:
			return failed(agent, &"no_berth")
		agent.activity = &"idle"
		if Cranes.moored_ship(province, port) == null:
			return failed(agent, &"no_ship")
		# Right after a lift he looks at once, then every Cranes.LOOK_TICKS for a while.
		var waited := int(bb.get("_waited", 0))
		bb["_waited"] = waited + 1
		if waited == 0 or (province.tick + agent.id) % Cranes.LOOK_TICKS == 0:
			if not Cranes.take_load(province, agent, port):
				return failed(agent, &"no_cargo") if waited >= Cranes.WAIT_TICKS else Status.RUNNING
		else:
			return Status.RUNNING
		bb["_port"] = port.id
		var dir := IsoMath.screen_dir(IsoMath.tile_center(port.berth_tile()) - agent.pos)
		if dir >= 0:
			agent.facing = dir
	var lift := int(bb["_lift"]) + 1
	bb["_lift"] = lift
	agent.activity = step.activity
	if lift == Cranes.HANDOVER_TICK and not Cranes.hand_over(province, agent):
		return failed(agent, &"target_gone")
	if lift >= Cranes.CYCLE_TICKS:
		agent.activity = &"idle"
		return Status.DONE
	return Status.RUNNING
