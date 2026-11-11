extends GdUnitTestSuite
## E2 part 1: the orchard. The orchardist plants apple trees on tiles around it, the whole
## orchard blossoms and bears fruit together (E1), and the apples feed the peasants.


func test_orchard_apples_reach_the_storage() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(4, 18))
	var orchard := SimFixture.place(sim, &"orchard", Vector2i(18, 18))
	var worker := SimFixture.spawn(sim, &"orchardist", orchard.entrance_tile())
	assert_str(String(sim.execute(AssignWorkerCommand.new(worker.id, orchard.id)))).is_empty()
	for tile: Vector2i in [Vector2i(16, 18), Vector2i(16, 19), Vector2i(17, 21), Vector2i(18, 21)]:
		assert_str(String(sim.execute(PlaceFieldCommand.new(orchard.id, tile)))).is_empty()
	var picked := SimFixture.run_until(sim, func() -> bool: return stock.stock.total(&"apples") >= 4, 420)
	assert_bool(picked).override_failure_message("no apples in the storage").is_true()
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_apples_are_food_for_peasants() -> void:
	var sim := SimFixture.make_sim()
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	stock.stock.add(&"apples", 20)
	stock.stock.add(&"wood", 20)
	var hut := SimFixture.house(sim, Vector2i(12, 12), 4, false)
	var fed := SimFixture.run_until(sim, func() -> bool: return bool(hut.house.satisfied.get(&"diet", false)), 90)
	assert_bool(fed).override_failure_message("apples did not feed the house").is_true()
	assert_int(hut.supply.total(&"apples")).is_greater(0)


func test_the_market_and_the_barracks_take_apples() -> void:
	var data := SimFixture.registry()
	assert_bool(data.get_building(&"market").stall_goods.has(&"apples")).is_true()
	assert_bool(Barracks.FOOD.has(&"apples")).is_true()
	assert_str(String(VineLayer.crop_of(data.get_building(&"orchard")))).is_equal("apples")


## Save v36: old pantries, market stalls and barracks pantries get a slot for apples.
func test_v35_save_migrates_with_room_for_apples() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v35_fields.json"))
	var state := SaveMigrations.migrate(document["state"], 35)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	var old := {"provinces": [{"state": {"buildings": [
		{"def": "market", "supply": {"slots": [["", 0], ["", 0], ["", 0], ["", 0], ["", 0], ["", 0], ["", 0]]}},
		{"def": "barracks", "supply": {"slots": [["", 0], ["", 0], ["", 0]]}}]}}]}
	var migrated := SaveMigrations.migrate_v35_to_v36(old)
	var buildings: Array = migrated["provinces"][0]["state"]["buildings"]
	assert_int((buildings[0]["supply"]["slots"] as Array).size()).is_equal(8)
	assert_int((buildings[1]["supply"]["slots"] as Array).size()).is_equal(4)
	for b: BuildingState in sim.province.buildings.all():
		if b.house != null:
			assert_bool(b.supply.can_accept(&"apples", 1) or b.supply.total(&"apples") > 0).is_true()
