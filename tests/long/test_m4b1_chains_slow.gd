extends GdUnitTestSuite
## Moved from test_m4b1_chains.gd (speed-up 2026-11-11).


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

func _village_with(sim: Simulation, goods: Dictionary) -> BuildingState:
	var village := SimFixture.village(sim, 30, 20)
	# A well keeps the village happy, so it keeps its workers.
	SimFixture.place(sim, &"well", Vector2i(9, 9))
	var stock: BuildingState = village["stock"]
	for good: StringName in goods:
		stock.stock.add(good, int(goods[good]))
	return stock


# --- Textiles ------------------------------------------------------------------------------

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
