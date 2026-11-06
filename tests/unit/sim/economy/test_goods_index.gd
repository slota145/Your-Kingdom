extends GdUnitTestSuite
## M4b-3: searches for a source or a room look only at buildings that can hold the good
## (ProvinceSim.storage_buildings, yard_buildings, market_buildings), kept up to date as
## buildings come and go.


func test_index_follows_new_and_removed_buildings() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	var province := sim.province
	var far := SimFixture.place(sim, &"stockpile", Vector2i(30, 30))
	far.stock.add(&"wood", 4)
	assert_int(province.nearest_source(&"wood", 2, Vector2i(2, 2))).is_equal(far.id)
	var near := SimFixture.place(sim, &"stockpile", Vector2i(4, 4))
	near.stock.add(&"wood", 3)
	assert_int(province.nearest_source(&"wood", 2, Vector2i(2, 2))).is_equal(near.id)
	assert_int(province.nearest_sink(&"wood", 1, Vector2i(2, 2))).is_equal(near.id)
	assert_int(province.stored(&"wood")).is_equal(7)
	province.remove_building(near.id)
	assert_int(province.nearest_sink(&"wood", 1, Vector2i(2, 2))).is_equal(far.id)
	assert_int(province.storage_buildings().size()).is_equal(1)


func test_production_yards_and_market_stalls_count() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	var province := sim.province
	var hut := SimFixture.place(sim, &"woodcutter", Vector2i(10, 10))
	hut.yard.add(&"wood", 2)
	var market := SimFixture.place(sim, &"market", Vector2i(20, 10))
	market.supply.add(&"bread", 3)
	assert_bool(province.yard_buildings(&"wood").has(hut)).is_true()
	assert_bool(province.yard_buildings(&"bread").is_empty()).is_true()
	assert_int(province.nearest_source(&"wood", 2, Vector2i(2, 2))).is_equal(ProvinceSim.yard_id(hut.id))
	assert_int(province.stored(&"wood")).is_equal(2)
	assert_int(province.stored(&"bread")).is_equal(3)
	assert_array(province.market_buildings()).contains_exactly([market])


## The list of all agents is shared until something changes; removing one while looping over
## it leaves the loop's list as it was.
func test_agent_list_is_cached_and_safe_to_change_in_a_loop() -> void:
	var sim := SimFixture.make_sim(Vector2i(16, 16))
	var province := sim.province
	for i: int in 3:
		SimFixture.spawn(sim, &"porter", Vector2i(2 + i, 2))
	var list := province.agents.all()
	assert_bool(is_same(list, province.agents.all())).is_true()
	var seen := 0
	for agent: Agent in list:
		province.remove_agent(agent)
		seen += 1
	assert_int(seen).is_equal(3)
	assert_int(province.agents.all().size()).is_equal(0)
