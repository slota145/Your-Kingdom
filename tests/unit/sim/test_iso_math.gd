extends GdUnitTestSuite


func test_tile_corners_project_to_diamond() -> void:
	assert_vector(IsoMath.grid_to_screen(Vector2(0, 0))).is_equal(Vector2(0, 0))
	assert_vector(IsoMath.grid_to_screen(Vector2(1, 0))).is_equal(Vector2(32, 16))
	assert_vector(IsoMath.grid_to_screen(Vector2(0, 1))).is_equal(Vector2(-32, 16))
	assert_vector(IsoMath.grid_to_screen(Vector2(1, 1))).is_equal(Vector2(0, 32))


func test_screen_to_grid_is_inverse() -> void:
	for p: Vector2 in [Vector2(3.25, 7.5), Vector2(-4, 2), Vector2(100.75, 0.125)]:
		assert_vector(IsoMath.screen_to_grid(IsoMath.grid_to_screen(p))).is_equal_approx(
				p, Vector2(1e-4, 1e-4))


func test_tile_at_screen_picks_containing_tile() -> void:
	var tile := Vector2i(5, 9)
	assert_vector(IsoMath.tile_at_screen(IsoMath.tile_center_screen(tile))).is_equal(tile)
	# Just inside the top vertex still belongs to the tile.
	var top := IsoMath.grid_to_screen(Vector2(tile)) + Vector2(0, 1)
	assert_vector(IsoMath.tile_at_screen(top)).is_equal(tile)


func test_grid_steps_map_to_their_screen_direction() -> void:
	for dir: int in IsoMath.DIR_COUNT:
		assert_int(IsoMath.screen_dir(Vector2(IsoMath.DIR_GRID_STEP[dir]))).is_equal(dir)


func test_screen_dir_of_zero_vector() -> void:
	assert_int(IsoMath.screen_dir(Vector2.ZERO)).is_equal(-1)
