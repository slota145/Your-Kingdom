extends GdUnitTestSuite


func test_commands_apply_at_next_tick_in_order() -> void:
	var sim := SimFixture.make_sim()
	sim.submit(SpawnAgentCommand.new(&"porter", Vector2i(1, 1)))
	sim.submit(SpawnAgentCommand.new(&"porter", Vector2i(2, 2)))
	assert_int(sim.province.agents.count()).is_equal(0)
	sim.step()
	var agents := sim.province.agents.all()
	assert_int(agents.size()).is_equal(2)
	assert_vector(agents[0].tile()).is_equal(Vector2i(1, 1))
	assert_int(sim.clock.tick).is_equal(1)


func test_rejected_command_emits_event_and_changes_nothing() -> void:
	var sim := SimFixture.make_sim(Vector2i(8, 8))
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"stockpile", Vector2i(6, 6))))) \
			.is_equal("outside_map")
	assert_int(sim.province.buildings.count()).is_equal(0)
	var events := sim.events.drain()
	assert_str(String(events.back()["type"])).is_equal("command_rejected")


## M4b-1.5: the whole footprint is solid, entrances too; people get in only through a door.
func test_placing_building_blocks_all_its_tiles() -> void:
	var sim := SimFixture.make_sim()
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	for tile: Vector2i in stock.tiles():
		assert_bool(sim.province.nav.is_walkable(tile)).is_false()
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"woodcutter", Vector2i(3, 3))))) \
			.is_equal("tile_occupied")


func test_cannot_build_on_people() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.spawn(sim, &"porter", Vector2i(3, 3))
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"stockpile", Vector2i(2, 2))))) \
			.is_equal("tile_has_people")


func test_worker_slots_are_limited() -> void:
	var sim := SimFixture.make_sim()
	var hut := SimFixture.place(sim, &"woodcutter", Vector2i(2, 2))
	var a := SimFixture.spawn(sim, &"woodcutter", Vector2i(8, 8))
	var b := SimFixture.spawn(sim, &"woodcutter", Vector2i(9, 8))
	assert_str(String(sim.execute(AssignWorkerCommand.new(a.id, hut.id)))).is_equal("")
	assert_str(String(sim.execute(AssignWorkerCommand.new(b.id, hut.id)))).is_equal("no_worker_slot")
