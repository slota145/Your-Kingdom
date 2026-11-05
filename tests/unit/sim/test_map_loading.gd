extends GdUnitTestSuite
## M3: the province map comes from an image; the start layout stands finished.

var _sim: Simulation
var _problems: PackedStringArray


func before() -> void:
	_problems = PackedStringArray()
	var registry := SimFixture.registry()
	_sim = Simulation.from_map(registry, registry.get_map(&"riverlands"), 1, _problems)


func test_map_loads_without_problems() -> void:
	assert_array(Array(_problems)).is_empty()
	assert_vector(_sim.province.grid.size).is_equal(Vector2i(96, 96))


func test_terrain_colours_are_unique() -> void:
	var seen := {}
	for terrain: TerrainDef in SimFixture.registry().terrains_by_index():
		assert_object(terrain).is_not_null()
		var color := terrain.map_color.to_html(false)
		assert_bool(seen.has(color)).override_failure_message("duplicate colour " + color).is_false()
		seen[color] = true


func test_forest_has_trees_and_water_blocks() -> void:
	var province := _sim.province
	var trees := 0
	var water := 0
	for y: int in 96:
		for x: int in 96:
			var tile := Vector2i(x, y)
			var terrain := province.terrain_at(tile)
			if terrain.id == &"forest" and province.resources.has_node(tile, &"tree"):
				trees += 1
			if terrain.id == &"water":
				water += 1
				assert_bool(province.nav.is_walkable(tile)).is_false()
	assert_int(trees).is_greater(200)
	assert_int(water).is_greater(100)


func test_river_is_crossed_only_at_fords() -> void:
	var province := _sim.province
	var path := province.nav.find_path(Vector2i(40, 30), Vector2i(90, 40))
	assert_array(path).is_not_empty()
	var crossed_ford := false
	for tile: Vector2i in path:
		if province.terrain_at(tile).id == &"ford":
			crossed_ford = true
	assert_bool(crossed_ford).is_true()


func test_start_layout() -> void:
	var province := _sim.province
	var counts := {}
	var residents := 0
	for building: BuildingState in province.buildings.all():
		assert_bool(building.is_complete()).is_true()
		counts[building.def.id] = int(counts.get(building.def.id, 0)) + 1
		if building.house != null:
			residents += building.house.residents
	assert_dict(counts).is_equal({&"town_hall": 1, &"stockpile": 1, &"hut": 3})
	assert_int(residents).is_equal(12)
	assert_int(province.goods_total(&"bread")).is_greater(0)
	assert_int(province.goods_total(&"wood")).is_greater(0)
	assert_bool(province.nav.is_walkable(province.entry_tile)).is_true()


func test_water_cannot_be_built_on() -> void:
	var province := _sim.province
	for y: int in 96:
		for x: int in 96:
			if province.terrain_at(Vector2i(x, y)).id == &"water":
				assert_str(String(province.placement_error(
						SimFixture.registry().get_building(&"well"), Vector2i(x, y)))) \
						.is_equal("terrain_not_buildable")
				return
