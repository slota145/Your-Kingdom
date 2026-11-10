extends SceneTree
## Why a ruler's plan stalls: the entries he lacks after N minutes and what stops them.

func _init() -> void:
	var s := GameSettings.new()
	s.world_seed = 5
	s.rulers = 3
	s.province_count = 22
	var r := DataRegistry.new()
	r.load_from("res://data")
	var sim := Simulation.from_settings(r, s, 1)
	for k: int in 25 * 60:
		sim.run_ticks(SimClock.TICKS_PER_SECOND)
		sim.events.drain()
	for owner: StringName in Rulers.alive(sim.world):
		var ruler := sim.world.rulers[owner]
		for id: int in Rulers.provinces_of(sim.world, owner):
			var town := sim.province_state(id)
			var counts := RulerPlanner.counts_of(town)
			print(owner, " ", id, " next_build ", ruler.next_build.get(id, 0), " now ", sim.clock.tick, " sites ", town.sites.size(), " saving ", ruler.saving_for)
			var n := 0
			for entry: Array in RulerPlanner.PLAN:
				if int(counts.get(entry[0], 0)) >= int(entry[1]):
					continue
				var def := r.get_building(entry[0])
				print("   lacks ", entry, " cost ", def.build_cost, " gold ", def.gold_cost, " no_room ", ruler.no_room.get("%d:%s" % [id, entry[0]], 0), " allowed ", RulerPlanner._allowed(town, def))
				n += 1
				if n >= 4:
					break
	quit()
