extends GdUnitTestSuite
## UI-2 part 3 (owner's survey 2026-11-13): a world of islands only with the rules of
## Colonization (or the Divided continent), e.g. in free play; saved with the world (v43).


func _settings(scenario: StringName, archipelago: bool) -> GameSettings:
	var s := GameSettings.new()
	s.scenario = scenario
	s.world_seed = 5
	s.rulers = 2
	s.province_count = 14
	s.victory = GameSettings.VICTORY_FREE
	s.archipelago = archipelago
	s.fit_scenario()
	return s


func test_colonization_among_islands_keeps_its_victory() -> void:
	var s := _settings(GameSettings.COLONIZATION, true)
	assert_bool(s.is_archipelago()).is_true()
	assert_str(String(s.victory)).is_equal(String(GameSettings.VICTORY_FREE))
	var data := SimFixture.registry()
	var world := WorldGenerator.generate(data, s)
	assert_int(world.provinces.size()).is_equal(14)
	for id: StringName in world.provinces:
		assert_bool(data.get_province(id).island).override_failure_message("%s not an island" % id).is_true()


func test_the_invasion_is_never_among_islands_only() -> void:
	assert_bool(_settings(GameSettings.INVASION, true).is_archipelago()).is_false()


func test_a_game_among_islands_runs_saves_and_loads() -> void:
	for scenario: StringName in [GameSettings.COLONIZATION, GameSettings.DIVIDED]:
		var problems := PackedStringArray()
		var sim := Simulation.from_settings(SimFixture.registry(), _settings(scenario, true), 1, problems)
		assert_array(Array(problems)).is_empty()
		assert_int(Rulers.alive(sim.world).size()).is_equal(2)
		sim.run_ticks(SimFixture.ticks(5))
		var copy := Simulation.from_dict(sim.to_dict(), sim.data)
		assert_bool(copy.world.settings.archipelago).is_true()
		assert_str(String(copy.world.settings.victory)).is_equal(String(GameSettings.VICTORY_FREE))
		copy.run_ticks(SimFixture.ticks(5))


func test_v42_games_load_on_a_continent() -> void:
	var old := {"tick": 5, "world": {"settings": {"seed": 3, "rulers": 2, "scenario": "colonization"}}}
	var migrated := SaveMigrations.migrate(old, 42)
	var settings := GameSettings.from_dict(migrated["world"]["settings"])
	assert_bool(settings.archipelago).is_false()
	assert_bool(settings.is_archipelago()).is_false()
	old["world"]["settings"]["scenario"] = "islands"
	assert_bool(GameSettings.from_dict(SaveMigrations.migrate(old, 42)["world"]["settings"]).is_archipelago()).is_true()
