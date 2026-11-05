class_name DepositStep
extends TaskStep
## Walks to the workplace and puts the carried good into its input store. Nothing carried
## (the fetch was skipped) = nothing to do.


func run(province: ProvinceSim, agent: Agent, _def: StepDef) -> Status:
	if not agent.is_carrying():
		return Status.DONE
	var workplace := province.buildings.get_building(agent.workplace_id)
	if workplace == null or workplace.supply == null:
		return failed(agent, &"no_workplace")
	var status := Movement.walk(province, agent, workplace.entrance_tile())
	if status != Status.DONE:
		return status
	if not workplace.supply.can_accept(agent.carry_good, agent.carry_amount):
		return failed(agent, &"no_space")
	workplace.supply.add(agent.carry_good, agent.carry_amount)
	province.events.emit(&"good_stored", {"agent": agent.id, "storage": workplace.id,
			"good": agent.carry_good, "amount": agent.carry_amount})
	agent.carry_good = &""
	agent.carry_amount = 0
	return Status.DONE
