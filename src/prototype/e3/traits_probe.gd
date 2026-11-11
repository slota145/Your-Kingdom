extends SceneTree
## How the automatic player and the AI rulers use the province traits (E3 part 3): every 10
## minutes, for each owner, quarries and stone pits with the stone per minute they make (the
## simplified mode's estimate), deep mines and the stone and iron ore in store.
## "$GODOT" --headless --path . -s res://src/prototype/e3/traits_probe.gd -- [--seed=5] [--minutes=120] [--provinces=22] [--scenario=colonization] [--all_rich] [--all_iron]
## --all_rich, --all_iron: every province rich in stone, in iron (to see the most the new
## buildings can take over).


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
	s.fit_scenario()
	var r := DataRegistry.new()
	r.load_from("res://data")
	var sim := Simulation.from_settings(r, s, 1)
	for flag: String in ["all_rich", "all_iron"]:
		if not args.has(flag):
			continue
		var t := ProvinceDef.RICH_STONE if flag == "all_rich" else ProvinceDef.RICH_IRON
		for id: int in sim.world.ids():
			var def := sim.world.def_of(id, r)
			if not def.traits.has(t):
				var own := def.traits.duplicate()
				own.append(t)
				def.traits = own
			var town := sim.province_state(id)
			if town != null:
				town.traits = def.all_traits()
	var rich := PackedStringArray()
	for id: int in sim.world.ids():
		var def := sim.world.def_of(id, r)
		if not def.all_traits().is_empty():
			rich.append("%s(%d %s %s)" % [def.id, id, def.owner, def.all_traits()])
	print("traits: %s" % ", ".join(rich))
	var bot := AutoPlayer.new(sim)
	bot.run(int(args.get("minutes", "120")) * 60, func(m: int) -> void:
		if m % 10 != 0:
			return
		print("%3d min  %s" % [m, bot.summary()])
		var owners: Array[StringName] = [ProvinceDef.OWNER_PLAYER]
		owners.append_array(Rulers.alive(sim.world))
		for owner: StringName in owners:
			for id: int in Rulers.provinces_of(sim.world, owner):
				var town := sim.province_state(id)
				if town == null:
					continue
				var n := {}
				var rate := {}
				var abstract := sim.runtimes.get(id) as ProvinceAbstract
				for b: BuildingState in town.buildings.all():
					if b.def.id in [&"quarry", &"stone_pit", &"mine", &"deep_mine"]:
						n[b.def.id] = int(n.get(b.def.id, 0)) + (1 if b.is_complete() else 0)
						if abstract != null and b.is_complete():
							rate[b.def.id] = float(rate.get(b.def.id, 0.0)) + abstract.cycles_per_second(b) * 60.0
				if n.is_empty() and town.traits.is_empty():
					continue
				var rates := ""
				for k: StringName in rate:
					rates += " %s %.1f/min" % [k, float(rate[k])]
				print("    %s %d %s: %s%s | stone %d ore %d ppl %d plan %s" % [owner, id, town.traits, n, rates,
						town.stored(&"stone"), town.stored(&"iron_ore"), RulerPlanner.residents(town),
						RulerPlanner.plan_progress(town)]))
	for line: String in bot.log:
		print(line)
	quit()
