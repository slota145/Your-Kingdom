extends GdUnitTestSuite
## M6 part 2: a province plays a variant of its map template: mirrored (x and y swapped, on
## screen left and right) and with more or fewer raw materials by its richness (1-3).


func _province(map_id: StringName, mirrored: bool, richness: int, settled: bool = false) -> ProvinceSim:
	var registry := SimFixture.registry()
	var map := registry.get_map(map_id)
	var province := ProvinceSim.new(registry, map.size_for(mirrored), SimEvents.new(), EntityIds.new())
	assert_array(Array(province.load_map(map, mirrored, richness, settled))).is_empty()
	return province


func test_mirrored_map_swaps_x_and_y() -> void:
	var plain := _province(&"riverlands", false, 2)
	var mirrored := _province(&"riverlands", true, 2)
	for tile: Vector2i in [Vector2i(3, 70), Vector2i(50, 12), Vector2i(90, 41)]:
		assert_int(mirrored.grid.terrain(Vector2i(tile.y, tile.x))).is_equal(plain.grid.terrain(tile))
	assert_that(mirrored.entry_tile).is_equal(Vector2i(plain.entry_tile.y, plain.entry_tile.x))
	# The start town stands mirrored too, every building turned (orientation 1).
	assert_int(mirrored.buildings.count()).is_equal(plain.buildings.count())
	for b: BuildingState in plain.buildings.all():
		var twin := mirrored.buildings.get_building(mirrored.grid.occupant(Vector2i(b.origin.y, b.origin.x)))
		assert_object(twin).is_not_null()
		assert_str(String(twin.def.id)).is_equal(String(b.def.id))
		assert_int(twin.orientation).is_equal(1)


func test_mirrored_coast_lands_on_the_mirrored_beach() -> void:
	var mirrored := _province(&"coast", true, 2)
	var map := SimFixture.registry().get_map(&"coast")
	assert_object(mirrored.landing).is_not_null()
	assert_that(mirrored.landing.beach).is_equal(Vector2i(map.beach_tile.y, map.beach_tile.x))
	assert_int(mirrored.sail_depth(mirrored.landing.anchor)).is_greater(0)


func test_richness_thins_out_or_enriches_the_raw_materials() -> void:
	var poor := _province(&"lakeland", false, 1)
	var normal := _province(&"lakeland", false, 2)
	var rich := _province(&"lakeland", false, 3)
	var nodes_poor := poor.resources.tiles_with_nodes().size()
	var nodes := normal.resources.tiles_with_nodes().size()
	assert_int(nodes_poor).is_less(nodes * 0.8)
	assert_int(nodes_poor).is_greater(nodes * 0.5)
	assert_int(rich.resources.tiles_with_nodes().size()).is_equal(nodes)
	var units_normal := 0
	var units_rich := 0
	for tile: Vector2i in normal.resources.tiles_with_nodes():
		units_normal += normal.resources.amount(tile)
		units_rich += rich.resources.amount(tile)
	assert_int(units_rich).is_greater(units_normal * 1.3)


func test_settled_province_has_no_start_layout() -> void:
	var settled := _province(&"riverlands", false, 2, true)
	assert_int(settled.buildings.count()).is_equal(0)
	assert_object(settled.landing).is_null()
	assert_str(String(settled.first_building)).is_equal("pioneer_camp")


func test_islands_map_loads_with_a_landing() -> void:
	var islands := _province(&"islands", false, 2)
	assert_object(islands.landing).is_not_null()
	assert_bool(islands.nav.is_walkable(islands.landing.beach)).is_true()
	assert_int(islands.sail_depth(islands.landing.anchor)).is_equal(2)
	# The map has no land edge: water all round.
	for tile: Vector2i in [Vector2i(0, 0), Vector2i(127, 0), Vector2i(0, 127), Vector2i(127, 127)]:
		assert_int(islands.sail_depth(tile)).is_greater(0)
