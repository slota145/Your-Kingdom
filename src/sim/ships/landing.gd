class_name Landing
extends RefCounted
## The start from a ship (ROADMAP M5 part 3, IDEAS: colonisation): on a map that starts by
## ship (MapDef.start_by_ship) no town stands yet. A cog comes in over the sea edge and drops
## anchor off the beach; the settlers wade ashore one by one and the start kit lies on the
## beach as one heap of ground piles. Then the cog sails away over the horizon (owner's
## decision 2026-11-06: the player builds his own cog at a shipyard).
##
## The settlers: a builder and porters. Until the pioneer camp stands, the builder builds
## without a workplace and all porters carry (owner's decision: nobody stands idle). When the
## camp is finished it takes its workers from them (they live in the camp); the others move
## into the first huts with free places. When everybody is settled the landing is over and
## ProvinceSim.landing goes back to null.

enum State { COMING, UNLOADING, LEAVING, DONE }

## The ship that brings the settlers (player's colours, sails away after the landing).
const SHIP := &"settler_cog"
## Seconds between two settlers stepping off the ship.
const LAND_EVERY := 2.0

var state: State = State.COMING
var ship_id: int = 0
## Deep water where the ship drops anchor, and the beach tile the settlers wade to.
var anchor: Vector2i = Agent.NO_TILE
var beach: Vector2i = Agent.NO_TILE
## Sea edge where it came in and goes out.
var edge: Vector2i = Agent.NO_TILE
## Settlers still aboard (kinds, in the order they step off).
var aboard: Array[StringName] = []
## Goods put on the beach when the ship has dropped anchor.
var kit: Dictionary[StringName, int] = {}
## Tick the next settler steps off.
var next_at: int = 0
## Settlers ashore without a workplace or a house yet (agent ids).
var settlers: Array[int] = []


## Starts the landing of [param map] in [param province]: the ship at the sea edge nearest to
## the anchorage, sailing in. Null when the map does not start by ship or no way leads in.
static func begin(province: ProvinceSim, map: MapDef) -> Landing:
	if not map.start_by_ship:
		return null
	var landing := Landing.new()
	landing.anchor = map.landing_tile
	landing.beach = map.beach_tile
	landing.aboard = map.start_settlers.duplicate()
	landing.kit = map.start_pile.duplicate()
	var def := province.data.get_ship(SHIP)
	var nav := Ships.nav_for(province, def)
	landing.edge = SeaMerchant._edge_for(province, nav, landing.anchor)
	var from := landing.edge if landing.edge != Agent.NO_TILE else landing.anchor
	var ship := ShipUnit.new(province.ids.take(), def, IsoMath.tile_center(from), province.data)
	province.ships[ship.id] = ship
	landing.ship_id = ship.id
	if not Ships.sail_to(province, ship, landing.anchor):
		ship.pos = IsoMath.tile_center(landing.anchor)
		ship.clear_path()
		ship.path_state = ShipUnit.PathState.ARRIVED
	province.events.emit(&"landing_coming", {"ship": ship.id})
	return landing


func is_landing_ship(ship: ShipUnit) -> bool:
	return ship.id == ship_id


## Once a second (ProvinceSim.step, before the workforce is balanced).
func update(province: ProvinceSim) -> void:
	var ship := province.ships.get(ship_id) as ShipUnit
	match state:
		State.COMING:
			if ship == null or ship.path_state != ShipUnit.PathState.MOVING:
				if ship != null:
					ship.clear_path()
				_unload_kit(province)
				state = State.UNLOADING
				next_at = province.tick
				province.events.emit(&"landing_anchored", {"ship": ship_id})
		State.UNLOADING:
			if not aboard.is_empty():
				if province.tick >= next_at:
					_land_one(province, ship)
					next_at = province.tick + SimClock.seconds_to_ticks(LAND_EVERY)
			elif not _wading(province):
				state = State.LEAVING
				if ship != null and (edge == Agent.NO_TILE or not Ships.sail_to(province, ship, edge)):
					ship.clear_path()
				province.events.emit(&"landing_leaving", {"ship": ship_id})
		State.LEAVING:
			if ship == null or ship.path_state != ShipUnit.PathState.MOVING:
				province.ships.erase(ship_id)
				state = State.DONE
	_settle(province)


## The landing is over: the ship is gone and every settler has a workplace or a house.
func is_over() -> bool:
	return state == State.DONE and settlers.is_empty()


## The province is left during the landing (M6, ARCHITECTURE §7.2): it ends at once. The kit
## lies on the beach, every settler still aboard stands on it, the ship is gone. The settlers
## keep waiting for the camp and for houses (ProvinceAbstract.wanderers).
func finish_at_once(province: ProvinceSim) -> void:
	if state == State.COMING:
		_unload_kit(province)
	while not aboard.is_empty():
		var kind: StringName = aboard.pop_front()
		settlers.append(province.spawn_agent(kind, beach).id)
	province.ships.erase(ship_id)
	state = State.DONE


## The start kit on the beach: one stack per ground pile, on the free tiles nearest to the
## beach tile (land, nothing built, no pile yet), in a fixed order.
func _unload_kit(province: ProvinceSim) -> void:
	var goods: Array[StringName] = []
	goods.assign(kit.keys())
	goods.sort()
	var tiles := _heap_tiles(province)
	var next := 0
	for good: StringName in goods:
		var left := kit[good]
		var stack := maxi(province.data.get_good(good).stack_size, 1)
		while left > 0:
			var tile := tiles[mini(next, tiles.size() - 1)] if not tiles.is_empty() else beach
			next += 1
			var amount := mini(left, stack)
			province.drop_goods(tile, good, amount)
			left -= amount
	kit = {}


## Free land tiles around the beach tile, nearest first (rings), the beach tile itself left
## free for the settlers wading in.
func _heap_tiles(province: ProvinceSim) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for r: int in range(1, 6):
		for y: int in range(beach.y - r, beach.y + r + 1):
			for x: int in range(beach.x - r, beach.x + r + 1):
				var tile := Vector2i(x, y)
				if maxi(absi(x - beach.x), absi(y - beach.y)) != r:
					continue
				if province.grid.is_inside(tile) and province.nav.is_walkable(tile) \
						and province.sail_depth(tile) == 0 and province.grid.occupant(tile) == 0:
					tiles.append(tile)
	# Inland first: the heap lies behind the beach, away from the water's edge.
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := (a - beach).length_squared()
		var db := (b - beach).length_squared()
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	return tiles


func _land_one(province: ProvinceSim, ship: ShipUnit) -> void:
	var kind: StringName = aboard.pop_front()
	var from := ship.tile() if ship != null else anchor
	var agent := province.spawn_agent(kind, from)
	TaskRunner.start_landing(agent, from, beach)
	settlers.append(agent.id)
	province.events.emit(&"settler_landed", {"agent": agent.id, "kind": kind})


func _wading(province: ProvinceSim) -> bool:
	for id: int in settlers:
		var agent := province.agents.get_agent(id)
		if agent != null and agent.task != null and agent.task.kind == Task.KIND_LAND:
			return true
	return false


## The pioneer camp takes its workers from the settlers; the others move into huts.
func _settle(province: ProvinceSim) -> void:
	if settlers.is_empty():
		return
	var left: Array[int] = []
	for id: int in settlers:
		var agent := province.agents.get_agent(id)
		if agent != null:
			left.append(id)
	settlers = left
	for building: BuildingState in province.buildings.all():
		if not building.def.unique or not building.is_complete() or building.def.worker_count() == 0:
			continue
		var missing := Population.missing_kinds(province, building)
		for kind: StringName in missing:
			for id: int in settlers:
				var agent := province.agents.get_agent(id)
				if agent.kind == kind and agent.workplace_id == 0 \
						and (agent.task == null or agent.task.kind != Task.KIND_LAND):
					province.assign_worker(agent, building)
					settlers.erase(id)
					province.events.emit(&"worker_hired", {"agent": id, "building": building.id,
							"home": 0})
					break
	for id: int in settlers.duplicate():
		var agent := province.agents.get_agent(id)
		if agent.workplace_id != 0 or not agent.is_idle() or agent.is_carrying():
			continue
		var house := _free_house(province, agent)
		if house == null:
			break
		settlers.erase(id)
		agent.kind = Population.SETTLER_KIND
		agent.vehicle = &""
		agent.home_id = house.id
		house.house.incoming += 1
		TaskRunner.start_move_in(agent)
		province.events.emit(&"settler_moving_in", {"agent": id, "building": house.id})
	if state == State.DONE and settlers.is_empty():
		province.events.emit(&"landing_over", {})


## The finished house with a free place nearest to [param agent], or null.
static func _free_house(province: ProvinceSim, agent: Agent) -> BuildingState:
	var best: BuildingState = null
	var best_d := 1 << 30
	for building: BuildingState in province.buildings.all():
		if building.house == null or not building.is_complete() \
				or building.house.free_places(building.capacity()) <= 0:
			continue
		var d := (building.entrance_tile() - agent.tile()).length_squared()
		if d < best_d:
			best_d = d
			best = building
	return best


func to_dict() -> Dictionary:
	var aboard_list: Array = []
	for kind: StringName in aboard:
		aboard_list.append(String(kind))
	var kit_dict := {}
	for good: StringName in kit:
		kit_dict[String(good)] = kit[good]
	return {"state": state, "ship": ship_id, "anchor": SimCodec.vec2i(anchor),
			"beach": SimCodec.vec2i(beach), "edge": SimCodec.vec2i(edge), "aboard": aboard_list,
			"kit": kit_dict, "next_at": next_at, "settlers": settlers.duplicate()}


static func from_dict(d: Dictionary) -> Landing:
	var landing := Landing.new()
	landing.state = clampi(int(d.get("state", 0)), State.COMING, State.DONE) as State
	landing.ship_id = int(d.get("ship", 0))
	landing.anchor = SimCodec.to_vec2i(d.get("anchor", [-1, -1]))
	landing.beach = SimCodec.to_vec2i(d.get("beach", [-1, -1]))
	landing.edge = SimCodec.to_vec2i(d.get("edge", [-1, -1]))
	for kind: Variant in d.get("aboard", []):
		landing.aboard.append(StringName(String(kind)))
	var kit_dict: Dictionary = d.get("kit", {})
	for good: Variant in kit_dict:
		landing.kit[StringName(String(good))] = int(kit_dict[good])
	landing.next_at = int(d.get("next_at", 0))
	for id: Variant in d.get("settlers", []):
		landing.settlers.append(int(id))
	return landing
