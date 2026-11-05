extends GdUnitTestSuite
## DoD scenarios on the real start map, played by SliceBot (commands only, no cheats):
## - M4a: at least 6 burgher houses with every basic need met (bread, fish, beer, firewood,
##   well) within 50 minutes of game time,
## - 2 hours of play without deadlocks: nothing stays reserved, every task keeps moving,
##   the chains keep producing.


## Minutes the bot may take to reach 4 supplied patrician houses.
const PATRICIAN_LIMIT := 90


func _new_game() -> Simulation:
	var registry := SimFixture.registry()
	var problems := PackedStringArray()
	var sim := Simulation.from_map(registry, registry.get_map(&"riverlands"), 1, problems)
	assert_array(Array(problems)).is_empty()
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
	var sim := _new_game()
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
	print("4 supplied patrician houses at minute ", result["minute"], "; bot log: ", bot.log)
	print("\n".join(trace))
	assert_array(Array(bot.log)).is_empty()
	assert_int(int(result["minute"])).is_between(1, PATRICIAN_LIMIT)


func test_two_hours_without_deadlocks() -> void:
	var sim := _new_game()
	var bot := SliceBot.new(sim)
	# Agent id -> [task, step index, minute first seen]: a task stuck on one step for
	# 5 minutes is a deadlock (all real steps take seconds; waiting restarts the task).
	var seen: Dictionary[int, Array] = {}
	var stuck: Array[String] = []
	var produced := {}
	bot.run(2 * 60 * 60, func(minute: int) -> void:
		var holds := sim.province.dangling_holds()
		if not holds.is_empty():
			stuck.append("minute %d: %s" % [minute, ", ".join(holds)])
		for agent: Agent in sim.province.agents.all():
			if agent.task == null:
				seen.erase(agent.id)
				continue
			var last: Array = seen.get(agent.id, [])
			if last.is_empty() or not is_same(last[0], agent.task) or last[1] != agent.task.step_index:
				seen[agent.id] = [agent.task, agent.task.step_index, minute]
			elif minute - int(last[2]) >= 5:
				stuck.append("minute %d: %s %d on %s step %d" % [minute, agent.kind, agent.id,
						agent.task.kind, agent.task.step_index])
		if minute % 20 == 0:
			var unmet := {}
			for b: BuildingState in sim.province.buildings.all():
				if b.house != null and b.house.level >= 2:
					for need: NeedDef in b.level_def().needs:
						if need.is_basic and not b.house.satisfied.get(need.id, false):
							unmet[need.id] = int(unmet.get(need.id, 0)) + 1
			produced[minute] = "bread %d, wood %d, supplied %d, unmet %s" % [sim.province.goods_total(&"bread"),
					sim.province.goods_total(&"wood"), bot.supplied_houses(2), unmet])
	assert_array(stuck).is_empty()
	# Goods keep flowing late in the game: burghers are still supplied after 2 hours.
	print("every 20 minutes: ", produced)
	assert_int(bot.supplied_houses(2)).is_greater_equal(6)
