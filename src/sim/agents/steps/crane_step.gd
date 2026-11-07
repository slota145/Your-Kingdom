class_name CraneStep
extends TaskStep
## The crane operator at work (N1 part 2, Cranes): waits at the wheel for a ship at his
## crane's berth, then makes one lift of up to Cranes.CRANE_LOAD units between the quay yard
## and the ship, treading the wheel. DONE after the jib has swung back; the recipe then starts
## over. Fails with &"no_berth" when the crane stands by no finished port or mooring.


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
		# Right after a lift he looks at once; while waiting, every Cranes.LOOK_TICKS.
		var look := not bb.has("_waited") or (province.tick + agent.id) % Cranes.LOOK_TICKS == 0
		bb["_waited"] = 1
		if not look or not Cranes.take_load(province, agent, port):
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
