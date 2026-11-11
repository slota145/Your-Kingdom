extends GdUnitTestSuite
## E2 part 2: the hunter creeps up on a wild herd, shoots one animal, carries the carcass to
## his lodge and dresses it into 2 meat and a hide; the rest of the herd flees.


func _scene() -> Dictionary:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	var forest := SimFixture.registry().get_terrain(&"forest")
	for y: int in range(24, 46):
		for x: int in range(24, 46):
			sim.province.grid.set_terrain(Vector2i(x, y), forest.index)
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(4, 6))
	var lodge := SimFixture.place(sim, &"hunter_lodge", Vector2i(12, 12))
	return {"sim": sim, "stock": stock, "lodge": lodge}


func test_the_hunter_brings_meat_and_a_hide() -> void:
	var scene := _scene()
	var sim: Simulation = scene["sim"]
	var lodge: BuildingState = scene["lodge"]
	var stock: BuildingState = scene["stock"]
	sim.run_ticks(SimFixture.ticks(2))
	var animals := sim.province.wild.animals()
	assert_int(animals).is_greater(0)
	var hunter := SimFixture.spawn(sim, &"hunter", lodge.entrance_tile())
	assert_str(String(sim.execute(AssignWorkerCommand.new(hunter.id, lodge.id)))).is_empty()
	var shots := 0
	var aimed := false
	var carried := false
	var done := false
	for i: int in SimFixture.ticks(300):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"hunt_shot":
				shots += 1
		aimed = aimed or hunter.activity == &"aim"
		carried = carried or hunter.carry_good == &"game"
		var meat := stock.stock.total(&"meat") + (lodge.yard.total(&"meat") if lodge.yard != null else 0)
		var hides := stock.stock.total(&"hides") + (lodge.yard.total(&"hides") if lodge.yard != null else 0)
		if meat >= 2 and hides >= 1:
			done = true
			break
	assert_bool(aimed).override_failure_message("the hunter never aimed").is_true()
	assert_bool(carried).override_failure_message("the hunter never carried game").is_true()
	assert_int(shots).is_greater_equal(1)
	assert_bool(done).override_failure_message("no meat and hide from the hunt").is_true()
	assert_int(sim.province.wild.animals()).is_less(animals + 2)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_no_game_no_hunt() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var lodge := SimFixture.place(sim, &"hunter_lodge", Vector2i(12, 12))
	var hunter := SimFixture.spawn(sim, &"hunter", lodge.entrance_tile())
	sim.execute(AssignWorkerCommand.new(hunter.id, lodge.id))
	sim.run_ticks(SimFixture.ticks(30))
	assert_str(String(hunter.last_fail)).is_equal("no_game")
	assert_str(String(hunter.carry_good)).is_empty()


func test_the_simplified_mode_hunts_the_herds() -> void:
	var scene := _scene()
	var sim: Simulation = scene["sim"]
	var lodge: BuildingState = scene["lodge"]
	sim.run_ticks(SimFixture.ticks(2))
	var hunter := SimFixture.spawn(sim, &"hunter", lodge.entrance_tile())
	sim.execute(AssignWorkerCommand.new(hunter.id, lodge.id))
	sim.run_ticks(2)
	var abstract := ProvinceAbstract.freeze(sim.province, sim.clock.tick)
	for t: int in range(0, SimFixture.ticks(240), ProvinceAbstract.STEP_TICKS):
		abstract.step(sim.clock.tick / ProvinceAbstract.STEP_TICKS * ProvinceAbstract.STEP_TICKS + t)
	assert_int(int(abstract.detail.ledger.made_total.get(&"meat", 0))).is_greater_equal(2)
	assert_int(int(abstract.detail.ledger.made_total.get(&"hides", 0))).is_greater_equal(1)
	# Herds breed and come out of the woods meanwhile; one hunter does not empty them.
	assert_int(abstract.detail.wild.animals()).is_greater(0)
