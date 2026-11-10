extends GdUnitTestSuite
## M8 part 5, a full test game (ROADMAP M8 DoD: three games without blocking errors, from the
## start to victory or defeat): the automatic player (AutoPlayer: the rulers' planner,
## expansion and commander for the player's provinces) in the scenario below, until the game
## is decided. A save in the middle loads back alike; no army of a ruler or of the raiders
## stands stuck in the field.
## Invasion from the sea, normal: the waves come every 5 minutes from the 20th; the game ends by
## the 60th minute (held out) or before (the last town taken).


func test_invasion_game_to_the_end() -> void:
	var s := GameSettings.new()
	s.scenario = GameSettings.INVASION
	s.world_seed = 5
	s.province_count = 16
	s.fit_scenario()
	var sim := Simulation.from_settings(SimFixture.registry(), s, 1)
	sim.raids_enabled = true
	var bot := AutoPlayer.new(sim)
	bot.save_minute = 15
	var result := bot.run(62 * 60)
	print("invasion: '%s' after %d min, %d waves; %s" % [result, sim.clock.tick / 600,
			sim.world.invasion.wave, bot.summary()])
	print("\n".join(bot.log))
	assert_str(String(result)).is_not_equal("")
	assert_int(sim.world.invasion.wave).is_greater_equal(1)
	if result == WorldSim.RESULT_WON:
		assert_int(Victory.elapsed_minutes(sim)).is_greater_equal(GameSettings.SURVIVE_MINUTES)
	else:
		assert_int(Victory.player_provinces(sim.world)).is_equal(0)
	assert_str(bot.save_mismatch).is_equal("")
	assert_array(Array(bot.stuck)).is_empty()
