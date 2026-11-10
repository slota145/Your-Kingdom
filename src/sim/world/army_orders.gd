class_name ArmyOrders
extends RefCounted
## Where armies and fleets go on the world map (ROADMAP M8 part 2): to any spot (an army over
## land, a fleet over the sea), to a town, or after an enemy army; they walk along the ways of
## WorldNav and stop wherever their way ends (in the field, or a fleet at sea).
## - An army of the player standing in his coastal province sails on its warships when there
##   is no way by land, or the sea is quicker (as in M7 part 3); at the far coast its men go
##   ashore and the warships stay off the coast as a fleet.
## - A fleet with soldiers sent to the land sails to the nearest sea there and sets them ashore;
##   a fleet sent to the town of the player's coastal province goes into its port.
## Static helpers like Armies.

## Seconds between two searches for the way to a chased army.
const CHASE_SECONDS := 5
## How far (parchment pixels) before a foreign town an army stops (at its border).
const TOWN_BORDER := 60.0
## How near to a town (parchment pixels) a click means the town.
const TOWN_CLICK := 34.0


static func nav(sim: Simulation) -> WorldNav:
	return WorldNav.of(sim.world, sim.data)


static func speed(sim: Simulation, army: Army) -> float:
	var def := sim.data.get_world(sim.world.world_id)
	if def == null:
		return 1.0
	return def.ship_speed if army.by_sea else def.army_speed


## Where an army of province [param id] stands beside its town (on land).
static func stand_point(sim: Simulation, id: int) -> Vector2:
	var def := sim.world.def_of(id, sim.data)
	if def == null:
		return Vector2.ZERO
	var n := nav(sim)
	var p := def.world_pos + Vector2(-50, 16)
	if n == null:
		return p
	if n.province_at(p) != id:
		p = def.world_pos + Vector2(0, 30)
	return _savable(n.nearest(p, false))


## The sea off the coast of province [param id], nearest its town; Vector2.INF inland.
static func offshore(sim: Simulation, id: int) -> Vector2:
	var def := sim.world.def_of(id, sim.data)
	var n := nav(sim)
	if def == null or n == null or not def.coastal:
		return Vector2.INF
	var p := n.nearest(def.world_pos, true)
	return _savable(p) if p != Vector2.INF else p


## The town of province [param id] under [param at] (parchment pixels): 0 if none is that near.
static func town_at(sim: Simulation, at: Vector2) -> int:
	for id: int in sim.world.ids():
		var def := sim.world.def_of(id, sim.data)
		if def == null:
			continue
		var has_town := sim.runtimes.has(id) or sim.world.owner_of(id) != ProvinceDef.OWNER_NONE \
				or (sim.world.camp != null and sim.world.camp.is_up() and sim.world.camp.province == id)
		if has_town and at.distance_to(def.world_pos) <= TOWN_CLICK:
			return id
	return 0


## Where [param army] stops when it goes to the town of [param id]: beside its own town, at
## the border of a foreign one, at the town itself for bandits on a raid.
static func town_point(sim: Simulation, army: Army, id: int) -> Vector2:
	var def := sim.world.def_of(id, sim.data)
	if def == null:
		return Vector2.INF
	var owner := sim.world.owner_of(id)
	if army.owner == owner:
		return stand_point(sim, id)
	if army.owner == Army.BANDITS:
		return def.world_pos
	var from := army.pos if army.pos != Vector2.INF else stand_point(sim, army.home)
	var dir := (from - def.world_pos).normalized() if from.distance_to(def.world_pos) > 1.0 else Vector2.LEFT
	var p := def.world_pos + dir * TOWN_BORDER
	var n := nav(sim)
	return _savable(n.nearest(p, false) if n != null else p)


## Warships of province [param id] that can carry an army now (Armies.warships_at), their room.
static func _room_at(sim: Simulation, id: int) -> int:
	var room := 0
	for ship: ShipUnit in Armies.warships_at(sim, id):
		room += ship.def.troops
	return room


## The way [param army] would go: {error, sea, board, path, ashore, ashore_goal, docking}.
## [param to] is a province whose town it goes to, or 0 with [param spot] a point of the map.
static func plan(sim: Simulation, army: Army, to: int, spot: Vector2) -> Dictionary:
	var result := {"error": &"", "sea": false, "board": false, "path": [] as Array[Vector2],
			"ashore": Vector2.INF, "ashore_goal": Vector2.INF, "docking": false}
	var n := nav(sim)
	if n == null or sim.world.is_single():
		result["error"] = &"no_world"
		return result
	if army.pos == Vector2.INF:
		result["error"] = &"army_busy"
		return result
	if to != 0 and sim.world.get_province(to) == null:
		result["error"] = &"unknown_province"
		return result
	var dest := town_point(sim, army, to) if to != 0 else spot
	if dest == Vector2.INF:
		result["error"] = &"no_way"
		return result
	if army.is_fleet():
		return _plan_fleet(sim, army, to, dest, result)
	if n.is_sea(dest):
		result["error"] = &"army_not_at_sea"
		return result
	var land := n.find_path(army.pos, dest, false)
	# By sea on the warships of the province it stands in (M7 part 3).
	var sea_path: Array[Vector2] = []
	var start := Vector2.INF
	if army.owner != Army.BANDITS and army.is_standing() \
			and sim.world.owner_of(army.at) == army.owner:
		start = offshore(sim, army.at)
	var landing_from := sim.world.def_of(to, sim.data).world_pos if to != 0 else dest
	var sea_end := n.nearest(landing_from, true)
	if start != Vector2.INF and sea_end != Vector2.INF:
		sea_path = n.find_path(start, sea_end, true)
	var ships_ok := not sea_path.is_empty() and _room_at(sim, army.at) >= army.men() and army.men() > 0
	if not land.is_empty():
		result["path"] = land
		if ships_ok:
			var def := sim.data.get_world(sim.world.world_id)
			var walk := WorldNav.length_of(army.pos, land) / def.army_speed
			var sail := WorldNav.length_of(start, sea_path) / def.ship_speed
			if sail < walk:
				_by_sea(n, result, sea_path, dest)
		return result
	if ships_ok:
		_by_sea(n, result, sea_path, dest)
		return result
	result["error"] = &"needs_warships" if not sea_path.is_empty() else &"no_way"
	return result


static func _by_sea(n: WorldNav, result: Dictionary, sea_path: Array[Vector2], dest: Vector2) -> void:
	result["sea"] = true
	result["board"] = true
	result["path"] = sea_path
	var end: Vector2 = sea_path[sea_path.size() - 1]
	result["ashore"] = _savable(n.nearest(end, false))
	result["ashore_goal"] = dest


static func _plan_fleet(sim: Simulation, army: Army, to: int, dest: Vector2, result: Dictionary) -> Dictionary:
	var n := nav(sim)
	result["sea"] = true
	if to == 0 and n.is_sea(dest):
		result["path"] = n.find_path(army.pos, dest, true)
		if (result["path"] as Array).is_empty():
			result["error"] = &"no_way"
		return result
	var own_port := to != 0 and army.owner != Army.BANDITS \
			and sim.world.owner_of(to) == army.owner and sim.runtimes.has(to)
	if own_port:
		var off := offshore(sim, to)
		if off == Vector2.INF:
			result["error"] = &"no_coast"
			return result
		result["path"] = n.find_path(army.pos, off, true)
		result["docking"] = true
	elif army.men() > 0:
		var land_at := sim.world.def_of(to, sim.data).world_pos if to != 0 else dest
		var end := n.nearest(land_at, true)
		if end == Vector2.INF:
			result["error"] = &"no_way"
			return result
		result["path"] = n.find_path(army.pos, _savable(end), true)
		result["ashore"] = _savable(n.nearest(end, false))
		result["ashore_goal"] = dest
	else:
		result["error"] = &"fleet_cannot_land"
		return result
	if (result["path"] as Array).is_empty():
		result["error"] = &"no_way"
	return result


## Why [param army] cannot be ordered to the town of [param to] / [param spot], or &"".
static func order_error(sim: Simulation, army: Army, to: int, spot: Vector2) -> StringName:
	var error := _can_take_orders(army)
	if error != &"":
		return error
	return plan(sim, army, to, spot)["error"]


static func _can_take_orders(army: Army) -> StringName:
	if army == null or army.owner != ProvinceDef.OWNER_PLAYER:
		return &"no_army"
	if army.state == Army.State.INSIDE:
		return &"army_busy"
	if army.state == Army.State.ENGAGED:
		return &"army_in_battle"
	return &""


## Sends [param army] on its way (checked with [method order_error]).
static func order(sim: Simulation, army: Army, to: int, spot: Vector2) -> void:
	var way := plan(sim, army, to, spot)
	if way["error"] != &"":
		return
	army.chase = 0
	follow(sim, army, way, to)
	sim.events.emit(&"army_sent", {"army": army.id, "province": to})


static func _follow(sim: Simulation, army: Army, way: Dictionary, to: int) -> void:
	follow(sim, army, way, to)


## Sets [param army] on [param way] (from [method plan]) to the town of [param to].
static func follow(sim: Simulation, army: Army, way: Dictionary, to: int) -> void:
	if bool(way["board"]):
		_board(sim, army)
	army.by_sea = bool(way["sea"]) or army.is_fleet()
	army.path.assign(way["path"])
	army.target = to
	army.ashore = way["ashore"]
	army.ashore_goal = way["ashore_goal"]
	army.docking = bool(way["docking"])
	army.warned = false
	army.state = Army.State.MOVING
	if army.path.is_empty():
		army.state = Army.State.IDLE


## Why [param army] cannot go after army [param enemy], or &"".
static func chase_error(sim: Simulation, army: Army, enemy: int) -> StringName:
	var error := _can_take_orders(army)
	if error != &"":
		return error
	var other := sim.world.armies.get(enemy) as Army
	if other == null or other.owner == army.owner or other.pos == Vector2.INF:
		return &"no_army"
	if other.by_sea != army.is_fleet():
		return &"cannot_reach"
	var n := nav(sim)
	if n == null or n.find_path(army.pos, other.pos, army.is_fleet()).is_empty():
		return &"no_way"
	return &""


static func order_chase(sim: Simulation, army: Army, enemy: int) -> void:
	army.chase = enemy
	army.target = 0
	army.ashore = Vector2.INF
	army.docking = false
	_repath_chase(sim, army)


static func _repath_chase(sim: Simulation, army: Army) -> void:
	var other := sim.world.armies.get(army.chase) as Army
	if other == null or other.pos == Vector2.INF or other.by_sea != army.by_sea:
		army.chase = 0
		army.path.clear()
		army.state = Army.State.IDLE
		return
	army.path = nav(sim).find_path(army.pos, other.pos, army.by_sea)
	army.state = Army.State.MOVING if not army.path.is_empty() else Army.State.IDLE
	if army.path.is_empty():
		army.chase = 0


## Bandits (or anyone not taking the player's orders) to the town of [param to] over land;
## false when there is no way.
static func send_over_land(sim: Simulation, army: Army, to: int) -> bool:
	var n := nav(sim)
	if n == null or army.pos == Vector2.INF:
		return false
	var dest := town_point(sim, army, to)
	var way := n.find_path(army.pos, dest, false)
	if way.is_empty():
		return false
	army.path = way
	army.target = to
	army.chase = 0
	army.by_sea = false
	army.warned = false
	army.state = Army.State.MOVING
	return true


## Seconds [param army] still needs to the end of its way.
static func seconds_left(sim: Simulation, army: Army) -> float:
	if army.state != Army.State.MOVING:
		return 0.0
	return WorldNav.length_of(army.pos, army.path) / maxf(speed(sim, army), 0.01)


## One second of walking (or sailing) along the way; true when the way ended.
static func step(sim: Simulation, army: Army, seconds: float) -> bool:
	if army.chase != 0 and sim.clock.tick % SimClock.seconds_to_ticks(CHASE_SECONDS) == 0:
		_repath_chase(sim, army)
		if army.state != Army.State.MOVING:
			return false
	var left := speed(sim, army) * seconds
	while left > 0.0 and not army.path.is_empty():
		var to := army.path[0]
		var d := army.pos.distance_to(to)
		if d <= left:
			army.pos = to
			army.path.remove_at(0)
			left -= d
		else:
			army.pos = army.pos + (to - army.pos) / d * left
			left = 0.0
	army.pos = _savable(army.pos)
	place(sim, army)
	return army.path.is_empty()


## [member Army.at] from where it is.
static func place(sim: Simulation, army: Army) -> void:
	var n := nav(sim)
	if n == null or army.pos == Vector2.INF:
		return
	army.at = 0 if army.by_sea else n.province_at(army.pos)


## The warships the army needs leave its province with it: it is a fleet now, setting out from
## the sea off its coast.
static func _board(sim: Simulation, army: Army) -> void:
	var province := sim.province_state(army.at)
	var room := 0
	for ship: ShipUnit in Armies.warships_at(sim, army.at):
		if room >= army.men():
			break
		room += ship.def.troops
		province.ships.erase(ship.id)
		army.ships += 1
		army.fleet[ship.def.id] = army.fleet.get(ship.def.id, 0) + 1
	army.fleet_home = army.at
	army.pos = offshore(sim, army.at)
	army.by_sea = true
	army.at = 0
	sim.events.emit(&"fleet_sailed", {"army": army.id, "province": army.fleet_home, "ships": army.ships})


static func _savable(p: Vector2) -> Vector2:
	if p == Vector2.INF:
		return p
	return Vector2(SimCodec.savable(p.x), SimCodec.savable(p.y))
