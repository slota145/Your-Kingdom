extends SceneTree
## Why the AI rulers do (not) send expeditions (E2 part 3): every 5 minutes, for each ruler's
## province, the residents, houses by level and the expedition errors by land and by sea.
## "$GODOT" --headless --path . -s res://src/prototype/e2/settle_probe.gd -- [--minutes=40]


func _init() -> void:
	var minutes := 40
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="):
			minutes = int(a.trim_prefix("--minutes="))
	var s := GameSettings.new()
	s.world_seed = 5
	s.rulers = 3
	s.province_count = 22
	var reg := DataRegistry.new()
	reg.load_from("res://data")
	var sim := Simulation.from_settings(reg, s, 1)
	for owner: StringName in Rulers.alive(sim.world):
		sim.world.rulers[owner].next_war = 1 << 40
	for m: int in minutes:
		for k: int in 60:
			sim.run_ticks(SimClock.TICKS_PER_SECOND)
			for e: Dictionary in sim.events.drain():
				if String(e["type"]).begins_with("expedition") or e["type"] == &"province_settled":
					print("  %d:%02d %s" % [m, k, e])
		if (m + 1) % 5 != 0:
			continue
		for owner: StringName in Rulers.alive(sim.world):
			for id: int in Rulers.provinces_of(sim.world, owner):
				var p := sim.province_state(id)
				var levels := [0, 0, 0, 0]
				var fed := 0
				var pts := 0.0
				var n := 0
				for b: BuildingState in p.buildings.all():
					if b.house != null and b.is_complete():
						levels[b.house.level] += 1
						n += 1
						pts += b.house.points
						if Population.is_fed(b):
							fed += 1
				print("%d min %s %d: ppl %d houses %s fed %d/%d pts %.0f land %s sea %s next %.0f s" % [m + 1,
						owner, id, RulerPlanner.residents(p), levels, fed, n, pts / maxf(n, 1),
						PrepareExpeditionCommand.error_for(sim, id, false, owner),
						PrepareExpeditionCommand.error_for(sim, id, true, owner),
						(sim.world.rulers[owner].next_expedition - sim.clock.tick) / float(SimClock.TICKS_PER_SECOND)])
	quit()
