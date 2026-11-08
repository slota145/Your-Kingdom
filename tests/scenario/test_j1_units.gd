extends GdUnitTestSuite
## J1 part 1: halberds, morning stars and crossbows from the blacksmith and the bowyer, and
## the halberdier, the crossbowman, the man-at-arms and the light cavalry recruited in the
## barracks with their gear from the armoury.


func _workshop_town(sim: Simulation) -> BuildingState:
	SimFixture.place(sim, &"town_hall", Vector2i(2, 2))
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(8, 2))
	stock.stock.add(&"iron", 20)
	stock.stock.add(&"planks", 20)
	for i: int in 3:
		SimFixture.house(sim, Vector2i(2 + 3 * i, 8))
	SimFixture.place(sim, &"armoury", Vector2i(20, 10))
	return stock


func _made(sim: Simulation, seconds: float) -> Dictionary[StringName, int]:
	var made: Dictionary[StringName, int] = {}
	for i: int in SimFixture.ticks(seconds):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"good_produced":
				made[e["good"]] = made.get(e["good"], 0) + int(e["amount"])
	return made


func test_blacksmith_forges_halberds_and_morning_stars() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 24))
	_workshop_town(sim)
	var smith := SimFixture.place(sim, &"blacksmith", Vector2i(16, 4))
	assert_int(smith.def.recipe_choices.size()).is_equal(4)
	assert_str(String(sim.execute(SetRecipeModeCommand.new(smith.id, 2)))).is_empty()
	var made := _made(sim, 4 * 60)
	assert_int(made.get(&"halberd", 0)).is_greater_equal(2)
	assert_str(String(sim.execute(SetRecipeModeCommand.new(smith.id, 3)))).is_empty()
	made = _made(sim, 4 * 60)
	assert_int(made.get(&"morning_star", 0)).is_greater_equal(2)
	assert_int(made.get(&"halberd", 0)).is_less_equal(1)


func test_bowyer_makes_crossbows_from_planks_and_iron() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 24))
	var stock := _workshop_town(sim)
	var bowyer := SimFixture.place(sim, &"bowyer", Vector2i(16, 4))
	assert_str(String(sim.execute(SetRecipeModeCommand.new(bowyer.id, 1)))).is_empty()
	var iron := stock.stock.total(&"iron")
	# Two walks a crossbow: the planks to the bench, then the iron.
	var made := _made(sim, 6 * 60)
	assert_int(made.get(&"crossbow", 0)).is_greater_equal(2)
	assert_int(made.get(&"bow", 0)).is_equal(0)
	assert_int(iron - stock.stock.total(&"iron")).is_greater_equal(made.get(&"crossbow", 0))


func test_new_units_are_recruited_with_their_gear() -> void:
	var sim := SimFixture.make_sim(Vector2i(36, 30))
	SimFixture.place(sim, &"town_hall", Vector2i(2, 2))
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(8, 2))
	stock.stock.add(&"bread", 30)
	for i: int in 4:
		SimFixture.house(sim, Vector2i(2 + 3 * i, 9), 6)
	var armoury := SimFixture.place(sim, &"armoury", Vector2i(16, 2))
	for good: StringName in [&"halberd", &"crossbow", &"morning_star", &"chainmail", &"spear"]:
		armoury.stock.add(good, 2)
	sim.province.rare_resource = &"horses"
	var stud := SimFixture.place(sim, &"stud_farm", Vector2i(28, 2))
	stud.yard.add(&"horse", 2)   # beyond the breeding pair
	var barracks := SimFixture.place(sim, &"barracks", Vector2i(20, 14))
	sim.treasury.gold = 1000
	sim.run_ticks(SimFixture.ticks(5))
	var gold := sim.treasury.gold
	for unit: StringName in [&"halberdier", &"crossbowman", &"man_at_arms"]:
		assert_str(String(sim.execute(RecruitCommand.new(barracks.id, unit)))).is_equal("")
	assert_int(gold - sim.treasury.gold).is_equal(80 + 50 + 90)
	assert_int(armoury.stock.available(&"chainmail")).is_equal(0)
	# The light cavalry takes a horse from the stud farm and a spear from the armoury.
	assert_str(String(sim.execute(RecruitCommand.new(barracks.id, &"light_cavalry")))).is_equal("")
	assert_bool(SimFixture.run_until(sim, func() -> bool: return barracks.soldiers.size() >= 4, 240)).is_true()
	var kinds: Array[StringName] = []
	for id: int in barracks.soldiers:
		kinds.append(sim.province.agents.get_agent(id).kind)
	assert_array(kinds).contains([&"halberdier", &"crossbowman", &"man_at_arms", &"light_cavalry"])


func test_roles_in_the_numbers() -> void:
	var data := SimFixture.registry()
	var knight := data.get_unit(&"knight").combat
	var light := data.get_unit(&"light_cavalry").combat
	var halberd := data.get_unit(&"halberdier").combat
	var cross := data.get_unit(&"crossbowman").combat
	var archer := data.get_unit(&"archer").combat
	var heavy := data.get_unit(&"man_at_arms").combat
	assert_float(halberd.bonus_vs.get(&"knight", 1.0)).is_equal_approx(2.5, 0.001)
	assert_float(light.speed).is_greater(knight.speed)
	assert_int(cross.attack_range).is_less(archer.attack_range)
	assert_int(cross.attack).is_greater(archer.attack * 2)
	assert_int(heavy.attack).is_greater(data.get_unit(&"swordsman").combat.attack)
	assert_int(heavy.hp).is_greater(halberd.hp)
