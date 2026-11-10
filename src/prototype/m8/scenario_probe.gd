extends SceneTree
## Prints the worlds of the M8 part 5 scenarios (owners, islands, coasts) and how long a game
## takes to start.
## "$GODOT" --headless --path . -s res://src/prototype/m8/scenario_probe.gd -- [--scenario=divided] [--seed=5] [--provinces=22] [--rulers=3]


func _init() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var s := GameSettings.new()
	s.scenario = StringName(args.get("scenario", "divided"))
	s.world_seed = int(args.get("seed", "5"))
	s.rulers = int(args.get("rulers", "3"))
	s.province_count = int(args.get("provinces", "22"))
	s.fit_scenario()
	var r := DataRegistry.new()
	r.load_from("res://data")
	var t0 := Time.get_ticks_msec()
	var problems := PackedStringArray()
	var sim := Simulation.from_settings(r, s, 1, problems)
	print("start %d ms, problems: %s" % [Time.get_ticks_msec() - t0, problems])
	var owners := {}
	for id: int in sim.world.ids():
		var def := sim.world.def_of(id, r)
		var o := String(sim.world.owner_of(id))
		owners[o] = owners.get(o, 0) + 1
		var t := sim.province_state(id)
		print("%2d %-12s %-10s island=%s coastal=%s bld=%d" % [id, o, def.template, def.island, def.coastal,
				t.buildings.all().size() if t != null else -1])
	print(owners, " camp=", r.get_world(sim.world.world_id).bandit_camp, " armies=", sim.world.armies.size())
	quit()
