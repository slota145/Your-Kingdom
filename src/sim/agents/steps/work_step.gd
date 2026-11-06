class_name WorkStep
extends TaskStep
## Visible work for a fixed time, facing the claimed node if there is one. An unhappy worker
## takes longer (Population.work_speed, GDD §3.2).


func run(province: ProvinceSim, agent: Agent, def: StepDef) -> Status:
	var step := def as WorkStepDef
	var bb := agent.task.bb
	if not bb.has("_work_left"):
		bb["_work_left"] = SimClock.seconds_to_ticks(
				step.duration / Population.work_speed(province, agent))
		if bb.has("node"):
			var dir := IsoMath.screen_dir(IsoMath.tile_center(SimCodec.to_vec2i(bb["node"])) - agent.pos)
			if dir >= 0:
				agent.facing = dir
	agent.activity = step.activity
	bb["_work_left"] = int(bb["_work_left"]) - 1
	return Status.DONE if int(bb["_work_left"]) <= 0 else Status.RUNNING
