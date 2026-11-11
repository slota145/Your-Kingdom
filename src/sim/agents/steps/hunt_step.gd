class_name HuntStep
extends TaskStep
## Runs HuntStepDef (E2 part 2): choose a herd, creep up, aim, shoot, fetch the carcass.
## The herd is reserved for this hunter (WildHerds.Herd.hunter) so it does not wander off
## while he creeps up; a failed task gives it back (ProvinceSim.release_agent).


func run(province: ProvinceSim, agent: Agent, def: StepDef) -> Status:
	var step := def as HuntStepDef
	var bb := agent.task.bb
	var lodge := province.buildings.get_building(agent.workplace_id)
	if lodge == null:
		return failed(agent, &"no_workplace")
	var wild := province.wild
	if not bb.has("_herd"):
		var herd := wild.nearest(lodge.entrance_tile(), lodge.def.work_radius, agent.id)
		if herd == null:
			return failed(agent, &"no_game")
		herd.hunter = agent.id
		bb["_herd"] = herd.id
		bb["_stand"] = SimCodec.vec2i(_stand_tile(province, herd.tile, agent.tile(), step.shot_range))
	match String(bb.get("_phase", "creep")):
		"creep":
			var herd: WildHerds.Herd = wild.herds.get(int(bb["_herd"]))
			if herd == null:
				return failed(agent, &"game_gone")
			var status := Movement.walk(province, agent, SimCodec.to_vec2i(bb["_stand"]))
			if status != Status.DONE:
				return status
			_face(agent, herd.tile)
			bb["_phase"] = "aim"
			bb["_work_left"] = SimClock.seconds_to_ticks(step.aim_time / Population.work_speed(province, agent))
		"aim":
			var herd: WildHerds.Herd = wild.herds.get(int(bb["_herd"]))
			if herd == null:
				return failed(agent, &"game_gone")
			agent.activity = &"aim"
			bb["_work_left"] = int(bb["_work_left"]) - 1
			if int(bb["_work_left"]) > 0:
				return Status.RUNNING
			var kill := herd.tile
			province.events.emit(&"hunt_shot", {"agent": agent.id, "herd": herd.id, "kind": herd.kind,
					"from": SimCodec.vec2(agent.pos), "to": SimCodec.vec2i(kill)})
			wild.take_one(province, herd, agent.tile())
			bb["_kill"] = SimCodec.vec2i(kill)
			bb["_phase"] = "fetch"
			bb.erase("_work_left")
		"fetch":
			var kill := SimCodec.to_vec2i(bb["_kill"])
			var status := Movement.walk(province, agent, kill)
			if status != Status.DONE:
				return status
			agent.activity = &"bend"
			if not bb.has("_work_left"):
				bb["_work_left"] = SimClock.seconds_to_ticks(step.pick_time)
			bb["_work_left"] = int(bb["_work_left"]) - 1
			if int(bb["_work_left"]) > 0:
				return Status.RUNNING
			agent.carry_good = step.carcass
			agent.carry_amount = 1
			province.events.emit(&"carcass_lifted", {"agent": agent.id, "tile": SimCodec.vec2i(kill)})
			for key: String in ["_herd", "_stand", "_phase", "_kill", "_work_left"]:
				bb.erase(key)
			return Status.DONE
	return Status.RUNNING


## A walkable tile [param shot_range] tiles from the herd on the hunter's side (the nearest one
## that is free), the herd's own tile when none is.
static func _stand_tile(province: ProvinceSim, herd: Vector2i, hunter: Vector2i, shot_range: int) -> Vector2i:
	var dir := Vector2(hunter - herd).normalized() if hunter != herd else Vector2(-1, 0)
	var goal := herd + Vector2i((dir * shot_range).round())
	var best := herd
	var best_d := 1 << 30
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var tile := goal + Vector2i(dx, dy)
			if not province.grid.is_inside(tile) or not province.nav.is_walkable(tile) \
					or province.is_tile_solid(tile):
				continue
			var d := (tile - goal).length_squared()
			if d < best_d:
				best = tile
				best_d = d
	return best


static func _face(agent: Agent, tile: Vector2i) -> void:
	var dir := IsoMath.screen_dir(IsoMath.tile_center(tile) - agent.pos)
	if dir >= 0:
		agent.facing = dir
