extends SceneTree
## How the slice bot's patricians eat (E2 part 3): every 5 minutes houses by level, supplied
## patrician houses, hungry houses and the food in the province.
## "$GODOT" --headless --path . -s res://src/prototype/e2/patrician_probe.gd -- [--map=riverlands] [--minutes=90]


func _init() -> void:
	var map_id := &"riverlands"
	var minutes := 90
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			map_id = StringName(a.trim_prefix("--map="))
		elif a.begins_with("--minutes="):
			minutes = int(a.trim_prefix("--minutes="))
	var reg := DataRegistry.new()
	reg.load_from("res://data")
	var sim := Simulation.from_map(reg, reg.get_map(map_id), 1)
	sim.province.grace_until = 0
	var bot: RefCounted = load("res://tests/support/slice_bot.gd").new(sim)
	bot.call("run", minutes * 60, func(minute: int) -> void:
		if minute % 5 != 0:
			return
		var hungry := 0
		var pts := [0.0, 0.0, 0.0, 0.0]
		var n := [0, 0, 0, 0]
		for b: BuildingState in sim.province.buildings.all():
			if b.house != null and b.is_complete() and b.house.residents > 0:
				n[b.house.level] += 1
				pts[b.house.level] += b.house.points
				if not Population.is_fed(b):
					hungry += 1
		var extra := ""
		for b: BuildingState in sim.province.buildings.all():
			if b.def.id in [&"orchard", &"tailor", &"weaver", &"meadery", &"pigsty", &"sheep_farm"]:
				var st := "ok"
				if not b.is_complete():
					var site := sim.province.sites.get(b.site_id) as ConstructionSite
					st = "site p%d %s has %s work %d" % [site.phase, site.current_cost(), site.stock.to_dict(), site.work_left] if site != null else "nosite"
				extra += " %s(%s w%d)" % [b.def.id, st, b.workers.size()]
		var n_sites := sim.province.sites.size()
		extra += " sites %d" % n_sites
		var food := ""
		for g: StringName in [&"bread", &"fish", &"meat", &"apples", &"beer", &"clothes", &"mead", &"wood", &"planks"]:
			food += " %s %d" % [g, sim.province.goods_total(g)]
		print("min %d: houses %s pts %s hungry %d L3 supplied %d |%s" % [minute, n,
				[roundi(pts[1] / maxi(n[1], 1)), roundi(pts[2] / maxi(n[2], 1)), roundi(pts[3] / maxi(n[3], 1))],
				hungry, bot.call("supplied_houses", 3), food] + " | work %d%s log %s" % [Population.workforce(sim.province), extra, bot.get("log")]))
	quit()
