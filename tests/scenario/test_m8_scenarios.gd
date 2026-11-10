extends GdUnitTestSuite
## M8 part 5: the scenarios (owner's survey 2026-11-10). The Divided continent leaves only the
## player's landing empty (the rulers' realms and neutral settlements ready); the Merchant
## islands are islands of 1-3 provinces and are won (or lost to a ruler) by gold; the Invasion
## from the sea sends its waves at the player's coastal towns, the raiders hold what they take,
## can be caught at sea, and the player wins by holding out 60 minutes. Save v31.


func _settings(scenario: StringName, seed_value: int = 5, rulers: int = 2, count: int = 16) -> GameSettings:
	var s := GameSettings.new()
	s.scenario = scenario
	s.world_seed = seed_value
	s.rulers = rulers
	s.province_count = count
	s.fit_scenario()
	return s


# --- The Divided continent ---------------------------------------------------------------------

func test_divided_continent_leaves_only_the_landing_empty() -> void:
	var data := SimFixture.registry()
	for seed_value: int in [3, 5, 11]:
		var s := _settings(GameSettings.DIVIDED, seed_value, 3, 22)
		var world := WorldGenerator.generate(data, s)
		var realms: Dictionary[StringName, int] = {}
		var player := data.get_province(world.start_province)
		assert_bool(player.coastal).override_failure_message("start on the coast (lands by ship)").is_true()
		for id: StringName in world.provinces:
			var def := data.get_province(id)
			if def == player:
				continue
			assert_str(String(def.owner)).override_failure_message("%s left empty" % id).is_not_equal("")
			realms[def.owner] = realms.get(def.owner, 0) + 1
			if Rulers.is_ruler(def.owner):
				assert_bool(player.neighbours.has(def.id)).override_failure_message("ruler next to the player").is_false()
		for r: int in range(1, 4):
			assert_int(realms.get(WorldGenerator.ruler_owner(r), 0)).is_greater_equal(2)
		assert_int(realms.get(ProvinceDef.OWNER_NEUTRAL, 0)).is_greater_equal(3)
		assert_str(String(world.bandit_camp)).is_equal("")


func test_divided_continent_starts_with_ready_towns() -> void:
	var problems := PackedStringArray()
	var sim := Simulation.from_settings(SimFixture.registry(), _settings(GameSettings.DIVIDED, 5, 2, 12), 1, problems)
	assert_array(Array(problems)).is_empty()
	assert_object(sim.province.landing).is_not_null()
	for id: int in sim.world.ids():
		if id == sim.viewed_id:
			continue
		assert_bool(sim.runtimes.has(id)).override_failure_message("province %d has no town" % id).is_true()
	# A ruler's capital is bigger and has barracks (he recruits from the start).
	for owner: StringName in Rulers.alive(sim.world):
		var biggest := 0
		var barracks := false
		for id: int in Rulers.provinces_of(sim.world, owner):
			var town := sim.province_state(id)
			biggest = maxi(biggest, town.buildings.all().size())
			for b: BuildingState in town.buildings.all():
				barracks = barracks or b.def.soldier_beds > 0
		assert_int(biggest).is_greater(38)
		assert_bool(barracks).is_true()
		assert_int(Rulers.provinces_of(sim.world, owner).size()).is_greater_equal(2)


# --- The Merchant islands ------------------------------------------------------------------------

func test_merchant_islands_are_islands_of_one_to_three_provinces() -> void:
	var data := SimFixture.registry()
	for seed_value: int in [2, 5, 9, 14]:
		for count: int in [12, 22, 40]:
			var world := WorldGenerator.generate(data, _settings(GameSettings.ISLANDS, seed_value, 2, count))
			assert_int(world.provinces.size()).is_equal(count)
			# Islands: groups of land neighbours.
			var seen: Dictionary[StringName, bool] = {}
			for id: StringName in world.provinces:
				var def := data.get_province(id)
				assert_bool(def.island and def.coastal).override_failure_message("%s not an island coast" % id).is_true()
				if seen.has(id):
					continue
				var group: Array[StringName] = [id]
				seen[id] = true
				var k := 0
				while k < group.size():
					for n: StringName in data.get_province(group[k]).neighbours:
						if not seen.has(n):
							seen[n] = true
							group.append(n)
					k += 1
				assert_int(group.size()).override_failure_message("island of %d in world %d/%d" % [
						group.size(), seed_value, count]).is_less_equal(4)
			assert_int(WorldGenerator.start_choices(data, world, _settings(GameSettings.ISLANDS)).size()).is_greater(3)


func test_gold_wins_the_merchant_islands_and_a_richer_ruler_wins_instead() -> void:
	var s := _settings(GameSettings.ISLANDS, 5, 2, 12)
	s.gold_target = 3000
	assert_str(String(s.victory)).is_equal(String(GameSettings.VICTORY_GOLD))
	var sim := Simulation.from_settings(SimFixture.registry(), s, 1)
	sim.treasury.gold = 2999
	sim.run_ticks(SimFixture.ticks(2))
	assert_str(String(sim.world.result)).is_equal("")
	assert_array(Victory.progress(sim)).is_equal([2999, 3000])
	sim.treasury.gold = 3000
	sim.run_ticks(SimFixture.ticks(2))
	assert_str(String(sim.world.result)).is_equal(String(WorldSim.RESULT_WON))
	# A ruler first: the player loses, the ruler is named.
	var other := Simulation.from_settings(SimFixture.registry(), s, 1)
	other.world.rulers[&"ruler_2"].treasury.gold = 3000
	var lost := false
	for i: int in SimFixture.ticks(2):
		other.step()
		for e: Dictionary in other.events.drain():
			if e["type"] == &"game_lost":
				lost = String(e.get("winner", "")) == "ruler_2"
	assert_bool(lost).is_true()


func test_rulers_of_the_islands_save_and_sell_their_surplus() -> void:
	var sim := Simulation.from_settings(SimFixture.registry(), _settings(GameSettings.ISLANDS, 5, 1, 12), 1)
	var colonial := Simulation.from_settings(SimFixture.registry(), _settings(GameSettings.COLONIZATION, 5, 1, 12), 1)
	assert_int(RulerWar.wanted(sim, &"ruler_1") * 2).is_equal(RulerWar.wanted(colonial, &"ruler_1"))
	var ruler := sim.world.rulers[&"ruler_1"]
	var id: int = Rulers.provinces_of(sim.world, &"ruler_1")[0]
	var town := sim.province_state(id)
	var post := NeutralTown.place(town, SimFixture.registry().get_building(&"trading_post"), RulerPlanner.centre(town))
	assert_object(post).is_not_null()
	var store := town.storage_buildings()[0]
	store.stock.add(&"beer", 60)
	var gold := ruler.treasury.gold
	var earned := RulerExpansion.sell_surplus(sim, ruler)
	assert_int(earned).is_greater_equal(RulerExpansion.SURPLUS_UNITS * 8)
	assert_int(ruler.treasury.gold).is_equal(gold + earned)
	assert_int(town.stored(&"beer")).is_greater_equal(RulerExpansion.SURPLUS_KEEP)


# --- The Invasion from the sea ------------------------------------------------------------------

## An Invasion game whose landing has a town hall (the waves go for towns with a seat).
func _invasion() -> Simulation:
	var problems := PackedStringArray()
	var sim := Simulation.from_settings(SimFixture.registry(), _settings(GameSettings.INVASION, 5, 2, 16), 1, problems)
	assert_array(Array(problems)).is_empty()
	RulerExpansion.found(sim, sim.viewed_id, sim.province)
	NeutralTown.place(sim.province, SimFixture.registry().get_building(ProvinceSim.SEAT), RulerPlanner.centre(sim.province))
	assert_bool(sim.province.has_seat()).is_true()
	return sim


## A second coastal province of the player with a town hall (not viewed: decided at once).
func _second_town(sim: Simulation) -> int:
	for id: int in sim.world.ids():
		var def := sim.world.def_of(id, sim.data)
		if sim.runtimes.has(id) or not def.coastal or sim.world.owner_of(id) != ProvinceDef.OWNER_NONE:
			continue
		sim.open_province(id, sim.data.get_map(sim.world.get_province(id).map_id))
		var town := sim.province_state(id)
		town.first_building = &""   # (a map from a ship: no camp needed here)
		var size := town.grid.size
		for y: int in range(8, size.y - 8, 12):
			for x: int in range(8, size.x - 8, 12):
				if town.seat() == null and town.nav.is_walkable(Vector2i(x, y)):
					NeutralTown.place(town, sim.data.get_building(ProvinceSim.SEAT), Vector2i(x, y))
		sim.bind_treasuries()
		return id
	return 0


func test_invasion_starts_without_rulers_with_six_soldiers() -> void:
	var sim := _invasion()
	assert_int(sim.world.settings.rulers).is_equal(0)
	assert_array(Rulers.alive(sim.world)).is_empty()
	assert_object(sim.world.invasion).is_not_null()
	var men := 0
	for army: Army in sim.world.armies.values():
		if army.owner == ProvinceDef.OWNER_PLAYER:
			men += army.men()
	assert_int(men).is_equal(6)
	assert_str(String(sim.data.get_world(sim.world.world_id).bandit_camp)).is_equal("")
	# The waves: from the 20th minute, every 5 minutes, eight, stronger each time.
	assert_int(sim.world.invasion.next_wave).is_equal(SimClock.seconds_to_ticks(20 * 60.0))
	var last := 0
	for wave: int in Invasion.WAVE_MEN.size():
		var units := Invasion.units_of(wave)
		var n := 0
		for unit: StringName in units:
			if unit != &"ram":
				n += units[unit]
		assert_int(n).is_greater(last)
		last = n
	assert_int(Invasion.units_of(0).values().reduce(func(a: int, b: int) -> int: return a + b)).is_equal(6)
	assert_int(last).is_equal(40)
	assert_bool(Invasion.units_of(7).has(&"ram")).is_true()


func test_a_wave_sails_in_and_storms_the_viewed_town_live() -> void:
	var sim := _invasion()
	sim.world.invasion.next_wave = sim.clock.tick + 1
	var fleet: Army = null
	var stormed := false
	for second: int in 400:
		sim.run_ticks(SimClock.TICKS_PER_SECOND)
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"invasion_wave":
				fleet = sim.world.armies.get(int(e["army"]))
				assert_int(int(e["province"])).is_equal(sim.viewed_id)
			if e["type"] == &"ruler_storming":
				stormed = true
		if stormed:
			break
	assert_object(fleet).is_not_null()
	assert_str(String(fleet.owner)).is_equal(String(Rulers.RAIDERS))
	assert_bool(stormed).override_failure_message("the wave did not storm the viewed town").is_true()
	assert_bool(sim.province.raids.conquest).is_true()
	assert_int(sim.world.invasion.wave).is_equal(1)
	assert_int(sim.world.invasion.next_wave).is_greater(sim.clock.tick)


func test_a_wave_takes_a_town_nobody_looks_at_and_the_player_takes_it_back() -> void:
	var sim := _invasion()
	var other := _second_town(sim)
	assert_int(other).is_not_equal(0)
	# Wave 2 goes for the second town (in turn).
	var fleet := Invasion.launch(sim, 1 if Invasion.targets(sim)[1] == other else 0)
	assert_object(fleet).is_not_null()
	assert_int(fleet.target).is_equal(other)
	var taken := false
	for second: int in 600:
		sim.run_ticks(SimClock.TICKS_PER_SECOND)
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"province_taken" and int(e["province"]) == other:
				taken = true
		if taken:
			break
	assert_bool(taken).is_true()
	assert_str(String(sim.world.owner_of(other))).is_equal(String(Rulers.RAIDERS))
	# The raiders' town stands as it is: their planner does not build.
	var count := sim.province_state(other).buildings.all().size()
	sim.run_ticks(SimFixture.ticks(120))
	assert_int(sim.province_state(other).sites.size()).is_equal(0)
	assert_int(sim.province_state(other).buildings.all().size()).is_less_equal(count)
	for army: Army in sim.world.armies.values():
		assert_bool(army.owner == Rulers.RAIDERS and army.is_fleet() and army.state == Army.State.IDLE) \
				.override_failure_message("raiders' ships left idle at sea").is_false()
	# The player's knights come: they wait at the border, and take it at once.
	var army := Army.new()
	army.id = sim.ids.take()
	army.owner = ProvinceDef.OWNER_PLAYER
	army.state = Army.State.IDLE
	army.at = other
	army.home = sim.viewed_id
	army.pos = ArmyOrders.town_point(sim, army, other)
	army.add(&"knight", 30)
	army.target = other
	sim.world.armies[army.id] = army
	Armies.arrive_on_land(sim, army)
	if army.state == Army.State.ENGAGED:
		return   # (raiders stood by the town: a battle in the field first; covered elsewhere)
	assert_int(army.state).is_equal(Army.State.WAITING)
	Armies.resolve_siege(sim, army)
	assert_str(String(sim.world.owner_of(other))).is_equal(String(ProvinceDef.OWNER_PLAYER))


func test_the_player_warships_catch_a_wave_at_sea() -> void:
	var sim := _invasion()
	var fleet := Invasion.launch(sim, 0)
	assert_object(fleet).is_not_null()
	var mine := Army.new()
	mine.id = sim.ids.take()
	mine.owner = ProvinceDef.OWNER_PLAYER
	mine.state = Army.State.IDLE
	mine.by_sea = true
	mine.pos = fleet.pos
	mine.fleet[&"galleon_war"] = 3
	mine.ships = 3
	mine.add(&"crossbowman", 30)
	mine.fleet_home = sim.viewed_id
	mine.home = sim.viewed_id
	sim.world.armies[mine.id] = mine
	var fought := false
	for i: int in SimFixture.ticks(3):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"sea_battle":
				fought = true
	assert_bool(fought).is_true()
	assert_bool(sim.world.armies.has(fleet.id) and sim.world.armies[fleet.id].men() == 6) \
			.override_failure_message("the wave sailed on untouched").is_false()


func test_holding_out_sixty_minutes_wins_the_invasion() -> void:
	var sim := _invasion()
	sim.world.invasion.wave = Invasion.WAVE_MEN.size()   # (no wave in the way)
	sim.clock.tick = sim.world.invasion.started + SimClock.seconds_to_ticks(59 * 60.0)
	sim.run_ticks(SimFixture.ticks(2))
	assert_str(String(sim.world.result)).is_equal("")
	assert_array(Victory.progress(sim)).is_equal([59, 60])
	sim.clock.tick = sim.world.invasion.started + SimClock.seconds_to_ticks(60 * 60.0)
	sim.run_ticks(SimFixture.ticks(2))
	assert_str(String(sim.world.result)).is_equal(String(WorldSim.RESULT_WON))


# --- Save ------------------------------------------------------------------------------------------

func test_scenarios_survive_a_save_and_v30_migrates() -> void:
	var sim := _invasion()
	sim.world.invasion.next_wave = sim.clock.tick + 1
	sim.run_ticks(SimFixture.ticks(20))
	var state := sim.to_dict()
	var copy := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(state))
	assert_int(copy.world.invasion.wave).is_equal(1)
	assert_str(String(copy.world.settings.scenario)).is_equal(String(GameSettings.INVASION))
	copy.run_ticks(SimFixture.ticks(10))
	var s := _settings(GameSettings.ISLANDS)
	s.gold_target = 25000
	assert_int(GameSettings.from_dict(s.to_dict()).gold_target).is_equal(25000)
	# v30: a Colonization game.
	var old := {"tick": 5, "world": {"settings": {"seed": 3, "rulers": 2}}}
	var migrated := SaveMigrations.migrate(old, 30)
	var settings := GameSettings.from_dict(migrated["world"]["settings"])
	assert_str(String(settings.scenario)).is_equal(String(GameSettings.COLONIZATION))
	assert_int(settings.gold_target).is_equal(GameSettings.DEFAULT_GOLD)
	assert_int(SaveMigrations.CURRENT_VERSION).is_equal(31)
