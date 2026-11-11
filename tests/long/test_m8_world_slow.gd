extends GdUnitTestSuite
## Moved from test_m8_world.gd (speed-up 2026-11-11).


func _settings(seed_value: int, rulers: int = 2, count: int = 22) -> GameSettings:
	var s := GameSettings.new()
	s.world_seed = seed_value
	s.rulers = rulers
	s.province_count = count
	return s

func test_victory_and_defeat() -> void:
	var data := SimFixture.registry()
	var settings := _settings(9, 1, 16)
	var sim := Simulation.from_settings(data, settings, 1)
	# Conquest: the only ruler loses his province.
	var ruler: int = Rulers.provinces_of(sim.world, WorldGenerator.ruler_owner(1))[0]
	sim.world.get_province(ruler).owner = ProvinceDef.OWNER_NONE
	sim.run_ticks(SimFixture.ticks(1.1))
	assert_str(String(sim.world.result)).is_equal(String(WorldSim.RESULT_WON))
	# Provinces: two needed.
	var sim2 := Simulation.from_settings(data, settings, 1)
	settings.victory = GameSettings.VICTORY_PROVINCES
	settings.victory_target = 2
	sim2.world.settings = settings
	sim2.run_ticks(SimFixture.ticks(1.1))
	assert_str(String(sim2.world.result)).is_equal("")
	sim2.world.get_province(ruler).owner = ProvinceDef.OWNER_PLAYER
	sim2.run_ticks(SimFixture.ticks(1.1))
	assert_str(String(sim2.world.result)).is_equal(String(WorldSim.RESULT_WON))
	# Defeat: the player holds nothing.
	var sim3 := Simulation.from_settings(data, _settings(9, 1, 16), 1)
	sim3.world.settings.victory = GameSettings.VICTORY_FREE
	for id: int in sim3.world.ids():
		if sim3.world.owner_of(id) == ProvinceDef.OWNER_PLAYER:
			sim3.world.get_province(id).owner = ProvinceDef.OWNER_NONE
	sim3.run_ticks(SimFixture.ticks(1.1))
	assert_str(String(sim3.world.result)).is_equal(String(WorldSim.RESULT_LOST))
