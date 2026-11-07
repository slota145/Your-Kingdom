class_name Landing
extends RefCounted
## The start from a ship (ROADMAP M5 part 3, IDEAS: colonisation): on a map that starts by
## ship (MapDef.start_by_ship) no town stands yet. The cog already lies at anchor off the beach
## when the game starts (review fix 2026-11-07: sailing in from the edge took too long); the
## settlers wade ashore one by one, each to his own spot along the shore, and the start kit
## lies on the beach as one heap of ground piles. Then the cog sails away over the horizon (owner's
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
## How far in from the map edge a land expedition makes camp (tiles along the way).
const CAMP_INLAND := 12
## Seconds between two settlers stepping off the ship.
const LAND_EVERY := 2.0
## How far along the shore from the beach tile the settlers spread (tiles).
const SHORE_REACH := 3

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
## Settlers stepped off so far: the next one wades to the next spot along the shore.
var landed: int = 0
## The expedition that brought them (M6 part 2); 0 = the start of a game.
var expedition: int = 0
## By land (M6 part 2): the settlers and their wagon come in over the map edge
## ([member edge] is then the land entry) and walk to [member beach], the camp site.
var by_land: bool = false
## By land: the agent driving the settlers' wagon (0 once it has gone).
var wagon_agent: int = 0


## Starts the landing of [param map] in [param province]: the ship at the sea edge nearest to
## the anchorage, sailing in. Null when the map does not start by ship or no way leads in.
static func begin(province: ProvinceSim, map: MapDef, mirrored: bool = false) -> Landing:
	if not map.start_by_ship:
		return null
	return arrive_by_sea(province, map, mirrored, map.start_settlers, map.start_pile, 0)


## An expedition of settlers comes by sea (M6 part 2), like the start of a game: the ship
## anchors at the map's landing tile and the settlers wade to its beach.
static func arrive_by_sea(province: ProvinceSim, map: MapDef, mirrored: bool,
		people: Array[StringName], goods: Dictionary[StringName, int], expedition_id: int) -> Landing:
	var landing := Landing.new()
	landing.expedition = expedition_id
	landing.anchor = ProvinceSim._variant_tile(map.landing_tile, mirrored)
	landing.beach = ProvinceSim._variant_tile(map.beach_tile, mirrored)
	landing.aboard = people.duplicate()
	landing.kit = goods.duplicate()
	var def := province.data.get_ship(SHIP)
	var nav := Ships.nav_for(province, def)
	landing.edge = SeaMerchant._edge_for(province, nav, landing.anchor)
	var ship := ShipUnit.new(province.ids.take(), def, IsoMath.tile_center(landing.anchor), province.data)
	province.ships[ship.id] = ship
	landing.ship_id = ship.id
	ship.clear_path()
	ship.path_state = ShipUnit.PathState.ARRIVED
	province.events.emit(&"landing_coming", {"ship": ship.id})
	return landing


## An expedition of settlers comes by land (M6 part 2): the settlers' wagon and the settlers
## walking beside it come in at the map's entry and go to a camp site a little way in; there
## the kit is unloaded and the wagon is left behind (it goes back over the edge empty).
static func arrive_by_land(province: ProvinceSim, people: Array[StringName],
		goods: Dictionary[StringName, int], expedition_id: int) -> Landing:
	var landing := Landing.new()
	landing.expedition = expedition_id
	landing.by_land = true
	landing.edge = province.entry_tile
	landing.beach = camp_site(province, province.entry_tile)
	landing.kit = goods.duplicate()
	var wagon := province.spawn_agent(Carriers.CARTER_KIND, landing.edge)
	wagon.vehicle = Carriers.SETTLER_WAGON
	TaskRunner.start_travel(wagon, landing.beach)
	landing.wagon_agent = wagon.id
	for kind: StringName in people:
		var agent := province.spawn_agent(kind, landing.edge)
		TaskRunner.start_travel(agent, landing.beach)
		landing.settlers.append(agent.id)
	province.events.emit(&"landing_coming", {"ship": 0, "by_land": true})
	return landing


## A camp site [constant CAMP_INLAND] tiles in from [param entry] on the way to the middle of
## the map (or as far as the way goes).
static func camp_site(province: ProvinceSim, entry: Vector2i) -> Vector2i:
	var centre := province.grid.size / 2
	var goal := Agent.NO_TILE
	for r: int in range(0, maxi(province.grid.size.x, province.grid.size.y) / 2):
		for dx: int in range(-r, r + 1):
			for dy: int in [-r, r]:
				var t := centre + Vector2i(dx, dy)
				if goal == Agent.NO_TILE and province.grid.is_inside(t) and province.nav.is_walkable(t):
					goal = t
		if goal != Agent.NO_TILE:
			break
	var path := province.find_path(entry, goal) if goal != Agent.NO_TILE else ([] as Array[Vector2i])
	if path.is_empty():
		return entry
	return path[mini(CAMP_INLAND, path.size() - 1)]


func is_landing_ship(ship: ShipUnit) -> bool:
	return ship.id == ship_id


## Once a second (ProvinceSim.step, before the workforce is balanced).
func update(province: ProvinceSim) -> void:
	if by_land:
		_update_by_land(province)
		_settle(province)
		return
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


## By land: the wagon reaches the camp site and is unloaded, then goes back over the edge.
func _update_by_land(province: ProvinceSim) -> void:
	var wagon := province.agents.get_agent(wagon_agent)
	match state:
		State.COMING:
			if wagon == null or wagon.task == null:
				_unload_kit(province)
				state = State.LEAVING
				province.events.emit(&"landing_anchored", {"ship": 0, "by_land": true})
				if wagon != null:
					TaskRunner.start_travel(wagon, edge, false, true)
		State.LEAVING, State.UNLOADING:
			if wagon == null:
				wagon_agent = 0
				state = State.DONE


## The landing is over: the ship is gone and every settler has a workplace or a house.
func is_over() -> bool:
	return state == State.DONE and settlers.is_empty()


## The province is left during the landing (M6, ARCHITECTURE §7.2): it ends at once. The kit
## lies on the beach, every settler still aboard stands on it, the ship is gone. The settlers
## keep waiting for the camp and for houses (ProvinceAbstract.wanderers).
func finish_at_once(province: ProvinceSim) -> void:
	if not kit.is_empty():
		_unload_kit(province)
	while not aboard.is_empty():
		var kind: StringName = aboard.pop_front()
		settlers.append(province.spawn_agent(kind, beach).id)
	province.ships.erase(ship_id)
	var wagon := province.agents.get_agent(wagon_agent)
	if wagon != null:
		province.remove_agent(wagon)
	wagon_agent = 0
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
	var spots := shore_spots(province)
	var to := spots[landed % spots.size()] if not spots.is_empty() else beach
	landed += 1
	TaskRunner.start_landing(agent, from, to)
	settlers.append(agent.id)
	province.events.emit(&"settler_landed", {"agent": agent.id, "kind": kind})


## Where the settlers come ashore (review fix 2026-11-07: spread along the beach instead of
## all on one tile): free land tiles at the water's edge within [constant SHORE_REACH] of the
## beach tile, the beach tile first, then the nearest, in a fixed order.
func shore_spots(province: ProvinceSim) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	for y: int in range(beach.y - SHORE_REACH, beach.y + SHORE_REACH + 1):
		for x: int in range(beach.x - SHORE_REACH, beach.x + SHORE_REACH + 1):
			var tile := Vector2i(x, y)
			if tile == beach or not _is_dry_free(province, tile):
				continue
			for step: Vector2i in IsoMath.DIR_GRID_STEP:
				var next := tile + step
				if province.grid.is_inside(next) and province.sail_depth(next) > 0:
					spots.append(tile)
					break
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := (a - beach).length_squared()
		var db := (b - beach).length_squared()
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	spots.push_front(beach)
	return spots


static func _is_dry_free(province: ProvinceSim, tile: Vector2i) -> bool:
	return province.grid.is_inside(tile) and province.nav.is_walkable(tile) 			and province.sail_depth(tile) == 0 and province.grid.occupant(tile) == 0


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
						and (agent.task == null or (agent.task.kind != Task.KIND_LAND \
						and agent.task.kind != Task.KIND_TRAVEL)):
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
	var d := {"state": state, "ship": ship_id, "anchor": SimCodec.vec2i(anchor),
			"beach": SimCodec.vec2i(beach), "edge": SimCodec.vec2i(edge), "aboard": aboard_list,
			"kit": kit_dict, "next_at": next_at, "settlers": settlers.duplicate()}
	if expedition != 0:
		d["expedition"] = expedition
	if landed != 0:
		d["landed"] = landed
	if by_land:
		d["by_land"] = true
		d["wagon"] = wagon_agent
	return d


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
	landing.expedition = int(d.get("expedition", 0))
	landing.landed = int(d.get("landed", 0))
	landing.by_land = bool(d.get("by_land", false))
	landing.wagon_agent = int(d.get("wagon", 0))
	return landing
