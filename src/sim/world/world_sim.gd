class_name WorldSim
extends RefCounted
## The world layer of the simulation (ARCHITECTURE §4.1, ROADMAP M6): the provinces, their
## owners, land borders and sea routes, and how long journeys between them take.
##
## A game on a single map ("Single province", every save from before M6) is a world with one
## province and no WorldDef.

## Province id of a single-province game and of the first province of a world.
const FIRST_ID := 1

## WorldDef id; empty in a single-province game.
var world_id: StringName = &""
var provinces: Dictionary[int, WorldProvince] = {}
## Expeditions of settlers on the world map by id (M6 part 2).
var expeditions: Dictionary[int, Expedition] = {}
## Trade routes by id (M6 part 3).
var routes: Dictionary[int, TradeRoute] = {}
## Demands of the neutral settlements by province id (M6 part 3).
var settlements: Dictionary[int, NeutralSettlement] = {}
## Armies of the player and of the bandits by id (M7 part 3).
var armies: Dictionary[int, Army] = {}
## The bandits' camp (null in a world without bandits and in a single-province game).
var camp: BanditCamp = null
## Reports of the last battles, newest last: {tick, province, kind, attacker, defender,
## result (BattleResult.to_dict)}.
var reports: Array[Dictionary] = []

const REPORTS_KEPT := 8


## A single-province game on [param map_id], owned by the player.
static func single(map_id: StringName) -> WorldSim:
	var world := WorldSim.new()
	world.provinces[FIRST_ID] = WorldProvince.new(FIRST_ID, &"", map_id, ProvinceDef.OWNER_PLAYER)
	return world


## The provinces of [param def] numbered from FIRST_ID in its order, with their start owners.
static func from_def(def: WorldDef, data: DataRegistry) -> WorldSim:
	var world := WorldSim.new()
	world.world_id = def.id
	var next := FIRST_ID
	for province_id: StringName in def.provinces:
		var pdef := data.get_province(province_id)
		if pdef == null:
			continue
		world.provinces[next] = WorldProvince.new(next, pdef.id, pdef.template, pdef.owner)
		next += 1
	return world


func is_single() -> bool:
	return world_id == &""


func ids() -> Array[int]:
	var result: Array[int] = []
	result.assign(provinces.keys())
	result.sort()
	return result


func get_province(id: int) -> WorldProvince:
	return provinces.get(id)


## The id of the province made from [param def_id], 0 if none.
func id_of(def_id: StringName) -> int:
	for province: WorldProvince in provinces.values():
		if province.def_id == def_id:
			return province.id
	return 0


func owner_of(id: int) -> StringName:
	var province := get_province(id)
	return province.owner if province != null else ProvinceDef.OWNER_NONE


func def_of(id: int, data: DataRegistry) -> ProvinceDef:
	var province := get_province(id)
	return data.get_province(province.def_id) if province != null and province.def_id != &"" else null


## Whether [param a] and [param b] share a land border.
func are_neighbours(a: int, b: int, data: DataRegistry) -> bool:
	var da := def_of(a, data)
	var db := def_of(b, data)
	if da == null or db == null:
		return false
	return da.neighbours.has(db.id) or db.neighbours.has(da.id)


## Whether a ship can sail from [param a] to [param b]: both have a coast.
func sea_route(a: int, b: int, data: DataRegistry) -> bool:
	var da := def_of(a, data)
	var db := def_of(b, data)
	return da != null and db != null and a != b and da.coastal and db.coastal


## Seconds of game time a journey takes from [param a] to [param b], by ship or by wagon;
## -1 when there is no such way (no coast, not neighbours).
func travel_seconds(a: int, b: int, by_sea: bool, data: DataRegistry) -> float:
	var world := data.get_world(world_id)
	if world == null:
		return -1.0
	if by_sea and not sea_route(a, b, data):
		return -1.0
	if not by_sea and not are_neighbours(a, b, data):
		return -1.0
	var distance := def_of(a, data).world_pos.distance_to(def_of(b, data).world_pos)
	return distance / (world.ship_speed if by_sea else world.wagon_speed)


func to_dict() -> Dictionary:
	var list: Array = []
	for id: int in ids():
		list.append(provinces[id].to_dict())
	var d := {"world": String(world_id), "provinces": list}
	if not expeditions.is_empty():
		var e: Array = []
		var keys: Array[int] = []
		keys.assign(expeditions.keys())
		keys.sort()
		for id: int in keys:
			e.append(expeditions[id].to_dict())
		d["expeditions"] = e
	if not routes.is_empty():
		var r: Array = []
		var keys: Array[int] = []
		keys.assign(routes.keys())
		keys.sort()
		for id: int in keys:
			r.append(routes[id].to_dict())
		d["routes"] = r
	if not settlements.is_empty():
		var s: Array = []
		var keys: Array[int] = []
		keys.assign(settlements.keys())
		keys.sort()
		for id: int in keys:
			s.append(settlements[id].to_dict())
		d["settlements"] = s
	if not armies.is_empty():
		var a: Array = []
		var keys: Array[int] = []
		keys.assign(armies.keys())
		keys.sort()
		for id: int in keys:
			a.append(armies[id].to_dict())
		d["armies"] = a
	if camp != null:
		d["camp"] = camp.to_dict()
	if not reports.is_empty():
		d["reports"] = reports.duplicate(true)
	return d


static func from_dict(d: Dictionary) -> WorldSim:
	var world := WorldSim.new()
	world.world_id = StringName(String(d.get("world", "")))
	for pd: Variant in d.get("provinces", []):
		var province := WorldProvince.from_dict(pd)
		world.provinces[province.id] = province
	for ed: Variant in d.get("expeditions", []):
		var expedition := Expedition.from_dict(ed)
		world.expeditions[expedition.id] = expedition
	for rd: Variant in d.get("routes", []):
		var route := TradeRoute.from_dict(rd)
		world.routes[route.id] = route
	for sd: Variant in d.get("settlements", []):
		var settlement := NeutralSettlement.from_dict(sd)
		world.settlements[settlement.province] = settlement
	for ad: Variant in d.get("armies", []):
		var army := Army.from_dict(ad)
		world.armies[army.id] = army
	if d.has("camp"):
		world.camp = BanditCamp.from_dict(d["camp"])
	for rd: Variant in d.get("reports", []):
		world.reports.append(rd)
	return world


## Adds a battle report (keeps the last REPORTS_KEPT).
func report(entry: Dictionary) -> void:
	reports.append(entry)
	while reports.size() > REPORTS_KEPT:
		reports.remove_at(0)


## The provinces an army walks through from [param a] to [param b] by land (neighbours one
## after another, the shortest walk; [param b] last), [] when there is no way by land.
func land_route(a: int, b: int, data: DataRegistry) -> Array[int]:
	if a == b:
		return []
	var came: Dictionary[int, int] = {a: a}
	var cost: Dictionary[int, float] = {a: 0.0}
	var open: Array[int] = [a]
	while not open.is_empty():
		var best := 0
		for k: int in open.size():
			if cost[open[k]] < cost[open[best]]:
				best = k
		var here := open[best]
		open.remove_at(best)
		if here == b:
			break
		for other: int in ids():
			if other == here or not are_neighbours(here, other, data):
				continue
			var c := cost[here] + def_of(here, data).world_pos.distance_to(def_of(other, data).world_pos)
			if not cost.has(other) or c < cost[other]:
				cost[other] = c
				came[other] = here
				if not open.has(other):
					open.append(other)
	if not came.has(b):
		return []
	var route: Array[int] = []
	var at := b
	while at != a:
		route.push_front(at)
		at = came[at]
	return route


## Seconds an army takes from [param a] to the neighbour (or, by sea, any coast) [param b].
func army_seconds(a: int, b: int, by_sea: bool, data: DataRegistry) -> float:
	var world := data.get_world(world_id)
	if world == null:
		return -1.0
	if by_sea:
		return travel_seconds(a, b, true, data)
	if not are_neighbours(a, b, data):
		return -1.0
	return def_of(a, data).world_pos.distance_to(def_of(b, data).world_pos) / world.army_speed


## Armies standing or fighting in province [param id] (not those passing through).
func armies_at(id: int) -> Array[Army]:
	var result: Array[Army] = []
	var keys: Array[int] = []
	keys.assign(armies.keys())
	keys.sort()
	for key: int in keys:
		var army := armies[key]
		if army.at == id and army.state != Army.State.MOVING:
			result.append(army)
	return result


## The routes set out from or going to province [param id], by id.
func routes_of(id: int) -> Array[TradeRoute]:
	var result: Array[TradeRoute] = []
	var keys: Array[int] = []
	keys.assign(routes.keys())
	keys.sort()
	for key: int in keys:
		if routes[key].from == id or routes[key].to == id:
			result.append(routes[key])
	return result


## The expedition headed for province [param id] (on its way, waiting or landing), or null.
func expedition_to(id: int) -> Expedition:
	for expedition: Expedition in expeditions.values():
		if expedition.to == id and expedition.state != Expedition.State.RETURNING:
			return expedition
	return null
