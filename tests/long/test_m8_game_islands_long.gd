extends GdUnitTestSuite
## M8 part 5, a full test game (ROADMAP M8 DoD: three games without blocking errors, from the
## start to victory or defeat): the automatic player (AutoPlayer: the rulers' planner,
## expansion and commander for the player's provinces) in the scenario below, until the game
## is decided. A save in the middle loads back alike; no army of a ruler or of the raiders
## stands stuck in the field.
## Merchant islands, two rulers, normal, 10 000 gold: the first to hold it wins (the rulers
## sell their surplus and save).


func test_merchant_islands_game_to_the_end() -> void:
	var s := GameSettings.new()
	s.scenario = GameSettings.ISLANDS
	s.world_seed = 5
	s.rulers = 2
	s.province_count = 16
	s.fit_scenario()
	var sim := Simulation.from_settings(SimFixture.registry(), s, 1)
	sim.raids_enabled = true
	var bot := AutoPlayer.new(sim)
	bot.save_minute = 40
	var result := bot.run(180 * 60)
	print("islands: '%s' after %d min; %s" % [result, sim.clock.tick / 600, bot.summary()])
	print("\n".join(bot.log))
	assert_str(String(result)).is_not_equal("")
	var richest := maxi(sim.treasury.gold, sim.world.rulers[Victory.richest_ruler(sim)].treasury.gold)
	assert_int(richest).is_greater_equal(s.gold_target)
	assert_int(bot.counts.get(&"province_settled", 0)).is_greater_equal(1)
	assert_str(bot.save_mismatch).is_equal("")
	assert_array(Array(bot.stuck)).is_empty()
