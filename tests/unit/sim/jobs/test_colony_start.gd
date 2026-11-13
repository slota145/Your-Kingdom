extends GdUnitTestSuite
## UI-2 part 2 (owner 2026-11-13: at the start the porters moved the kit into the new storage
## while the builder waited for wood): materials for building come first, a site takes them
## straight from the goods on the ground, and a builder with nothing to build fetches them.


func _site_of(sim: Simulation, building: BuildingState) -> ConstructionSite:
	return sim.province.sites.get(building.site_id) as ConstructionSite


func _hut_site(sim: Simulation, origin: Vector2i) -> BuildingState:
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"hut", origin)))).is_equal("")
	return sim.province.buildings.get_building(sim.province.grid.occupant(origin))


func test_porters_serve_building_sites_before_older_requests() -> void:
	var sim := SimFixture.make_sim()
	var a := SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	var b := SimFixture.place(sim, &"stockpile", Vector2i(20, 2))
	a.stock.add(&"wood", 20)
	# An older request: wood from one storage to the other.
	sim.execute(RequestTransportCommand.new(&"wood", 10, a.id, b.id))
	var hut := _hut_site(sim, Vector2i(8, 12))
	var porter := SimFixture.spawn(sim, &"porter", Vector2i(10, 10))
	sim.run_ticks(JobBoard.MATCH_INTERVAL + 1)
	assert_object(porter.task).is_not_null()
	assert_int(int(porter.task.bb["to"])).is_equal(hut.site_id)


func test_a_site_takes_wood_straight_from_the_ground() -> void:
	var sim := SimFixture.make_sim()
	# The start kit on the beach: wood on the ground, no storage yet.
	sim.province.drop_goods(Vector2i(4, 4), &"wood", 10)
	var hut := _hut_site(sim, Vector2i(10, 10))
	SimFixture.spawn(sim, &"porter", Vector2i(6, 6))
	SimFixture.spawn(sim, &"builder", Vector2i(8, 8))
	assert_bool(SimFixture.run_until(sim, func() -> bool: return hut.is_complete(), 240.0)).is_true()


func test_a_builder_without_porters_fetches_the_materials_himself() -> void:
	var sim := SimFixture.make_sim()
	var store := SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	store.stock.add(&"wood", 20)
	var hut := _hut_site(sim, Vector2i(12, 12))
	var builder := SimFixture.spawn(sim, &"builder", Vector2i(8, 8))
	sim.run_ticks(JobBoard.MATCH_INTERVAL + 1)
	assert_object(builder.task).is_not_null()
	assert_str(String(builder.task.kind)).is_equal(String(Task.KIND_TRANSPORT))
	assert_int(int(builder.task.bb["to"])).is_equal(hut.site_id)
	assert_bool(SimFixture.run_until(sim, func() -> bool: return hut.is_complete(), 400.0)).is_true()


func test_a_builder_builds_when_a_site_has_its_materials() -> void:
	var sim := SimFixture.make_sim()
	var store := SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	store.stock.add(&"wood", 20)
	var hut := _hut_site(sim, Vector2i(12, 12))
	var site := _site_of(sim, hut)
	for good: StringName in site.current_cost():
		site.stock.add(good, int(site.current_cost()[good]))
	var builder := SimFixture.spawn(sim, &"builder", Vector2i(8, 8))
	sim.run_ticks(JobBoard.MATCH_INTERVAL + 1)
	assert_str(String(builder.task.kind)).is_equal(String(Task.KIND_BUILD))
