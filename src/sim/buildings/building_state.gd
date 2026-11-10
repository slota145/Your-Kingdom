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
## Herd size at which the work of a herd_work building takes as long as before Z1 part 2.
const HERD_WORK_BASE := 8.0
## Hives at which an apiary's work takes as long as before Z1 part 3.
const HIVE_WORK_BASE := 4.0

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
## Public storage, present on finished buildings with def.storage_slots > 0. On a port
## (def.quay_slots > 0) the quay yard: private, only requests naming the port use it (M5).
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
## Herd: animals nobody takes, kept for breeding (Z1: the player's slider, from 2 up to the
## herd's room; starts at def.herd_keep).
var herd_keep: int = 2
## Herd with pens (Z1): the starting pair has come (with the first pen tile).
var herd_given: bool = false
## Herd with pens (Z1): pen tiles the building owns. Not saved: counted from the field tiles
## (ProvinceSim.update_herd_room).
var pens: int = 0
## Apiary (Z1 part 3): hive tiles it owns. Not saved, counted like [member pens].
var hives: int = 0
## Pen tiles the game still places for this building (a sheep farm from a save before v33,
## ProvinceSim._place_due_pens); 0 = none.
var pens_due: int = 0
## Storage: handcarts bought for its porters (M4b-3, at most def.max_carts).
var carts: int = 0
## Trading post: merchant wagons lent to trade routes (M6 part 3).
var lent: int = 0
## Shipyard: ship kinds ordered by the player, the first one on the slipway (M5).
var ship_orders: Array[StringName] = []
## Workshop with def.recipe_choices (a blacksmith, M7): -1 = take turns, else the index of
## the chosen recipe. [member next_choice] is the recipe of the next cycle when taking turns.
var recipe_mode: int = -1
var next_choice: int = 0
## Barracks (M7): ids of the soldiers living here, and recruits on their way here.
var soldiers: Array[int] = []
var recruits: Array[int] = []
## Barracks in the simplified mode (M7): kinds of its soldiers while nobody walks the map
## (ProvinceAbstract); they come back as people when the province is seen again.
var garrison: Array[StringName] = []
## Barracks: food eaten but not yet taken from the pantry (fractional consumption).
var mess_hunger: float = 0.0
## Siege workshop (M7 part 2): engines ordered (unit ids, the first one in the works) and
## ticks of work done on it.
var siege_orders: Array[StringName] = []
var siege_work: int = 0
## Life in a fight (def.max_hp > 0, M7 part 2): a gatehouse, a tower, a town hall's door.
## Set on placement; 0 = broken (a gatehouse then stands open to everybody).
var hp: int = 0
## Present on finished houses.
var house: HouseState
## Agent ids of assigned workers, in assignment order.
var workers: Array[int] = []


func _init(entity_id: int, building_def: BuildingDef, at: Vector2i, turned: int = 0) -> void:
	id = entity_id
	def = building_def
	origin = at
	orientation = turned
	hp = def.max_hp if def != null else 0
	herd_keep = def.herd_keep if def != null else 2


## Makes a finished building usable: storage, pantry, household.
func finish(data: DataRegistry) -> void:
	under_construction = false
	if def.storage_slots > 0 and stock == null:
		stock = Stockpile.new(def.storage_slots, data)
		reserves = def.default_reserves.duplicate()
	apply_storage_filter(data)
	if def.quay_slots > 0 and stock == null:
		stock = Stockpile.new(def.quay_slots, data)
	if not def.input_goods.is_empty() and supply == null:
		supply = Stockpile.new(def.input_goods.size(), data)
		supply.stack_limit = INPUT_UNITS
	ensure_stalls(data)
	ensure_yard(data)
	if not def.siege_engines.is_empty() and supply == null:
		supply = Stockpile.new(SiegeWorks.MATERIALS.size(), data)
		supply.stack_limit = SiegeWorks.STORE_UNITS
		supply.one_slot_per_good = true
	if def.soldier_beds > 0 and supply == null:
		supply = Stockpile.new(Barracks.FOOD.size(), data)
		supply.stack_limit = Barracks.PANTRY_UNITS
		supply.one_slot_per_good = true
	if def.is_house() and house == null:
		house = HouseState.new()
		var goods := house_goods()
		supply = Stockpile.new(maxi(goods.size(), 1), data)
		supply.stack_limit = level_def().supply_units


## The recipe of the next work cycle (M7): the chosen one of def.recipe_choices, or each in
## turn; def.recipe for a workshop without choices.
func take_recipe() -> RecipeDef:
	var choices := def.recipe_choices
	if choices.is_empty():
		return def.recipe
	if recipe_mode >= 0 and recipe_mode < choices.size():
		return choices[recipe_mode]
	var recipe := choices[next_choice % choices.size()]
	next_choice = (next_choice + 1) % choices.size()
	return recipe


## Which goods the storage takes (M7): an armoury only weapons, other storages no weapons.
func apply_storage_filter(data: DataRegistry) -> void:
	if stock == null or def.storage_slots <= 0:
		return
	stock.only = def.storage_accepts.duplicate()
	stock.never.clear()
	if def.storage_accepts.is_empty():
		stock.never = data.special_storage_categories()


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
		yard.stack_limit = maxi(herd_room(), 1)
		# A stud farm starts with a pair of horses (M7). A herd in pens gets its pair with
		# the first pen tile (Z1, ProvinceSim.add_field).
		if def.herd_start > 0 and not def.has_pens():
			yard.add(def.herd_good, def.herd_start)
		give_pair()
		return
	var goods := yard_goods(def, data)
	if goods.is_empty():
		return
	yard = Stockpile.new(goods.size(), data)
	yard.stack_divisor = YARD_DIVISOR


## A herd in pens gets its starting pair once (Z1, owner's survey 2026-11-10): when the first
## pen has room for it next to a finished building. Returns the animals given.
func give_pair() -> int:
	# Once the pen has room for the pair (a stud farm: its second tile, one horse a tile).
	if not def.has_pens() or herd_given or yard == null or pens == 0 or herd_room() < def.herd_start:
		return 0
	herd_given = true
	var pair := def.herd_start
	if pair > 0:
		yard.add(def.herd_good, pair)
	return pair


## Animals the herd has room for: 2 per pen tile (Z1), else the building's own capacity.
func herd_room() -> int:
	if def.has_pens():
		return pens * def.pen_animals
	return def.herd_capacity


## Work time of a cycle of a building with def.paced_work() against the time before Z1: with a
## herd (part 2) 1 with HERD_WORK_BASE animals, slower with fewer (×2 with 2), faster with more
## (×0.58 with 24); with hives (part 3) 1 with HIVE_WORK_BASE hives (×1.41 with 2, ×0.71 with 8).
func work_factor() -> float:
	if def.has_hives():
		return sqrt(HIVE_WORK_BASE / float(maxi(hives, 1)))
	var herd := yard.total(def.herd_good) if yard != null and def.herd_good != &"" else 0
	return sqrt(HERD_WORK_BASE / float(maxi(herd, 1)))


## Whether a paced building has what its work needs: animals in the herd, hives.
func has_work_source() -> bool:
	if def.has_hives():
		return hives > 0
	return yard != null and yard.total(def.herd_good) > 0


## Animals of the herd's good others may take: all above the breeding reserve.
func herd_spare() -> int:
	if yard == null or def.herd_good == &"":
		return 0
	return maxi(yard.available(def.herd_good) - herd_keep, 0)


## What the workers of a building of [param building_def] bring to storages (one yard slot
## each); empty for storages, houses and buildings whose cycle delivers nothing.
static func yard_goods(building_def: BuildingDef, data: DataRegistry) -> Array[StringName]:
	var goods: Array[StringName] = []
	if building_def.recipe == null or building_def.storage_slots > 0 or building_def.is_house():
		return goods
	var delivers := false
	var steps: Array[StepDef] = []
	for recipe: RecipeDef in building_def.all_recipes():
		steps.append_array(recipe.steps)
	for step: StepDef in steps:
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
		elif step is SailStepDef and (step as SailStepDef).target == &"shoal":
			var shoal := data.get_resource_node((step as SailStepDef).resource)
			good = shoal.good if shoal != null else &""
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


## Water tile where this building's ships moor or are launched (M5), Agent.NO_TILE if none.
func berth_tile() -> Vector2i:
	return def.berth_at(origin, orientation) if def.has_berth() else Agent.NO_TILE


## Port: the quay tile at the foot of the gangway (M5 part 2), Agent.NO_TILE if none.
func gangway_tile() -> Vector2i:
	return def.gangway_at(origin, orientation) if def.is_port() else Agent.NO_TILE


## Gatehouse passage tiles in grid space (empty for other buildings).
func passage_tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for t: Vector2i in def.passage_at(orientation):
		result.append(origin + t)
	return result


func is_broken() -> bool:
	return def.max_hp > 0 and hp <= 0


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
	if herd_keep != def.herd_keep:
		d["herd_keep"] = herd_keep
	if herd_given:
		d["herd_given"] = true
	if pens_due != 0:
		d["pens_due"] = pens_due
	if carts != 0:
		d["carts"] = carts
	if lent != 0:
		d["lent"] = lent
	if recipe_mode != -1:
		d["recipe_mode"] = recipe_mode
	if next_choice != 0:
		d["next_choice"] = next_choice
	if not soldiers.is_empty():
		d["soldiers"] = soldiers.duplicate()
	if not recruits.is_empty():
		d["recruits"] = recruits.duplicate()
	if mess_hunger != 0.0:
		d["mess_hunger"] = mess_hunger
	if not garrison.is_empty():
		var g := []
		for unit: StringName in garrison:
			g.append(String(unit))
		d["garrison"] = g
	if not siege_orders.is_empty():
		var orders := []
		for unit: StringName in siege_orders:
			orders.append(String(unit))
		d["siege_orders"] = orders
	if siege_work != 0:
		d["siege_work"] = siege_work
	if def.max_hp > 0 and hp != def.max_hp:
		d["hp"] = hp
	if not ship_orders.is_empty():
		var orders := []
		for ship: StringName in ship_orders:
			orders.append(String(ship))
		d["ship_orders"] = orders
	return d


static func from_dict(d: Dictionary, data: DataRegistry) -> BuildingState:
	var b := BuildingState.new(int(d["id"]), data.get_building(StringName(String(d["def"]))),
			SimCodec.to_vec2i(d["origin"]), int(d.get("orient", 0)))
	b.workers = SimCodec.int_array(d.get("workers", []))
	b.under_construction = bool(d.get("building", false))
	b.site_id = int(d.get("site", 0))
	if d.has("stock"):
		b.stock = Stockpile.from_dict(d["stock"], data)
		b.apply_storage_filter(data)
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
	b.herd_keep = int(d.get("herd_keep", b.def.herd_keep))
	b.herd_given = bool(d.get("herd_given", false))
	b.pens_due = int(d.get("pens_due", 0))
	b.carts = int(d.get("carts", 0))
	b.lent = int(d.get("lent", 0))
	b.recipe_mode = int(d.get("recipe_mode", -1))
	b.next_choice = int(d.get("next_choice", 0))
	b.soldiers = SimCodec.int_array(d.get("soldiers", []))
	b.recruits = SimCodec.int_array(d.get("recruits", []))
	b.mess_hunger = float(d.get("mess_hunger", 0.0))
	for unit: Variant in d.get("garrison", []):
		b.garrison.append(StringName(String(unit)))
	for ship: Variant in d.get("ship_orders", []):
		b.ship_orders.append(StringName(String(ship)))
	b.hp = int(d.get("hp", b.def.max_hp))
	for unit: Variant in d.get("siege_orders", []):
		b.siege_orders.append(StringName(String(unit)))
	b.siege_work = int(d.get("siege_work", 0))
	b.priority = clampi(int(d.get("priority", Priority.NORMAL)), Priority.HIGH, Priority.LOW) as Priority
	return b
