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
	return {"world": String(world_id), "provinces": list}


static func from_dict(d: Dictionary) -> WorldSim:
	var world := WorldSim.new()
	world.world_id = StringName(String(d.get("world", "")))
	for pd: Variant in d.get("provinces", []):
		var province := WorldProvince.from_dict(pd)
		world.provinces[province.id] = province
	return world
