class_name FetchStep
extends TaskStep
## Reserves goods (in the given or the nearest storage), walks there and picks them up.
## Blackboard: "good"/"amount"/"from" override the step definition (transport tasks).


func run(province: ProvinceSim, agent: Agent, def: StepDef) -> Status:
	var step := def as FetchStepDef
	var bb := agent.task.bb
	var good := StringName(String(bb.get("good", step.good)))
	var amount := int(bb.get("amount", step.amount))
	if not bb.has("_src"):
		if step.skip_if_stocked and _stocked(province, agent, good, amount):
			return Status.DONE
		if agent.is_carrying():
			return failed(agent, &"hands_full")
		if agent.task.kind == Task.KIND_RECIPE and not province.workshop_may_take(good, amount):
			return failed(agent, &"kept_for_building")
		var src := int(bb.get("from", 0))
		if src == 0:
			src = province.nearest_source(good, amount, agent.tile())
		var stock := province.storage(src)
		if stock == null:
			return failed(agent, &"no_source")
		var res := stock.reserve_out(good, amount, agent.id)
		if res == 0:
			return failed(agent, &"no_source")
		bb["_src"] = src
		bb["_res"] = res
	var src_id := int(bb["_src"])
	var source := province.storage(src_id)
	if source == null or not source.has_reservation(int(bb["_res"])):
		return failed(agent, &"source_gone")
	var status := Movement.walk(province, agent, Carriers.stop_for(province, agent, src_id))
	if status != Status.DONE:
		return status
	if Carriers.still_handling(agent, amount):
		return Status.RUNNING
	var taken := source.commit(int(bb["_res"]))
	agent.carry_good = good
	agent.carry_amount = taken
	province.events.emit(&"good_taken", {"agent": agent.id, "storage": src_id, "good": good,
			"amount": taken})
	return Status.DONE


static func _stocked(province: ProvinceSim, agent: Agent, good: StringName, amount: int) -> bool:
	var workplace := province.buildings.get_building(agent.workplace_id)
	return workplace != null and workplace.supply != null and workplace.supply.total(good) >= amount
