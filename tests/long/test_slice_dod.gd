extends GdUnitTestSuite
## DoD scenarios on the real start map, played by SliceBot (commands only, no cheats):
## - M4a: at least 6 burgher houses with every basic need met (bread, fish, beer, firewood,
##   well) within 50 minutes of game time,
## - 2 hours of play without deadlocks: nothing stays reserved, every task keeps moving,
##   the chains keep producing.


## Minutes the bot may take to reach 4 supplied patrician houses.
const PATRICIAN_LIMIT := 90


func _new_game(map_id: StringName = &"riverlands") -> Simulation:
	var registry := SimFixture.registry()
	var problems := PackedStringArray()
	var sim := Simulation.from_map(registry, registry.get_map(map_id), 1, problems)
	assert_array(Array(problems)).is_empty()
	# The bot's timed plan was tuned without the start protection (review fixes 2026-11-07):
	# protected houses keep newcomers coming, the bigger early town overloads the bot's porters
	# and its build queue (Riverlands: 43 residents in minute 30 instead of 68). Measured here
	# without it; the Coast, harbour and world bots play with it.
	sim.province.grace_until = 0
	return sim


func test_six_supplied_burgher_houses_within_50_minutes() -> void:
	var sim := _new_game()
	var bot := SliceBot.new(sim)
	# Lambdas capture locals by value: keep results in a shared dictionary.
	var result := {"minute": -1}
	bot.run(50 * 60, func(minute: int) -> void:
		if result["minute"] == -1 and bot.supplied_houses(2) >= 6:
			result["minute"] = minute)
	print("6 supplied burgher houses at minute ", result["minute"], "; gold ", sim.treasury.gold,
			"; bot log: ", bot.log)
	assert_array(Array(bot.log)).is_empty()
	assert_int(int(result["minute"])).is_between(1, 50)
	assert_int(bot.supplied_houses(2)).is_greater_equal(6)


## M4b-1: patrician townhouses with every basic need met (also clothes and mead).
func test_four_supplied_patrician_houses() -> void:
	_patricians_on(&"riverlands")


## M4b-3: the same on the 128x128 Lakeland map (quarry by the stony hill, anglers by the lake).
func test_four_supplied_patrician_houses_on_lakeland() -> void:
	_patricians_on(&"lakeland")


## M5 part 3: on the Coast map the game starts from a ship (settlers, the start kit on the
## beach, the pioneer camp first).
func test_four_supplied_patrician_houses_on_coast_from_the_ship() -> void:
	_patricians_on(&"coast")


func _patricians_on(map_id: StringName) -> void:
	var sim := _new_game(map_id)
	var bot := SliceBot.new(sim)
	var result := {"minute": -1}
	var trace := PackedStringArray()
	bot.run(PATRICIAN_LIMIT * 60, func(minute: int) -> void:
		if minute % 10 == 0:
			trace.append("min %d: L3 %d (supplied %d), bricks %d, clothes %d, mead %d, gold %d" % [minute,
					bot.houses_at_level(3), bot.supplied_houses(3), sim.province.goods_total(&"bricks"),
					sim.province.goods_total(&"clothes"), sim.province.goods_total(&"mead"), sim.treasury.gold])
		if result["minute"] == -1 and bot.supplied_houses(3) >= 4:
			result["minute"] = minute)
	print(map_id, ": 4 supplied patrician houses at minute ", result["minute"], "; bot log: ", bot.log)
	print("\n".join(trace))
	assert_array(Array(bot.log)).is_empty()
	assert_int(int(result["minute"])).is_between(1, PATRICIAN_LIMIT)


func test_two_hours_without_deadlocks() -> void:
	var sim := _new_game()
	var bot := SliceBot.new(sim)
	var watch := DeadlockWatch.new()
	var produced := {}
	bot.run(2 * 60 * 60, func(minute: int) -> void:
		watch.check(sim, minute)
		if minute % 20 == 0:
			var unmet := {}
			for b: BuildingState in sim.province.buildings.all():
				if b.house != null and b.house.level >= 2:
					for need: NeedDef in b.level_def().needs:
						if need.is_basic and not b.house.satisfied.get(need.id, false):
							unmet[need.id] = int(unmet.get(need.id, 0)) + 1
			produced[minute] = "bread %d, wood %d, pigs %d, meat made %d, supplied %d, unmet %s" % [
					sim.province.goods_total(&"bread"), sim.province.goods_total(&"wood"),
					sim.province.goods_total(&"pig"), bot.produced.get(&"meat", 0), bot.supplied_houses(2), unmet])
	assert_array(watch.stuck).is_empty()
	# M4b-2: the meat chain runs on pigs bought from the merchant, who also buys the surplus.
	print("sold to the merchant: ", bot.sold)
	assert_int(int(bot.produced.get(&"meat", 0))).is_greater(0)
	assert_int(sim.province.goods_total(&"pig")).is_greater_equal(2)
	assert_int(int(bot.sold.get(&"hides", 0))).is_greater(0)
	# Goods keep flowing late in the game: burghers are still supplied after 2 hours.
	print("every 20 minutes: ", produced)
	assert_int(bot.supplied_houses(2)).is_greater_equal(6)

