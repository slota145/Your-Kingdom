extends GdUnitTestSuite
## E4 part 1: the developer mode (owner's survey 2026-11-11). A full treasury, everything built
## at once and for free in the player's provinces (buildings, roads, walls, house upgrades),
## residents who never leave; ships and soldiers as usual. Saved with the game, F12 switches it.


func _row(y: int, x0: int, x1: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x: int in range(x0, x1 + 1):
		tiles.append(Vector2i(x, y))
	return tiles


func test_gold_is_topped_up_and_buildings_stand_at_once() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	sim.treasury.gold = 10
	assert_str(String(sim.execute(SetDevModeCommand.new(true)))).is_empty()
	assert_bool(sim.dev_mode).is_true()
	assert_int(sim.treasury.gold).is_equal(Simulation.DEV_GOLD)
	var events := sim.events.drain()
	assert_bool(events.any(func(e: Dictionary) -> bool: return e["type"] == &"dev_mode_changed")).is_true()
	# A building with a gold cost stands at once, free, with no site.
	var def := sim.data.get_building(&"church")
	assert_int(def.gold_cost).is_greater(0)
	sim.treasury.gold = 0
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"church", Vector2i(10, 10))))).is_empty()
	var church := sim.province.buildings.get_building(sim.province.grid.occupant(Vector2i(10, 10)))
	assert_object(church).is_not_null()
	assert_bool(church.is_complete()).is_true()
	assert_int(sim.province.sites.size()).is_equal(0)
	assert_int(sim.treasury.gold).is_equal(0)
	sim.step()
	assert_int(sim.treasury.gold).is_equal(Simulation.DEV_GOLD)
	# Spending is fine: the treasury is full again on the next tick.
	sim.treasury.gold = Simulation.DEV_GOLD + 500
	sim.step()
	assert_int(sim.treasury.gold).is_equal(Simulation.DEV_GOLD + 500)


func test_open_sites_roads_and_walls_are_done_at_once() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	sim.treasury.gold = 1000
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"stockpile", Vector2i(4, 4))))).is_empty()
	assert_int(sim.province.sites.size()).is_equal(1)
	var hut := SimFixture.house(sim, Vector2i(14, 4))
	Construction.open_upgrade_site(sim.province, hut, hut.def.house_levels[hut.house.level])
	var paving := _row(20, 5, 9)
	assert_str(String(sim.execute(BuildPavingCommand.new(paving)))).is_empty()
	var wall := _row(25, 10, 13)
	assert_str(String(sim.execute(BuildWallCommand.new(wall, Walls.STONE)))).is_empty()
	assert_int(sim.province.paving.size()).is_equal(2)
	sim.execute(SetDevModeCommand.new(true))
	sim.step()
	assert_int(sim.province.sites.size()).is_equal(0)
	assert_int(sim.province.paving.size()).is_equal(0)
	assert_bool(sim.province.buildings.get_building(sim.province.grid.occupant(Vector2i(4, 4))).is_complete()).is_true()
	assert_int(hut.house.level).is_equal(2)
	for tile: Vector2i in paving:
		assert_bool(sim.province.grid.is_paved(tile)).is_true()
	for tile: Vector2i in wall:
		assert_int(sim.province.walls.kind(tile)).is_equal(Walls.STONE)
	# A wall ordered now stands on the next tick too.
	var more := _row(28, 10, 12)
	assert_str(String(sim.execute(BuildWallCommand.new(more, Walls.PALISADE)))).is_empty()
	sim.step()
	for tile: Vector2i in more:
		assert_int(sim.province.walls.kind(tile)).is_equal(Walls.PALISADE)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_residents_never_leave_and_the_mode_switches_off() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var province := sim.province
	var hut := SimFixture.house(sim, Vector2i(10, 10), 4, false)
	hut.house.happiness = 60.0
	province.grace_until = 0
	sim.execute(SetDevModeCommand.new(true))
	sim.events.drain()
	var warnings := 0
	var lowest := 100.0
	for i: int in SimFixture.ticks(Population.LEAVE_AFTER + Population.LEAVE_EVERY + 20):
		sim.step()
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"house_warning" or event["type"] == &"resident_left":
				warnings += 1
		lowest = minf(lowest, hut.house.happiness)
	assert_int(warnings).is_equal(0)
	assert_int(hut.house.residents).is_equal(4)
	assert_float(lowest).is_greater_equal(60.0)
	# Off: the shortage counts again and buildings are sites again.
	sim.execute(SetDevModeCommand.new(false))
	sim.step()
	assert_bool(province.dev_mode).is_false()
	assert_bool(province.in_grace()).is_false()
	sim.treasury.gold = 1000
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"stockpile", Vector2i(2, 2))))).is_empty()
	assert_int(province.sites.size()).is_equal(1)
	for i: int in SimFixture.ticks(30):
		sim.step()
	assert_float(hut.house.happiness).is_less(60.0)


func test_saved_with_the_game_and_old_games_are_normal() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	sim.execute(SetDevModeCommand.new(true))
	var state := sim.to_dict()
	assert_bool(bool(state["dev"])).is_true()
	var copy := Simulation.from_dict(state, SimFixture.registry())
	assert_bool(copy.dev_mode).is_true()
	assert_bool(copy.province.dev_mode).is_true()
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(state))
	# v38: an older game is a normal one.
	var old := {"tick": 5}
	assert_bool(bool(SaveMigrations.migrate(old, 37)["dev"])).is_false()
	assert_int(SaveMigrations.CURRENT_VERSION).is_greater_equal(38)


## "New game" with the tick box: the player's provinces only; the rulers build as usual, and the
## full treasury wins no gold race.
func test_new_game_in_the_developer_mode() -> void:
	var s := GameSettings.new()
	s.scenario = GameSettings.ISLANDS
	s.world_seed = 5
	s.rulers = 1
	s.province_count = 9
	s.dev_mode = true
	s.fit_scenario()
	assert_bool(GameSettings.from_dict(s.to_dict()).dev_mode).is_true()
	assert_bool(GameSettings.new().to_dict().has("dev")).is_false()
	var sim := Simulation.from_settings(SimFixture.registry(), s)
	assert_bool(sim.dev_mode).is_true()
	assert_int(sim.treasury.gold).is_equal(Simulation.DEV_GOLD)
	assert_bool(sim.province.dev_mode).is_true()
	var rulers_towns := 0
	for id: int in sim.runtimes:
		if Rulers.is_ruler(sim.world.owner_of(id)):
			rulers_towns += 1
			assert_bool(sim.province_state(id).dev_mode).is_false()
	assert_int(rulers_towns).is_greater(0)
	assert_int(s.gold_target).is_less_equal(Simulation.DEV_GOLD)
	assert_bool(Victory.is_won(sim)).is_false()
