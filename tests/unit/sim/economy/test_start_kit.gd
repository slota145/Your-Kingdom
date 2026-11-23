extends GdUnitTestSuite
## UI-3 part 2 (owner's choice 2026-11-23): what lies on the ground goes at once into the
## first storage built; more food in the ship's start kit.


func test_the_first_storage_takes_the_goods_on_the_ground() -> void:
	var sim := SimFixture.make_sim()
	var p := sim.province
	p.drop_goods(Vector2i(20, 20), &"bread", 40)
	p.drop_goods(Vector2i(21, 20), &"fish", 12)
	var store := SimFixture.place(sim, &"stockpile", Vector2i(4, 4))
	assert_bool(p.is_first_storage(store)).is_true()
	p.store_loose_goods(store)
	assert_int(store.stock.total(&"bread")).is_equal(40)
	assert_int(store.stock.total(&"fish")).is_equal(12)
	assert_bool(p.piles.is_empty()).is_true()
	assert_int(p.jobs.count()).is_equal(0)
	# A second storage is not the first.
	var other := SimFixture.place(sim, &"stockpile", Vector2i(10, 4))
	assert_bool(p.is_first_storage(other)).is_false()


func test_goods_a_porter_comes_for_stay_on_the_ground() -> void:
	var sim := SimFixture.make_sim()
	var p := sim.province
	var pile_id := p.drop_goods(Vector2i(20, 20), &"wood", 10)
	var pile := p.piles[pile_id] as GroundPile
	var held := pile.stock.reserve_out(&"wood", 4, 99)
	assert_int(held).is_not_equal(0)
	var store := SimFixture.place(sim, &"stockpile", Vector2i(4, 4))
	p.store_loose_goods(store)
	assert_int(store.stock.total(&"wood")).is_equal(6)
	assert_int(pile.stock.total(&"wood")).is_equal(4)
	assert_bool(p.piles.has(pile_id)).is_true()


func test_the_ship_brings_more_food() -> void:
	var coast := SimFixture.registry().get_map(&"coast")
	assert_int(coast.start_pile.get(&"bread", 0)).is_equal(60)
	assert_int(coast.start_pile.get(&"fish", 0)).is_equal(30)
	assert_int(coast.start_pile.get(&"wood", 0)).is_equal(90)
	var islands := SimFixture.registry().get_map(&"islands")
	assert_dict(islands.start_pile).is_equal(coast.start_pile)
