extends GdUnitTestSuite
## M8 part 5, a full test game (ROADMAP M8 DoD: three games without blocking errors, from the
## start to victory or defeat): the automatic player (AutoPlayer: the rulers' planner,
## expansion and commander for the player's provinces) in the scenario below, until the game
## is decided. A save in the middle loads back alike; no army of a ruler or of the raiders
## stands stuck in the field.
## Divided continent, two rulers, hard, conquest: the rulers fight each other and the
## neutral settlements, and march on the player. Since UI-3 part 2 (60 bread and 30 fish at
## the start) the game may still be going after 180 minutes: the player and the rulers keep
## taking a province from each other (balance: M10 part 5).


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
	# Decided, or (owner's choice 2026-11-23, UI-3 part 2: with the bigger start kit the
	# automatic player holds out) still a real war: provinces change hands again and again.
	if String(result) == "":
		assert_int(bot.counts.get(&"province_taken", 0)).is_greater_equal(10)
	assert_int(bot.counts.get(&"ruler_marched", 0)).is_greater_equal(2)
	assert_int(bot.counts.get(&"province_taken", 0)).is_greater_equal(1)
	assert_str(bot.save_mismatch).is_equal("")
	assert_array(Array(bot.stuck)).is_empty()
