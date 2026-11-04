extends GdUnitTestSuite
## Sort points of building strips and wall pieces agree with true isometric depth for a
## person walking anywhere around them (ARCHITECTURE §6.2, ROADMAP M1 risk R1/R2).

const D := WallConnectivity.GridDir


# --- Buildings -----------------------------------------------------------------------

func test_building_strips_sort_correctly() -> void:
	for footprint: Vector2i in [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 4), Vector2i(4, 4)]:
		var failures := _check_building(Vector2i(10, 10), footprint)
		assert_array(Array(failures)).override_failure_message(
				"footprint %s:\n%s" % [footprint, "\n".join(failures.slice(0, 10))]).is_empty()


func test_oracle_catches_wrong_sort_keys() -> void:
	# Control check: shifting sort points far enough must be detected.
	assert_int(_check_building(Vector2i(10, 10), Vector2i(3, 3), 16.0).size()).is_greater(10)
	assert_int(_check_building(Vector2i(10, 10), Vector2i(3, 3), -48.0).size()).is_greater(10)
	assert_int(_check_walls(_line(Vector2i(0, 0), Vector2i(1, 0), 5), [], 48.0).size()).is_greater(10)
	assert_int(_check_walls(_line(Vector2i(0, 5), Vector2i(1, -1), 5), [], -48.0).size()).is_greater(10)


func test_strips_cover_the_whole_image() -> void:
	var strips := BuildingSlicer.slices(Vector2i(3, 2), Vector2i(104, 150), Vector2i(176, 150))
	assert_int(strips.size()).is_equal(5)
	assert_int(strips[0].region.position.x).is_equal(0)
	assert_int(strips[-1].region.end.x).is_equal(176)
	for i: int in range(1, strips.size()):
		assert_int(strips[i].region.position.x).is_equal(strips[i - 1].region.end.x)


func _check_building(origin: Vector2i, footprint: Vector2i, key_bias: float = 0.0) -> PackedStringArray:
	var failures := PackedStringArray()
	var rect := Rect2i(origin, footprint)
	var poly := PackedVector2Array([
		Vector2(rect.position), Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end), Vector2(rect.position.x, rect.end.y)])
	# Placeholder-like image: 8 px eaves on both sides, 120 px tall.
	var pivot := Vector2i(32 * footprint.x + 8, 120)
	var image := Vector2i(32 * (footprint.x + footprint.y) + 16, 120)
	var b_screen := IsoMath.grid_to_screen(Vector2(rect.end))
	var strips := BuildingSlicer.slices(footprint, pivot, image)
	var area := rect.grow(3)
	var blocked := func(t: Vector2i) -> bool: return rect.has_point(t)
	for p: Vector2 in DepthOracle.walk_samples(area, blocked):
		var a := IsoMath.grid_to_screen(p)
		for strip: BuildingSlicer.Strip in strips:
			var s0 := b_screen.x + strip.region.position.x - pivot.x
			var s1 := b_screen.x + strip.region.end.x - pivot.x
			var c0 := maxf(a.x - DepthOracle.AGENT_HALF_WIDTH, s0)
			var c1 := minf(a.x + DepthOracle.AGENT_HALF_WIDTH, s1)
			if c0 >= c1:
				continue
			var rel := DepthOracle.relation(p, poly, c0, c1)
			var key := b_screen.y + strip.sort_offset.y + key_bias
			if (rel == DepthOracle.IN_FRONT and a.y <= key) or (rel == DepthOracle.BEHIND and a.y >= key):
				failures.append("agent %s (y=%.1f) %s strip at x=%.0f (key %.1f)" % [
					p, a.y, "in front of" if rel == DepthOracle.IN_FRONT else "behind", s0, key])
	return failures


# --- Walls ---------------------------------------------------------------------------

func test_wall_straight_along_x() -> void:
	_assert_walls(_line(Vector2i(0, 0), Vector2i(1, 0), 6))


func test_wall_straight_along_y() -> void:
	_assert_walls(_line(Vector2i(0, 0), Vector2i(0, 1), 6))


func test_wall_diagonal_screen_vertical() -> void:
	_assert_walls(_line(Vector2i(0, 0), Vector2i(1, 1), 6))


func test_wall_diagonal_screen_horizontal() -> void:
	_assert_walls(_line(Vector2i(0, 5), Vector2i(1, -1), 6))


func test_wall_corner_90() -> void:
	_assert_walls(_line(Vector2i(0, 0), Vector2i(1, 0), 4) + _line(Vector2i(3, 1), Vector2i(0, 1), 3))


func test_wall_corners_45_and_135() -> void:
	_assert_walls(_line(Vector2i(0, 4), Vector2i(1, 0), 4) + _line(Vector2i(4, 3), Vector2i(1, -1), 3))
	_assert_walls(_line(Vector2i(0, 0), Vector2i(1, 0), 4) + _line(Vector2i(4, 1), Vector2i(1, 1), 3))


func test_wall_tee_and_cross() -> void:
	_assert_walls(_line(Vector2i(0, 0), Vector2i(1, 0), 5) + _line(Vector2i(2, 1), Vector2i(0, 1), 3))
	_assert_walls(_line(Vector2i(0, 2), Vector2i(1, 0), 5) + _line(Vector2i(2, 0), Vector2i(0, 1), 2)
			+ _line(Vector2i(2, 3), Vector2i(0, 1), 2))


func test_wall_diagonal_cross() -> void:
	var walls := _line(Vector2i(0, 0), Vector2i(1, 1), 5)
	walls.erase(Vector2i(2, 2))
	_assert_walls(walls + _line(Vector2i(0, 4), Vector2i(1, -1), 5))


func test_wall_with_gate() -> void:
	_assert_walls(_line(Vector2i(0, 0), Vector2i(1, 0), 5), [Vector2i(2, 0)])
	_assert_walls(_line(Vector2i(0, 0), Vector2i(0, 1), 5), [Vector2i(0, 2)])


func _line(start: Vector2i, step: Vector2i, count: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for i: int in count:
		tiles.append(start + step * i)
	return tiles


func _assert_walls(walls: Array[Vector2i], gates: Array[Vector2i] = []) -> void:
	var failures := _check_walls(walls, gates)
	assert_array(Array(failures)).override_failure_message(
			"%d failures, first:\n%s" % [failures.size(), "\n".join(failures.slice(0, 12))]).is_empty()


func _check_walls(walls: Array[Vector2i], gates: Array[Vector2i], key_bias: float = 0.0) -> PackedStringArray:
	var lookup := {}
	for w: Vector2i in walls:
		lookup[w] = true
	var is_wall := func(t: Vector2i) -> bool: return lookup.has(t)
	var blocked := func(t: Vector2i) -> bool: return lookup.has(t) and not gates.has(t)
	var bounds := Rect2i(walls[0], Vector2i.ONE)
	for w: Vector2i in walls:
		bounds = bounds.expand(w).expand(w + Vector2i.ONE)

	# Every piece: absolute ground polygon, screen column range, vertical extent, sort key.
	var pieces: Array[Dictionary] = []
	for tile: Vector2i in walls:
		var mask := WallConnectivity.mask_at(tile, is_wall)
		var center := IsoMath.tile_center(tile)
		for piece: WallGeometry.Piece in WallGeometry.pieces_for(mask, gates.has(tile)):
			var poly := PackedVector2Array()
			var x_min := INF
			var x_max := -INF
			var y_min := INF
			var y_max := -INF
			for g: Vector2 in piece.base:
				poly.append(center + g)
				var s := IsoMath.grid_to_screen(center + g)
				x_min = minf(x_min, s.x)
				x_max = maxf(x_max, s.x)
				y_min = minf(y_min, s.y)
				y_max = maxf(y_max, s.y)
			pieces.append({
				"name": "%s@%s" % [piece.name, tile], "poly": poly,
				"x0": x_min, "x1": x_max, "top": y_min - piece.z_top, "bottom": y_max - piece.z_bottom,
				"key": IsoMath.grid_to_screen(center).y + piece.sort_offset().y,
			})

	var failures := PackedStringArray()
	for p: Vector2 in DepthOracle.walk_samples(bounds.grow(2), blocked):
		var a := IsoMath.grid_to_screen(p)
		for piece: Dictionary in pieces:
			var c0 := maxf(a.x - DepthOracle.AGENT_HALF_WIDTH, piece.x0)
			var c1 := minf(a.x + DepthOracle.AGENT_HALF_WIDTH, piece.x1)
			if c0 >= c1 or a.y <= piece.top or a.y - DepthOracle.AGENT_HEIGHT >= piece.bottom:
				continue
			var rel := DepthOracle.relation(p, piece.poly, c0, c1)
			var key: float = piece.key + key_bias
			if (rel == DepthOracle.IN_FRONT and a.y <= key) or (rel == DepthOracle.BEHIND and a.y >= key):
				failures.append("agent %s (y=%.1f) %s %s (key %.1f)" % [
					p, a.y, "in front of" if rel == DepthOracle.IN_FRONT else "behind", piece.name, key])
	return failures
