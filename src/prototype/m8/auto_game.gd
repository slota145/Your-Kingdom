extends SceneTree
## A full test game of the automatic player (M8 part 5) with a line every 5 minutes.
## "$GODOT" --headless --path . -s res://src/prototype/m8/auto_game.gd -- --scenario=invasion|divided|islands [--seed=5] [--minutes=120] [--rulers=2] [--level=1] [--gold=10000] [--provinces=16]


func _init() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var s := GameSettings.new()
	s.scenario = StringName(args.get("scenario", "invasion"))
	s.world_seed = int(args.get("seed", "5"))
	s.rulers = int(args.get("rulers", "2"))
	s.province_count = int(args.get("provinces", "16"))
	s.difficulty = int(args.get("level", "1"))
	s.gold_target = int(args.get("gold", "10000"))
	s.fit_scenario()
	var r := DataRegistry.new()
	r.load_from("res://data")
	var sim := Simulation.from_settings(r, s, 1)
	sim.raids_enabled = true
	var bot := AutoPlayer.new(sim)
	var t0 := Time.get_ticks_msec()
	var result := bot.run(int(args.get("minutes", "120")) * 60, func(m: int) -> void:
		if m % 5 == 0:
			print("%3d min  %s" % [m, bot.summary()]))
	for line: String in bot.log:
		print(line)
	print(bot.counts)
	print("result: '%s' after %d min, %.1f s real" % [result, sim.clock.tick / 600, (Time.get_ticks_msec() - t0) / 1000.0])
	quit()
