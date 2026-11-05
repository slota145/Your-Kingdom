class_name MerchantStep
extends TaskStep
## Walks the travelling merchant through his visit (Merchant.State): to the market, waits
## while he trades, then back to the map edge, where the task ends and he leaves the map.


func run(province: ProvinceSim, agent: Agent, _def: StepDef) -> Status:
	var merchant := province.merchant
	if merchant.agent_id != agent.id:
		return Status.DONE
	match merchant.state:
		Merchant.State.COMING:
			var status := Movement.walk(province, agent, merchant.stand)
			if status == Status.FAILED:
				merchant.give_up(province)
			elif status == Status.DONE:
				merchant.start_trading(province)
				agent.activity = &"idle"
			return Status.RUNNING
		Merchant.State.TRADING:
			agent.activity = &"idle"
			return Status.RUNNING
		Merchant.State.LEAVING:
			var status := Movement.walk(province, agent, province.entry_tile)
			return Status.RUNNING if status == Status.RUNNING else Status.DONE
	return Status.DONE
