extends GdUnitTestSuite
## Level-2 houses side by side, facing the same way, join into a row: ends, middles and
## corners (ARCHITECTURE §6.6, M4b-1.5).


func _h(id: int, origin: Vector2i, orientation: int = 0, level: int = 2) -> Dictionary:
	return {"id": id, "origin": origin, "orientation": orientation, "footprint": Vector2i(2, 2), "level": level}


func test_row_of_three_facing_x_runs_along_y() -> void:
	var rows := HouseRowResolver.resolve([_h(1, Vector2i(0, 0)), _h(2, Vector2i(0, 2)), _h(3, Vector2i(0, 4))])
	assert_str(rows[1]).is_equal("end_a")
	assert_str(rows[2]).is_equal("middle")
	assert_str(rows[3]).is_equal("end_b")


func test_row_facing_y_runs_along_x() -> void:
	var rows := HouseRowResolver.resolve([_h(1, Vector2i(0, 0), 1), _h(2, Vector2i(2, 0), 1),
			_h(3, Vector2i(0, 9), 1), _h(4, Vector2i(0, 11), 1)])
	assert_str(rows[1]).is_equal("end_a")
	assert_str(rows[2]).is_equal("end_b")
	# Side by side along y but facing y: their fronts do not line up.
	assert_str(rows[3]).is_equal("single")
	assert_str(rows[4]).is_equal("single")


func test_houses_facing_other_ways_do_not_join() -> void:
	var rows := HouseRowResolver.resolve([_h(1, Vector2i(0, 0), 0), _h(2, Vector2i(0, 2), 2),
			_h(3, Vector2i(9, 0), 1), _h(4, Vector2i(11, 0), 3)])
	for id: int in [1, 2, 3, 4]:
		assert_str(rows[id]).is_equal("single")


func test_misaligned_gap_or_other_level_do_not_join() -> void:
	var rows := HouseRowResolver.resolve([_h(1, Vector2i(0, 0)), _h(2, Vector2i(1, 2)),
			_h(3, Vector2i(0, 10)), _h(4, Vector2i(0, 13)), _h(5, Vector2i(0, 20)), _h(6, Vector2i(0, 22), 0, 1)])
	for id: int in [1, 2, 3, 4, 5]:
		assert_str(rows[id]).is_equal("single")


func test_two_rows_back_to_back_stay_two_rows() -> void:
	var houses: Array[Dictionary] = []
	for i: int in 3:
		houses.append(_h(1 + i, Vector2i(0, 2 * i), 2))   # door to -x, back to the other row
		houses.append(_h(11 + i, Vector2i(2, 2 * i), 0))  # door to +x
	var rows := HouseRowResolver.resolve(houses)
	for base: int in [1, 11]:
		assert_str(rows[base]).is_equal("end_a")
		assert_str(rows[base + 1]).is_equal("middle")
		assert_str(rows[base + 2]).is_equal("end_b")


func test_rows_meeting_at_a_right_angle_share_a_corner() -> void:
	# Row along y facing +x ends at (10, 10); the row along x facing +y runs into its back.
	var rows := HouseRowResolver.resolve([_h(1, Vector2i(10, 6)), _h(2, Vector2i(10, 8)), _h(3, Vector2i(10, 10)),
			_h(4, Vector2i(6, 10), 1), _h(5, Vector2i(8, 10), 1)])
	assert_str(rows[1]).is_equal("end_a")
	assert_str(rows[2]).is_equal("middle")
	assert_str(rows[3]).is_equal("corner_a")
	assert_str(rows[4]).is_equal("end_a")
	# Joined to the corner: no gable on that side.
	assert_str(rows[5]).is_equal("middle")


func test_corner_at_the_start_of_a_row() -> void:
	# Row along y facing +x starts at (10, 10) and goes on to (10, 12); the other row is
	# behind it (smaller x), facing -y.
	var rows := HouseRowResolver.resolve([_h(1, Vector2i(10, 10)), _h(2, Vector2i(10, 12)),
			_h(3, Vector2i(8, 10), 3)])
	assert_str(rows[1]).is_equal("corner_b")
	assert_str(rows[2]).is_equal("end_b")
	# The corner is at its "b" end (larger x).
	assert_str(rows[3]).is_equal("end_a")


func test_end_of_a_row_between_two_roads_is_a_corner() -> void:
	# Row along y facing +x, road in front (x = 2) and a side street at y = 4.
	var roads: Dictionary[Vector2i, bool] = {}
	for y: int in range(-1, 6):
		roads[Vector2i(2, y)] = true
	for x: int in range(0, 3):
		roads[Vector2i(x, 4)] = true
	var has_road := func(t: Vector2i) -> bool: return roads.has(t)
	var rows := HouseRowResolver.resolve([_h(1, Vector2i(0, 0)), _h(2, Vector2i(0, 2))], has_road)
	assert_str(rows[1]).is_equal("end_a")
	assert_str(rows[2]).is_equal("corner_a")
	# Without a neighbour in the row it stays a single house.
	rows = HouseRowResolver.resolve([_h(2, Vector2i(0, 2))], has_road)
	assert_str(rows[2]).is_equal("single")
