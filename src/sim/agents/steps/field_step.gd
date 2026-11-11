class_name FieldStep
extends TaskStep
## One job on the farm's fields (GDD §4.4): harvest a ripe tile, sow a ploughed one or plough
## a fallow one, in that order, nearest first. A harvest leaves the farmer holding a sheaf,
## which he binds before the next step carries it away. E1 part 2: the sown field starts
## growing when the last tile is sown (FieldStore.start_if_ready); while it grows the farmer
## weeds it tile by tile. With nothing at all to do he waits a bit.


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
	var speed := Population.work_speed(province, agent)
	match action:
		"plow":
			if _work(agent, &"plow", step.plow_time / speed) == Status.DONE:
				province.fields.set_stage(tile, FieldStore.Stage.PLOWED)
				return _done(province, agent, tile)
		"sow":
			if _work(agent, &"sow", step.sow_time / speed) == Status.DONE:
				var grow := farm.def.field_grow_time
				var terrain := province.terrain_at(tile)
				if farm.def.field_bonus_terrain != &"" and terrain != null \
						and terrain.is_kind(farm.def.field_bonus_terrain):
					grow /= farm.def.field_bonus   # vines on vine soil (M6 part 3)
				province.fields.sow(tile, province.tick, SimClock.seconds_to_ticks(grow))
				_start_growing(province, farm)
				return _done(province, agent, tile)
		"weed":
			if _work(agent, &"weed", step.weed_time / speed) == Status.DONE:
				return _done(province, agent, tile)
		"harvest":
			if _work(agent, &"harvest", step.harvest_time / speed) == Status.DONE:
				province.fields.set_stage(tile, FieldStore.Stage.FALLOW)
				var amount := farm.take_field_yield(step)
				agent.carry_good = step.harvest_good
				agent.carry_amount = amount
				province.ledger.made(step.harvest_good, amount, province.tick)
				province.note_output(agent, step.harvest_good, amount)
				province.events.emit(&"good_harvested", {"agent": agent.id, "tile": tile,
						"good": step.harvest_good, "amount": amount})
				province.events.emit(&"field_changed", {"tile": tile})
				bb["_action"] = "bind"
				bb.erase("_work_left")
		"bind":
			if _work(agent, &"bind", step.bind_time / speed) == Status.DONE:
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
		# Nothing to reap, sow or plough: a field that waited too long starts (no field waits
		# forever), and a growing field is weeded.
		_start_growing(province, farm)
		best = _tile_to_weed(province, agent, farm)
		if best == Agent.NO_TILE:
			bb["_action"] = "wait"
			return
		province.fields.claim(best, agent.id)
		bb["field"] = SimCodec.vec2i(best)
		bb["_action"] = "weed"
		return
	province.fields.claim(best, agent.id)
	bb["field"] = SimCodec.vec2i(best)
	bb["_action"] = ["harvest", "sow", "plow"][best_rank]


## Starts the farm's waiting tiles when the field is sown (E1 part 2).
static func _start_growing(province: ProvinceSim, farm: BuildingState) -> void:
	for tile: Vector2i in province.fields.start_if_ready(farm.id, province.tick):
		province.events.emit(&"field_changed", {"tile": tile})


## A growing tile of the farm to weed: the nearest one but the tile the farmer stands on, so
## he moves along the field; NO_TILE when nothing grows.
static func _tile_to_weed(province: ProvinceSim, agent: Agent, farm: BuildingState) -> Vector2i:
	var best := Agent.NO_TILE
	var best_d := 1 << 30
	var here := agent.tile()
	for tile: Vector2i in province.fields.tiles_of(farm.id):
		if not province.fields.is_growing(tile, province.tick) or province.fields.claimant(tile) != 0:
			continue
		var d := (tile - here).length_squared()
		if d == 0:
			d = 1 << 29   # the tile just weeded: only when it is the last one growing
		if d < best_d:
			best = tile
			best_d = d
	return best


func _done(province: ProvinceSim, agent: Agent, tile: Vector2i) -> Status:
	province.fields.release(tile, agent.id)
	agent.task.bb.erase("field")
	agent.activity = &"idle"
	province.events.emit(&"field_changed", {"tile": tile})
	return Status.DONE


## Counts down a work timer in the blackboard; DONE when it runs out. Field work is already
## divided by the worker's speed (Population.work_speed), waiting is not.
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
