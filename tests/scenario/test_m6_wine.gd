extends GdUnitTestSuite
## M6 part 3 DoD: wine. Provinces with vines get patches of vine soil; a vineyard stands only
## by vine soil and lays its vines only there; its grapes go to the wine press (3 baskets ->
## a barrel in about 40 s); wine is an extra need of patricians: met, it raises happiness and
## tax; unmet, nothing changes (old maps without vines play as before).


func _registry() -> DataRegistry:
	return SimFixture.registry()


func _count_terrain(province: ProvinceSim, id: StringName) -> int:
	var index := _registry().get_terrain(id).index
	var n := 0
	for y: int in province.grid.size.y:
		for x: int in province.grid.size.x:
			if province.grid.terrain(Vector2i(x, y)) == index:
				n += 1
	return n


func test_only_provinces_with_vines_get_vine_soil() -> void:
	var sim := SimFixture.make_sim(Vector2i(16, 16))
	sim.world = WorldSim.from_def(_registry().get_world(&"kingdom"), _registry())
	var hills := sim.world.id_of(&"vine_hills")
	var vale := sim.world.id_of(&"willow_vale")
	sim.open_province(hills, _registry().get_map(&"riverlands"))
	sim.open_province(vale, _registry().get_map(&"riverlands"))
	var soil := _count_terrain(sim.province_state(hills), &"vine_soil")
	print("vine soil tiles in Vine Hills: ", soil)
	assert_int(soil).is_greater(100)
	assert_int(_count_terrain(sim.province_state(vale), &"vine_soil")).is_equal(0)
	# The same province always gets the same patches.
	var again := ProvinceSim.new(_registry(), _registry().get_map(&"riverlands").size_for(true), SimEvents.new(), sim.ids)
	again.treasury = Treasury.new()
	again.load_map(_registry().get_map(&"riverlands"), true, 2, false, &"vines")
	assert_int(_count_terrain(again, &"vine_soil")).is_equal(soil)


## 40x40 village with vine soil on the east side, vineyard and press.
func test_vineyard_grapes_become_wine() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var village := SimFixture.village(sim, 30, 40)
	SimFixture.place(sim, &"well", Vector2i(9, 9))
	for i: int in 3:
		SimFixture.house(sim, Vector2i(2 + 3 * i, 14))
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"vineyard", Vector2i(24, 20))))).is_equal("no_vine_soil_nearby")
	var soil := _registry().get_terrain(&"vine_soil")
	for y: int in range(26, 34):
		for x: int in range(20, 30):
			sim.province.grid.set_terrain(Vector2i(x, y), soil.index)
			sim.province.refresh_tile(Vector2i(x, y))
	var vineyard := SimFixture.place(sim, &"vineyard", Vector2i(23, 22))
	# Vines only on vine soil.
	assert_str(String(sim.execute(PlaceFieldCommand.new(vineyard.id, Vector2i(20, 21))))).is_equal("needs_vine_soil")
	var fields := 0
	for y: int in range(26, 30):
		for x: int in range(21, 28):
			if fields < 10 and sim.execute(PlaceFieldCommand.new(vineyard.id, Vector2i(x, y))) == &"":
				fields += 1
	assert_int(fields).is_equal(10)
	SimFixture.place(sim, &"wine_press", Vector2i(16, 4))
	var grapes := 0
	var wine := 0
	# Test houses come with full pantries (wine of the patrician level included).
	var before := sim.province.goods_total(&"wine")
	for i: int in SimFixture.ticks(12 * 60):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"good_harvested" and e["good"] == &"grapes":
				grapes += int(e["amount"])
			if e["type"] == &"good_produced" and e["good"] == &"wine":
				wine += int(e["amount"])
	print("vineyard in 12 min: grapes %d, wine %d" % [grapes, wine])
	assert_int(grapes).is_greater_equal(9)
	assert_int(wine).is_greater_equal(3)
	assert_int(sim.province.goods_total(&"wine")).is_equal(before + wine)
	assert_int(village.size()).is_greater(0)


## A patrician house with wine is happier and pays a quarter more; without wine it keeps its
## level and pays as before.
func test_wine_raises_patrician_happiness_and_tax() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	SimFixture.place(sim, &"town_hall", Vector2i(2, 2))
	var house := SimFixture.house(sim, Vector2i(10, 10))
	house.house.level = 3
	house.supply.stack_limit = house.level_def().supply_units
	house.house.residents = house.capacity()
	var wine := sim.data.get_def(&"need", &"wine") as NeedDef
	assert_bool(wine.extra).is_true()
	assert_bool(wine.is_basic).is_false()
	house.house.happiness = 80.0
	house.house.satisfied[&"wine"] = false
	var gold := sim.treasury.gold
	for i: int in 600:
		Population._pay_taxes(sim.province, house)
	var plain := sim.treasury.gold - gold
	house.house.satisfied[&"wine"] = true
	gold = sim.treasury.gold
	for i: int in 600:
		Population._pay_taxes(sim.province, house)
	var with_wine := sim.treasury.gold - gold
	print("patrician house in 10 min: %d gold, with wine %d" % [plain, with_wine])
	assert_int(with_wine).is_between(roundi(plain * 1.25) - 1, roundi(plain * 1.25) + 1)
	# Happiness: wine in the pantry is met and counts on top of the rest (at most 100).
	house.supply.add(&"wine", 4)
	Population.update(sim.province)
	sim.run_ticks(SimFixture.ticks(2))
	assert_bool(bool(house.house.satisfied.get(&"wine", false))).is_true()
