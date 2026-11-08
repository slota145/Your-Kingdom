extends GdUnitTestSuite
## J1 part 3: the large shipyard builds caravels, carracks and galleons (each for trade or for
## war); an army at sea keeps its warships by kind, a sea battle weighs them by their hull and
## bolts, and the ships sunk stay sunk.


func _units(d: Dictionary) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for unit: Variant in d:
		result[StringName(String(unit))] = int(d[unit])
	return result


func _fleet(d: Dictionary) -> BattleSide:
	var side := BattleSide.new(_units(d.get("men", {})), true, 0)
	for id: Variant in d.get("ships", {}):
		side.fleet[StringName(String(id))] = int(d["ships"][id])
		side.ships += int(d["ships"][id])
	return side


func test_each_ship_is_bigger_than_the_last() -> void:
	var data := SimFixture.registry()
	var order := [&"cog", &"caravel", &"carrack", &"galleon"]
	for k: int in range(1, order.size()):
		var small := data.get_ship(order[k - 1])
		var big := data.get_ship(order[k])
		assert_int(big.hold_slots).is_greater(small.hold_slots)
		assert_int(data.get_ship(StringName(String(order[k]) + "_war")).troops).is_greater(
				data.get_ship(&"warship").troops if k == 1 else data.get_ship(StringName(String(order[k - 1]) + "_war")).troops)
	for id: StringName in [&"caravel", &"carrack", &"galleon"]:
		assert_bool(data.get_ship(id).trades).is_true()
		var war := data.get_ship(StringName(String(id) + "_war"))
		assert_int(war.troops).is_greater(0)
		assert_bool(war.trades).is_false()
	assert_int(data.get_ship(&"galleon_war").hp).is_greater(data.get_ship(&"carrack_war").hp)
	assert_int(data.get_ship(&"carrack_war").hp).is_greater(data.get_ship(&"caravel_war").hp)
	assert_int(data.get_ship(&"caravel_war").hp).is_greater(data.get_ship(&"warship").hp)


func test_large_shipyard_builds_a_caravel() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48), 1)
	SimFixture.coast(sim, 30, 33)
	var village := SimFixture.village(sim, 60, 40)
	var stock: BuildingState = village["stock"]
	stock.stock.add(&"planks", 40)
	stock.stock.add(&"tar", 12)
	stock.stock.add(&"cloth", 12)
	for i: int in 3:
		SimFixture.house(sim, Vector2i(14 + 3 * i, 8))
	var yard := SimFixture.place(sim, &"large_shipyard", Vector2i(10, 27))
	assert_str(String(sim.execute(OrderShipCommand.new(yard.id, &"caravel")))).is_empty()
	# The small shipyard's ships are not built here, nor the big ones there.
	assert_str(String(sim.execute(OrderShipCommand.new(yard.id, &"cog")))).is_not_empty()
	var small := SimFixture.place(sim, &"shipyard", Vector2i(30, 28))
	assert_str(String(sim.execute(OrderShipCommand.new(small.id, &"galleon")))).is_not_empty()
	var built := [0]
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		for ship: ShipUnit in sim.province.ships.values():
			if ship.def.id == &"caravel":
				built[0] = ship.id
				return true
		return false, 900)).is_true()
	var caravel: ShipUnit = sim.province.ships[built[0]]
	assert_int(caravel.hold.slot_count()).is_equal(6)


func test_a_galleon_outfights_two_war_cogs_at_sea() -> void:
	var data := SimFixture.registry()
	var rng := RandomNumberGenerator.new()
	var wins := 0
	for k: int in 10:
		rng.seed = 31 * (k + 1)
		var r := BattleResolver.resolve(data, _fleet({"men": {"spearman": 40}, "ships": {"galleon_war": 1}}),
				_fleet({"men": {"spearman": 40}, "ships": {"warship": 2}}), BattleResolver.Kind.NAVAL, rng)
		if r.a_won():
			wins += 1
	assert_int(wins).is_greater_equal(6)


func test_men_drown_beyond_the_room_of_the_ships_left() -> void:
	var data := SimFixture.registry()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var r := BattleResolver.resolve(data, _fleet({"men": {"spearman": 60}, "ships": {"caravel_war": 1, "warship": 1}}),
			_fleet({"men": {"spearman": 80, "archer": 30}, "ships": {"galleon_war": 1, "carrack_war": 1}}),
			BattleResolver.Kind.NAVAL, rng)
	assert_bool(r.a_won()).is_false()
	var left := 0
	for unit: StringName in r.left_a:
		left += r.left_a[unit]
	# A caravel carries 40, a war cog 30: whatever stays afloat, no more men than that.
	assert_int(left).is_less_equal(70)
	assert_int(r.ships_left_a).is_less_equal(2)


func test_an_army_keeps_its_fleet_by_kind_and_sunk_ships_stay_sunk() -> void:
	var army := Army.new()
	army.ships = 3
	army.fleet = {&"galleon_war": 1, &"warship": 2}
	var side := army.side()
	assert_int(side.fleet[&"galleon_war"]).is_equal(1)
	army.sink_to(1)
	assert_int(army.ships).is_equal(1)
	assert_int(army.fleet.values().reduce(func(a: int, b: int) -> int: return a + b, 0)).is_equal(1)
	# Saved and loaded alike; an army saved before J1 (ships only) had war cogs.
	var copy := Army.from_dict(army.to_dict())
	assert_dict(copy.fleet).is_equal(army.fleet)
	var old := Army.from_dict({"id": 7, "ships": 2, "fleet_home": 1})
	assert_dict(old.fleet).is_equal({&"warship": 2})
	assert_int(SaveMigrations.CURRENT_VERSION).is_greater_equal(23)
