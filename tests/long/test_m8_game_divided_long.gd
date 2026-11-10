extends GdUnitTestSuite
## M8 part 5, a full test game (ROADMAP M8 DoD: three games without blocking errors, from the
## start to victory or defeat): the automatic player (AutoPlayer: the rulers' planner,
## expansion and commander for the player's provinces) in the scenario below, until the game
## is decided. A save in the middle loads back alike; no army of a ruler or of the raiders
## stands stuck in the field.
## Divided continent, two rulers, hard, conquest: the rulers fight each other and the
## neutral settlements, and march on the player.


func test_divided_continent_game_to_the_end() -> void:
	var s := GameSettings.new()
	s.scenario = GameSettings.DIVIDED
	s.world_seed = 5
	s.rulers = 2
	s.province_count = 16
	s.difficulty = GameSettings.HARD
	s.fit_scenario()
	var sim := Simulation.from_settings(SimFixture.registry(), s, 1)
	sim.raids_enabled = true
	var bot := AutoPlayer.new(sim)
	bot.save_minute = 35
	var result := bot.run(180 * 60)
	print("divided: '%s' after %d min; %s" % [result, sim.clock.tick / 600, bot.summary()])
	print("\n".join(bot.log))
	assert_str(String(result)).is_not_equal("")
	assert_int(bot.counts.get(&"ruler_marched", 0)).is_greater_equal(2)
	assert_int(bot.counts.get(&"province_taken", 0)).is_greater_equal(1)
	assert_str(bot.save_mismatch).is_equal("")
	assert_array(Array(bot.stuck)).is_empty()
