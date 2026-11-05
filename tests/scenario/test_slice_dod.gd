extends GdUnitTestSuite
## M3 DoD scenarios on the real start map, played by SliceBot (commands only, no cheats):
## - at least 6 level-2 houses supplied with bread within 30 minutes of game time,
## - 2 hours of play without deadlocks: nothing stays reserved, every task keeps moving,
##   the bread chain keeps producing.


func _new_game() -> Simulation:
	var registry := SimFixture.registry()
	var problems := PackedStringArray()
	var sim := Simulation.from_map(registry, registry.get_map(&"riverlands"), 1, problems)
	assert_array(Array(problems)).is_empty()
	return sim


func _fed_level2_houses(sim: Simulation) -> int:
	var n := 0
	for b: BuildingState in sim.province.buildings.all():
		if b.house != null and b.house.level >= 2 and b.house.satisfied.get(&"food", false):
			n += 1
	return n


func test_six_burgher_houses_fed_with_bread_within_30_minutes() -> void:
	var sim := _new_game()
	var bot := SliceBot.new(sim)
	# Lambdas capture locals by value: keep results in a shared dictionary.
	var result := {"minute": -1}
	bot.run(30 * 60, func(minute: int) -> void:
		if result["minute"] == -1 and _fed_level2_houses(sim) >= 6:
			result["minute"] = minute)
	print("6 burgher houses fed with bread at minute ", result["minute"], "; bot log: ", bot.log)
	assert_array(Array(bot.log)).is_empty()
	assert_int(int(result["minute"])).is_between(1, 30)
	assert_int(_fed_level2_houses(sim)).is_greater_equal(6)


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
			produced[minute] = sim.province.goods_total(&"bread"))
	assert_array(stuck).is_empty()
	# Bread keeps flowing late in the game: houses are still fed after 2 hours.
	print("bread in the province every 20 minutes: ", produced)
	assert_int(_fed_level2_houses(sim)).is_greater_equal(6)
