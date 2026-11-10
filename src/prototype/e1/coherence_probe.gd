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
	var detailed := Simulation.from_dict(state, registry)
	detailed.run_ticks(SimClock.seconds_to_ticks(1800))
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
