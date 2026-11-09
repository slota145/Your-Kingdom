class_name Harbour
extends RefCounted
## Ports (GDD §5.4, ROADMAP M5 part 2): one berth per port, reserved by a ship on its way in;
## dockers carry goods unit by unit between the quay yard and a moored ship, walking over the
## quay and up the gangway; goods on the quay yard that no ship is waiting for go to storages.
## Static helpers over ProvinceSim state, like Ships.
##
## The quay yard is the port's stock (BuildingDef.quay_slots), addressed by the port id. A
## moored ship's hold is addressed by the ship id; its access tile is the port entrance, and
## the last stretch from there to the ship (over the quay and the gangway) is walked by the
## steps themselves (walk_out, walk_back), so ships need no walkable tiles on the water.

const DOCKER_KIND := &"docker"
## Handing one unit over at the ship (ROADMAP M5: about 1 s per unit).
const HANDLING_TICKS := 10
## Activity of a docker handing goods over at the ship.
const HAND_OVER := &"hand_over"


## How far (tiles) past the berth centre, away from the quay, a ship lies moored (owner's
## request 2026-11-07: the cog's hull reached over the quay). It stays on the berth tile; the
## view draws a cog's hull a little further still (ShipLayer.MOORED_HULL_SHIFT).
const MOOR_OFFSET := 0.45


## How far (tiles, Chebyshev between centres) a port's dockers serve a mooring (N1).
const SERVE_RADIUS := 12


# --- Mooring -------------------------------------------------------------------------------

## The finished port with dockers of its own nearest to [param centre] within SERVE_RADIUS,
## or null (who serves a mooring, N1).
static func serving_port(province: ProvinceSim, centre: Vector2i) -> BuildingState:
	var best: BuildingState = null
	var best_d := 1 << 30
	for building: BuildingState in province.buildings.all():
		if not building.def.is_port() or not building.def.worker_kinds.has(DOCKER_KIND) \
				or not building.is_complete():
			continue
		var c := building.origin + building.def.footprint / 2
		var d := maxi(absi(c.x - centre.x), absi(c.y - centre.y))
		if d <= SERVE_RADIUS and (d < best_d or (d == best_d and building.id < best.id)):
			best_d = d
			best = building
	return best


## Whose dockers work at [param port]: the port itself, or for a mooring the port serving it
## (0 when none does).
static func crew_of(province: ProvinceSim, port: BuildingState) -> int:
	# A port's own dockers; a mooring or a bollard is served by the nearest port (N1, P2).
	if not port.def.served_by_port and not port.def.uses_port_storage:
		return port.id
	var serving := serving_port(province, port.origin + port.def.footprint / 2)
	return serving.id if serving != null else 0


static func _centre(building: BuildingState) -> Vector2i:
	return building.origin + building.def.footprint / 2


static func _reach(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## The finished port warehouse (any size) nearest to [param centre] within SERVE_RADIUS, or
## null (where a bollard's cargo waits, P2 part 1).
static func port_storage_near(province: ProvinceSim, centre: Vector2i) -> BuildingState:
	var best: BuildingState = null
	var best_d := 1 << 30
	for building: BuildingState in province.buildings.all():
		if not building.def.is_port_storage() or not building.is_complete():
			continue
		var d := _reach(_centre(building), centre)
		if d <= SERVE_RADIUS and (d < best_d or (d == best_d and building.id < best.id)):
			best_d = d
			best = building
	return best


## Where the cargo of ships moored at [param dock] waits: its own quay yard (a port, a
## mooring), or for a bollard the nearest port warehouse (P2 part 1); null when there is none
## (a bollard's cargo then goes straight to and from the storages).
static func yard(province: ProvinceSim, dock: BuildingState) -> BuildingState:
	if dock == null:
		return null
	if not dock.def.uses_port_storage:
		return dock if dock.stock != null else null
	return port_storage_near(province, _centre(dock))


## Id of [method yard], 0 when there is none (requests then name any storage).
static func yard_id(province: ProvinceSim, dock: BuildingState) -> int:
	var store := yard(province, dock)
	return store.id if store != null else 0


## Workplaces whose dockers carry the cargo of ships at [param dock] (P2 part 1): its own
## crew (a port, or the port serving a mooring) and every finished house of dockers within
## SERVE_RADIUS. Empty when nobody can.
static func crews_for(province: ProvinceSim, dock: BuildingState) -> Array[int]:
	var crews: Array[int] = []
	var own := crew_of(province, dock)
	if own != 0:
		crews.append(own)
	crews.append_array(docker_houses_near(province, _centre(dock)))
	return crews


## Finished houses of dockers within SERVE_RADIUS of [param centre] (by id).
static func docker_houses_near(province: ProvinceSim, centre: Vector2i) -> Array[int]:
	var result: Array[int] = []
	for building: BuildingState in province.buildings.all():
		if building.def.is_docker_house() and building.is_complete() \
				and _reach(_centre(building), centre) <= SERVE_RADIUS:
			result.append(building.id)
	return result


## The ship that reserved the berth of [param port] (moored or on its way in), or null.
static func berth_holder(province: ProvinceSim, port: BuildingState) -> ShipUnit:
	for ship: ShipUnit in province.ships.values():
		if ship.berth_id == port.id:
			return ship
	return null


## Reserves the berth of [param port] for [param ship]; false when another ship holds it.
static func claim_berth(province: ProvinceSim, ship: ShipUnit, port: BuildingState) -> bool:
	var holder := berth_holder(province, port)
	if holder != null and holder != ship:
		return false
	ship.berth_id = port.id
	return true


## Moors [param ship] at the berth of [param port], lying along the quay.
static func moor(ship: ShipUnit, port: BuildingState) -> void:
	Ships.dock(ship, port)
	ship.pos = moor_point(port.gangway_tile(), port.berth_tile())
	ship.prev_pos = ship.pos
	ship.berth_id = port.id
	var along := port.def.turned(Vector2i(1, 0), port.orientation) - port.def.turned(Vector2i.ZERO, port.orientation)
	var dir := IsoMath.screen_dir(Vector2(along))
	if dir >= 0:
		ship.facing = dir


## A finished port whose berth is free, nearest to [param near]; null if none.
static func free_port(province: ProvinceSim, near: Vector2i) -> BuildingState:
	var best: BuildingState = null
	var best_d := 1 << 30
	for building: BuildingState in province.buildings.all():
		if not building.def.is_port() or not building.is_complete():
			continue
		if berth_holder(province, building) != null:
			continue
		var d := (building.berth_tile() - near).length_squared()
		if d < best_d:
			best_d = d
			best = building
	return best


## The port at which the ship with id [param ship_id] lies moored, or null (also when the id
## is not a ship).
static func port_of(province: ProvinceSim, ship_id: int) -> BuildingState:
	var ship := province.ships.get(ship_id) as ShipUnit
	if ship == null or not ship.is_moored():
		return null
	var port := province.buildings.get_building(ship.dock_id)
	return port if port != null and port.def.is_port() and port.is_complete() else null


## Port of a transport request between a quay yard and a moored ship: only that port's
## dockers carry it. 0 when neither end is a ship; -1 when a ship end is not moored at a port
## (nobody can carry it now).
static func request_port(province: ProvinceSim, request: TransportRequest) -> int:
	for id: int in [request.source_id, request.dest_id]:
		if id > 0 and province.ships.has(id):
			var port := port_of(province, id)
			return port.id if port != null else -1
	return 0


## Workplaces whose dockers carry [param request] (P2 part 1): for the cargo of a moored
## ship, the crews of its dock ([method crews_for]); for goods to or from a harbour building
## (a quay yard, a port warehouse), the houses of dockers near it, who help the porters.
## [code]null[/code] when it is not port work (porters carry it); an empty list when it is the
## cargo of a ship nobody can carry now.
static func request_crews(province: ProvinceSim, request: TransportRequest) -> Variant:
	var port_id := request_port(province, request)
	if port_id < 0:
		return [] as Array[int]
	if port_id > 0:
		return crews_for(province, province.buildings.get_building(port_id))
	for id: int in [request.source_id, request.dest_id]:
		var building := province.buildings.get_building(id) if id > 0 else null
		if building != null and (building.def.is_port_storage() or building.def.quay_slots > 0):
			var houses := docker_houses_near(province, _centre(building))
			return houses if not houses.is_empty() else null
	return null


# --- Gangway -------------------------------------------------------------------------------

## The way from the port entrance over the quay to the foot of the gangway and up it to the
## ship at the berth (tile centres in grid space).
static func gangway_points(port: BuildingState) -> PackedVector2Array:
	return _points(port.entrance_tile(), port.gangway_tile(), port.berth_tile())


## Where a ship moored at [param berth] lies (grid space): the berth centre moved
## MOOR_OFFSET away from the quay (from the gangway foot [param foot]). Still on the berth tile.
static func moor_point(foot: Vector2i, berth: Vector2i) -> Vector2:
	var away := Vector2(berth - foot)
	if away == Vector2.ZERO:
		return IsoMath.tile_center(berth)
	return IsoMath.tile_center(berth) + away.normalized() * MOOR_OFFSET


## Entrance and gangway foot tile centres, and the spot on the ship's deck where the ship
## lies (moor_point; the view draws the hull a little further, so he stands by its near rail).
static func _points(door: Vector2i, foot: Vector2i, berth: Vector2i) -> PackedVector2Array:
	var a := IsoMath.tile_center(foot)
	var b := moor_point(foot, berth)
	return PackedVector2Array([IsoMath.tile_center(door), a, b])


static func _length(points: PackedVector2Array) -> float:
	var sum := 0.0
	for i: int in range(1, points.size()):
		sum += points[i - 1].distance_to(points[i])
	return sum


## Ticks to walk the gangway one way.
static func walk_ticks(port: BuildingState) -> int:
	return maxi(ceili(_length(gangway_points(port)) / (Movement.BASE_SPEED * SimClock.TICK)), 1)


## Puts [param agent] [param along] tiles from the entrance on the way to the ship, facing
## the way he goes.
static func _place(agent: Agent, points: PackedVector2Array, along: float, outwards: bool) -> void:
	var left := along
	for i: int in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var segment := a.distance_to(b)
		if left <= segment or i == points.size() - 1:
			agent.pos = a.lerp(b, clampf(left / maxf(segment, 0.001), 0.0, 1.0))
			var dir := IsoMath.screen_dir(b - a if outwards else a - b)
			if dir >= 0:
				agent.facing = dir
			return
		left -= segment


## [param agent] standing at the entrance of [param port] walks over the quay and up the
## gangway, then hands the goods over for HANDLING_TICKS. True while that goes on; false on
## the tick the goods change hands (the step then moves them and calls [method turn_back]).
## Progress is kept in the task blackboard, so a save in the middle resumes there.
static func walk_out(agent: Agent, port: BuildingState) -> bool:
	var bb := agent.task.bb
	var ticks := walk_ticks(port)
	var t := int(bb.get("_gw", 0))
	if t == 0:
		bb["_gw_door"] = [port.entrance_tile().x, port.entrance_tile().y]
		bb["_gw_ticks"] = ticks
	t += 1
	bb["_gw"] = t
	if t <= ticks:
		var points := gangway_points(port)
		_place(agent, points, _length(points) * t / ticks, true)
		agent.activity = &"walk"
		return true
	agent.activity = HAND_OVER
	return t < ticks + HANDLING_TICKS


## The goods have changed hands at the ship: from now on the step only walks back.
static func turn_back(agent: Agent, port: BuildingState) -> void:
	var bb := agent.task.bb
	bb["_gw_back"] = 0
	var berth := port.berth_tile()
	bb["_gw_berth"] = [berth.x, berth.y]
	var foot := port.gangway_tile()
	bb["_gw_foot"] = [foot.x, foot.y]


## Whether [param agent] is on his way back from a ship (after [method turn_back]).
static func is_walking_back(agent: Agent) -> bool:
	return agent.task != null and agent.task.bb.has("_gw_back")


## Walks [param agent] back down the gangway and over the quay to the entrance (the way is
## kept in the blackboard, so it does not need the port or the ship any more). DONE there.
static func walk_back(agent: Agent) -> TaskStep.Status:
	var bb := agent.task.bb
	var ticks := int(bb.get("_gw_ticks", 1))
	var t := int(bb["_gw_back"]) + 1
	bb["_gw_back"] = t
	var points := _saved_points(bb)
	if t < ticks:
		_place(agent, points, _length(points) * (ticks - t) / ticks, false)
		agent.activity = &"walk"
		return TaskStep.Status.RUNNING
	agent.pos = points[0]
	agent.activity = &"idle"
	for key: String in ["_gw", "_gw_back", "_gw_door", "_gw_foot", "_gw_berth", "_gw_ticks"]:
		bb.erase(key)
	return TaskStep.Status.DONE


static func _saved_points(bb: Dictionary) -> PackedVector2Array:
	var tiles: Array[Vector2i] = []
	for key: String in ["_gw_door", "_gw_foot", "_gw_berth"]:
		var t: Array = bb[key]
		tiles.append(Vector2i(int(t[0]), int(t[1])))
	return _points(tiles[0], tiles[1], tiles[2])


## A task ends while [param agent] is out on the quay or the gangway: he steps back to the
## port entrance, so nothing he drops lands in the water.
static func step_ashore(agent: Agent) -> void:
	if agent.task == null or not agent.task.bb.has("_gw_door"):
		return
	var door: Array = agent.task.bb["_gw_door"]
	agent.pos = IsoMath.tile_center(Vector2i(int(door[0]), int(door[1])))
	agent.prev_pos = agent.pos


# --- Quay yard -----------------------------------------------------------------------------

## Goods each port's quay yard keeps for a ship (port id -> good -> units on the quay that
## wait to be loaded); everything else on the quay goes to storages.
static func _kept_on_quay(province: ProvinceSim) -> Dictionary[int, Dictionary]:
	var kept: Dictionary[int, Dictionary] = {}
	var trader := province.sea_merchant
	if trader.is_trading():
		kept[yard_id(province, province.buildings.get_building(trader.port_id))] = trader.loading_goods()
	for ship: ShipUnit in province.ships.values():
		if ship.voyage != null and not ship.voyage.loading_goods().is_empty():
			kept[yard_id(province, province.buildings.get_building(ship.dock_id))] = ship.voyage.loading_goods()
	return kept


## Once a second: goods on a quay yard that no ship is loading are carried to storages.
static func update(province: ProvinceSim) -> void:
	var kept := _kept_on_quay(province)
	for building: BuildingState in province.buildings.all():
		if not building.def.is_port() or building.stock == null:
			continue
		var keep: Dictionary = kept.get(building.id, {})
		var goods := building.stock.totals()
		for good: StringName in goods:
			var wanted := 0 if keep.has(good) else building.stock.available(good)
			province.jobs.set_amount(good, building.id, 0, wanted)
