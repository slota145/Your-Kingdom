extends GdUnitTestSuite


func test_finds_straight_path() -> void:
	var nav := NavGrid.new(Vector2i(8, 8))
	var path := nav.find_path(Vector2i(0, 0), Vector2i(3, 0))
	assert_array(path).is_equal([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])


func test_cannot_slip_through_diagonal_wall_joint() -> void:
	# Diagonal wall (0,0)-(1,1)-(2,2)... cuts the map; the only crossing would be corner to corner.
	var nav := NavGrid.new(Vector2i(6, 6))
	for i: int in 6:
		nav.set_solid(Vector2i(i, i), true)
	assert_array(nav.find_path(Vector2i(1, 0), Vector2i(0, 1))).is_empty()
	assert_array(nav.find_path(Vector2i(5, 0), Vector2i(0, 5))).is_empty()


func test_path_goes_around_obstacle_and_version_bumps() -> void:
	var nav := NavGrid.new(Vector2i(8, 8))
	var before := nav.version
	nav.set_solid_rect(Rect2i(2, 0, 1, 6), true)
	assert_int(nav.version).is_greater(before)
	var path := nav.find_path(Vector2i(0, 0), Vector2i(4, 0))
	assert_bool(path.is_empty()).is_false()
	for tile: Vector2i in path:
		assert_bool(nav.is_walkable(tile)).is_true()


func test_unreachable_or_solid_endpoints_give_empty_path() -> void:
	var nav := NavGrid.new(Vector2i(4, 4))
	nav.set_solid(Vector2i(3, 3), true)
	assert_array(nav.find_path(Vector2i(0, 0), Vector2i(3, 3))).is_empty()
	assert_array(nav.find_path(Vector2i(0, 0), Vector2i(9, 9))).is_empty()
