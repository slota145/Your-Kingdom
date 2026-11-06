extends GdUnitTestSuite
## M4b-3 DoD: the big city (400+ characters, the saved fixture of tests/support/big_city.gd)
## plays 2 hours of game time without deadlocks, keeps its people and keeps producing.
## Headless the speed setting does not matter: 4x only runs 4 ticks per frame.

## Characters the fixture starts with at least, and has on average over the 2 hours.
## Householders come and go, so the count moves (about 320 to 580).
const MIN_CHARACTERS := 400
## Fewest characters at any minute: the town never shrinks for good.
const FEWEST_CHARACTERS := 300


func test_fixture_is_a_big_city() -> void:
	var sim := BigCity.load_fixture(SimFixture.registry())
	print(BigCity.summary(sim))
	assert_int(sim.province.agents.all().size()).is_greater_equal(MIN_CHARACTERS)
	var kinds := {}
	for agent: Agent in sim.province.agents.all():
		kinds[agent.kind] = true
		if agent.vehicle != &"":
			kinds[agent.vehicle] = true
	# Every chain has its workers, and both kinds of carts are in use.
	for kind: StringName in [&"farmer", &"miller", &"baker", &"angler", &"brewer", &"woodcutter",
			&"sawyer", &"stonecutter", &"brickmaker", &"weaver", &"tailor", &"mead_maker",
			&"butcher", &"swineherd", &"innkeeper", &"stallholder", &"carter", &"porter"]:
		assert_bool(kinds.has(kind)).override_failure_message("no %s in the city" % kind).is_true()
	assert_int(sim.province.grid.paved_count()).is_greater(100)


func test_two_hours_without_deadlocks() -> void:
	var sim := BigCity.load_fixture(SimFixture.registry())
	var watch := DeadlockWatch.new()
	var produced: Dictionary[StringName, int] = {}
	var trace := PackedStringArray()
	var fewest := 1 << 30
	var sum := 0
	for minute: int in range(1, 121):
		for i: int in 60 * SimClock.TICKS_PER_SECOND:
			sim.step()
			sum += sim.province.agents.all().size()
			for e: Dictionary in sim.events.drain():
				if e["type"] == &"good_produced" and minute > 100:
					produced[e["good"]] = produced.get(e["good"], 0) + int(e["amount"])
		watch.check(sim, minute)
		fewest = mini(fewest, sim.province.agents.all().size())
		if minute % 20 == 0:
			trace.append("min %d: characters %d, residents %d, bread %d, beer %d, gold %d" % [minute,
					sim.province.agents.all().size(), _residents(sim), sim.province.goods_total(&"bread"),
					sim.province.goods_total(&"beer"), sim.treasury.gold])
	print("\n".join(trace))
	print("produced in the last 20 minutes: ", produced)
	var average := sum / (120 * 60 * SimClock.TICKS_PER_SECOND)
	print("characters: average %d, fewest %d" % [average, fewest])
	assert_array(watch.stuck).is_empty()
	assert_int(average).is_greater_equal(MIN_CHARACTERS)
	assert_int(fewest).is_greater_equal(FEWEST_CHARACTERS)
	# The chains still run at the end: every made good is made in the last 20 minutes
	# (gathered ones, like wood and stone, have no "produced" event).
	for good: StringName in [&"bread", &"fish", &"beer", &"planks", &"bricks", &"clothes", &"mead",
			&"meat", &"flour", &"cloth"]:
		assert_int(int(produced.get(good, 0))).override_failure_message(
				"no %s made in the last 20 minutes" % good).is_greater(0)


func _residents(sim: Simulation) -> int:
	var n := 0
	for b: BuildingState in sim.province.buildings.all():
		if b.house != null:
			n += b.house.residents
	return n
