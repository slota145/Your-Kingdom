extends GdUnitTestSuite
## M6 part 1, risk R8 (ARCHITECTURE §7.2): the same province over 30 minutes of game time in
## the detailed and in the simplified mode makes about as much bread (and planks and beer):
## within ±15%. The big city is viewed for 10 minutes first, so the simplified mode has its
## calibration (ProductionLog).

const CALIBRATE_MINUTES := 10
const MINUTES := 30
const TOLERANCE := 0.15
const GOODS: Array[StringName] = [&"bread", &"planks", &"beer"]


func test_both_modes_make_about_as_much() -> void:
	var registry := SimFixture.registry()
	var sim := BigCity.load_fixture(registry)
	sim.run_ticks(SimFixture.ticks(CALIBRATE_MINUTES * 60))
	var state := JSON.parse_string(JSON.stringify(sim.to_dict(), "", false, true)) as Dictionary
	# Detailed: the city as it is.
	var detailed := Simulation.from_dict(state, registry)
	detailed.run_ticks(SimFixture.ticks(MINUTES * 60))
	# Simplified: the same city, nobody looking.
	var simplified := Simulation.from_dict(state, registry)
	var abstract := ProvinceAbstract.freeze(simplified.province, simplified.clock.tick)
	var ticks := SimFixture.ticks(MINUTES * 60)
	for t: int in range(0, ticks, ProvinceAbstract.STEP_TICKS):
		abstract.step(simplified.clock.tick / ProvinceAbstract.STEP_TICKS * ProvinceAbstract.STEP_TICKS + t)
	var lines := PackedStringArray()
	for good: StringName in GOODS:
		var a := int(detailed.province.ledger.made_total.get(good, 0))
		var b := int(abstract.detail.ledger.made_total.get(good, 0))
		lines.append("%s: detailed %d, simplified %d" % [good, a, b])
	print("\n".join(lines))
	for good: StringName in GOODS:
		var a := float(detailed.province.ledger.made_total.get(good, 0))
		var b := float(abstract.detail.ledger.made_total.get(good, 0))
		assert_float(a).override_failure_message("no %s made" % good).is_greater(0.0)
		assert_float(absf(b - a) / a).override_failure_message("\n".join(lines)).is_less_equal(TOLERANCE)
