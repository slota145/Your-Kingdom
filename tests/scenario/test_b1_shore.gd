extends GdUnitTestSuite
## B1 part 2: the angler's hut, the clay pit, the crane and the port warehouse may stand with
## one edge row over shallow water on piles (owner's survey 2026-11-08); never over deep sea,
## never damming a river, never cutting boats off the open sea; other buildings as before.


## 48x48 with a river [param width] tiles wide from column 20, top to bottom; a village.
func _river_sim(width: int = 4) -> Simulation:
	var sim := SimFixture.make_sim(Vector2i(48, 48), 1)
	var water := SimFixture.registry().get_terrain(&"water")
	for y: int in sim.province.grid.size.y:
		for x: int in range(20, 20 + width):
			sim.province.grid.set_terrain(Vector2i(x, y), water.index)
	sim.province.rebuild_nav()
	SimFixture.village(sim, 40, 20)
	return sim


## The first way the building can be turned at [param origin], or the last reason it cannot.
func _place_error(sim: Simulation, id: StringName, origin: Vector2i) -> StringName:
	var def := sim.data.get_building(id)
	var error := &""
	for o: int in def.orientation_count():
		error = sim.province.placement_error(def, origin, o)
		if error == &"":
			return error
	return error


func test_angler_hut_stands_with_one_row_over_the_river() -> void:
	var sim := _river_sim()
	var def := sim.data.get_building(&"fishing_hut")
	assert_str(String(_place_error(sim, &"fishing_hut", Vector2i(19, 10)))).is_empty()
	assert_array(sim.province.stilt_tiles(def, Vector2i(19, 10))).contains_exactly_in_any_order(
			[Vector2i(20, 10), Vector2i(20, 11)])
	# Both rows over the water: no.
	assert_str(String(_place_error(sim, &"fishing_hut", Vector2i(20, 10)))).is_equal("too_much_water")
	# On the far bank the piles are fine too; only nobody can walk there without a bridge.
	assert_str(String(_place_error(sim, &"fishing_hut", Vector2i(23, 20)))).is_equal("no_access")
	# Placed for real: its tiles over the water are the building's, boats or no boats.
	var hut := SimFixture.place(sim, &"fishing_hut", Vector2i(19, 10))
	assert_int(sim.province.grid.occupant(Vector2i(20, 10))).is_equal(hut.id)
	assert_bool(sim.province.nav.is_walkable(Vector2i(20, 10))).is_false()


func test_clay_pit_too_and_other_buildings_stay_on_land() -> void:
	var sim := _river_sim()
	assert_str(String(_place_error(sim, &"clay_pit", Vector2i(19, 30)))).is_empty()
	assert_str(String(_place_error(sim, &"woodcutter", Vector2i(19, 30)))).is_equal("terrain_not_buildable")


func test_a_narrow_river_is_not_dammed() -> void:
	# 3 wide: 2 tiles of water stay beyond the piles.
	var sim := _river_sim(3)
	assert_str(String(_place_error(sim, &"fishing_hut", Vector2i(19, 10)))).is_empty()
	# 2 wide: only one would stay.
	sim = _river_sim(2)
	assert_str(String(_place_error(sim, &"fishing_hut", Vector2i(19, 10)))).is_equal("blocks_water")
	# Nor face to face with another hut on the other bank.
	sim = _river_sim(3)
	SimFixture.place(sim, &"fishing_hut", Vector2i(19, 10))
	assert_str(String(_place_error(sim, &"fishing_hut", Vector2i(22, 10)))).is_equal("blocks_water")


func test_shallow_sea_yes_deep_sea_no() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48), 1)
	SimFixture.coast(sim, 30, 33)
	SimFixture.village(sim, 40, 20)
	# Land on row 29, shallow sea on row 30 (and 31, 32 beyond it).
	assert_str(String(_place_error(sim, &"fishing_hut", Vector2i(12, 29)))).is_empty()
	# Shallow on row 32, deep on row 33: deep sea takes no piles.
	var shallow := SimFixture.registry().get_terrain(&"sea_shallow")
	for x: int in range(30, 40):
		for y: int in range(25, 33):
			if y < 32:
				sim.province.grid.set_terrain(Vector2i(x, y), SimFixture.registry().get_terrain(&"grass").index)
	sim.province.rebuild_nav()
	assert_int(sim.province.grid.terrain(Vector2i(34, 32))).is_equal(shallow.index)
	assert_str(String(_place_error(sim, &"fishing_hut", Vector2i(34, 32)))).is_not_empty()


## The port warehouse still needs a quay under its other rows; its last row may hang over
## shallow water on piles.
func test_port_warehouse_leans_one_row_off_the_quay() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48), 1)
	SimFixture.coast(sim, 30, 34)
	SimFixture.village(sim, 40, 20)
	var province := sim.province
	for x: int in range(8, 16):
		for y: int in range(30, 32):
			province.grid.set_quay(Vector2i(x, y), TileGrid.STONE_QUAY)
			province.refresh_tile(Vector2i(x, y))
	province.refresh_fairways()
	var def := sim.data.get_building(&"port_warehouse")
	assert_str(String(_place_error(sim, &"port_warehouse", Vector2i(10, 30)))).is_empty()
	assert_array(province.stilt_tiles(def, Vector2i(10, 30))).has_size(3)
	# Two rows over the water: no.
	assert_str(String(_place_error(sim, &"port_warehouse", Vector2i(10, 31)))).is_equal("too_much_water")
