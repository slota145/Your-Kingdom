class_name ProduceStep
extends TaskStep
## Turns what the worker carries (the fetched input), plus any goods of the workplace's
## input store the recipe consumes, into the output good.


func run(province: ProvinceSim, agent: Agent, def: StepDef) -> Status:
	var step := def as ProduceStepDef
	if not step.consume.is_empty():
		var workplace := province.buildings.get_building(agent.workplace_id)
		var store := workplace.supply if workplace != null else null
		for good: StringName in step.consume:
			if store == null or store.total(good) < step.consume[good]:
				agent.task.bb["good"] = String(good)
				return failed(agent, &"no_source")
		for good: StringName in step.consume:
			store.remove(good, step.consume[good])
			province.ledger.used(good, step.consume[good], province.tick)
	var used := agent.carry_good
	province.ledger.used(used, agent.carry_amount, province.tick)
	province.ledger.made(step.output, step.amount, province.tick)
	agent.carry_good = step.output
	agent.carry_amount = step.amount
	province.events.emit(&"good_produced", {"agent": agent.id, "good": step.output,
			"amount": step.amount, "input": used})
	return Status.DONE
