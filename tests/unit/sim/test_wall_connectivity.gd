extends GdUnitTestSuite

const D := WallConnectivity.GridDir


func _mask(walls: Array[Vector2i], tile: Vector2i) -> int:
	var lookup := {}
	for w: Vector2i in walls:
		lookup[w] = true
	return WallConnectivity.mask_at(tile, func(t: Vector2i) -> bool: return lookup.has(t))


func _bits(dirs: Array) -> int:
	var mask := 0
	for dir: int in dirs:
		mask |= WallConnectivity.bit(dir)
	return mask


func test_lone_wall_has_no_connections_and_a_post() -> void:
	var mask := _mask([Vector2i(0, 0)], Vector2i(0, 0))
	assert_int(mask).is_equal(0)
	assert_bool(WallConnectivity.needs_post(mask)).is_true()


func test_straight_runs_hide_the_post() -> void:
	var along_x: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)]
	assert_int(_mask(along_x, Vector2i(0, 0))).is_equal(_bits([D.E, D.W]))
	assert_bool(WallConnectivity.needs_post(_bits([D.E, D.W]))).is_false()
	var diagonal: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, 0), Vector2i(1, 1)]
	assert_int(_mask(diagonal, Vector2i(0, 0))).is_equal(_bits([D.SE, D.NW]))
	assert_bool(WallConnectivity.needs_post(_bits([D.SE, D.NW]))).is_false()


func test_corners_tees_and_ends_show_the_post() -> void:
	assert_bool(WallConnectivity.needs_post(_bits([D.E, D.S]))).is_true()
	assert_bool(WallConnectivity.needs_post(_bits([D.E, D.SW]))).is_true()
	assert_bool(WallConnectivity.needs_post(_bits([D.E, D.W, D.S]))).is_true()
	assert_bool(WallConnectivity.needs_post(_bits([D.E]))).is_true()


func test_diagonal_link_dropped_when_wall_turns_orthogonally() -> void:
	# L-shape (0,0)-(1,0)-(1,1): (0,0) must not also link diagonally to (1,1).
	var walls: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]
	assert_int(_mask(walls, Vector2i(0, 0))).is_equal(_bits([D.E]))
	assert_int(_mask(walls, Vector2i(1, 0))).is_equal(_bits([D.W, D.S]))
	assert_int(_mask(walls, Vector2i(1, 1))).is_equal(_bits([D.N]))


func test_connections_are_symmetric() -> void:
	var walls: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(4, 1), Vector2i(5, 0), Vector2i(2, 3), Vector2i(1, 4),
	]
	for tile: Vector2i in walls:
		var mask := _mask(walls, tile)
		for dir: int in WallConnectivity.half_dirs(mask):
			var other := tile + WallConnectivity.OFFSETS[dir]
			var back := WallConnectivity.bit(WallConnectivity.opposite(dir))
			assert_int(_mask(walls, other) & back).override_failure_message(
					"%s links %s to %s but not back" % [tile, WallConnectivity.NAMES[dir], other]
			).is_equal(back)


func test_gate_axis() -> void:
	assert_str(String(WallConnectivity.gate_axis(_bits([D.E, D.W])))).is_equal("x")
	assert_str(String(WallConnectivity.gate_axis(_bits([D.N, D.S])))).is_equal("y")
	assert_str(String(WallConnectivity.gate_axis(_bits([D.NE, D.SW])))).is_equal("")
