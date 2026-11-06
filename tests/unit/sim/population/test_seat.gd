extends GdUnitTestSuite
## M6 part 2: the town hall is the province's seat. Burghers and patricians pay their class's
## tax only where one stands (finished); one town hall per province.


func test_burghers_pay_full_tax_only_with_a_town_hall() -> void:
	var sim := SimFixture.make_sim()
	var hut := SimFixture.house(sim, Vector2i(10, 10))
	hut.house.level = 2
	var peasants := hut.def.house_levels[0].tax_per_minute
	var burghers := hut.def.house_levels[1].tax_per_minute
	assert_float(burghers).is_greater(peasants)
	assert_bool(sim.province.has_seat()).is_false()
	assert_float(Population.tax_per_minute(sim.province, hut)).is_equal(peasants)
	# A town hall under construction is not a seat yet.
	sim.execute(PlaceBuildingCommand.new(&"town_hall", Vector2i(2, 2)))
	assert_bool(sim.province.has_seat()).is_false()
	assert_float(Population.tax_per_minute(sim.province, hut)).is_equal(peasants)
	sim.province.seat().finish(sim.data)
	sim.province.seat().under_construction = false
	assert_bool(sim.province.has_seat()).is_true()
	assert_float(Population.tax_per_minute(sim.province, hut)).is_equal(burghers)
	# Peasants pay the same either way.
	hut.house.level = 1
	assert_float(Population.tax_per_minute(sim.province, hut)).is_equal(peasants)


func test_only_one_town_hall_per_province() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.place(sim, &"town_hall", Vector2i(2, 2))
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"town_hall", Vector2i(12, 12), true)))) \
			.is_equal("only_one")
