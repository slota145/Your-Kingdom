class_name DeliverStep
extends TaskStep
## Reserves space (in the given or the nearest accepting storage), walks there and puts the
## carried goods down. Blackboard "to" fixes the destination (transport tasks).
## With drop_on_fail it never fails: the goods go on the ground instead.
##
## Production yard (M4b-2, UI-2 part 2): a worker puts what he made on the yard of his workplace
## (porters take it to a storage); when YARD_WAITING units already wait there (the porters cannot
## keep up) or the yard is full, he carries it to the nearest storage himself, and when no storage has room either, he waits at his workplace with the goods in hand
## (blackboard "_yard_full") and looks for room again every WAIT_CHECK_TICKS.

## Units of his good waiting on his yard from which a worker no longer adds to it but carries
## to a storage himself (UI-2 part 2: the porters cannot keep up).
const YARD_WAITING := 3
## How often a waiting worker looks for room again (1 s).
const WAIT_CHECK_TICKS := 10


func run(province: ProvinceSim, agent: Agent, def: StepDef) -> Status:
	var step := def as DeliverStepDef
	var bb := agent.task.bb
	if Harbour.is_walking_back(agent):
		return Harbour.walk_back(agent)
	if not agent.is_carrying():
		return Status.DONE
	if not bb.has("_dst"):
		if bb.has("_yard_full"):
			var at_work := _walk_to_work(province, agent)
			if at_work != Status.DONE or (province.tick + agent.id) % WAIT_CHECK_TICKS != 0:
				return Status.RUNNING
		var dst := int(bb.get("to", 0))
		if dst == 0:
			if agent.vehicle == Carriers.WAGON:
				dst = Carriers.road_sink(province, agent.carry_good, agent.carry_amount, agent.tile(),
						int(bb.get("from", 0)))
			else:
				# UI-2 part 2 (owner 2026-11-13): a worker puts what he made on the yard of his
				# workplace and goes back to work; porters take it on. Only when the yard is full
				# does he carry it to a storage himself.
				dst = _yard_first(province, agent)
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
	var status := Movement.walk(province, agent, Carriers.stop_for(province, agent, dst_id))
	if status == Status.FAILED:
		target.cancel(int(bb["_res"]))
		return _give_up(province, agent, step, &"no_path")
	if status != Status.DONE:
		return status
	# A ship moored at a port: over the quay and up the gangway first (M5 part 2).
	var port := Harbour.port_of(province, dst_id)
	if port != null:
		if Harbour.walk_out(agent, port):
			return Status.RUNNING
	elif Carriers.still_handling(agent, agent.carry_amount):
		return Status.RUNNING
	var good := agent.carry_good
	var stored := target.commit(int(bb["_res"]))
	province.events.emit(&"good_stored", {"agent": agent.id, "storage": dst_id,
			"good": good, "amount": stored})
	agent.carry_good = &""
	agent.carry_amount = 0
	if port != null:
		Harbour.turn_back(agent, port)
		return Status.RUNNING
	if dst_id < 0:
		# Porters take it to a storage as soon as one has room.
		province.jobs.add_or_merge(good, stored, dst_id, 0)
	return Status.DONE


## The yard of the agent's workplace, or null.
static func _own_yard(province: ProvinceSim, agent: Agent) -> Stockpile:
	return province.storage(ProvinceSim.yard_id(agent.workplace_id)) if agent.workplace_id != 0 else null


## The yard of the agent's workplace for what he made there (a recipe's or a stash's output, no
## live animal: those go to their herd) when it has room, else 0.
static func _yard_first(province: ProvinceSim, agent: Agent) -> int:
	if agent.task.kind != Task.KIND_RECIPE and agent.task.kind != Task.KIND_STASH:
		return 0
	var good_def := province.data.get_good(agent.carry_good)
	if good_def != null and good_def.is_live():
		return 0
	# Porters behind (a big town's yards fill faster than they are emptied): he takes it to a
	# storage himself, as before, instead of piling up more for the porters.
	var yard := _own_yard(province, agent)
	if yard != null and yard.total(agent.carry_good) >= YARD_WAITING:
		return 0
	return _yard_with_room(province, agent)


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
