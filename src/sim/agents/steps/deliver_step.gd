class_name DeliverStep
extends TaskStep
## Reserves space (in the given or the nearest accepting storage), walks there and puts the
## carried goods down. Blackboard "to" fixes the destination (transport tasks).
## With drop_on_fail it never fails: the goods go on the ground instead.
##
## Production yard (M4b-2): when no storage has room, a worker puts the goods on the yard of
## his workplace; when that is full too, he waits at his workplace with the goods in hand
## (blackboard "_yard_full") and looks for room again every WAIT_CHECK_TICKS.

## How often a waiting worker looks for room again (1 s).
const WAIT_CHECK_TICKS := 10


func run(province: ProvinceSim, agent: Agent, def: StepDef) -> Status:
	var step := def as DeliverStepDef
	var bb := agent.task.bb
	if not agent.is_carrying():
		return Status.DONE
	if not bb.has("_dst"):
		if bb.has("_yard_full"):
			var at_work := _walk_to_work(province, agent)
			if at_work != Status.DONE or (province.tick + agent.id) % WAIT_CHECK_TICKS != 0:
				return Status.RUNNING
		var dst := int(bb.get("to", 0))
		if dst == 0:
			dst = province.nearest_sink(agent.carry_good, agent.carry_amount, agent.tile(),
					int(bb.get("from", 0)))
			if dst == 0:
				dst = _yard_with_room(province, agent)
		var stock := province.storage(dst) if province.accepts_deliveries(dst) else null
		var res := stock.reserve_in(agent.carry_good, agent.carry_amount, agent.id) \
				if stock != null else 0
		if res == 0:
			if int(bb.get("to", 0)) == 0 and _own_yard(province, agent) != null \
					and agent.task.kind in [Task.KIND_RECIPE, Task.KIND_STASH]:
				bb["_yard_full"] = true
				agent.activity = &"idle"
				return Status.RUNNING
			return _give_up(province, agent, step, &"no_space")
		bb.erase("_yard_full")
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
	if Carriers.still_handling(agent, agent.carry_amount):
		return Status.RUNNING
	var good := agent.carry_good
	var stored := target.commit(int(bb["_res"]))
	province.events.emit(&"good_stored", {"agent": agent.id, "storage": dst_id,
			"good": good, "amount": stored})
	agent.carry_good = &""
	agent.carry_amount = 0
	if dst_id < 0:
		# Porters take it to a storage as soon as one has room.
		province.jobs.add_or_merge(good, stored, dst_id, 0)
	return Status.DONE


## The yard of the agent's workplace, or null.
static func _own_yard(province: ProvinceSim, agent: Agent) -> Stockpile:
	return province.storage(ProvinceSim.yard_id(agent.workplace_id)) if agent.workplace_id != 0 else null


## Storage id of the agent's workplace yard when it has room for what he carries, else 0.
static func _yard_with_room(province: ProvinceSim, agent: Agent) -> int:
	var yard := _own_yard(province, agent)
	if yard != null and yard.can_accept(agent.carry_good, agent.carry_amount):
		return ProvinceSim.yard_id(agent.workplace_id)
	return 0


static func _walk_to_work(province: ProvinceSim, agent: Agent) -> Status:
	var workplace := province.buildings.get_building(agent.workplace_id)
	if workplace == null:
		return Status.DONE
	var status := Movement.walk(province, agent, workplace.entrance_tile())
	return Status.DONE if status == Status.FAILED else status


func _give_up(province: ProvinceSim, agent: Agent, step: DeliverStepDef, reason: StringName) -> Status:
	if not step.drop_on_fail:
		return failed(agent, reason)
	province.release_agent(agent)
	province.drop_carried(agent)
	return Status.DONE
