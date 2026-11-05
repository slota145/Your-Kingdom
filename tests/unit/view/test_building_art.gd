extends GdUnitTestSuite
## M4b-1.5: which art a turned building shows. Orientations 1 and 3 are mirrored, houses
## turned to 2 and 3 show their back; other buildings have no back art.


func test_turned_hut_uses_back_and_mirrored_art() -> void:
	var hut := SimFixture.registry().get_building(&"hut")
	assert_str(BuildingLayer.oriented_art("buildings/hut/base", hut, 0)).is_equal("buildings/hut/base")
	assert_str(BuildingLayer.oriented_art("buildings/hut/base", hut, 1)).is_equal("buildings/hut/base@m")
	assert_str(BuildingLayer.oriented_art("buildings/hut/base", hut, 2)).is_equal("buildings/hut/base_back")
	assert_str(BuildingLayer.oriented_art("buildings/hut/level_3_corner_a_2", hut, 3)) \
			.is_equal("buildings/hut/level_3_corner_a_2_back@m")


func test_workshop_is_only_mirrored() -> void:
	var bakery := SimFixture.registry().get_building(&"bakery")
	assert_str(BuildingLayer.oriented_art("buildings/bakery/base", bakery, 1)).is_equal("buildings/bakery/base@m")


func test_every_row_piece_has_front_and_back_art() -> void:
	var visual := BuildingVisualDef.for_building(&"hut")
	for level: String in ["level_2", "level_3"]:
		for piece: String in ["single", "end_a", "middle", "end_b", "corner_a", "corner_b"]:
			for look: int in visual.row_variants:
				var name := "%s_%s%s" % [level, piece, "" if look == 0 else "_%d" % (look + 1)]
				for suffix: String in ["", "_back"]:
					var path := ArtPaths.resolve("buildings/hut/%s%s.png" % [name, suffix])
					assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()


func test_neighbours_in_a_row_get_different_gables() -> void:
	var visual := BuildingVisualDef.for_building(&"hut")
	var names: Dictionary[String, bool] = {}
	for i: int in 3:
		names[visual.row_variant_name("level_2_middle", Vector2i(10, 10 + 2 * i))] = true
	assert_int(names.size()).is_greater(1)
