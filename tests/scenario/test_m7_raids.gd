extends GdUnitTestSuite
## M7 part 2, step D: bandit raids (ROADMAP M7, GDD §8, §9; owner's decisions 2026-11-08).
## - rare raids with a warning a minute ahead, from the edge of the map,
## - bandits break through walls and gates to the town hall's door and fight soldiers,
## - townsfolk near bandits hide in the town hall, then go back to work,
## - a broken door with no defender: the bandits loot and leave; happiness drops,
## - a full take-over of a province is ready for part 3.


func _town() -> Simulation:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	var v := SimFixture.village(sim, 40, 40)
	(v["stock"] as BuildingState).stock.add(&"planks", 30)
	sim.treasury.gold = 500
	sim.raids_enabled = true
	return sim


func _run(sim: Simulation, seconds: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i: int in SimFixture.ticks(seconds):
		sim.step()
		events.append_array(sim.events.drain())
	return events


func _types(events: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	for event: Dictionary in events:
		result.append(event["type"])
	return result


func test_first_raid_comes_after_forty_minutes_with_a_warning() -> void:
	var sim := _town()
	var province := sim.province
	_run(sim, 1)
	assert_int(province.raids.next_tick).is_equal(SimClock.seconds_to_ticks(Raids.FIRST_SECONDS))
	# Jump close to the raid instead of playing 40 minutes.
	province.raids.next_tick = sim.clock.tick + SimClock.seconds_to_ticks(70)
	var events := _run(sim, 15)
	assert_array(_types(events)).contains([&"raid_warning"])
	assert_int(province.raids.state).is_equal(Raids.State.WARNED)
	events = _run(sim, 60)
	assert_array(_types(events)).contains([&"raid_started"])
	assert_int(province.raids.members.size()).is_between(Raids.SIZE_MIN, Raids.SIZE_MAX)
	for id: int in province.raids.members:
		var bandit := province.agents.get_agent(id)
		assert_int(bandit.combat.faction).is_equal(CombatState.BANDITS)
		assert_bool(bandit.combat.commanded).is_true()


func test_undefended_town_is_looted_and_loses_heart() -> void:
	var sim := _town()
	var province := sim.province
	var gold := sim.treasury.gold
	Raids.start(province, sim.rng.stream(&"raids"))
	var events: Array[Dictionary] = []
	var looted := false
	for k: int in 30:
		events = _run(sim, 10)
		if _types(events).has(&"raid_looted"):
			looted = true
			break
	assert_bool(looted).override_failure_message("the bandits never broke the door").is_true()
	assert_int(sim.treasury.gold).is_less(gold)
	assert_int(province.raids.state).is_equal(Raids.State.LEAVING)
	assert_bool(province.raids.mood_until > province.tick).is_true()
	# They go away; the door is mended.
	assert_bool(SimFixture.run_until(sim, func() -> bool: return province.raids.state == Raids.State.WAITING, 300)).is_true()
	assert_int(province.seat().hp).is_equal(province.seat().def.max_hp)
	for agent: Agent in province.agents.all():
		assert_bool(agent.combat != null and agent.combat.faction == CombatState.BANDITS).is_false()


func test_townsfolk_hide_in_the_town_hall_and_go_back_to_work() -> void:
	var sim := _town()
	var province := sim.province
	_run(sim, 20)
	Raids.start(province, sim.rng.stream(&"raids"))
	var bandit := province.agents.get_agent(province.raids.members[0])
	# One bandit right next to the stockpile, among the porters.
	var porter: Agent = null
	for agent: Agent in province.agents.all():
		if agent.combat == null and agent.kind == &"porter":
			porter = agent
	assert_object(porter).is_not_null()
	bandit.pos = porter.pos + Vector2(1, 0)
	_run(sim, 1.5)
	assert_str(String(porter.task.kind)).is_equal(String(Task.KIND_SHELTER))
	# Raid over: everybody back to work.
	for id: int in province.raids.members.duplicate():
		Troops.kill(province, province.agents.get_agent(id))
	_run(sim, 30)   # he reaches the hall first, then comes out
	assert_int(province.raids.state).is_equal(Raids.State.WAITING)
	assert_bool(porter.task == null or porter.task.kind != Task.KIND_SHELTER).is_true()


func test_bandits_break_the_palisade_in_their_way() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var hall := SimFixture.place(sim, &"town_hall", Vector2i(18, 4))
	var province := sim.province
	sim.raids_enabled = true
	# A palisade right across the map below the hall.
	for x: int in 40:
		province.lay_wall(Vector2i(x, 14), Walls.PALISADE)
	province.raids.entry = Vector2i(20, 37)
	Raids.start(province, sim.rng.stream(&"raids"))
	var broke := SimFixture.run_until(sim, func() -> bool:
		for x: int in 40:
			if province.walls.kind(Vector2i(x, 14)) == Walls.NONE:
				return true
		return false, 240)
	assert_bool(broke).is_true()
	assert_int(hall.hp).is_less_equal(hall.def.max_hp)


func test_soldiers_at_the_door_save_the_town() -> void:
	var sim := _town()
	var province := sim.province
	var hall := province.seat()
	var guards: Array[Agent] = []
	for k: int in 8:
		var a := province.spawn_agent(&"swordsman", hall.entrance_tile())
		a.combat = CombatState.new(sim.data.get_unit(&"swordsman").combat.hp)
		guards.append(a)
	var ids: Array[int] = []
	for a: Agent in guards:
		ids.append(a.id)
	sim.execute(OrderTroopsCommand.new(ids, OrderTroopsCommand.MOVE, province.door_tile(hall)))
	Raids.start(province, sim.rng.stream(&"raids"))
	var events: Array[Dictionary] = []
	for k: int in 40:
		events.append_array(_run(sim, 10))
		if province.raids.state == Raids.State.WAITING:
			break
	assert_array(_types(events)).contains([&"raid_defeated"])
	assert_array(_types(events)).not_contains([&"raid_looted"])


func test_a_province_can_be_taken_over() -> void:
	var sim := _town()
	var province := sim.province
	var hall := province.seat()
	assert_bool(Raids.can_capture(province)).is_false()
	Troops.damage_structure(province, hall.entrance_tile(), hall.def.max_hp)
	assert_bool(hall.is_broken()).is_true()
	assert_bool(Raids.can_capture(province)).is_true()
	Raids.capture(sim, sim.viewed_id, ProvinceDef.OWNER_NEUTRAL)
	assert_str(String(sim.world.owner_of(sim.viewed_id))).is_equal(String(ProvinceDef.OWNER_NEUTRAL))
	assert_bool(province.raids.mood_until > province.tick).is_true()


func test_raid_survives_a_save() -> void:
	var sim := _town()
	var province := sim.province
	Raids.start(province, sim.rng.stream(&"raids"))
	_run(sim, 5)
	var copy := ProvinceSim.from_dict(JSON.parse_string(JSON.stringify(province.to_dict())),
			sim.data, SimEvents.new(), EntityIds.new())
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(province.to_dict()))
	assert_int(copy.raids.members.size()).is_equal(province.raids.members.size())


## v18 saves load as v19 (and on): no walls, the first raid 40 minutes after the game goes on;
## in a world game (M7 part 3) raids come from the bandits' camp instead of the province's own
## schedule.
func test_v18_save_loads_and_gets_its_first_raid_later() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v14_routes.json"))
	var state := SaveMigrations.migrate(document["state"], 14)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	assert_int(sim.province.walls.count()).is_equal(0)
	sim.raids_enabled = true
	sim.run_ticks(SimClock.TICKS_PER_SECOND + 1)
	assert_bool(sim.world.is_single()).is_false()
	assert_int(sim.province.raids.next_tick).is_equal(-1)
	assert_object(sim.world.camp).is_not_null()
	assert_int(sim.world.camp.next_raid).is_greater(sim.clock.tick + SimClock.seconds_to_ticks(BanditCamp.FIRST_SECONDS) - 20)
	assert_int(SaveMigrations.CURRENT_VERSION).is_greater_equal(20)
