extends GdUnitTestSuite
## Level-2 houses side by side join into a row: ends and middles (ARCHITECTURE §6.6).


func _h(id: int, origin: Vector2i, level: int = 2) -> Dictionary:
	return {"id": id, "origin": origin, "footprint": Vector2i(2, 2), "level": level}


func test_row_of_three_along_x() -> void:
	var rows := HouseRowResolver.resolve([_h(1, Vector2i(0, 0)), _h(2, Vector2i(2, 0)), _h(3, Vector2i(4, 0))])
	assert_array(rows[1]).is_equal(["end_a", "x"])
	assert_array(rows[2]).is_equal(["middle", "x"])
	assert_array(rows[3]).is_equal(["end_b", "x"])


func test_pair_along_y_and_single() -> void:
	var rows := HouseRowResolver.resolve([_h(1, Vector2i(0, 0)), _h(2, Vector2i(0, 2)), _h(3, Vector2i(9, 9))])
	assert_array(rows[1]).is_equal(["end_a", "y"])
	assert_array(rows[2]).is_equal(["end_b", "y"])
	assert_array(rows[3]).is_equal(["single", "x"])


func test_misaligned_gap_or_other_level_do_not_join() -> void:
	var rows := HouseRowResolver.resolve([_h(1, Vector2i(0, 0)), _h(2, Vector2i(2, 1)),
			_h(3, Vector2i(10, 0)), _h(4, Vector2i(13, 0)), _h(5, Vector2i(20, 0)), _h(6, Vector2i(22, 0), 1)])
	for id: int in [1, 2, 3, 4, 5]:
		assert_str(String(rows[id][0])).is_equal("single")
