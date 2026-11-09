extends GdUnitTestSuite
## P2 part 3: the builders' hut gives the town more builders; five tax rates, one for the
## whole town (owner's survey 2026-11-09).


## A village with 6 full huts (enough hands for the hall and a builders' hut) and [param hut]
## a builders' hut; then 4 wells ordered. Returns the seconds until all 4 stand.
func _wells_time(with_hut: bool) -> float:
	var sim := SimFixture.make_sim(Vector2i(40, 40), 1)
	var village := SimFixture.village(sim, 60, 40)
	for i: int in 4:
		SimFixture.house(sim, Vector2i(8 + 3 * i, 8))
	if with_hut:
		var hut := SimFixture.place(sim, &"builders_hut", Vector2i(14, 2))
		assert_bool(SimFixture.run_until(sim, func() -> bool: return hut.workers.size() == 2, 30)).is_true()
	else:
		SimFixture.run_until(sim, func() -> bool: return false, 2)
	var wells: Array[int] = []
	for i: int in 4:
		var at := Vector2i(4 + 4 * i, 16)
		assert_str(String(sim.execute(PlaceBuildingCommand.new(&"well", at)))).is_empty()
		wells.append(sim.province.grid.occupant(at))
	var start := sim.province.tick
	var done := SimFixture.run_until(sim, func() -> bool:
		for id: int in wells:
			var well := sim.province.buildings.get_building(id)
			if well == null or not well.is_complete():
				return false
		return true, 400)
	assert_bool(done).is_true()
	return float(sim.province.tick - start) / SimClock.TICKS_PER_SECOND


func test_builders_hut_builds_faster() -> void:
	var alone := _wells_time(false)
	var helped := _wells_time(true)
	print("4 wells: town hall's builder %.1f s, with a builders' hut %.1f s" % [alone, helped])
	# Porters bringing the wood limit it too: clearly faster, not three times.
	assert_float(helped).is_less(alone * 0.85)


func test_five_tax_rates_and_older_saves() -> void:
	var sim := SimFixture.make_sim(Vector2i(24, 24), 1)
	for rate: int in Treasury.RATE_KEYS.size():
		assert_str(String(sim.execute(SetTaxRateCommand.new(rate)))).is_empty()
		assert_int(sim.treasury.tax_rate).is_equal(rate)
	assert_str(String(sim.execute(SetTaxRateCommand.new(5)))).is_not_empty()
	assert_float(Treasury.RATE_FACTOR[Treasury.TaxRate.NONE]).is_equal(0.0)
	assert_float(Treasury.RATE_FACTOR[Treasury.TaxRate.VERY_HIGH]).is_greater(Treasury.RATE_FACTOR[Treasury.TaxRate.HIGH])
	assert_float(Treasury.RATE_HAPPINESS[Treasury.TaxRate.NONE]).is_greater(Treasury.RATE_HAPPINESS[Treasury.TaxRate.LOW])
	assert_float(Treasury.RATE_HAPPINESS[Treasury.TaxRate.VERY_HIGH]).is_less(Treasury.RATE_HAPPINESS[Treasury.TaxRate.HIGH])
	# An older save's low, normal and high (0, 1, 2) keep their meaning.
	for old: int in 3:
		var state := SaveMigrations.migrate({"treasury": {"gold": 10, "rate": old}}, 25)
		assert_int(int(state["treasury"]["rate"])).is_equal([Treasury.TaxRate.LOW, Treasury.TaxRate.NORMAL,
				Treasury.TaxRate.HIGH][old])
	assert_int(SaveMigrations.CURRENT_VERSION).is_greater_equal(26)


## The panel's icons read what a building needs and makes from its recipe.
func test_goods_flow_of_workshops() -> void:
	var data := SimFixture.registry()
	var cases := {&"bakery": [[&"flour"], [&"bread"]], &"woodcutter": [[], [&"wood"]], &"farm": [[], [&"grain"]],
			&"sawmill": [[&"wood"], [&"planks"]]}
	for id: StringName in cases:
		var flow: Array = BuildingPanel.goods_flow(data.get_building(id), data)
		assert_array(flow[0]).override_failure_message("%s needs %s" % [id, flow[0]]).contains_exactly(cases[id][0])
		assert_array(flow[1]).override_failure_message("%s makes %s" % [id, flow[1]]).contains_exactly(cases[id][1])
