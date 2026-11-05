class_name DeliverStep
extends TaskStep
## Reserves space (in the given or the nearest accepting storage), walks there and puts the
## carried goods down. Blackboard "to" fixes the destination (transport tasks).
## With drop_on_fail it never fails: the goods go on the ground instead.


func run(province: ProvinceSim, agent: Agent, def: StepDef) -> Status:
	var step := def as DeliverStepDef
	var bb := agent.task.bb
	if not agent.is_carrying():
		return Status.DONE
	if not bb.has("_dst"):
		var dst := int(bb.get("to", 0))
		if dst == 0:
			dst = province.nearest_sink(agent.carry_good, agent.carry_amount, agent.tile(),
					int(bb.get("from", 0)))
		var stock := province.storage(dst) if province.accepts_deliveries(dst) else null
		var res := stock.reserve_in(agent.carry_good, agent.carry_amount, agent.id) \
				if stock != null else 0
		if res == 0:
			return _give_up(province, agent, step, &"no_space")
		bb["_dst"] = dst
		bb["_res"] = res
	var dst_id := int(bb["_dst"])
	var target := province.storage(dst_id)
	if target == null or not target.has_reservation(int(bb["_res"])):
		return _give_up(province, agent, step, &"target_gone")
	var status := Movement.walk(province, agent, province.access_tile(dst_id))
	if status == Status.FAILED:
		target.cancel(int(bb["_res"]))
		return _give_up(province, agent, step, &"no_path")
	if status != Status.DONE:
		return status
	var stored := target.commit(int(bb["_res"]))
	province.events.emit(&"good_stored", {"agent": agent.id, "storage": dst_id,
			"good": agent.carry_good, "amount": stored})
	agent.carry_good = &""
	agent.carry_amount = 0
	return Status.DONE


func _give_up(province: ProvinceSim, agent: Agent, step: DeliverStepDef, reason: StringName) -> Status:
	if not step.drop_on_fail:
		return failed(agent, reason)
	province.release_agent(agent)
	province.drop_carried(agent)
	return Status.DONE
