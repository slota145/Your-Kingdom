class_name SoldierStep
extends TaskStep
## A soldier at his barracks (M7 part 1): he walks to his place in the ranks on the parade
## ground (Barracks.post_of, by his place in the barracks' list) and drills there with the
## others, or, without a place, rests inside. He looks at his place again every few seconds
## (a new soldier, a building put on the parade ground). Never finishes.
## In a barracks with a courtyard (E4 part 4) he walks to its gate (the entrance) and from there
## straight across the courtyard to his place, and back to the gate before he goes anywhere else.
## Blackboard: "_px"/"_py" the place walked to (in hundredths of a tile), "_placed" once
## standing there, "_inside" when resting in the barracks, "_court" while crossing the courtyard.


func run(province: ProvinceSim, agent: Agent, _def: StepDef) -> Status:
	if agent.combat != null and agent.combat.commanded:
		return Status.RUNNING   # under the player's orders (Troops, M7 part 2)
	var bb := agent.task.bb
	var barracks := province.buildings.get_building(agent.home_id)
	if barracks == null or barracks.def.soldier_beds <= 0:
		return failed(agent, &"no_barracks")
	if bb.has("_placed") and (province.tick + agent.id) % Barracks.RECHECK_TICKS != 0:
		_drill(province, agent, bb)
		return Status.RUNNING
	var post := Barracks.post_of(province, barracks, barracks.soldiers.find(agent.id))
	var inside := post.x < 0.0
	var goal := barracks.entrance_tile() if inside else Vector2i(floori(post.x), floori(post.y))
	var px := roundi(post.x * 100.0)
	var py := roundi(post.y * 100.0)
	if int(bb.get("_px", -1)) != px or int(bb.get("_py", -1)) != py:
		bb["_px"] = px
		bb["_py"] = py
		bb.erase("_placed")
		bb.erase("_court")
		agent.clear_path()
	if bb.has("_placed"):
		_drill(province, agent, bb)
		return Status.RUNNING
	var gate := barracks.entrance_tile()
	var court := not barracks.def.parade_tiles.is_empty()
	var in_court := court and agent.tile() != gate \
			and Barracks.courtyard_at(province, agent.tile()) == barracks
	if in_court and inside:
		# Going in: first back to the gate (the courtyard is no ground for paths).
		if not _cross(agent, IsoMath.tile_center(gate)):
			return Status.RUNNING
	if court and not inside:
		if in_court or agent.tile() == gate or bb.has("_court"):
			bb["_court"] = 1
			if not _cross(agent, post):
				return Status.RUNNING
			return _arrive(province, agent, bb, barracks, post, false)
		goal = gate
	var status := Movement.walk(province, agent, goal)
	if status == Status.FAILED:
		# Cut off from his place: he rests where he is and looks again later.
		agent.clear_path()
		bb["_placed"] = 1
		bb["_inside"] = 1
		agent.activity = &"idle"
		return Status.RUNNING
	if status != Status.DONE:
		return status
	if court and not inside:
		bb["_court"] = 1   # at the gate: across the courtyard next tick
		return Status.RUNNING
	return _arrive(province, agent, bb, barracks, post, inside)


static func _arrive(province: ProvinceSim, agent: Agent, bb: Dictionary, barracks: BuildingState,
		post: Vector2, inside: bool) -> Status:
	bb.erase("_court")
	if inside:
		bb["_inside"] = 1
	else:
		bb.erase("_inside")
		agent.pos = post
		agent.prev_pos = post
		# Facing away from the barracks, towards the open ground; in a courtyard towards the gate.
		var dir := IsoMath.screen_dir(post - IsoMath.tile_center(barracks.entrance_tile()))
		if not barracks.def.parade_tiles.is_empty():
			dir = IsoMath.screen_dir(Vector2(1, 1))
		if dir >= 0:
			agent.facing = dir
	bb["_placed"] = 1
	_drill(province, agent, bb)
	return Status.RUNNING


## One tick of walking straight towards [param target] (across a courtyard); true once there.
static func _cross(agent: Agent, target: Vector2) -> bool:
	var delta := target - agent.pos
	var step := Movement.BASE_SPEED * SimClock.TICK
	agent.clear_path()
	if delta.length() <= step:
		agent.pos = target
		agent.activity = &"idle"
		return true
	agent.pos += delta / delta.length() * step
	agent.activity = &"walk"
	var dir := IsoMath.screen_dir(delta)
	if dir >= 0:
		agent.facing = dir
	return false


static func _drill(province: ProvinceSim, agent: Agent, bb: Dictionary) -> void:
	agent.activity = &"drill" if not bb.has("_inside") and Barracks.drilling(province.tick) else &"idle"
