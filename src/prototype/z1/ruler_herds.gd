extends SceneTree
## Z1 part 4: how the AI rulers keep animals and hives. Every 10 minutes prints, per ruler
## province, its pigsties, sheep farms, stud farms and apiaries (tiles, animals, room, workers)
## and the province's meat, wool, honey, horses.
## "$GODOT" --headless --path . -s res://src/prototype/z1/ruler_herds.gd -- [--minutes=90] [--level=1] [--seed=5] [--scenario=divided]


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
	if args.has("scenario"):
		s.scenario = StringName(String(args["scenario"]))
		s.fit_scenario()
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var sim := Simulation.from_settings(registry, s, 1)
	var minutes := int(args.get("minutes", "90"))
	for m: int in minutes:
		sim.run_ticks(SimClock.TICKS_PER_SECOND * 60)
		sim.events.drain()
		if (m + 1) % 10 != 0:
			continue
		print("--- %d min" % (m + 1))
		for owner: StringName in Rulers.alive(sim.world):
			for id: int in Rulers.provinces_of(sim.world, owner):
				var t := sim.province_state(id)
				var parts: Array[String] = []
				for b: BuildingState in t.buildings.all():
					if not b.def.has_tiles():
						continue
					var herd := b.yard.total(b.def.herd_good) if b.yard != null and b.def.herd_good != &"" else 0
					parts.append("%s%s t%d a%d/%d w%d" % [b.def.id, " (site)" if b.under_construction else "",
							t.fields.tiles_of(b.id).size(), herd, b.herd_room(), b.workers.size() + t.abstract_staff.get(b.id, 0)])
				print("%s %d (%d bld): %s | meat %d wool %d honey %d horse %d" % [owner, id, t.buildings.all().size(),
						", ".join(parts), t.stored(&"meat"), t.stored(&"wool"), t.stored(&"honey"), t.goods_total(&"horse")])
	quit()
