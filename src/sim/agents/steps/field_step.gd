class_name FieldStep
extends TaskStep
## One job on the farm's fields (GDD §4.4): harvest a ripe tile, sow a ploughed one or plough
## a fallow one, in that order, nearest first. A harvest leaves the farmer holding a sheaf,
## which he binds before the next step carries it away. With nothing to do he waits a bit.


func run(province: ProvinceSim, agent: Agent, def: StepDef) -> Status:
	var step := def as FieldStepDef
	var bb := agent.task.bb
	var farm := province.buildings.get_building(agent.workplace_id)
	if farm == null:
		return failed(agent, &"no_workplace")
	if not bb.has("_action"):
		_choose(province, agent, farm, step)
	var action := String(bb["_action"])
	if action == "wait":
		return _work(agent, &"idle", step.idle_time)
	var tile := SimCodec.to_vec2i(bb["field"])
	if province.fields.claimant(tile) != agent.id:
		return failed(agent, &"field_gone")
	if action != "bind":
		var status := Movement.walk(province, agent, tile)
		if status != Status.DONE:
			return status
	match action:
		"plow":
			if _work(agent, &"plow", step.plow_time) == Status.DONE:
				province.fields.set_stage(tile, FieldStore.Stage.PLOWED)
				return _done(province, agent, tile)
		"sow":
			if _work(agent, &"sow", step.sow_time) == Status.DONE:
				province.fields.sow(tile, province.tick,
						SimClock.seconds_to_ticks(farm.def.field_grow_time))
				return _done(province, agent, tile)
		"harvest":
			if _work(agent, &"harvest", step.harvest_time) == Status.DONE:
				province.fields.set_stage(tile, FieldStore.Stage.FALLOW)
				agent.carry_good = step.harvest_good
				agent.carry_amount = step.harvest_amount
				province.ledger.made(step.harvest_good, step.harvest_amount, province.tick)
				province.note_output(agent, step.harvest_good, step.harvest_amount)
				province.events.emit(&"good_harvested", {"agent": agent.id, "tile": tile,
						"good": step.harvest_good, "amount": step.harvest_amount})
				province.events.emit(&"field_changed", {"tile": tile})
				bb["_action"] = "bind"
				bb.erase("_work_left")
		"bind":
			if _work(agent, &"bind", step.bind_time) == Status.DONE:
				province.fields.release(tile, agent.id)
				bb.erase("field")
				return Status.DONE
	return Status.RUNNING


func _choose(province: ProvinceSim, agent: Agent, farm: BuildingState, _step: FieldStepDef) -> void:
	var bb := agent.task.bb
	var best := Agent.NO_TILE
	var best_rank := 99
	var best_d := 1 << 30
	for tile: Vector2i in province.fields.tiles_of(farm.id):
		if province.fields.claimant(tile) != 0:
			continue
		var rank := 99
		match province.fields.stage(tile, province.tick):
			FieldStore.Stage.RIPE: rank = 0
			FieldStore.Stage.PLOWED: rank = 1
			FieldStore.Stage.FALLOW: rank = 2
		if agent.is_carrying() and rank == 0:
			continue
		var d := (tile - agent.tile()).length_squared()
		if rank < best_rank or (rank == best_rank and d < best_d):
			best = tile
			best_rank = rank
			best_d = d
	if best == Agent.NO_TILE or best_rank == 99:
		bb["_action"] = "wait"
		return
	province.fields.claim(best, agent.id)
	bb["field"] = SimCodec.vec2i(best)
	bb["_action"] = ["harvest", "sow", "plow"][best_rank]


func _done(province: ProvinceSim, agent: Agent, tile: Vector2i) -> Status:
	province.fields.release(tile, agent.id)
	agent.task.bb.erase("field")
	agent.activity = &"idle"
	province.events.emit(&"field_changed", {"tile": tile})
	return Status.DONE


## Counts down a work timer in the blackboard; DONE when it runs out.
static func _work(agent: Agent, activity: StringName, seconds: float) -> Status:
	var bb := agent.task.bb
	if not bb.has("_work_left"):
		bb["_work_left"] = SimClock.seconds_to_ticks(seconds)
	agent.activity = activity
	bb["_work_left"] = int(bb["_work_left"]) - 1
	if int(bb["_work_left"]) <= 0:
		bb.erase("_work_left")
		return Status.DONE
	return Status.RUNNING
