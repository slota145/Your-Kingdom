extends SceneTree
## UI-2 part 2 PROTOTYPE: how fast a colony starts. The slice bot plays the first minutes; every
## minute: buildings finished, construction sites waiting, and what the porters and builders do
## (idle, carrying to a site, carrying elsewhere). Prints the minutes the camp and the 5th and
## 10th finished buildings stood.
## "$GODOT" --headless --path . -s res://src/prototype/ui2/start_probe.gd -- [--map=coast] [--minutes=30]
## --player (Coast): a player-like start instead of the bot's plan: the camp by the kit, a storage
## inland (not by the heap on the beach), a woodcutter and two huts at once; every 15 s what
## each site has and what the porters and the builder do.


func _init() -> void:
	var map_id := &"coast"
	var minutes := 30
	var player := false
	for a: String in OS.get_cmdline_user_args():
		if a == "--player":
			player = true
		if a.begins_with("--map="):
			map_id = StringName(a.trim_prefix("--map="))
		elif a.begins_with("--minutes="):
			minutes = int(a.trim_prefix("--minutes="))
	var reg := DataRegistry.new()
	reg.load_from("res://data")
	var sim := Simulation.from_map(reg, reg.get_map(map_id), 1)
	sim.province.grace_until = 0
	var start_count := sim.province.buildings.count()
	var bot: RefCounted = load("res://tests/support/slice_bot.gd").new(sim, true)
	var marks := {"camp": -1, "5": -1, "10": -1, "15": -1}
	if player:
		_player_start(sim, bot, minutes)
		quit()
		return
	bot.call("run", minutes * 60, func(minute: int) -> void:
		var done := 0
		for b: BuildingState in sim.province.buildings.all():
			if b.is_complete():
				done += 1
				if b.def.id == &"pioneer_camp" and marks["camp"] == -1:
					marks["camp"] = minute
		done -= start_count
		for k: String in ["5", "10", "15"]:
			if marks[k] == -1 and done >= int(k):
				marks[k] = minute
		var counts := {"idle": 0, "to_site": 0, "elsewhere": 0, "other": 0}
		var builders := {"building": 0, "idle": 0, "other": 0}
		for agent: Agent in sim.province.agents.all():
			if agent.kind == &"porter":
				if agent.is_idle():
					counts["idle"] += 1
				elif agent.task != null and agent.task.kind == Task.KIND_TRANSPORT:
					var to := int(agent.task.bb.get("to", 0))
					counts["to_site" if sim.province.sites.has(to) else "elsewhere"] += 1
				else:
					counts["other"] += 1
			elif agent.kind == &"builder":
				if agent.is_idle():
					builders["idle"] += 1
				elif agent.task != null and agent.task.kind == Task.KIND_BUILD:
					builders["building"] += 1
				else:
					builders["other"] += 1
		print("min %2d: finished %2d sites %2d porters %s builders %s wood %d" % [minute, done,
				sim.province.sites.size(), counts, builders, sim.province.goods_total(&"wood")]))
	print("RESULT %s camp %d, 5th %d, 10th %d, 15th %d" % [map_id, marks["camp"], marks["5"], marks["10"], marks["15"]])
	quit()


func _player_start(sim: Simulation, bot: RefCounted, minutes: int) -> void:
	var beach := sim.province.landing.beach
	var town := beach + Vector2i(-12, -8)
	var plan: Array[Dictionary] = [
		{"at": 0, "build": &"pioneer_camp", "near": beach + Vector2i(-6, -4)},
		{"at": 20, "build": &"stockpile", "near": town},
		{"at": 20, "build": &"woodcutter", "near": beach + Vector2i(-10, 10)},
		{"at": 20, "build": &"hut", "near": town + Vector2i(0, 7)},
		{"at": 20, "build": &"hut", "near": town + Vector2i(3, 7)},
	]
	bot.set("_plan", plan)
	var finished := {}
	for second: int in minutes * 60:
		bot.call("act", second)
		for i: int in SimClock.TICKS_PER_SECOND:
			sim.step()
			sim.events.drain()
		for b: BuildingState in sim.province.buildings.all():
			if b.is_complete() and not finished.has(b.id):
				finished[b.id] = second
				print("  %4d s: %s finished" % [second, b.def.id])
		if second % 15 != 14:
			continue
		var porters := PackedStringArray()
		for agent: Agent in sim.province.agents.all():
			if agent.kind == &"porter" or agent.kind == &"builder":
				var what := "idle"
				if agent.task != null:
					what = String(agent.task.kind)
					if agent.task.kind == Task.KIND_TRANSPORT:
						var to := int(agent.task.bb.get("to", 0))
						what = "%s>%s" % [agent.task.bb.get("good", ""), "site" if sim.province.sites.has(to) else "store"]
				porters.append("%s:%s" % [String(agent.kind).left(1), what])
		var sites := PackedStringArray()
		for site: ConstructionSite in sim.province.sites.values():
			var b := sim.province.buildings.get_building(site.building_id)
			sites.append("%s p%d %s" % [b.def.id if b != null else "?", site.phase, site.stock.to_dict().get("amounts", site.stock.to_dict())])
		print("%4d s: %s | %s" % [second + 1, " ".join(porters), "; ".join(sites)])
