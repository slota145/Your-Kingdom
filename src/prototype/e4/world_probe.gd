extends SceneTree
## How fast the AI rulers and the automatic player grow and arm (E4 part 5): every 5 minutes,
## for each owner, people, houses by level, soldiers by unit, barracks, schools and
## universities, and the researches done; the minute of the first attack of each ruler and of
## the player's first patrician house and first soldier.
## "$GODOT" --headless --path . -s res://src/prototype/e4/world_probe.gd -- [--seed=5] [--minutes=90] [--rulers=2] [--provinces=22] [--scenario=colonization] [--difficulty=1]
## [--archipelago] (UI-2 part 3): islands only with the rules of the scenario.


func _init() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var s := GameSettings.new()
	s.scenario = StringName(args.get("scenario", "colonization"))
	s.world_seed = int(args.get("seed", "5"))
	s.rulers = int(args.get("rulers", "2"))
	s.province_count = int(args.get("provinces", "22"))
	s.archipelago = args.has("archipelago")
	if args.has("difficulty"):
		s.difficulty = int(args["difficulty"])
	s.fit_scenario()
	var r := DataRegistry.new()
	r.load_from("res://data")
	var sim := Simulation.from_settings(r, s, 1)
	var bot := AutoPlayer.new(sim)
	var firsts := {}
	var minutes := int(args.get("minutes", "90"))
	bot.run(minutes * 60, func(m: int) -> void:
		for line: String in bot.log:
			if line.contains("ruler_marched"):
				var owner := line.get_slice("owner=", 1).get_slice(" ", 0)
				if not firsts.has("march " + owner):
					firsts["march " + owner] = m
		var owners: Array[StringName] = [ProvinceDef.OWNER_PLAYER]
		owners.append_array(Rulers.alive(sim.world))
		for owner: StringName in owners:
			var levels := [0, 0, 0, 0]
			for id: int in Rulers.provinces_of(sim.world, owner):
				var town := sim.province_state(id)
				if town == null:
					continue
				for b: BuildingState in town.buildings.all():
					if b.house != null and b.is_complete() and b.house.residents > 0:
						levels[b.house.level] += 1
			if levels[3] > 0 and not firsts.has("patrician " + owner):
				firsts["patrician " + owner] = m
			if RulerWar.strength(sim, owner) > 0 and not firsts.has("soldier " + owner):
				firsts["soldier " + owner] = m
		if m % 5 != 0:
			return
		print("%3d min  %s" % [m, bot.summary()])
		for owner: StringName in owners:
			var levels := [0, 0, 0, 0]
			var have := {}
			var units := {}
			for id: int in Rulers.provinces_of(sim.world, owner):
				var town := sim.province_state(id)
				if town == null:
					continue
				for b: BuildingState in town.buildings.all():
					if b.house != null and b.is_complete() and b.house.residents > 0:
						levels[b.house.level] += 1
					if b.def.id in [&"school", &"university", &"barracks", &"barracks_small", &"barracks_large"]:
						var key := String(b.def.id) + ("" if b.is_complete() else "(site)")
						have[key] = int(have.get(key, 0)) + 1
					for u: StringName in b.garrison:
						units[u] = int(units.get(u, 0)) + 1
			var done := ""
			var research: Variant = _research_of(sim, owner)
			if research != null:
				var list: Array = (research as ResearchState).done.keys()
				list.sort()
				done = " research %s now %s" % [list, (research as ResearchState).current]
			print("    %s provinces %d houses %s %s units %s%s" % [owner, Rulers.provinces_of(sim.world, owner).size(), levels, have, units, done]))
	print("FIRSTS %s" % firsts)
	print("END %s" % bot.summary())
	quit()


## The research of [param owner] (null where rulers have none yet).
func _research_of(sim: Simulation, owner: StringName) -> Variant:
	if owner == ProvinceDef.OWNER_PLAYER:
		return sim.research
	if sim.has_method(&"research_of_owner"):
		return sim.call(&"research_of_owner", owner)
	return null
