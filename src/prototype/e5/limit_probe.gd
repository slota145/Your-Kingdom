extends SceneTree
## E5 PROTOTYPE: the big M4b-3 city with the player's limits of a few goods. Every 5 minutes the
## stock of each limited good, how much of it was made in those 5 minutes and the workers
## waiting at a limit; at the end whether any limited good ran out (a chain stuck).
## "$GODOT" --headless --path . -s res://src/prototype/e5/limit_probe.gd -- [--minutes=40]
##     [--limit=<good>:<n> ...] (default: wood 60, planks 30, flour 20, bread 40, beer 30)


func _init() -> void:
	var minutes := 40
	var limits: Dictionary[StringName, int] = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="):
			minutes = int(a.trim_prefix("--minutes="))
		elif a.begins_with("--limit="):
			var parts := a.trim_prefix("--limit=").split(":")
			limits[StringName(parts[0])] = int(parts[1])
	if limits.is_empty():
		limits = {&"wood": 60, &"planks": 30, &"flour": 20, &"bread": 40, &"beer": 30}
	var reg := DataRegistry.new()
	reg.load_from("res://data")
	var sim := BigCity.load_fixture(reg)
	var start := {}
	for good: StringName in limits:
		start[good] = sim.province.kingdom_stock(good)
		sim.execute(SetGoodsLimitCommand.new(good, limits[good]))
	print("start stocks: ", start)
	var ran_out := {}
	for minute: int in range(1, minutes + 1):
		sim.run_ticks(SimClock.TICKS_PER_SECOND * 60)
		sim.events.drain()
		for good: StringName in limits:
			if sim.province.kingdom_stock(good) == 0:
				ran_out[good] = int(ran_out.get(good, 0)) + 1
		if minute % 5 != 0:
			continue
		var waiting := {}
		for agent: Agent in sim.province.agents.all():
			if agent.task == null and agent.last_fail == &"goods_limit":
				waiting[agent.last_fail_good] = int(waiting.get(agent.last_fail_good, 0)) + 1
		var line := "min %3d:" % minute
		for good: StringName in limits:
			line += "  %s %d/%d made %.1f/min wait %d" % [good, sim.province.kingdom_stock(good),
					limits[good], sim.province.ledger.made_per_minute(good, sim.province.tick),
					int(waiting.get(good, 0))]
		print(line)
	print("minutes with a limited good at 0: ", ran_out)
	quit()
