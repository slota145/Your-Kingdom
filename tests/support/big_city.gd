class_name BigCity
extends RefCounted
## Builds the large test city of M4b-3 on the Lakeland map (ROADMAP M4b-3, part 3): every
## production chain, storages with handcarts, stables with wagons, a street grid with paved
## main streets, markets, taverns and churches, and enough burgher and patrician houses for
## 400+ characters. Buildings are placed finished (like the map start); the city then runs a
## few minutes so the workers are hired and the chains get going. tools/build_big_city.gd
## saves the result as tests/fixtures/saves/big_city.json.
##
## Spots are searched near anchor tiles, preferring a street in front of the door (wagons
## only drive on roads). A building that works on rocks, trees or water moves its anchor to the
## nearest of them. Doors left without a street get a short dirt road to the nearest one.

const FIXTURE_PATH := "res://tests/fixtures/saves/big_city.json"
## Minutes the finished city runs before it is saved (workers walk to work, chains start).
const WARM_UP_MINUTES := 5
const START_GOLD := 3000

## Street grid: [from, to] (inclusive, straight lines). Tiles that cannot take a road are skipped.
const STREETS: Array = [
	# Town centre and the eastern housing quarters.
	[Vector2i(47, 66), Vector2i(122, 66)],
	[Vector2i(47, 72), Vector2i(122, 72)],
	[Vector2i(47, 78), Vector2i(120, 78)],
	[Vector2i(47, 84), Vector2i(80, 84)],
	[Vector2i(89, 84), Vector2i(120, 84)],
	[Vector2i(52, 56), Vector2i(52, 90)],
	[Vector2i(66, 56), Vector2i(66, 116)],
	[Vector2i(80, 56), Vector2i(80, 79)],
	[Vector2i(94, 56), Vector2i(94, 90)],
	[Vector2i(108, 56), Vector2i(108, 100)],
	[Vector2i(66, 60), Vector2i(122, 60)],
	# North: the road to the farms and the lake shore.
	[Vector2i(47, 56), Vector2i(110, 56)],
	[Vector2i(47, 36), Vector2i(47, 56)],
	[Vector2i(4, 36), Vector2i(66, 36)],
	[Vector2i(20, 20), Vector2i(20, 36)],
	[Vector2i(8, 20), Vector2i(34, 20)],
	# West: the pastures.
	[Vector2i(22, 36), Vector2i(22, 80)],
	[Vector2i(15, 80), Vector2i(52, 80)],
	# South: workshops and the stony hill.
	[Vector2i(47, 96), Vector2i(104, 96)],
	[Vector2i(40, 90), Vector2i(66, 90)],
	[Vector2i(40, 84), Vector2i(47, 84)],
	[Vector2i(40, 84), Vector2i(40, 116)],
	[Vector2i(40, 116), Vector2i(100, 116)],
	[Vector2i(52, 104), Vector2i(104, 104)],
]
## Main streets laid as cobbles at once (the rest is dirt road).
const PAVED: Array = [
	[Vector2i(47, 72), Vector2i(122, 72)],
	[Vector2i(66, 56), Vector2i(66, 96)],
	[Vector2i(94, 60), Vector2i(94, 84)],
]
## A street the builder is still paving when the city is saved (stone comes from storage).
const PAVING_ORDER: Array = [Vector2i(47, 78), Vector2i(65, 78)]

## District anchor -> buildings placed around it, in order: [building, count, fields, house
## level]. Food and drink are made next to the storages by the fields (workshops fetch their
## inputs themselves, so short walks keep them busy); houses get them from markets and storages.
const DISTRICTS: Array = [
	# Housing east of the town hall: patricians in the middle, burghers and peasants around.
	{"near": Vector2i(86, 69), "build": [[&"stockpile", 1], [&"market", 1], [&"church", 1],
			[&"tavern", 1], [&"well", 3], [&"hut", 10, 0, 3]]},
	{"near": Vector2i(101, 69), "build": [[&"stockpile", 1], [&"market", 1], [&"tavern", 1], [&"well", 3],
			[&"hut", 10, 0, 3]]},
	{"near": Vector2i(86, 81), "build": [[&"stockpile", 1], [&"market", 1], [&"tavern", 1], [&"well", 2],
			[&"hut", 10, 0, 2]]},
	{"near": Vector2i(114, 69), "build": [[&"stockpile", 1], [&"church", 1], [&"tavern", 1], [&"well", 3],
			[&"hut", 10, 0, 2]]},
	{"near": Vector2i(102, 82), "build": [[&"stockpile", 1], [&"market", 1], [&"tavern", 1], [&"church", 1],
			[&"chapel", 1], [&"well", 4], [&"hut", 14, 0, 1]]},
	{"near": Vector2i(73, 62), "build": [[&"stockpile", 1], [&"stable", 1], [&"well", 2],
			[&"hut", 10, 0, 2]]},
	{"near": Vector2i(112, 92), "build": [[&"stockpile", 1], [&"chapel", 1], [&"well", 3],
			[&"hut", 14, 0, 1]]},
	{"near": Vector2i(58, 80), "build": [[&"stockpile", 1], [&"market", 1], [&"chapel", 1],
			[&"well", 2], [&"hut", 14, 0, 1]]},
	{"near": Vector2i(74, 90), "build": [[&"stockpile", 1], [&"market", 1], [&"tavern", 1], [&"chapel", 1], [&"well", 2],
			[&"hut", 14, 0, 1]]},
	# Fields with mills, bakeries and breweries by their storage.
	{"near": Vector2i(26, 46), "build": [[&"stockpile", 1], [&"stable", 1], [&"mill", 5],
			[&"bakery", 6], [&"brewery", 9], [&"farm", 9, 16], [&"hop_farm", 4, 12]]},
	{"near": Vector2i(20, 22), "build": [[&"stockpile", 1], [&"mill", 4], [&"bakery", 5],
			[&"brewery", 6], [&"farm", 7, 16], [&"hop_farm", 4, 12]]},
	{"near": Vector2i(60, 108), "build": [[&"stockpile", 1], [&"stable", 1], [&"mill", 5],
			[&"bakery", 6], [&"brewery", 9], [&"farm", 8, 16], [&"hop_farm", 4, 12]]},
	{"near": Vector2i(62, 44), "build": [[&"stockpile", 1], [&"mill", 2], [&"bakery", 5],
			[&"brewery", 3], [&"farm", 4, 16], [&"hop_farm", 3, 12]]},
	# Lake and river: anglers, clay pits and brickworks.
	{"near": Vector2i(90, 54), "build": [[&"stockpile", 1], [&"brickworks", 3],
			[&"fishing_hut", 10], [&"clay_pit", 3]]},
	{"near": Vector2i(72, 44), "build": [[&"stockpile", 1], [&"fishing_hut", 5], [&"clay_pit", 1]]},
	{"near": Vector2i(48, 24), "build": [[&"fishing_hut", 7]]},
	# Pastures, bees, cloth, mead and meat west of the town.
	{"near": Vector2i(20, 66), "build": [[&"stockpile", 1], [&"weaver", 7], [&"tailor", 9],
			[&"meadery", 14], [&"slaughterhouse", 2], [&"sheep_farm", 8], [&"apiary", 14],
			[&"pigsty", 2]]},
	# Forests: woodcutters with foresters, sawmills by the storage.
	{"near": Vector2i(49, 64), "build": [[&"stockpile", 1], [&"sawmill", 4], [&"woodcutter", 8],
			[&"forester", 4]]},
	{"near": Vector2i(17, 95), "build": [[&"stockpile", 1], [&"woodcutter", 5], [&"forester", 3]]},
	{"near": Vector2i(118, 52), "build": [[&"stockpile", 1], [&"woodcutter", 5], [&"forester", 2]]},
	{"near": Vector2i(8, 76), "build": [[&"stockpile", 1], [&"woodcutter", 2], [&"forester", 1]]},
	# Stony hill: quarries.
	{"near": Vector2i(30, 97), "build": [[&"stockpile", 1], [&"quarry", 5]]},
	{"near": Vector2i(60, 93), "build": [[&"stockpile", 1], [&"quarry", 1]]},
]
## Pigs put into every pigsty (bought from the merchant earlier), so the herds breed.
const PIGS_PER_STY := 6

## Goods every storage starts with (the city has been running for a while).
const STOCK := {&"bread": 20, &"fish": 16, &"beer": 16, &"wood": 14, &"clothes": 8, &"mead": 10,
		&"planks": 12, &"stone": 12, &"flour": 6, &"grain": 8, &"bricks": 6}
## What the merchant may buy: everything above these amounts.
const SELL_ABOVE := {&"fish": 200, &"wood": 200, &"hops": 150, &"grain": 200, &"planks": 120, &"stone": 120, &"hides": 0, &"bricks": 120, &"clay": 80,
		&"wool": 60, &"honey": 60}

var sim: Simulation
var log: PackedStringArray = PackedStringArray()


func _init(simulation: Simulation) -> void:
	sim = simulation


## A new Lakeland game turned into the big city, warmed up and ready to save.
static func build_new(registry: DataRegistry) -> Simulation:
	var problems := PackedStringArray()
	var sim := Simulation.from_map(registry, registry.get_map(&"lakeland"), 1, problems)
	assert(problems.is_empty(), "lakeland: %s" % [problems])
	var city := BigCity.new(sim)
	city.build()
	for problem: String in city.log:
		push_warning("big city: " + problem)
	city.warm_up(WARM_UP_MINUTES)
	return sim


## The saved city (the fixture), migrated to the current save version.
static func load_fixture(registry: DataRegistry) -> Simulation:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	var state := SaveMigrations.migrate(document["state"], int(document["header"]["save_version"]))
	return Simulation.from_dict(state, registry)


## Characters by kind, buildings by type, houses by level and residents (for logs).
static func summary(sim: Simulation) -> String:
	var kinds: Dictionary[StringName, int] = {}
	for agent: Agent in sim.province.agents.all():
		kinds[agent.kind] = kinds.get(agent.kind, 0) + 1
	var defs: Dictionary[StringName, int] = {}
	var levels: Dictionary[int, int] = {}
	var residents := 0
	var unstaffed := 0
	for b: BuildingState in sim.province.buildings.all():
		defs[b.def.id] = defs.get(b.def.id, 0) + 1
		if b.house != null:
			levels[b.house.level] = levels.get(b.house.level, 0) + 1
			residents += b.house.residents
		elif b.workers.size() < b.def.worker_count():
			unstaffed += b.def.worker_count() - b.workers.size()
	return "characters %d %s\nbuildings %d %s\nhouses by level %s, residents %d, workforce %d, missing workers %d\nroads %d (paved %d), gold %d" % [
			sim.province.agents.all().size(), kinds, sim.province.buildings.all().size(), defs, levels,
			residents, Population.workforce(sim.province), unstaffed, sim.province.grid.road_count(),
			sim.province.grid.paved_count(), sim.treasury.gold]


func build() -> void:
	sim.treasury.gold = START_GOLD
	for street: Array in STREETS:
		sim.execute(BuildRoadCommand.new(_line(street[0], street[1])))
	for street: Array in PAVED:
		for tile: Vector2i in _line(street[0], street[1]):
			if sim.province.grid.has_road(tile):
				sim.province.grid.set_paved(tile, true)
				sim.province.refresh_tile(tile)
	for district: Dictionary in DISTRICTS:
		for item: Array in district["build"]:
			for i: int in int(item[1]):
				_place(item, district["near"])
	_connect_doors()
	_stock_storages()
	for building: BuildingState in sim.province.buildings.all():
		while building.def.max_carts > building.carts \
				and sim.execute(BuyCartCommand.new(building.id)) == &"":
			pass
	for good: StringName in SELL_ABOVE:
		sim.execute(SetSellAboveCommand.new(good, int(SELL_ABOVE[good])))
	var error := sim.execute(BuildPavingCommand.new(_line(PAVING_ORDER[0], PAVING_ORDER[1])))
	if error != &"":
		log.append("paving: %s" % error)
	sim.events.drain()


func warm_up(minutes: int) -> void:
	for i: int in minutes * 60 * SimClock.TICKS_PER_SECOND:
		sim.step()
		sim.events.drain()


func _place(item: Array, near: Vector2i) -> void:
	var def := sim.data.get_building(item[0])
	var spot := _find_spot(def, _near_its_work(def, near))
	if spot.is_empty():
		log.append("no spot for %s near %s" % [def.id, near])
		return
	var error := sim.execute(PlaceBuildingCommand.new(def.id, spot["origin"], true, spot["orientation"]))
	if error != &"":
		log.append("%s at %s: %s" % [def.id, spot["origin"], error])
		return
	var building := sim.province.buildings.get_building(sim.province.grid.occupant(spot["origin"]))
	if building.house != null:
		_settle(building, int(item[3]))
	if building.def.herd_good != &"":
		building.yard.add(building.def.herd_good, PIGS_PER_STY)
	var fields := int(item[2]) if item.size() > 2 else 0
	for r: int in range(1, def.work_radius + 1):
		for y: int in range(building.origin.y - r, building.origin.y + def.footprint.y + r):
			for x: int in range(building.origin.x - r, building.origin.x + def.footprint.x + r):
				if fields > 0 and sim.execute(PlaceFieldCommand.new(building.id, Vector2i(x, y))) == &"":
					fields -= 1


## A full house of [param level] with a full pantry.
func _settle(building: BuildingState, level: int) -> void:
	building.house.level = level
	building.supply.stack_limit = building.level_def().supply_units
	building.house.residents = building.capacity()
	building.house.happiness = 80.0
	for need: NeedDef in building.level_def().needs:
		for good: StringName in need.goods:
			building.supply.add(good, building.level_def().supply_units)


func _stock_storages() -> void:
	for building: BuildingState in sim.province.buildings.all():
		if building.def.id != &"stockpile":
			continue
		for good: StringName in STOCK:
			building.stock.add(good, int(STOCK[good]))


## The free spot nearest to [param near] that keeps a free tile around the building; a spot
## with a street in front of the door wins over a nearer one without (up to 6 tiles further).
## Returns {"origin", "orientation"} or {}.
func _find_spot(def: BuildingDef, near: Vector2i) -> Dictionary:
	var fallback := {}
	var fallback_ring := -1
	for r: int in 30:
		if fallback_ring >= 0 and r > fallback_ring + 6:
			return fallback
		for y: int in range(near.y - r, near.y + r + 1):
			for x: int in range(near.x - r, near.x + r + 1):
				if maxi(absi(x - near.x), absi(y - near.y)) != r:
					continue
				var origin := Vector2i(x, y)
				if not _free_with_margin(def, origin):
					continue
				for o: int in def.orientation_count():
					var front := def.door_front(origin, o)
					var on_street := sim.province.grid.has_road(front)
					if not on_street and fallback_ring >= 0:
						continue
					if not sim.province.grid.is_inside(front) or not sim.province.nav.is_walkable(front):
						continue
					if sim.province.placement_error(def, origin, o) != &"":
						continue
					if on_street:
						return {"origin": origin, "orientation": o}
					fallback = {"origin": origin, "orientation": o}
					fallback_ring = r
	return fallback


func _free_with_margin(def: BuildingDef, origin: Vector2i) -> bool:
	var province := sim.province
	for y: int in range(origin.y - 1, origin.y + def.footprint.y + 1):
		for x: int in range(origin.x - 1, origin.x + def.footprint.x + 1):
			var t := Vector2i(x, y)
			if not province.grid.is_inside(t) or province.grid.occupant(t) != 0 \
					or not province.nav.is_walkable(t) or province.fields.has_field(t):
				return false
			var inside := x >= origin.x and y >= origin.y \
					and x < origin.x + def.footprint.x and y < origin.y + def.footprint.y
			if inside and province.grid.has_road(t):
				return false
	return true


## [param near], or the nearest tile with what [param def] works on when there is none in its
## reach (the same rule as SliceBot).
func _near_its_work(def: BuildingDef, near: Vector2i) -> Vector2i:
	var node := &""
	if def.recipe != null:
		for step: StepDef in def.recipe.steps:
			if step is GoToStepDef and (step as GoToStepDef).target == &"resource":
				node = (step as GoToStepDef).resource
	if node == &"" and def.needs_terrain_near == &"":
		return near
	var reach := maxi(def.work_radius, 3)
	var best := near
	var best_d := 1 << 30
	var size := sim.province.grid.size
	for y: int in size.y:
		for x: int in size.x:
			var t := Vector2i(x, y)
			var hit := false
			if node != &"":
				hit = sim.province.resources.has_node(t, node) and not sim.province.resources.is_depleted(t)
			else:
				var terrain := sim.province.terrain_at(t)
				hit = terrain != null and terrain.is_kind(def.needs_terrain_near)
			if not hit:
				continue
			var d := (t - near).length_squared()
			if d <= reach * reach:
				return near
			if d < best_d:
				best_d = d
				best = t
	return best


## Lays a short dirt road from every door without one to the nearest street (12 tiles at most).
func _connect_doors() -> void:
	for building: BuildingState in sim.province.buildings.all():
		if building.house != null or building.def.id == &"well":
			continue
		var front := building.def.door_front(building.origin, building.orientation)
		if not sim.province.grid.is_inside(front) or sim.province.grid.has_road(front):
			continue
		var path := _path_to_road(front, 12)
		if not path.is_empty():
			sim.execute(BuildRoadCommand.new(path))


## Free tiles from [param from] to the nearest road (breadth first), without the road tile.
func _path_to_road(from: Vector2i, limit: int) -> Array[Vector2i]:
	var came: Dictionary[Vector2i, Vector2i] = {from: from}
	var queue: Array[Vector2i] = [from]
	var depth: Dictionary[Vector2i, int] = {from: 0}
	while not queue.is_empty():
		var t: Vector2i = queue.pop_front()
		if sim.province.grid.has_road(t):
			var path: Array[Vector2i] = []
			var c: Vector2i = came[t]
			while c != from:
				path.append(c)
				c = came[c]
			path.append(from)
			return path
		if depth[t] >= limit:
			continue
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n := t + d
			if came.has(n) or not sim.province.grid.is_inside(n):
				continue
			if not sim.province.grid.has_road(n) and sim.province.road_error(n) != &"":
				continue
			came[n] = t
			depth[n] = depth[t] + 1
			queue.append(n)
	return []


static func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y: int in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x: int in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			tiles.append(Vector2i(x, y))
	return tiles
