extends GdUnitTestSuite
## M3 DoD: every loaf of bread comes from the visible chain
## field -> sheaf -> mill -> sack of flour -> baker -> basket of bread -> storage -> house.
## Checked with event counters over a long run of a self-staffed village.


func _bakery_village(sim: Simulation) -> Dictionary:
	var village := SimFixture.village(sim, 60, 0)
	for x: int in [8, 11]:
		SimFixture.house(sim, Vector2i(x, 8))
	SimFixture.place(sim, &"well", Vector2i(9, 12))
	var farm := SimFixture.place(sim, &"farm", Vector2i(18, 14))
	for y: int in range(12, 16):
		for x: int in range(20, 24):
			assert_str(String(sim.execute(PlaceFieldCommand.new(farm.id, Vector2i(x, y))))).is_equal("")
	var mill := SimFixture.place(sim, &"mill", Vector2i(14, 4))
	var bakery := SimFixture.place(sim, &"bakery", Vector2i(18, 4))
	village["farm"] = farm
	village["mill"] = mill
	village["bakery"] = bakery
	return village


func test_every_loaf_comes_from_the_chain() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var village := _bakery_village(sim)
	var stock: BuildingState = village["stock"]
	var houses: Array[int] = []
	for b: BuildingState in sim.province.buildings.all():
		if b.house != null:
			houses.append(b.id)
	var bread_start := sim.province.goods_total(&"bread")
	var counts := {"harvested": 0, "flour": 0, "bread": 0, "grain_used": 0, "flour_used": 0,
			"bread_stored": 0, "bread_to_houses": 0, "eaten": 0}
	for i: int in SimFixture.ticks(20 * 60):
		sim.step()
		for e: Dictionary in sim.events.drain():
			match e["type"]:
				&"good_harvested":
					counts["harvested"] += int(e["amount"])
				&"good_produced":
					if e["good"] == &"flour":
						assert_str(String(e["input"])).is_equal("grain")
						counts["flour"] += int(e["amount"])
						counts["grain_used"] += 1
					elif e["good"] == &"bread":
						assert_str(String(e["input"])).is_equal("flour")
						counts["bread"] += int(e["amount"])
						counts["flour_used"] += 1
				&"good_stored":
					if e["good"] == &"bread" and e["storage"] == stock.id:
						counts["bread_stored"] += int(e["amount"])
					if e["good"] == &"bread" and houses.has(int(e["storage"])):
						counts["bread_to_houses"] += int(e["amount"])
				&"good_consumed":
					if e["good"] == &"bread":
						counts["eaten"] += int(e["amount"])
	print("bread chain after 20 min: ", counts)
	# The chain ran several times over.
	assert_int(counts["bread"]).is_greater(10)
	# Nothing appears from nowhere: each step uses what the previous one made.
	assert_int(counts["grain_used"]).is_less_equal(counts["harvested"])
	assert_int(counts["flour_used"]).is_less_equal(counts["flour"])
	assert_int(counts["bread_stored"]).is_less_equal(counts["bread"])
	# Bread reached the houses and was eaten there, and every loaf is accounted for.
	assert_int(counts["bread_to_houses"]).is_greater(0)
	assert_int(sim.province.goods_total(&"bread")).is_equal(bread_start + counts["bread"] - counts["eaten"])
	assert_int(sim.province.goods_total(&"grain")).is_equal(counts["harvested"] - counts["grain_used"])
	assert_int(sim.province.goods_total(&"flour")).is_equal(counts["flour"] - counts["flour_used"])
	assert_array(Array(sim.province.dangling_holds())).is_empty()
