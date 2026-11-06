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
## How far (tiles) past the berth centre a docker stands on the ship's deck.
const ON_DECK := 0.15
## Activity of a docker handing goods over at the ship.
const HAND_OVER := &"hand_over"


# --- Mooring -------------------------------------------------------------------------------

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


# --- Gangway -------------------------------------------------------------------------------

## The way from the port entrance over the quay to the foot of the gangway and up it to the
## ship at the berth (tile centres in grid space).
static func gangway_points(port: BuildingState) -> PackedVector2Array:
	return _points(port.entrance_tile(), port.gangway_tile(), port.berth_tile())


## Entrance and gangway foot tile centres, and the spot on the ship's deck just past its
## middle (so the docker is drawn on the deck, in front of the hull).
static func _points(door: Vector2i, foot: Vector2i, berth: Vector2i) -> PackedVector2Array:
	var a := IsoMath.tile_center(foot)
	var b := IsoMath.tile_center(berth)
	return PackedVector2Array([IsoMath.tile_center(door), a, b + (b - a).normalized() * ON_DECK])


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
		kept[trader.port_id] = trader.loading_goods()
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
