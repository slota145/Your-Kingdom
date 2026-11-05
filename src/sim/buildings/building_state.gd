class_name BuildingState
extends RefCounted
## Runtime state of one placed building.

## Work priority set by the player (GDD §3.4): staffed first, and may take workers from
## buildings of a lower priority.
enum Priority { HIGH, NORMAL, LOW }

## Units of a workshop's input store per good.
const INPUT_UNITS := 2
## Highest reserve the player can set in a storage.
const MAX_RESERVE := 60

var id: int
var def: BuildingDef
## Footprint origin in grid space (the tile with the smallest x and y).
var origin: Vector2i
## True from placement until the construction site is finished.
var under_construction: bool = false
## Construction or upgrade site entity id, 0 = none.
var site_id: int = 0
## Public storage, present on finished buildings with def.storage_slots > 0.
var stock: Stockpile
## Private pantry of a house (only its householders deliver here, nobody takes from it), or
## the input store of a workshop with def.input_goods (only its workers use it).
var supply: Stockpile
## Storage: good -> units construction deliveries leave in place.
var reserves: Dictionary[StringName, int] = {}
var priority: Priority = Priority.NORMAL
## Present on finished houses.
var house: HouseState
## Agent ids of assigned workers, in assignment order.
var workers: Array[int] = []


func _init(entity_id: int, building_def: BuildingDef, at: Vector2i) -> void:
	id = entity_id
	def = building_def
	origin = at


## Makes a finished building usable: storage, pantry, household.
func finish(data: DataRegistry) -> void:
	under_construction = false
	if def.storage_slots > 0 and stock == null:
		stock = Stockpile.new(def.storage_slots, data)
		reserves = def.default_reserves.duplicate()
	if not def.input_goods.is_empty() and supply == null:
		supply = Stockpile.new(def.input_goods.size(), data)
		supply.stack_limit = INPUT_UNITS
	if def.is_house() and house == null:
		house = HouseState.new()
		var goods := house_goods()
		supply = Stockpile.new(maxi(goods.size(), 1), data)
		supply.stack_limit = level_def().supply_units


func is_complete() -> bool:
	return not under_construction


func entrance_tile() -> Vector2i:
	return origin + def.entrance


func tiles() -> Array[Vector2i]:
	return def.footprint_tiles(origin)


func level_def() -> HouseLevelDef:
	if not def.is_house():
		return null
	var level := house.level if house != null else 1
	return def.house_levels[clampi(level - 1, 0, def.house_levels.size() - 1)]


func capacity() -> int:
	var level := level_def()
	return level.capacity if level != null and house != null else 0


## Every good any level of this house needs, sorted (pantry slots).
func house_goods() -> Array[StringName]:
	var goods: Array[StringName] = []
	for level: HouseLevelDef in def.house_levels:
		for need: NeedDef in level.needs:
			for good: StringName in need.goods:
				if not goods.has(good):
					goods.append(good)
	goods.sort()
	return goods


func to_dict() -> Dictionary:
	var d := {"id": id, "def": String(def.id), "origin": SimCodec.vec2i(origin), "workers": workers}
	if under_construction:
		d["building"] = true
	if site_id != 0:
		d["site"] = site_id
	if stock != null:
		d["stock"] = stock.to_dict()
	if supply != null:
		d["supply"] = supply.to_dict()
	if house != null:
		d["house"] = house.to_dict()
	if not reserves.is_empty():
		var r := {}
		for good: StringName in reserves:
			r[String(good)] = reserves[good]
		d["reserves"] = r
	if priority != Priority.NORMAL:
		d["priority"] = priority
	return d


static func from_dict(d: Dictionary, data: DataRegistry) -> BuildingState:
	var b := BuildingState.new(int(d["id"]), data.get_building(StringName(String(d["def"]))),
			SimCodec.to_vec2i(d["origin"]))
	b.workers = SimCodec.int_array(d.get("workers", []))
	b.under_construction = bool(d.get("building", false))
	b.site_id = int(d.get("site", 0))
	if d.has("stock"):
		b.stock = Stockpile.from_dict(d["stock"], data)
	if d.has("supply"):
		b.supply = Stockpile.from_dict(d["supply"], data)
	if d.has("house"):
		b.house = HouseState.from_dict(d["house"])
		# A pantry needs a slot per good any level uses; the data may have added goods.
		b.supply.grow_to(b.house_goods().size())
	var r: Dictionary = d.get("reserves", {})
	for good: Variant in r:
		b.reserves[StringName(String(good))] = int(r[good])
	b.priority = clampi(int(d.get("priority", Priority.NORMAL)), Priority.HIGH, Priority.LOW) as Priority
	return b
