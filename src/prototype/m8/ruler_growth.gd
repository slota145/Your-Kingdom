extends SceneTree
## Prints how the AI rulers grow (M8 part 3): buildings, people, gold, provinces each 5 minutes.
## "$GODOT" --headless --path . -s res://src/prototype/m8/ruler_growth.gd -- [--minutes=60] [--level=1] [--seed=5]


func _init() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var s := GameSettings.new()
	s.world_seed = int(args.get("seed", "5"))
	s.rulers = int(args.get("rulers", "3"))
	s.province_count = int(args.get("provinces", "22"))
	s.difficulty = int(args.get("level", "1"))
	var sim := Simulation.from_settings(_registry(), s, 1)
	var minutes := int(args.get("minutes", "60"))
	var t0 := Time.get_ticks_msec()
	for m: int in minutes:
		for k: int in 60:
			sim.run_ticks(SimClock.TICKS_PER_SECOND)
			for e: Dictionary in sim.events.drain():
				if String(e["type"]).begins_with("expedition_") or e["type"] in [&"province_settled",
						&"settlement_joined", &"route_created", &"ruler_marched", &"province_taken", &"battle_resolved",
						&"ruler_defeated", &"ruler_sallied", &"army_lost", &"sea_battle", &"fleet_docked", &"army_landed"]:
					print("  %d:%02d %s %s" % [m, k, e["type"], e])
		if (m + 1) % 5 == 0:
			for owner: StringName in Rulers.alive(sim.world):
				var line := "%3d min %s gold %d soldiers %d:" % [m + 1, owner, sim.world.rulers[owner].treasury.gold,
						RulerWar.strength(sim, owner)]
				for id: int in Rulers.provinces_of(sim.world, owner):
					var t := sim.province_state(id)
					var people := 0
					var levels := [0, 0, 0, 0]
					for b: BuildingState in t.buildings.all():
						if b.house != null:
							people += b.house.residents
							levels[b.house.level] += 1
					line += " [%d: %d bld, %d sites, %d ppl, houses %s, plan %s, wood %d planks %d stone %d bread %d]" % [id,
							t.buildings.all().size(), t.sites.size(), people, levels,
							RulerPlanner.plan_progress(t), t.stored(&"wood"), t.stored(&"planks"),
							t.stored(&"stone"), t.stored(&"bread")]
				print(line)
	print("ms per sim minute: %.0f" % [float(Time.get_ticks_msec() - t0) / minutes])
	quit()


func _registry() -> DataRegistry:
	var r := DataRegistry.new()
	r.load_from("res://data")
	return r
