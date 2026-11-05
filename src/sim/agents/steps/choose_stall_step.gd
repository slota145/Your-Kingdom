class_name ChooseStallStep
extends TaskStep
## Chooses the stall good to fetch next (ChooseStallStepDef): the emptiest stall whose good a
## storage can give. Fails with "stalls_full" when every stall is full and with "no_source"
## when nothing missing is to be had.


func run(province: ProvinceSim, agent: Agent, def: StepDef) -> Status:
	var step := def as ChooseStallStepDef
	var workplace := province.buildings.get_building(agent.workplace_id)
	if workplace == null or workplace.supply == null or workplace.def.stall_goods.is_empty():
		return failed(agent, &"no_workplace")
	var stalls := workplace.supply
	var best: StringName = &""
	var best_fill := 2.0
	var any_room := false
	for good: StringName in workplace.def.stall_goods:
		var room := stalls.free_space(good)
		if room <= 0:
			continue
		any_room = true
		var fill := float(stalls.total(good)) / stalls.stack_size(good)
		if fill < best_fill and province.nearest_source(good, 1, agent.tile()) != 0 \
				and province.workshop_may_take(good, 1):
			best_fill = fill
			best = good
	if best == &"":
		return failed(agent, &"no_source" if any_room else &"stalls_full")
	agent.task.bb["good"] = String(best)
	agent.task.bb["amount"] = mini(step.load, stalls.free_space(best))
	return Status.DONE
