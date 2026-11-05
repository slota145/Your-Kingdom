extends GdUnitTestSuite
## Dense forest (ROADMAP M4b-2): trees are walkable but slow people down, and a forester
## plants tile by tile with no limit, never on roads, fields or next to buildings.


func test_trees_are_walkable_and_slow() -> void:
	var sim := SimFixture.make_sim()
	var tile := Vector2i(10, 10)
	assert_float(sim.province.nav.get_cost(tile)).is_equal_approx(1.0, 0.001)
	SimFixture.plant_trees(sim, Rect2i(tile, Vector2i.ONE))
	assert_bool(sim.province.nav.is_walkable(tile)).is_true()
	assert_float(sim.province.nav.get_cost(tile)).is_equal_approx(1.5, 0.001)
	# A felled tree (taken with its stump) leaves plain ground.
	for i: int in 3:
		sim.province.resources.take(tile)
	sim.province.refresh_tile(tile)
	assert_float(sim.province.nav.get_cost(tile)).is_equal_approx(1.0, 0.001)


func test_people_walk_through_a_forest() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.plant_trees(sim, Rect2i(10, 0, 3, 32))
	var path := sim.province.find_path(Vector2i(5, 5), Vector2i(20, 5))
	assert_bool(path.is_empty()).is_false()


func test_forester_plants_tile_by_tile() -> void:
	var sim := SimFixture.make_sim()
	var province := sim.province
	assert_bool(province.can_plant(Vector2i(10, 10))).is_true()
	SimFixture.plant_trees(sim, Rect2i(10, 10, 1, 1))
	assert_bool(province.can_plant(Vector2i(11, 10))).is_true()
	assert_bool(province.can_plant(Vector2i(11, 11))).is_true()
	assert_bool(province.can_plant(Vector2i(10, 10))).is_false()


func test_forester_never_plants_on_roads_fields_or_by_buildings() -> void:
	var sim := SimFixture.make_sim()
	var province := sim.province
	province.set_road(Vector2i(5, 20), true)
	assert_bool(province.can_plant(Vector2i(5, 20))).is_false()
	assert_bool(province.can_plant(Vector2i(5, 21))).is_true()   # beside a road is fine
	var farm := SimFixture.place(sim, &"farm", Vector2i(20, 20))
	province.add_field(farm.id, Vector2i(18, 25))
	assert_bool(province.can_plant(Vector2i(18, 25))).is_false()
	var hut := SimFixture.place(sim, &"woodcutter", Vector2i(10, 4))
	assert_bool(province.can_plant(hut.door_front_tile())).is_false()
	for tile: Vector2i in hut.tiles():
		for step: Vector2i in [Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1)]:
			if not hut.tiles().has(tile + step):
				assert_bool(province.can_plant(tile + step)).is_false()


func test_forester_has_no_tree_limit() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	var lodge := SimFixture.place(sim, &"forester", Vector2i(20, 20))
	# Far more trees than the old limit of 30 in its range; there is still room left.
	SimFixture.plant_trees(sim, Rect2i(13, 13, 16, 4))
	var spot := sim.province.find_plant_spot(lodge, &"tree", lodge.entrance_tile())
	assert_bool(spot != Agent.NO_TILE).is_true()
	assert_bool(sim.province.can_plant(spot)).is_true()
