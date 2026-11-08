extends GdUnitTestSuite
## M7 part 2, step A: walls in the game (ROADMAP M7, GDD §5.3, ARCHITECTURE §6.3).
## - palisades, stone walls and stairs are ordered as lines and laid tile by tile by a builder
##   with material brought by porters; a laid wall blocks the ground,
## - stone walls corner to corner get wedges ("straight" diagonals), solid on the ground,
## - walls may not cut a part of the town off; a gatehouse lets people through,
## - stairs lean against a stone wall; walls have life and fall when it runs out.


func _town(stone: int = 60) -> Simulation:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var v := SimFixture.village(sim, 60)
	(v["stock"] as BuildingState).stock.add(&"stone", stone)
	return sim


func _row(y: int, x0: int, x1: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x: int in range(x0, x1 + 1):
		tiles.append(Vector2i(x, y))
	return tiles


func test_builder_lays_a_stone_wall_with_stone_from_the_store() -> void:
	var sim := _town()
	var province := sim.province
	var line := _row(20, 10, 13)
	assert_str(String(sim.execute(BuildWallCommand.new(line, Walls.STONE)))).is_empty()
	var site: PavingSite = province.paving.values()[0]
	assert_bool(site.is_wall()).is_true()
	assert_int(site.per_tile()).is_equal(3)
	var stone_before := province.stored(&"stone")
	assert_bool(SimFixture.run_until(sim, func() -> bool: return province.paving.is_empty(), 400)).is_true()
	for tile: Vector2i in line:
		assert_int(province.walls.kind(tile)).is_equal(Walls.STONE)
		assert_int(province.walls.hp(tile)).is_equal(Walls.STONE_HP)
		assert_bool(province.nav.is_walkable(tile)).is_false()
		assert_bool(province.walls.is_walkway(tile)).is_true()
	assert_int(stone_before - province.stored(&"stone")).is_equal(12)
	assert_int(province.claim_count()).is_equal(0)


func test_palisade_costs_wood_and_has_no_wall_walk() -> void:
	var sim := _town()
	var province := sim.province
	var wood_before := province.stored(&"wood")
	assert_str(String(sim.execute(BuildWallCommand.new(_row(22, 10, 11), Walls.PALISADE)))).is_empty()
	assert_bool(SimFixture.run_until(sim, func() -> bool: return province.paving.is_empty(), 300)).is_true()
	assert_int(wood_before - province.stored(&"wood")).is_equal(4)
	assert_int(province.walls.kind(Vector2i(10, 22))).is_equal(Walls.PALISADE)
	assert_bool(province.nav.is_walkable(Vector2i(10, 22))).is_false()
	assert_bool(province.walls.is_walkway(Vector2i(10, 22))).is_false()


func test_diagonal_stone_wall_gets_solid_wedges() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var province := sim.province
	var line := BuildWallCommand.line(Vector2i(10, 10), Vector2i(13, 13))
	assert_int(line.size()).is_equal(4)
	for tile: Vector2i in line:
		province.lay_wall(tile, Walls.STONE)
	# Wedges fill both sides of every step, so the diagonal wall is sealed and straight.
	for tile: Vector2i in [Vector2i(11, 10), Vector2i(10, 11), Vector2i(13, 12), Vector2i(12, 13)]:
		assert_bool(province.walls.wedges.has(tile)).override_failure_message("wedge at %s" % tile).is_true()
		assert_bool(province.nav.is_walkable(tile)).is_false()
	# A 90° corner (the wall runs on straight through the corner tile) gets no wedge.
	var corner := SimFixture.make_sim(Vector2i(32, 32)).province
	for tile: Vector2i in [Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(6, 6), Vector2i(6, 7)]:
		corner.lay_wall(tile, Walls.STONE)
	assert_bool(corner.walls.wedges.has(Vector2i(5, 6))).is_false()
	# Same rule as the view model.
	var model := BlockWallModel.new()
	for tile: Vector2i in line:
		model.walls[tile] = false
	model.build()
	assert_array(model.wedge_tiles.keys()).contains_exactly_in_any_order(province.walls.wedges.keys())


func test_wall_may_not_cut_the_town_apart_but_a_gatehouse_lets_people_through() -> void:
	var sim := _town()
	var province := sim.province
	# A wall right across the map, between the village (top) and a hut at the bottom.
	SimFixture.house(sim, Vector2i(20, 30))
	var across := _row(20, 0, 39)
	var plan := province.wall_plan(across, Walls.STONE)
	assert_array(plan["tiles"]).is_empty()
	assert_str(String((plan["errors"] as Dictionary)[Vector2i(5, 20)])).is_equal("blocks_access")
	# With a gatehouse in the line the wall is fine, and people walk through it.
	var gate := SimFixture.place(sim, &"gatehouse", Vector2i(19, 19))
	assert_array(gate.passage_tiles()).contains_exactly_in_any_order(
			[Vector2i(20, 19), Vector2i(20, 20), Vector2i(20, 21)])
	plan = province.wall_plan(across, Walls.STONE)
	assert_int((plan["tiles"] as Array).size()).is_equal(37)
	for tile: Vector2i in plan["tiles"]:
		province.lay_wall(tile, Walls.STONE)
	var path := province.find_path(Vector2i(20, 10), Vector2i(20, 28))
	assert_array(path).is_not_empty()
	assert_bool(path.has(Vector2i(20, 20))).is_true()
	# The gate's side tiles are part of the stone mass and the wall-walk.
	assert_bool(province.walls.is_mass(Vector2i(19, 20))).is_true()
	assert_bool(province.walls.is_walkway(Vector2i(21, 20))).is_true()
	assert_bool(province.nav.is_walkable(Vector2i(19, 20))).is_false()


func test_gatehouse_replaces_the_wall_it_stands_in() -> void:
	var sim := _town()
	var province := sim.province
	for tile: Vector2i in _row(20, 14, 26):
		province.lay_wall(tile, Walls.STONE)
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"gatehouse", Vector2i(19, 19), true)))).is_empty()
	assert_int(province.walls.kind(Vector2i(20, 20))).is_equal(Walls.NONE)
	assert_bool(province.nav.is_walkable(Vector2i(20, 20))).is_true()
	# Other buildings may not stand on a wall.
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"well", Vector2i(14, 20), true)))).is_equal("tile_occupied")


func test_stairs_lean_against_a_stone_wall() -> void:
	var sim := _town()
	var province := sim.province
	var stairs: Array[Vector2i] = [Vector2i(12, 21)]
	assert_str(String(sim.execute(BuildWallCommand.new(stairs, Walls.STAIRS)))).is_equal("needs_stone_wall")
	for tile: Vector2i in _row(20, 10, 14):
		province.lay_wall(tile, Walls.STONE)
	assert_str(String(sim.execute(BuildWallCommand.new(stairs, Walls.STAIRS)))).is_empty()
	assert_bool(SimFixture.run_until(sim, func() -> bool: return province.paving.is_empty(), 300)).is_true()
	assert_int(province.walls.stairs_dir(Vector2i(12, 21))).is_equal(3)   # up towards -y
	assert_object(province.walls.stairs_top(Vector2i(12, 21))).is_equal(Vector2i(12, 20))
	assert_bool(province.nav.is_walkable(Vector2i(12, 21))).is_true()
	# Stairs go when their wall falls.
	assert_bool(province.damage_wall(Vector2i(12, 20), Walls.STONE_HP)).is_true()
	assert_int(province.walls.kind(Vector2i(12, 21))).is_equal(Walls.NONE)


func test_wall_falls_when_its_life_runs_out_and_is_walkable_again() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var province := sim.province
	province.lay_wall(Vector2i(8, 8), Walls.PALISADE)
	assert_bool(province.damage_wall(Vector2i(8, 8), 200)).is_false()
	assert_int(province.walls.hp(Vector2i(8, 8))).is_equal(100)
	assert_bool(province.damage_wall(Vector2i(8, 8), 200)).is_true()
	assert_bool(province.nav.is_walkable(Vector2i(8, 8))).is_true()


func test_pulling_a_wall_down_gives_part_of_the_stone_back() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var province := sim.province
	province.lay_wall(Vector2i(8, 8), Walls.STONE)
	assert_str(String(sim.execute(RemoveWallCommand.new(Vector2i(8, 8))))).is_empty()
	assert_int(province.walls.kind(Vector2i(8, 8))).is_equal(Walls.NONE)
	assert_int(province.goods_total(&"stone")).is_greater(0)


func test_walls_and_their_orders_survive_a_save() -> void:
	var sim := _town()
	var province := sim.province
	for tile: Vector2i in BuildWallCommand.line(Vector2i(20, 10), Vector2i(23, 13)):
		province.lay_wall(tile, Walls.STONE)
	province.damage_wall(Vector2i(21, 11), 300)
	SimFixture.place(sim, &"gatehouse", Vector2i(28, 10))
	assert_str(String(sim.execute(BuildWallCommand.new(_row(30, 10, 12), Walls.PALISADE)))).is_empty()
	var copy := ProvinceSim.from_dict(JSON.parse_string(JSON.stringify(province.to_dict())),
			sim.data, SimEvents.new(), EntityIds.new())
	assert_int(copy.walls.hp(Vector2i(21, 11))).is_equal(700)
	assert_array(copy.walls.wedges.keys()).contains_exactly_in_any_order(province.walls.wedges.keys())
	assert_bool(copy.nav.is_walkable(Vector2i(29, 11))).is_true()   # the gate passage
	assert_bool(copy.nav.is_walkable(Vector2i(28, 11))).is_false()
	assert_int((copy.paving.values()[0] as PavingSite).kind).is_equal(PavingSite.KIND_PALISADE)
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(province.to_dict()))
