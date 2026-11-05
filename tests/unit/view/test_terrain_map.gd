extends GdUnitTestSuite
## The organic ground reads terrain and roads from a per-tile map texture (ART_SPEC §8.1).


func _terrain(id: StringName, index: int) -> TerrainDef:
	var def := TerrainDef.new()
	def.id = id
	def.index = index
	return def


func test_slot_table_maps_known_terrains_and_falls_back_to_grass() -> void:
	var terrains: Array[TerrainDef] = [_terrain(&"grass", 0), _terrain(&"water", 1), null,
			_terrain(&"swamp", 3), _terrain(&"ford", 4)]
	var table := TerrainLayer.slot_table(terrains)
	assert_int(table[0]).is_equal(TerrainLayer.Slot.GRASS)
	assert_int(table[1]).is_equal(TerrainLayer.Slot.WATER)
	assert_int(table[2]).is_equal(TerrainLayer.Slot.GRASS)
	assert_int(table[3]).is_equal(TerrainLayer.Slot.GRASS)
	assert_int(table[4]).is_equal(TerrainLayer.Slot.FORD)


func test_map_image_encodes_slot_and_road() -> void:
	var grid := TileGrid.new(Vector2i(4, 3))
	grid.set_terrain(Vector2i(1, 0), 1)
	grid.set_road(Vector2i(2, 2), true)
	grid.set_terrain(Vector2i(3, 1), 7)  # no slot for this index -> grass
	var slots := PackedInt32Array([TerrainLayer.Slot.GRASS, TerrainLayer.Slot.WATER])
	var image := TerrainLayer.build_map_image(grid, slots)
	assert_vector(Vector2(image.get_size())).is_equal(Vector2(4, 3))
	assert_int(roundi(image.get_pixel(1, 0).r * 255.0)).is_equal(TerrainLayer.Slot.WATER)
	assert_float(image.get_pixel(1, 0).g).is_equal(0.0)
	assert_int(roundi(image.get_pixel(2, 2).r * 255.0)).is_equal(TerrainLayer.Slot.GRASS)
	assert_float(image.get_pixel(2, 2).g).is_equal(1.0)
	assert_int(roundi(image.get_pixel(3, 1).r * 255.0)).is_equal(TerrainLayer.Slot.GRASS)
