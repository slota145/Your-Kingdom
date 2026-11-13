extends GdUnitTestSuite
## UI-2 part 1: roads and cobbles from two clicks run in an L.


func test_l_runs_along_x_then_y() -> void:
	var line := LineTool.l_path(Vector2i(2, 3), Vector2i(5, 1))
	assert_array(line).is_equal([Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3),
			Vector2i(5, 2), Vector2i(5, 1)])


func test_r_puts_y_first() -> void:
	var line := LineTool.l_path(Vector2i(2, 3), Vector2i(5, 1), true)
	assert_array(line).is_equal([Vector2i(2, 3), Vector2i(2, 2), Vector2i(2, 1), Vector2i(3, 1),
			Vector2i(4, 1), Vector2i(5, 1)])


func test_a_straight_line_and_a_single_tile() -> void:
	assert_array(LineTool.l_path(Vector2i(4, 4), Vector2i(4, 8))).has_size(5)
	assert_array(LineTool.l_path(Vector2i(4, 4), Vector2i(4, 4))).is_equal([Vector2i(4, 4)])


func test_every_step_is_one_grid_step() -> void:
	var line := LineTool.l_path(Vector2i(10, 0), Vector2i(0, 7), true)
	for i: int in range(1, line.size()):
		var d := line[i] - line[i - 1]
		assert_int(absi(d.x) + absi(d.y)).is_equal(1)
