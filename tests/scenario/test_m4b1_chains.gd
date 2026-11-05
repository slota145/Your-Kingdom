extends GdUnitTestSuite
## M4b-1 DoD: every new chain runs on its own and every unit comes from its visible steps
## (event counters): wool, cloth, clothes, honey, mead, clay and bricks. Also the forester,
## pausing production and the tavern that works only while it serves drinks.


## Runs [param seconds] and counts produced/gathered/harvested goods by id.
func _run_counting(sim: Simulation, seconds: float) -> Dictionary:
	var counts := {}
	for i: int in SimFixture.ticks(seconds):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] in [&"good_produced", &"good_gathered", &"good_harvested"]:
				var key := "%s:%s" % [e["type"], e["good"]]
				counts[key] = int(counts.get(key, 0)) + int(e["amount"])
			elif e["type"] in [&"resource_planted", &"resource_grown", &"goods_served"]:
				counts[String(e["type"])] = int(counts.get(String(e["type"]), 0)) + 1
	return counts


func _set_water(sim: Simulation, rect: Rect2i) -> void:
	var water := SimFixture.registry().get_terrain(&"water")
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			sim.province.grid.set_terrain(Vector2i(x, y), water.index)
			sim.province.refresh_tile(Vector2i(x, y))


func _village_with(sim: Simulation, goods: Dictionary) -> BuildingState:
	var village := SimFixture.village(sim, 30, 20)
	# A well keeps the village happy, so it keeps its workers.
	SimFixture.place(sim, &"well", Vector2i(9, 9))
	var stock: BuildingState = village["stock"]
	for good: StringName in goods:
		stock.stock.add(good, int(goods[good]))
	return stock


# --- Textiles ------------------------------------------------------------------------------

func test_sheep_farm_shears_wool() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var stock := _village_with(sim, {})
	SimFixture.place(sim, &"sheep_farm", Vector2i(14, 4))
	var counts := _run_counting(sim, 180)
	var wool := int(counts.get("good_produced:wool", 0))
	print("sheep farm in 3 min: ", counts)
	assert_int(wool).is_greater_equal(6)
	assert_int(sim.province.goods_total(&"wool")).is_equal(wool)
	assert_int(stock.stock.total(&"wool")).is_greater(0)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_weaver_turns_two_wool_into_cloth() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village_with(sim, {&"wool": 20})
	SimFixture.place(sim, &"weaver", Vector2i(14, 4))
	var counts := _run_counting(sim, 180)
	var cloth := int(counts.get("good_produced:cloth", 0))
	print("weaver in 3 min: ", counts)
	assert_int(cloth).is_greater_equal(4)
	assert_int(sim.province.goods_total(&"cloth")).is_equal(cloth)
	assert_int(sim.province.goods_total(&"wool")).is_equal(20 - 2 * cloth)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_tailor_sews_clothes_from_cloth() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village_with(sim, {&"cloth": 10})
	SimFixture.place(sim, &"tailor", Vector2i(14, 4))
	var before := sim.province.goods_total(&"clothes")
	var counts := _run_counting(sim, 180)
	var clothes := int(counts.get("good_produced:clothes", 0))
	print("tailor in 3 min: ", counts)
	assert_int(clothes).is_greater_equal(8)
	assert_int(clothes % 2).is_equal(0)
	assert_int(sim.province.goods_total(&"cloth")).is_equal(10 - clothes / 2)
	# The village pantries hold some clothes from the start; nobody there wears them.
	assert_int(sim.province.goods_total(&"clothes")).is_equal(before + clothes)


# --- Honey and mead ------------------------------------------------------------------------

func test_apiary_collects_honey() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village_with(sim, {})
	SimFixture.place(sim, &"apiary", Vector2i(14, 4))
	var before := sim.province.goods_total(&"honey")
	var counts := _run_counting(sim, 180)
	var honey := int(counts.get("good_produced:honey", 0))
	print("apiary in 3 min: ", counts)
	assert_int(honey).is_greater_equal(4)
	assert_int(sim.province.goods_total(&"honey")).is_equal(before + honey)


func test_meadery_makes_two_mead_from_honey() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village_with(sim, {&"honey": 10})
	var before_honey := sim.province.goods_total(&"honey") - 10
	SimFixture.place(sim, &"meadery", Vector2i(14, 4))
	var before := sim.province.goods_total(&"mead")
	var counts := _run_counting(sim, 180)
	var mead := int(counts.get("good_produced:mead", 0))
	print("meadery in 3 min: ", counts)
	assert_int(mead).is_greater_equal(8)
	assert_int(mead % 2).is_equal(0)
	assert_int(sim.province.goods_total(&"honey")).is_equal(10 + before_honey - mead / 2)
	assert_int(sim.province.goods_total(&"mead")).is_equal(before + mead)


# --- Clay and bricks -----------------------------------------------------------------------

func test_clay_pit_must_stand_near_water_and_digs_clay() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village_with(sim, {})
	_set_water(sim, Rect2i(22, 0, 4, 40))
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"clay_pit", Vector2i(10, 20))))).is_equal("no_water_nearby")
	SimFixture.place(sim, &"clay_pit", Vector2i(18, 4))
	var counts := _run_counting(sim, 180)
	var clay := int(counts.get("good_produced:clay", 0))
	print("clay pit in 3 min: ", counts)
	assert_int(clay).is_greater_equal(8)
	assert_int(sim.province.goods_total(&"clay")).is_equal(clay)


func test_brickworks_fires_bricks_from_clay_and_wood() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village_with(sim, {&"clay": 10})
	SimFixture.place(sim, &"brickworks", Vector2i(14, 4))
	var counts := _run_counting(sim, 240)
	var bricks := int(counts.get("good_produced:bricks", 0))
	print("brickworks in 4 min: ", counts)
	assert_int(bricks).is_greater_equal(6)
	assert_int(bricks % 2).is_equal(0)
	# 1 clay (+ 1 log for the kiln) -> 2 bricks; the clay of an unfinished batch may wait inside.
	assert_int(sim.province.goods_total(&"clay")).is_between(10 - bricks / 2 - 1, 10 - bricks / 2)
	assert_int(sim.province.goods_total(&"bricks")).is_equal(bricks)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


# --- Tavern --------------------------------------------------------------------------------

func test_tavern_reaches_houses_only_while_it_serves() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var stock := _village_with(sim, {})
	var tavern := SimFixture.place(sim, &"tavern", Vector2i(14, 4))
	var size := sim.province.grid.size
	sim.run_ticks(SimFixture.ticks(30))
	# No drinks yet: finished and staffed, but not working.
	assert_bool(tavern.provides_service(sim.province.tick)).is_false()
	assert_bool(sim.province.coverage.covers(&"tavern", tavern.entrance_tile(), size)).is_false()
	stock.stock.add(&"beer", 3)
	stock.stock.add(&"mead", 3)
	var mead_before := sim.province.goods_total(&"mead")
	# One serving takes ~50 s plus the walk to the stockpile and back through the doors.
	var counts := _run_counting(sim, 180)
	print("tavern in 3 min: ", counts)
	assert_int(int(counts.get("goods_served", 0))).is_greater_equal(2)
	assert_bool(tavern.provides_service(sim.province.tick)).is_true()
	assert_bool(sim.province.coverage.covers(&"tavern", tavern.entrance_tile(), size)).is_true()
	# Every serving used one beer and one mead; nothing else vanished.
	var served := int(counts["goods_served"])
	assert_int(sim.province.goods_total(&"mead") + served).is_equal(mead_before)
	# Out of drinks: the service lapses after its hold time.
	sim.run_ticks(SimFixture.ticks(240))
	assert_int(stock.stock.total(&"mead")).is_equal(0)
	assert_bool(tavern.provides_service(sim.province.tick)).is_false()
	sim.run_ticks(SimFixture.ticks(2))
	assert_bool(sim.province.coverage.covers(&"tavern", tavern.entrance_tile(), size)).is_false()


# --- Forester ------------------------------------------------------------------------------

func test_forester_plants_on_stumps_first_and_saplings_grow_into_trees() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village_with(sim, {})
	var lodge := SimFixture.place(sim, &"forester", Vector2i(20, 20))
	var tree := SimFixture.registry().get_resource_node(&"tree")
	var stumps: Array[Vector2i] = [Vector2i(25, 21), Vector2i(26, 23)]
	for tile: Vector2i in stumps:
		sim.province.resources.place(tile, tree)
		for i: int in tree.amount:
			sim.province.resources.take(tile)
		sim.province.refresh_tile(tile)
	var counts := _run_counting(sim, 40)
	print("forester in 40 s: ", counts)
	assert_int(int(counts.get("resource_planted", 0))).is_greater_equal(2)
	for tile: Vector2i in stumps:
		assert_str(String(sim.province.resources.def_at(tile).id)).is_equal("sapling")
	# Saplings never stand next to a building.
	for tile: Vector2i in sim.province.resources.tiles_with_nodes():
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				assert_int(sim.province.grid.occupant(tile + Vector2i(dx, dy))).is_equal(0)
	# Five minutes after planting the saplings are trees a woodcutter can fell.
	counts = _run_counting(sim, 330)
	assert_int(int(counts.get("resource_grown", 0))).is_greater_equal(2)
	for tile: Vector2i in stumps:
		assert_bool(sim.province.resources.has_node(tile, &"tree")).is_true()
	assert_bool(sim.province.resources.find_nearest(&"tree", lodge.entrance_tile(), 8) != Agent.NO_TILE).is_true()


func test_forest_with_a_forester_lasts_two_hours() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	_village_with(sim, {&"bread": 200})
	# Two more huts: workers for both the woodcutter and the forester.
	SimFixture.house(sim, Vector2i(2, 12))
	SimFixture.house(sim, Vector2i(5, 12))
	SimFixture.place(sim, &"woodcutter", Vector2i(24, 24))
	SimFixture.place(sim, &"forester", Vector2i(24, 30))
	SimFixture.plant_trees(sim, Rect2i(28, 22, 4, 4))
	var woodcutter_trees := func() -> int:
		var n := 0
		for tile: Vector2i in sim.province.resources.tiles_with_nodes():
			if sim.province.resources.has_node(tile, &"tree"):
				n += 1
		return n
	var felled := 0
	var planted := 0
	var lowest := 1 << 30
	for minute: int in 120:
		var counts := _run_counting(sim, 60)
		felled += int(counts.get("good_gathered:wood", 0))
		planted += int(counts.get("resource_planted", 0))
		lowest = mini(lowest, woodcutter_trees.call() + sim.province.resources.growing_count())
	print("2 h with a forester: %d logs felled, %d saplings planted, at least %d trees or saplings at any time" % [felled, planted, lowest])
	# 16 trees give 48 logs; the woodcutter got far more and the forest is still there.
	assert_int(felled).is_greater(100)
	assert_int(lowest).is_greater(0)
	assert_int(woodcutter_trees.call()).is_greater(0)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


# --- Pausing production --------------------------------------------------------------------

func test_paused_workshop_starts_no_new_cycle_and_resumes() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village_with(sim, {&"cloth": 10})
	var tailor := SimFixture.place(sim, &"tailor", Vector2i(14, 4))
	assert_str(String(sim.execute(SetPausedCommand.new(tailor.id, true)))).is_equal("")
	var counts := _run_counting(sim, 90)
	assert_int(int(counts.get("good_produced:clothes", 0))).is_equal(0)
	assert_int(sim.province.goods_total(&"cloth")).is_equal(10)
	# Survives a save.
	var loaded := Simulation.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())), SimFixture.registry())
	assert_bool(loaded.province.buildings.get_building(tailor.id).paused).is_true()
	sim.execute(SetPausedCommand.new(tailor.id, false))
	counts = _run_counting(sim, 90)
	assert_int(int(counts.get("good_produced:clothes", 0))).is_greater(0)


func test_buildings_without_production_cannot_be_paused() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var stock := _village_with(sim, {})
	assert_str(String(sim.execute(SetPausedCommand.new(stock.id, true)))).is_equal("no_production")


# --- Saving --------------------------------------------------------------------------------

func test_saplings_and_serving_survive_save_load() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village_with(sim, {&"beer": 4, &"mead": 4})
	# Two more huts: workers for both the forester and the tavern.
	SimFixture.house(sim, Vector2i(2, 12))
	SimFixture.house(sim, Vector2i(5, 12))
	SimFixture.place(sim, &"forester", Vector2i(20, 20))
	var tavern := SimFixture.place(sim, &"tavern", Vector2i(14, 4))
	sim.run_ticks(SimFixture.ticks(80))
	assert_int(sim.province.resources.growing_count()).is_greater(0)
	assert_int(tavern.serving_until).is_greater(0)
	var first := SimCodec.canonical(sim.to_dict())
	var loaded := Simulation.from_dict(JSON.parse_string(first), SimFixture.registry())
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(first)
	loaded.run_ticks(SimFixture.ticks(60))
	sim.run_ticks(SimFixture.ticks(60))
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))


## M4b-1.5 (owner's play test): the player marks where the forester plants; with a full
## forest around it the forester says so instead of "no trees in range".
func test_forester_plants_only_in_the_marked_area() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village_with(sim, {})
	var lodge := SimFixture.place(sim, &"forester", Vector2i(20, 20))
	var marked: Array[Vector2i] = [Vector2i(26, 26), Vector2i(28, 26), Vector2i(26, 28), Vector2i(40, 40)]
	assert_str(String(sim.execute(SetPlantAreaCommand.new(lodge.id, marked)))).is_equal("")
	sim.run_ticks(1)
	# The tile outside its work area is left out.
	assert_int(lodge.plant_area.size()).is_equal(3)
	var counts := _run_counting(sim, 90)
	assert_int(int(counts.get("resource_planted", 0))).is_greater_equal(2)
	for tile: Vector2i in sim.province.resources.tiles_with_nodes():
		assert_bool(lodge.plant_area.has(tile)).override_failure_message("planted at %s" % tile).is_true()
	var copy := Simulation.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())), SimFixture.registry())
	assert_int(copy.province.buildings.get_building(lodge.id).plant_area.size()).is_equal(3)
	var none: Array[Vector2i] = []
	sim.execute(SetPlantAreaCommand.new(lodge.id, none))
	sim.run_ticks(1)
	assert_int(lodge.plant_area.size()).is_equal(0)


func test_forester_without_room_waits_and_says_why() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village_with(sim, {})
	var lodge := SimFixture.place(sim, &"forester", Vector2i(20, 20))
	# No limit on trees since M4b-2: he waits only when every free tile in range is a tree.
	var area := Rect2i(lodge.origin, lodge.def.footprint).grow(lodge.def.work_radius) 			.intersection(Rect2i(Vector2i.ZERO, Vector2i(40, 40)))
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			if sim.province.can_plant(Vector2i(x, y)):
				SimFixture.plant_trees(sim, Rect2i(Vector2i(x, y), Vector2i.ONE))
	assert_bool(sim.province.find_plant_spot(lodge, &"tree", lodge.entrance_tile()) == Agent.NO_TILE).is_true()
	var reasons: Dictionary = {}
	for i: int in SimFixture.ticks(30):
		sim.step()
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"task_failed":
				reasons[event.get("reason", &"")] = true
	assert_bool(reasons.has(&"no_plant_spot")).override_failure_message(str(reasons)).is_true()


## A felled tree taken with its stump leaves grass where the forest floor was.
func test_cut_forest_floor_turns_to_grass() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var forest := SimFixture.registry().get_terrain(&"forest")
	var tile := Vector2i(16, 8)
	sim.province.grid.set_terrain(tile, forest.index)
	sim.province.refresh_tile(tile)
	sim.province.clear_forest_floor(tile)
	assert_str(String(sim.province.terrain_at(tile).id)).is_equal("grass")
	assert_float(sim.province.nav.get_cost(tile)).is_equal_approx(1.0, 0.001)
