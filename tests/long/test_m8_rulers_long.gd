extends GdUnitTestSuite
## M8 part 3, long: a sandbox world with three AI rulers runs 90 minutes of game time (owner's
## survey 2026-11-10). Each ruler builds by his plan, settles at least one new province and
## runs a trade route; no ruler's town gets stuck (it keeps growing), a save in the middle
## loads back alike, and the simplified-mode cost of the growing rulers stays small.

const MINUTES := 90


func test_three_rulers_grow_settle_and_trade_for_90_minutes() -> void:
	var s := GameSettings.new()
	s.world_seed = 5
	s.rulers = 3
	s.province_count = 22
	var sim := Simulation.from_settings(SimFixture.registry(), s, 1)
	var start: Dictionary[StringName, int] = {}
	for owner: StringName in Rulers.alive(sim.world):
		start[owner] = _buildings(sim, owner)
		sim.world.rulers[owner].next_war = 1 << 40   # (growth alone here; the war: test_m8_war_long)
	var settled: Dictionary[StringName, int] = {}
	var routes: Dictionary[StringName, int] = {}
	var at_45: Dictionary[StringName, int] = {}
	var started := Time.get_ticks_usec()
	for minute: int in MINUTES:
		for second: int in 60:
			sim.run_ticks(SimClock.TICKS_PER_SECOND)
			for e: Dictionary in sim.events.drain():
				var owner: StringName = e.get("owner", &"")
				if not Rulers.is_ruler(owner):
					continue
				if e["type"] == &"province_settled" or e["type"] == &"settlement_joined":
					settled[owner] = settled.get(owner, 0) + 1
				elif e["type"] == &"route_created":
					routes[owner] = routes.get(owner, 0) + 1
		if minute == 44:
			for owner: StringName in Rulers.alive(sim.world):
				at_45[owner] = _buildings(sim, owner)
			var state := sim.to_dict()
			var copy := Simulation.from_dict(state, SimFixture.registry())
			assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(state))
	var ms_per_tick := (Time.get_ticks_usec() - started) / 1000.0 / (MINUTES * 60 * SimClock.TICKS_PER_SECOND)
	print("rulers after %d min: %s settled %s routes %s, %.3f ms per tick" % [MINUTES,
			_summary(sim), settled, routes, ms_per_tick])
	for owner: StringName in start:
		assert_int(Rulers.provinces_of(sim.world, owner).size()).override_failure_message(
				"%s settled nothing" % owner).is_greater_equal(2)
		assert_int(settled.get(owner, 0)).is_greater_equal(1)
		assert_int(routes.get(owner, 0)).override_failure_message("%s: no route" % owner).is_greater_equal(1)
		assert_int(_buildings(sim, owner)).is_greater(start[owner] + 40)
		# Still growing in the second half (nothing stuck).
		assert_int(_buildings(sim, owner)).is_greater(at_45[owner])
		assert_int(sim.world.rulers[owner].treasury.gold).is_greater(0)
	# Every ruler's province is in the simplified mode and cheap (the player's landing is viewed).
	assert_float(ms_per_tick).is_less(4.0)


func _buildings(sim: Simulation, owner: StringName) -> int:
	var n := 0
	for id: int in Rulers.provinces_of(sim.world, owner):
		var p := sim.province_state(id)
		if p != null:
			n += p.buildings.all().size()
	return n


func _summary(sim: Simulation) -> String:
	var parts := PackedStringArray()
	for owner: StringName in Rulers.alive(sim.world):
		parts.append("%s %d prov %d bld %d gold" % [owner, Rulers.provinces_of(sim.world, owner).size(),
				_buildings(sim, owner), sim.world.rulers[owner].treasury.gold])
	return ", ".join(parts)
