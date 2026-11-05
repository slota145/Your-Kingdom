class_name BuildingState
extends RefCounted
## Runtime state of one placed building.

## Work priority set by the player (GDD §3.4): staffed first, and may take workers from
## buildings of a lower priority.
enum Priority { HIGH, NORMAL, LOW }

## Units of a workshop's input store per good.
const INPUT_UNITS := 2
## Units a market stall holds per good (M4b-2).
const STALL_UNITS := 6
## Highest reserve the player can set in a storage.
const MAX_RESERVE := 60
## A production yard holds this share of a storage slot (half a stack, M4b-2). A herd (a
## pigsty's animals) is a yard too.
const YARD_DIVISOR := 2

var id: int
var def: BuildingDef
## Footprint origin in grid space (the tile with the smallest x and y).
var origin: Vector2i
## Which way the building is turned (BuildingDef.entrance_at): 0 as drawn, 1 mirrored,
## 2 and 3 (houses only) with the door at the back.
var orientation: int = 0
## Look chosen by the player (M4b-1.5): 0 = picked by position, 1.. = that look. Only the
## view reads it.
var look: int = 0
## True from placement until the construction site is finished.
var under_construction: bool = false
## Construction or upgrade site entity id, 0 = none.
var site_id: int = 0
## Public storage, present on finished buildings with def.storage_slots > 0.
var stock: Stockpile
## Private pantry of a house (only its householders deliver here, nobody takes from it), or
## the input store of a workshop with def.input_goods (only its workers use it).
var supply: Stockpile
## Production yard (M4b-2): the stack beside a workshop where its workers put their output
## while no storage has room. Anybody may take from it; porters bring it to a storage once
## there is room. Addressed as storage id -id (ProvinceSim.yard_id).
var yard: Stockpile
## Storage: good -> units construction deliveries leave in place.
var reserves: Dictionary[StringName, int] = {}
var priority: Priority = Priority.NORMAL
## Production paused by the player: workers do not start a new cycle (M4b-1).
var paused: bool = false
## Service with def.service_needs_supply: tick until which it reaches houses (last serving).
var serving_until: int = 0
## Forester: tiles the player marked for planting (M4b-1.5); empty = anywhere in range.
var plant_area: Array[Vector2i] = []
## Herd (pigsty): ticks of breeding towards the next young animal.
var breed_ticks: int = 0
## Present on finished houses.
var house: HouseState
## Agent ids of assigned workers, in assignment order.
var workers: Array[int] = []


func _init(entity_id: int, building_def: BuildingDef, at: Vector2i, turned: int = 0) -> void:
	id = entity_id
	def = building_def
	origin = at
	orientation = turned


## Makes a finished building usable: storage, pantry, household.
func finish(data: DataRegistry) -> void:
	under_construction = false
	if def.storage_slots > 0 and stock == null:
		stock = Stockpile.new(def.storage_slots, data)
		reserves = def.default_reserves.duplicate()
	if not def.input_goods.is_empty() and supply == null:
		supply = Stockpile.new(def.input_goods.size(), data)
		supply.stack_limit = INPUT_UNITS
	ensure_stalls(data)
	ensure_yard(data)
	if def.is_house() and house == null:
		house = HouseState.new()
		var goods := house_goods()
		supply = Stockpile.new(maxi(goods.size(), 1), data)
		supply.stack_limit = level_def().supply_units


## Gives a finished market its stalls (also for saves from before M4b-2): a slot per stall
## good, STALL_UNITS each. Only its stallholders fill them, householders buy from them.
func ensure_stalls(data: DataRegistry) -> void:
	if def.stall_goods.is_empty() or supply != null or under_construction:
		return
	supply = Stockpile.new(def.stall_goods.size(), data)
	supply.stack_limit = STALL_UNITS
	supply.one_slot_per_good = true


## Gives a finished workshop its production yard (also for saves from before M4b-2).
func ensure_yard(data: DataRegistry) -> void:
	if yard != null or under_construction:
		return
	if def.herd_good != &"":
		# A herd is a yard of one slot holding up to herd_capacity animals.
		yard = Stockpile.new(1, data)
		yard.stack_limit = def.herd_capacity
		return
	var goods := yard_goods(def, data)
	if goods.is_empty():
		return
	yard = Stockpile.new(goods.size(), data)
	yard.stack_divisor = YARD_DIVISOR


## What the workers of a building of [param building_def] bring to storages (one yard slot
## each); empty for storages, houses and buildings whose cycle delivers nothing.
static func yard_goods(building_def: BuildingDef, data: DataRegistry) -> Array[StringName]:
	var goods: Array[StringName] = []
	if building_def.recipe == null or building_def.storage_slots > 0 or building_def.is_house():
		return goods
	var delivers := false
	for step: StepDef in building_def.recipe.steps:
		var good: StringName = &""
		if step is DeliverStepDef:
			delivers = true
		elif step is ProduceStepDef:
			good = (step as ProduceStepDef).output
		elif step is FieldStepDef:
			good = (step as FieldStepDef).harvest_good
		elif step is GoToStepDef and (step as GoToStepDef).target == &"resource":
			var node := data.get_resource_node((step as GoToStepDef).resource)
			good = node.good if node != null else &""
		if good != &"" and not goods.has(good):
			goods.append(good)
	if not delivers:
		goods.clear()
	return goods


func is_complete() -> bool:
	return not under_construction


## Whether this finished service building reaches houses right now (at [param tick]).
func provides_service(tick: int) -> bool:
	if def.service_radius <= 0 or under_construction:
		return false
	return not def.service_needs_supply or tick < serving_until


func entrance_tile() -> Vector2i:
	return origin + def.entrance_at(orientation)


## The tile in front of the door, the only way in and out (BuildingDef.door_front).
func door_front_tile() -> Vector2i:
	return def.door_front(origin, orientation)


## Entrance tiles of every door (the main one first).
func entrance_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for o: int in def.door_orientations(orientation):
		tiles.append(origin + def.entrance_at(o))
	return tiles


func is_entrance(tile: Vector2i) -> bool:
	return entrance_tiles().has(tile)


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
	var d := {"id": id, "def": String(def.id), "origin": SimCodec.vec2i(origin), "orient": orientation,
			"workers": workers}
	if under_construction:
		d["building"] = true
	if site_id != 0:
		d["site"] = site_id
	if stock != null:
		d["stock"] = stock.to_dict()
	if supply != null:
		d["supply"] = supply.to_dict()
	if yard != null and not yard.is_empty():
		# An empty yard is rebuilt from the data on load (saves stay as before M4b-2).
		d["yard"] = yard.to_dict()
	if house != null:
		d["house"] = house.to_dict()
	if not reserves.is_empty():
		var r := {}
		for good: StringName in reserves:
			r[String(good)] = reserves[good]
		d["reserves"] = r
	if priority != Priority.NORMAL:
		d["priority"] = priority
	if paused:
		d["paused"] = true
	if look != 0:
		d["look"] = look
	if not plant_area.is_empty():
		var area := []
		for t: Vector2i in plant_area:
			area.append(SimCodec.vec2i(t))
		d["plant_area"] = area
	if serving_until != 0:
		d["serving_until"] = serving_until
	if breed_ticks != 0:
		d["breed"] = breed_ticks
	return d


static func from_dict(d: Dictionary, data: DataRegistry) -> BuildingState:
	var b := BuildingState.new(int(d["id"]), data.get_building(StringName(String(d["def"]))),
			SimCodec.to_vec2i(d["origin"]), int(d.get("orient", 0)))
	b.workers = SimCodec.int_array(d.get("workers", []))
	b.under_construction = bool(d.get("building", false))
	b.site_id = int(d.get("site", 0))
	if d.has("stock"):
		b.stock = Stockpile.from_dict(d["stock"], data)
	if d.has("supply"):
		b.supply = Stockpile.from_dict(d["supply"], data)
	if d.has("yard"):
		b.yard = Stockpile.from_dict(d["yard"], data)
	else:
		b.ensure_yard(data)
	b.ensure_stalls(data)
	if d.has("house"):
		b.house = HouseState.from_dict(d["house"])
		# A pantry needs a slot per good any level uses; the data may have added goods.
		b.supply.grow_to(b.house_goods().size())
	var r: Dictionary = d.get("reserves", {})
	for good: Variant in r:
		b.reserves[StringName(String(good))] = int(r[good])
	b.paused = bool(d.get("paused", false))
	b.look = int(d.get("look", 0))
	for t: Variant in d.get("plant_area", []):
		b.plant_area.append(SimCodec.to_vec2i(t))
	b.serving_until = int(d.get("serving_until", 0))
	b.breed_ticks = int(d.get("breed", 0))
	b.priority = clampi(int(d.get("priority", Priority.NORMAL)), Priority.HIGH, Priority.LOW) as Priority
	return b
