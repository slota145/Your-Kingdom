class_name ProduceStep
extends TaskStep
## Turns what the worker carries (the fetched input) into the output good.


func run(province: ProvinceSim, agent: Agent, def: StepDef) -> Status:
	var step := def as ProduceStepDef
	var used := agent.carry_good
	agent.carry_good = step.output
	agent.carry_amount = step.amount
	province.events.emit(&"good_produced", {"agent": agent.id, "good": step.output,
			"amount": step.amount, "input": used})
	return Status.DONE
