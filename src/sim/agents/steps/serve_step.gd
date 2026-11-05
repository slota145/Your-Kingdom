class_name ServeStep
extends TaskStep
## Uses up the goods a service needs from the workplace's input store and keeps the service
## running for a while (a tavern pours beer and mead).


func run(province: ProvinceSim, agent: Agent, def: StepDef) -> Status:
	var step := def as ServeStepDef
	var workplace := province.buildings.get_building(agent.workplace_id)
	if workplace == null or workplace.supply == null:
		return failed(agent, &"no_workplace")
	for good: StringName in step.consume:
		if workplace.supply.total(good) < step.consume[good]:
			agent.task.bb["good"] = String(good)
			return failed(agent, &"no_source")
	for good: StringName in step.consume:
		workplace.supply.remove(good, step.consume[good])
	workplace.serving_until = province.tick + SimClock.seconds_to_ticks(step.hold)
	province.events.emit(&"goods_served", {"agent": agent.id, "building": workplace.id,
			"goods": step.consume.duplicate()})
	return Status.DONE
