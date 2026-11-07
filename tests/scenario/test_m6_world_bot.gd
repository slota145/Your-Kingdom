extends GdUnitTestSuite
## M6 part 3 DoD: the automatic player in the world. It builds up Landing Bay (the Coast, from
## the ship) with a town hall and a stable, settles Willow Vale and Amber Coast by land
## expeditions, and runs a wagon route with bread to Willow Vale. Nothing gets stuck.

const LIMIT_MINUTES := 90


func test_world_bot_settles_provinces_and_runs_a_route() -> void:
	var registry := SimFixture.registry()
	var sim := Simulation.from_world(registry, registry.get_world(&"kingdom"))
	var bot := WorldBot.new(sim)
	var watch := DeadlockWatch.new()
	var trace := PackedStringArray()
	bot.run(LIMIT_MINUTES * 60, func(minute: int) -> void:
		if sim.viewed_id == bot.home:
			watch.check(sim, minute)
		if minute % 10 == 0:
			var routes := ""
			for route: TradeRoute in sim.world.routes.values():
				routes += " route %d->%d state %d runs %d delivered %d" % [route.from, route.to,
						route.state, route.runs, route.delivered]
			trace.append("min %d: provinces %d, residents %d, gold %d, bread %d, wood %d%s" % [minute,
					bot.owned(), WorldMapScreen._residents(sim.province_state(bot.home)), sim.treasury.gold,
					sim.province_state(bot.home).kingdom_stock(&"bread"),
					sim.province_state(bot.home).kingdom_stock(&"wood"), routes]))
	print("\n".join(trace))
	print("settled ", bot.settled_at, ", route at ", bot.route_at, ", log ", bot.log, ", home bot log ",
			bot.bots[bot.home].log)
	assert_array(watch.stuck).is_empty()
	assert_array(Array(bot.log)).is_empty()
	assert_int(bot.owned()).is_greater_equal(3)
	assert_int(bot.route_at).is_greater(0)
	var runs := 0
	for route: TradeRoute in sim.world.routes.values():
		runs += route.runs
	assert_int(runs).is_greater_equal(1)
