extends SceneTree
## E1 probe (prototype): the M6 coherence test with more goods printed and the storage
## multiplier chosen by --mult=1|2, to see which mode a bigger stockpile changes.
## Run: "$GODOT" --headless --path . -s res://src/prototype/e1/coherence_probe.gd -- --mult=1


func _init() -> void:
	var mult := 2
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mult="):
			mult = int(arg.trim_prefix("--mult="))
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	for id: StringName in [&"stockpile", &"port_store", &"port_warehouse", &"port_warehouse_small"]:
		registry.get_building(id).stack_multiplier = mult
	var sim: Simulation = load("res://tests/support/big_city.gd").load_fixture(registry)
	sim.run_ticks(SimClock.seconds_to_ticks(600))
	var state := JSON.parse_string(JSON.stringify(sim.to_dict(), "", false, true)) as Dictionary
	var calib := {}
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id in [&"farm", &"mill", &"bakery"]:
			var r := sim.province.production.rate(b.id)
			calib[b.def.id] = float(calib.get(b.def.id, 0.0)) + maxf(r, 0.0) * 1800.0
			var c: Array = calib.get(String(b.def.id) + "_n", [0, 0, 0])
			c[0] += 1
			c[1] += b.workers.size()
			c[2] += 1 if r > 0 else 0
			calib[String(b.def.id) + "_n"] = c
	print("calibrated 30 min output by type: ", calib)
	var detailed := Simulation.from_dict(state, registry)
	var fails := {}
	for chunk: int in 6:
		var before := {}
		for good: StringName in [&"grain", &"flour", &"bread"]:
			before[good] = int(detailed.province.ledger.made_total.get(good, 0))
		for t: int in SimClock.seconds_to_ticks(300):
			detailed.step()
			for event: Dictionary in detailed.events.drain():
				if event["type"] == &"task_failed":
					var agent := detailed.province.agents.get_agent(int(event["agent"]))
					var work := detailed.province.buildings.get_building(agent.workplace_id) if agent != null else null
					if work != null and work.def.id in [&"mill", &"bakery", &"farm"]:
						var key := "%s:%s" % [work.def.id, event["reason"]]
						fails[key] = int(fails.get(key, 0)) + 1
		var line := "min %d-%d:" % [chunk * 5, chunk * 5 + 5]
		for good: StringName in [&"grain", &"flour", &"bread"]:
			line += " %s %d (stored %d)" % [good, int(detailed.province.ledger.made_total.get(good, 0)) - int(before[good]),
					detailed.province.stored(good)]
		line += ", work speed %.2f, gold %d" % [Population.average_work_speed(detailed.province), detailed.treasury.gold]
		print(line)
	print("failures: ", fails)
	var after := {}
	for b: BuildingState in detailed.province.buildings.all():
		if b.def.id in [&"farm", &"mill", &"bakery"]:
			after[b.def.id] = float(after.get(b.def.id, 0.0)) + maxf(detailed.province.production.rate(b.id), 0.0) * 1800.0
	print("rate measured at the end x 30 min: ", after)
	var yards := {}
	var full_yards := {}
	for b: BuildingState in detailed.province.buildings.all():
		if b.yard != null:
			for good: StringName in b.yard.totals():
				yards[good] = int(yards.get(good, 0)) + b.yard.total(good)
				if not b.yard.can_accept(good, 1):
					full_yards[good] = int(full_yards.get(good, 0)) + 1
	var porters := 0
	var idle := 0
	for agent: Agent in detailed.province.agents.all():
		if agent.kind == &"porter":
			porters += 1
			if agent.is_idle():
				idle += 1
	print("detailed yards ", yards, " full ", full_yards, " porters ", porters, " idle ", idle,
			" open requests ", detailed.province.jobs.all().size())
	if OS.get_cmdline_user_args().has("--detailed_only"):
		quit()
		return
	var simplified := Simulation.from_dict(state, registry)
	var abstract := ProvinceAbstract.freeze(simplified.province, simplified.clock.tick)
	var ticks := SimClock.seconds_to_ticks(1800)
	for t: int in range(0, ticks, ProvinceAbstract.STEP_TICKS):
		abstract.step(simplified.clock.tick / ProvinceAbstract.STEP_TICKS * ProvinceAbstract.STEP_TICKS + t)
	print("mult ", mult)
	for good: StringName in [&"grain", &"flour", &"bread", &"fish", &"meat", &"planks", &"beer", &"wood"]:
		print("%s: detailed made %d (stored %d), simplified made %d (stored %d)" % [good,
				int(detailed.province.ledger.made_total.get(good, 0)), detailed.province.stored(good),
				int(abstract.detail.ledger.made_total.get(good, 0)), abstract.detail.stored(good)])
	quit()
