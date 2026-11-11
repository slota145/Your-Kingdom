extends SceneTree
## E2 probe (prototype): herds of a map after some seconds.
## Run: "$GODOT" --headless --path . -s res://src/prototype/e2/herd_probe.gd -- --map=lakeland


func _init() -> void:
	var map := "lakeland"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map = arg.trim_prefix("--map=")
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var sim := Simulation.from_map(registry, registry.get_map(StringName(map)))
	sim.run_ticks(SimClock.seconds_to_ticks(5))
	var w := sim.province.wild
	print("map ", map, " populated ", w.populated, " target ", w.target(sim.province), " herds ", w.herds.size())
	for h: WildHerds.Herd in w.all():
		print("  ", h.kind, " x", h.count, " at ", h.tile)
	quit()
