extends GdUnitTestSuite
## Moved from test_m8_rulers.gd (speed-up 2026-11-11).


func _settings(seed_value: int, rulers: int = 2, count: int = 18, level: int = GameSettings.NORMAL) -> GameSettings:
	var s := GameSettings.new()
	s.world_seed = seed_value
	s.rulers = rulers
	s.province_count = count
	s.difficulty = level
	return s

func _game(level: int = GameSettings.NORMAL, rulers: int = 2) -> Simulation:
	var problems := PackedStringArray()
	var sim := Simulation.from_settings(SimFixture.registry(), _settings(5, rulers, 18, level), 1, problems)
	assert_array(Array(problems)).is_empty()
	return sim

func _home(sim: Simulation, owner: StringName) -> int:
	return Rulers.provinces_of(sim.world, owner)[0]

func test_hard_rulers_grow_faster_than_easy_ones() -> void:
	var grown: Array[int] = []
	for level: int in [GameSettings.EASY, GameSettings.HARD]:
		var sim := _game(level, 1)
		var owner: StringName = Rulers.alive(sim.world)[0]
		var before := sim.province_state(_home(sim, owner)).buildings.all().size()
		sim.run_ticks(SimFixture.ticks(480))
		grown.append(sim.province_state(_home(sim, owner)).buildings.all().size() - before)
	assert_int(grown[1]).is_greater(grown[0])

func _expedition(sim: Simulation, owner: StringName, from: int, to: int, seconds: int) -> Expedition:
	var e := Expedition.new()
	e.id = sim.ids.take()
	e.owner = owner
	e.from = from
	e.to = to
	e.settlers = Departure.SETTLERS.duplicate()
	e.kit = {&"wood": 90, &"bread": 20}
	e.depart_at = sim.clock.tick
	e.arrive_at = sim.clock.tick + SimFixture.ticks(seconds)
	sim.world.expeditions[e.id] = e
	return e

## The rulers' treasuries, plans, expeditions and bids are saved; a v28 save gets them.
func test_rulers_survive_a_save_and_v28_migrates() -> void:
	var sim := _game()
	var owner: StringName = Rulers.alive(sim.world)[0]
	sim.world.rulers[owner].saving_for = _home(sim, owner)
	var e := _expedition(sim, owner, _home(sim, owner), RulerExpansion.best_target(sim, owner, _home(sim, owner), false), 100)
	e.bounced = false
	sim.run_ticks(SimFixture.ticks(90))
	var state := sim.to_dict()
	assert_int((state["world"]["rulers"] as Array).size()).is_equal(2)
	var copy := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(state))
	assert_object(copy.province_state(_home(copy, owner)).treasury).is_same(copy.world.rulers[owner].treasury)
	assert_str(String(copy.world.expeditions[e.id].owner)).is_equal(String(owner))
	# A save from before part 3: no rulers' states, expeditions without owners.
	var old := sim.to_dict().duplicate(true)
	(old["world"] as Dictionary).erase("rulers")
	for ed: Variant in old["world"].get("expeditions", []):
		(ed as Dictionary).erase("owner")
	var migrated := SaveMigrations.migrate(old, 28)
	var loaded := Simulation.from_dict(migrated, SimFixture.registry())
	assert_int(loaded.world.rulers.size()).is_equal(2)
	assert_int(loaded.world.rulers[owner].treasury.gold).is_equal(RulerPlanner.START_GOLD[GameSettings.NORMAL])
	assert_object(loaded.province_state(_home(loaded, owner)).treasury).is_same(loaded.world.rulers[owner].treasury)
	loaded.run_ticks(SimFixture.ticks(60))
	assert_int(SaveMigrations.CURRENT_VERSION).is_greater_equal(29)
