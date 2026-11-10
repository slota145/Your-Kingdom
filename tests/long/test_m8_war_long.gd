extends GdUnitTestSuite
## M8 part 4, long: a sandbox world with three AI rulers on the normal level runs 90 minutes of
## game time. They recruit and march; towns change hands; armies do not get stuck (no ruler's
## army stands about in the field for long); a save in the middle of the war loads back alike;
## the cost per tick stays small.

const MINUTES := 90
## A ruler's army standing still this long away from his towns counts as stuck.
const STUCK_SECONDS := 240


func test_three_rulers_at_war_for_90_minutes() -> void:
	var s := GameSettings.new()
	s.world_seed = 5
	s.rulers = 3
	s.province_count = 22
	var sim := Simulation.from_settings(SimFixture.registry(), s, 1)
	sim.province.grace_until = 1 << 40   # (nobody builds the player's town here)
	var marched := 0
	var taken := 0
	var recruited := 0
	var idle_since: Dictionary[int, int] = {}
	var stuck := PackedStringArray()
	var started := Time.get_ticks_usec()
	for minute: int in MINUTES:
		for second: int in 60:
			sim.run_ticks(SimClock.TICKS_PER_SECOND)
			for e: Dictionary in sim.events.drain():
				match e["type"]:
					&"ruler_marched":
						marched += 1
					&"province_taken":
						taken += 1
					&"ruler_recruited":
						recruited += 1
			for army: Army in sim.world.armies.values():
				if not Rulers.is_ruler(army.owner) or army.state != Army.State.IDLE \
						or sim.world.owner_of(army.at) == army.owner:
					idle_since.erase(army.id)
					continue
				if not idle_since.has(army.id):
					idle_since[army.id] = sim.clock.tick
				elif sim.clock.tick - idle_since[army.id] > SimClock.seconds_to_ticks(STUCK_SECONDS) \
						and not army.is_fleet():
					stuck.append("army %d of %s at %d" % [army.id, army.owner, army.at])
					idle_since[army.id] = sim.clock.tick
		if minute == 50:
			var state := sim.to_dict()
			var copy := Simulation.from_dict(state, SimFixture.registry())
			assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(state))
	var ms_per_tick := (Time.get_ticks_usec() - started) / 1000.0 / (MINUTES * 60 * SimClock.TICKS_PER_SECOND)
	var parts := PackedStringArray()
	for owner: StringName in sim.world.rulers:
		parts.append("%s %d prov %d soldiers" % [owner, Rulers.provinces_of(sim.world, owner).size(),
				RulerWar.strength(sim, owner)])
	print("war after %d min: %s; %d recruited, %d campaigns, %d towns taken, %.3f ms per tick" % [
			MINUTES, ", ".join(parts), recruited, marched, taken, ms_per_tick])
	assert_int(recruited).is_greater(20)
	assert_int(marched).is_greater_equal(3)
	assert_int(taken).is_greater_equal(1)
	assert_array(Array(stuck)).is_empty()
	assert_bool(Rulers.alive(sim.world).is_empty()).is_false()
	assert_float(ms_per_tick).is_less(4.0)
