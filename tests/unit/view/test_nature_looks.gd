extends GdUnitTestSuite
## A mixed forest (owner 2026-11-10): every tree tile has a fixed look (species) picked from its
## position, so the look survives felling and loading a game; the simulation knows nothing of it.


func test_one_look_means_no_suffix() -> void:
	assert_str(NatureLayer.variant_suffix(Vector2i(3, 7), 1)).is_equal("")
	assert_str(NatureLayer.variant_suffix(Vector2i(3, 7), 0)).is_equal("")


func test_the_same_tile_always_gets_the_same_look() -> void:
	for tile: Vector2i in [Vector2i(0, 0), Vector2i(12, -5), Vector2i(127, 127)]:
		assert_str(NatureLayer.variant_suffix(tile, 5)).is_equal(NatureLayer.variant_suffix(tile, 5))


func test_a_forest_uses_every_look_and_nothing_else() -> void:
	var seen: Dictionary[String, int] = {}
	for x in range(20):
		for y in range(20):
			var s := NatureLayer.variant_suffix(Vector2i(x, y), 5)
			seen[s] = seen.get(s, 0) + 1
	assert_array(seen.keys()).contains_exactly_in_any_order(["", "_2", "_3", "_4", "_5"])
	for s: String in seen:   # no look is rare: every one covers at least a tenth of the trees
		assert_int(seen[s]).is_greater(40)
