extends GdUnitTestSuite
## M7 part 1: metals, weapons, barracks and recruitment (ROADMAP M7).
## - every map has a few ore veins in its rocks, the province with iron ore many,
## - charcoal burner, mine, smelter, blacksmith, armourer and bowyer make weapons; weapons go
##   only to an armoury, never to a common storage,
## - the blacksmith makes spears, swords or each in turn (owner's decision 2026-11-07),
## - a recruit is a free resident: he leaves his house, takes his gear and lives in the
##   barracks, where he eats, is paid and drills in the ranks.


func _registry() -> DataRegistry:
	return SimFixture.registry()


func _count_nodes(province: ProvinceSim, id: StringName) -> int:
	var n := 0
	for tile: Vector2i in province.resources.tiles_with_nodes():
		if province.resources.def_at(tile).id == id:
			n += 1
	return n


func test_every_map_has_ore_veins_and_the_iron_province_many() -> void:
	for map_id: StringName in [&"riverlands", &"lakeland", &"coast", &"islands"]:
		var map := _registry().get_map(map_id)
		var province := ProvinceSim.new(_registry(), map.size(), SimEvents.new(), EntityIds.new())
		province.load_map(map)
		var veins := _count_nodes(province, &"ore_vein")
		print("%s: %d ore veins" % [map_id, veins])
		assert_int(veins).is_greater_equal(2)
		var rich := ProvinceSim.new(_registry(), map.size(), SimEvents.new(), EntityIds.new())
		rich.load_map(map, false, 2, false, &"iron_ore")
		assert_int(_count_nodes(rich, &"ore_vein")).is_greater(veins)
		# The same map always gets the same veins.
		var again := ProvinceSim.new(_registry(), map.size(), SimEvents.new(), EntityIds.new())
		again.load_map(map)
		assert_str(SimCodec.canonical(again.resources.to_dict())).is_equal(
				SimCodec.canonical(province.resources.to_dict()))


func test_mine_stands_only_near_an_ore_vein() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"mine", Vector2i(10, 10))))).is_equal("no_ore_vein_nearby")
	SimFixture.place_nodes(sim, Rect2i(15, 10, 1, 1), &"ore_vein")
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"mine", Vector2i(10, 10))))).is_equal("")


func test_stud_farm_only_with_pastures_and_starts_with_a_pair() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"stud_farm", Vector2i(10, 10))))).is_equal("needs_horses")
	sim.province.rare_resource = &"horses"
	var farm := SimFixture.place(sim, &"stud_farm", Vector2i(10, 10))
	assert_int(farm.yard.total(&"horse")).is_equal(2)


## A small town with every workshop of the weapon chains, workers from 16 huts.
func _armoury_town(sim: Simulation) -> Dictionary:
	var hall := SimFixture.place(sim, &"town_hall", Vector2i(2, 2))
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(8, 2))
	stock.stock.add(&"wood", 60)
	stock.stock.add(&"planks", 40)
	stock.stock.add(&"bread", 40)
	# Huts without a well slowly lose up to half of their residents: enough of them.
	for i: int in 16:
		SimFixture.house(sim, Vector2i(2 + 3 * (i % 4), 8 + 3 * (i / 4)))
	SimFixture.place_nodes(sim, Rect2i(36, 4, 2, 2), &"ore_vein")
	var b := {
		"hall": hall, "stock": stock,
		"charcoal": SimFixture.place(sim, &"charcoal_burner", Vector2i(14, 2)),
		"charcoal2": SimFixture.place(sim, &"charcoal_burner", Vector2i(14, 6)),
		"mine": SimFixture.place(sim, &"mine", Vector2i(32, 4)),
		"smelter": SimFixture.place(sim, &"smelter", Vector2i(18, 2)),
		"smelter2": SimFixture.place(sim, &"smelter", Vector2i(18, 6)),
		"blacksmith": SimFixture.place(sim, &"blacksmith", Vector2i(22, 2)),
		"bowyer": SimFixture.place(sim, &"bowyer", Vector2i(26, 2)),
		"armoury": SimFixture.place(sim, &"armoury", Vector2i(22, 10)),
	}
	return b


func test_weapon_chains_fill_the_armoury_only() -> void:
	var sim := SimFixture.make_sim(Vector2i(44, 30))
	var town := _armoury_town(sim)
	var made: Dictionary[StringName, int] = {}
	for i: int in SimFixture.ticks(14 * 60):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"good_produced":
				made[e["good"]] = made.get(e["good"], 0) + int(e["amount"])
	print("weapon chains in 14 min: ", made)
	assert_int(made.get(&"charcoal", 0)).is_greater_equal(6)
	assert_int(made.get(&"iron", 0)).is_greater_equal(3)
	assert_int(made.get(&"bow", 0)).is_greater_equal(4)
	# The blacksmith takes turns: spears and swords.
	assert_int(made.get(&"spear", 0)).is_greater_equal(2)
	assert_int(made.get(&"sword", 0)).is_greater_equal(1)
	var stock: BuildingState = town["stock"]
	var armoury: BuildingState = town["armoury"]
	for weapon: StringName in [&"spear", &"sword", &"bow"]:
		assert_int(stock.stock.total(weapon)).is_equal(0)
	assert_int(armoury.stock.total(&"bow")).is_greater_equal(1)
	assert_int(armoury.stock.total(&"wood")).is_equal(0)
	assert_bool(armoury.stock.can_accept(&"bread", 1)).is_false()
	assert_bool(stock.stock.can_accept(&"spear", 1)).is_false()
	# Iron ore comes out of the vein.
	assert_int(sim.province.resources.amount(Vector2i(36, 4)) + sim.province.resources.amount(Vector2i(37, 4))
			+ sim.province.resources.amount(Vector2i(36, 5)) + sim.province.resources.amount(Vector2i(37, 5))).is_less(160)


func test_blacksmith_follows_the_players_choice() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 24))
	var hall := SimFixture.place(sim, &"town_hall", Vector2i(2, 2))
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(8, 2))
	stock.stock.add(&"iron", 20)
	stock.stock.add(&"planks", 20)
	for i: int in 3:
		SimFixture.house(sim, Vector2i(2 + 3 * i, 8))
	var smith := SimFixture.place(sim, &"blacksmith", Vector2i(16, 4))
	SimFixture.place(sim, &"armoury", Vector2i(20, 10))
	assert_str(String(sim.execute(SetRecipeModeCommand.new(smith.id, 1)))).is_equal("")
	assert_str(String(sim.execute(SetRecipeModeCommand.new(hall.id, 1)))).is_equal("no_production")
	assert_str(String(sim.execute(SetRecipeModeCommand.new(smith.id, 2)))).is_equal("bad_choice")
	var made: Dictionary[StringName, int] = {}
	for i: int in SimFixture.ticks(4 * 60):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"good_produced":
				made[e["good"]] = made.get(e["good"], 0) + int(e["amount"])
	assert_int(made.get(&"sword", 0)).is_greater_equal(2)
	assert_int(made.get(&"spear", 0)).is_equal(0)


## Town hall, a stockpile with bread, 3 huts, a finished armoury with gear and a barracks.
func _barracks_town(sim: Simulation) -> Dictionary:
	SimFixture.place(sim, &"town_hall", Vector2i(2, 2))
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(8, 2))
	stock.stock.add(&"bread", 30)
	var houses: Array[BuildingState] = []
	for i: int in 4:
		houses.append(SimFixture.house(sim, Vector2i(2 + 3 * i, 9), 6))
	var armoury := SimFixture.place(sim, &"armoury", Vector2i(16, 2))
	armoury.stock.add(&"spear", 6)
	armoury.stock.add(&"bow", 2)
	var barracks := SimFixture.place(sim, &"barracks", Vector2i(20, 14))
	sim.treasury.gold = 500
	return {"stock": stock, "houses": houses, "armoury": armoury, "barracks": barracks}


func _residents(houses: Array[BuildingState]) -> int:
	var n := 0
	for house: BuildingState in houses:
		n += house.house.residents
	return n


func test_recruit_leaves_home_takes_gear_and_moves_into_barracks() -> void:
	var sim := SimFixture.make_sim(Vector2i(36, 30))
	var town := _barracks_town(sim)
	var barracks: BuildingState = town["barracks"]
	var armoury: BuildingState = town["armoury"]
	var houses: Array[BuildingState] = []
	houses.assign(town["houses"])
	# Let the workers settle in first.
	sim.run_ticks(SimFixture.ticks(5))
	var residents := _residents(houses)
	var gold := sim.treasury.gold
	assert_str(String(sim.execute(RecruitCommand.new(barracks.id, &"spearman")))).is_equal("")
	assert_int(sim.treasury.gold).is_equal(gold - 10)
	assert_int(_residents(houses)).is_equal(residents - 1)
	assert_int(armoury.stock.available(&"spear")).is_equal(5)
	assert_int(barracks.recruits.size()).is_equal(1)
	var armed: Array[int] = []
	var start := sim.clock.tick
	var ok := SimFixture.run_until(sim, func() -> bool:
		for agent: Agent in sim.province.agents.all():
			if agent.kind == &"spearman" and armed.is_empty():
				armed.append(sim.clock.tick)
		return barracks.soldiers.size() == 1, 120)
	print("armed after %.1f s, in the barracks after %.1f s" % [(armed[0] - start) / 10.0 if not armed.is_empty() else -1.0, (sim.clock.tick - start) / 10.0])
	assert_bool(ok).is_true()
	assert_bool(armed.is_empty()).is_false()
	assert_int(barracks.recruits.size()).is_equal(0)
	assert_int(armoury.stock.total(&"spear")).is_equal(5)
	var soldier := sim.province.agents.get_agent(barracks.soldiers[0])
	assert_str(String(soldier.kind)).is_equal("spearman")
	assert_int(soldier.combat.hp).is_equal(100)
	assert_int(soldier.home_id).is_equal(barracks.id)
	# The house takes a newcomer in its place later (Population).


func test_recruit_errors() -> void:
	var sim := SimFixture.make_sim(Vector2i(36, 30))
	var town := _barracks_town(sim)
	var barracks: BuildingState = town["barracks"]
	sim.run_ticks(SimFixture.ticks(5))
	assert_str(String(sim.execute(RecruitCommand.new(barracks.id, &"swordsman")))).is_equal("no_gear")
	assert_str(String(sim.execute(RecruitCommand.new(barracks.id, &"dragon")))).is_equal("unknown_unit")
	assert_str(String(sim.execute(RecruitCommand.new((town["stock"] as BuildingState).id, &"spearman")))).is_equal("not_barracks")
	sim.treasury.gold = 5
	assert_str(String(sim.execute(RecruitCommand.new(barracks.id, &"spearman")))).is_equal("not_enough_gold")
	sim.treasury.gold = 500
	# Everybody able to work has a job: no free resident.
	for house: BuildingState in town["houses"]:
		house.house.residents = 0
	assert_str(String(sim.execute(RecruitCommand.new(barracks.id, &"spearman")))).is_equal("no_free_resident")
	# A barracks with soldiers cannot be demolished.
	barracks.recruits.append(999)
	assert_str(String(sim.execute(DemolishCommand.new(barracks.id)))).is_equal("barracks_has_soldiers")


func test_soldiers_drill_in_ranks_eat_and_are_paid() -> void:
	var sim := SimFixture.make_sim(Vector2i(36, 30))
	var town := _barracks_town(sim)
	var barracks: BuildingState = town["barracks"]
	sim.run_ticks(SimFixture.ticks(5))
	for i: int in 3:
		assert_str(String(sim.execute(RecruitCommand.new(barracks.id, &"spearman")))).is_equal("")
	assert_str(String(sim.execute(RecruitCommand.new(barracks.id, &"archer")))).is_equal("")
	assert_bool(SimFixture.run_until(sim, func() -> bool: return barracks.soldiers.size() == 4, 120)).is_true()
	# Everyone in his place in the ranks, each place different.
	sim.run_ticks(SimFixture.ticks(30))
	var places: Dictionary[Vector2, bool] = {}
	var drilling := 0
	for id: int in barracks.soldiers:
		var soldier := sim.province.agents.get_agent(id)
		var post := Barracks.post_of(sim.province, barracks, barracks.soldiers.find(id))
		assert_float(soldier.pos.distance_to(post)).is_less(0.01)
		places[post] = true
	assert_int(places.size()).is_equal(4)
	var seen_drill := false
	for i: int in SimFixture.ticks(Barracks.DRILL_ROUND):
		sim.step()
		sim.events.drain()
		for id: int in barracks.soldiers:
			if sim.province.agents.get_agent(id).activity == &"drill":
				seen_drill = true
	assert_bool(seen_drill).is_true()
	# Porters bring bread to the pantry; 4 soldiers eat about 0.24 a minute.
	assert_bool(SimFixture.run_until(sim, func() -> bool: return barracks.supply.total(&"bread") > 0, 60)).is_true()
	# Wages: 1 gold a minute per soldier (taxes off for the count).
	for house: BuildingState in town["houses"]:
		house.house.residents = 0
	var gold := sim.treasury.gold
	sim.run_ticks(SimFixture.ticks(120))
	assert_int(gold - sim.treasury.gold).is_between(7, 9)


func test_soldiers_survive_save_and_load_mid_walk() -> void:
	var sim := SimFixture.make_sim(Vector2i(36, 30))
	var town := _barracks_town(sim)
	var barracks: BuildingState = town["barracks"]
	sim.run_ticks(SimFixture.ticks(5))
	sim.execute(RecruitCommand.new(barracks.id, &"spearman"))
	sim.execute(RecruitCommand.new(barracks.id, &"archer"))
	sim.run_ticks(SimFixture.ticks(6))
	var text := JSON.stringify(sim.to_dict(), "", false, true)
	var loaded := Simulation.from_dict(JSON.parse_string(text), _registry())
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))
	var b := loaded.province.buildings.get_building(barracks.id)
	assert_bool(SimFixture.run_until(loaded, func() -> bool: return b.soldiers.size() == 2, 120)).is_true()
	assert_array(Array(loaded.province.dangling_holds())).is_empty()
	# Both runs go on alike.
	sim.run_ticks(600)
	loaded2_check(sim)


func loaded2_check(sim: Simulation) -> void:
	var text := JSON.stringify(sim.to_dict(), "", false, true)
	var loaded := Simulation.from_dict(JSON.parse_string(text), _registry())
	sim.run_ticks(300)
	loaded.run_ticks(300)
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))


func test_v17_save_gets_ore_veins_on_migration() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v14_routes.json"))
	var state := SaveMigrations.migrate(document["state"], 14)
	var sim := Simulation.from_dict(state, _registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	var veins := 0
	for id: int in sim.runtimes:
		veins += _count_nodes(sim.province_state(id), &"ore_vein")
	print("ore veins after migration: ", veins)
	assert_int(veins).is_greater(0)
