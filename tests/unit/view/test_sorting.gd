extends GdUnitTestSuite
## Sort points of building strips and wall pieces agree with true isometric depth for a
## person walking anywhere around them (ARCHITECTURE §6.2, ROADMAP M1 risk R1/R2).

const D := WallConnectivity.GridDir


# --- Buildings -----------------------------------------------------------------------

func test_building_strips_sort_correctly() -> void:
	# 3x3: fishing wharf, 4x4: shipyard (M5), both partly on the water.
	for footprint: Vector2i in [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 4), Vector2i(3, 3), Vector2i(4, 4)]:
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


## M4b-1.5: turned buildings (mirrored art: eaves swap sides), rows, corners and two rows
## back to back. People around them and the buildings among themselves must sort right.
func test_turned_buildings_rows_and_corners_sort_correctly() -> void:
	var layouts: Dictionary[String, Array] = {
		"single": [[Vector2i(10, 10), 0]],
		"single mirrored": [[Vector2i(10, 10), 1]],
		"single back": [[Vector2i(10, 10), 2]],
		"single back mirrored": [[Vector2i(10, 10), 3]],
		"row along y": [[Vector2i(10, 8), 0], [Vector2i(10, 10), 0], [Vector2i(10, 12), 0]],
		"row along x": [[Vector2i(8, 10), 1], [Vector2i(10, 10), 1], [Vector2i(12, 10), 1]],
		"corner": [[Vector2i(10, 6), 0], [Vector2i(10, 8), 0], [Vector2i(10, 10), 0],
				[Vector2i(6, 10), 1], [Vector2i(8, 10), 1]],
		"back corner": [[Vector2i(10, 10), 2], [Vector2i(10, 12), 2], [Vector2i(12, 10), 3], [Vector2i(14, 10), 3]],
		"back to back": [[Vector2i(10, 8), 2], [Vector2i(10, 10), 2], [Vector2i(10, 12), 2],
				[Vector2i(12, 8), 0], [Vector2i(12, 10), 0], [Vector2i(12, 12), 0]],
		"back to back along x": [[Vector2i(8, 10), 3], [Vector2i(10, 10), 3], [Vector2i(8, 12), 1], [Vector2i(10, 12), 1]],
	}
	for name: String in layouts:
		var failures := _check_layout(layouts[name])
		assert_array(Array(failures)).override_failure_message(
				"%s:\n%s" % [name, "\n".join(failures.slice(0, 10))]).is_empty()


## Houses (2x2) given as [origin, orientation]. Each gets strips like BuildingView: the
## art has wider eaves on its right (20 px) than on its left (8 px), and mirrored art
## (orientations 1, 3) has them the other way round.
func _check_layout(houses: Array) -> PackedStringArray:
	var failures := PackedStringArray()
	var fp := Vector2i(2, 2)
	var items: Array[Dictionary] = []
	var area := Rect2i(houses[0][0], fp)
	for h: Array in houses:
		var rect := Rect2i(h[0], fp)
		area = area.merge(rect)
		var mirrored := int(h[1]) % 2 == 1
		var width := 32 * (fp.x + fp.y) + 28
		var pivot := Vector2i(32 * fp.x + (20 if mirrored else 8), 120)
		items.append({"rect": rect, "poly": _poly(rect), "b": IsoMath.grid_to_screen(Vector2(rect.end)),
				"pivot": pivot, "strips": BuildingSlicer.slices(fp, pivot, Vector2i(width, 120))})
	var blocked := func(t: Vector2i) -> bool:
		for item: Dictionary in items:
			if (item["rect"] as Rect2i).has_point(t):
				return true
		return false
	# People walking around.
	for p: Vector2 in DepthOracle.walk_samples(area.grow(3), blocked):
		var a := IsoMath.grid_to_screen(p)
		for item: Dictionary in items:
			for strip: BuildingSlicer.Strip in item["strips"]:
				var cols := _columns(item, strip)
				var c0 := maxf(a.x - DepthOracle.AGENT_HALF_WIDTH, cols.x)
				var c1 := minf(a.x + DepthOracle.AGENT_HALF_WIDTH, cols.y)
				if c0 >= c1:
					continue
				var rel := DepthOracle.relation(p, item["poly"], c0, c1)
				var key: float = (item["b"] as Vector2).y + strip.sort_offset.y
				if (rel == DepthOracle.IN_FRONT and a.y <= key) or (rel == DepthOracle.BEHIND and a.y >= key):
					failures.append("agent %s vs house %s" % [p, item["rect"]])
	# Buildings among themselves: where two strips share screen columns and one footprint
	# lies wholly behind the other there, its strip must sort first.
	for i: int in items.size():
		for j: int in items.size():
			if i == j:
				continue
			for sa: BuildingSlicer.Strip in items[i]["strips"]:
				for sb: BuildingSlicer.Strip in items[j]["strips"]:
					var ca := _columns(items[i], sa)
					var cb := _columns(items[j], sb)
					var c0 := maxf(ca.x, cb.x)
					var c1 := minf(ca.y, cb.y)
					if c1 - c0 < 1.0:
						continue
					var da := _depth_range(items[i]["poly"], c0, c1)
					var db := _depth_range(items[j]["poly"], c0, c1)
					if da.x == INF or db.x == INF or da.y > db.x:
						continue
					var ka: float = (items[i]["b"] as Vector2).y + sa.sort_offset.y
					var kb: float = (items[j]["b"] as Vector2).y + sb.sort_offset.y
					if ka >= kb:
						failures.append("house %s (key %.1f) drawn over %s (key %.1f)" % [
							items[i]["rect"], ka, items[j]["rect"], kb])
	return failures


func _poly(rect: Rect2i) -> PackedVector2Array:
	return PackedVector2Array([Vector2(rect.position), Vector2(rect.end.x, rect.position.y),
			Vector2(rect.end), Vector2(rect.position.x, rect.end.y)])


## Screen x range a strip covers.
func _columns(item: Dictionary, strip: BuildingSlicer.Strip) -> Vector2:
	var b: Vector2 = item["b"]
	var pivot: Vector2i = item["pivot"]
	return Vector2(b.x + strip.region.position.x - pivot.x, b.x + strip.region.end.x - pivot.x)


## (min, max) of x + y over the ground polygon within screen columns [x0, x1]; INF if none.
func _depth_range(poly: PackedVector2Array, x0: float, x1: float) -> Vector2:
	var uv := PackedVector2Array()
	for g: Vector2 in poly:
		uv.append(Vector2((g.x - g.y) * IsoMath.HALF_W, g.x + g.y))
	uv = DepthOracle._clip(DepthOracle._clip(uv, x0, 1.0), x1, -1.0)
	if uv.is_empty():
		return Vector2(INF, INF)
	var lo := INF
	var hi := -INF
	for q: Vector2 in uv:
		lo = minf(lo, q.y)
		hi = maxf(hi, q.y)
	return Vector2(lo, hi)


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


# --- Ports (M5 part 2) -----------------------------------------------------------------

## A docker handing goods over on a moored ship is drawn over the ship and the gangway plank
## (his feet sort just past the ship's middle, the plank 1 px past it), for both turns of the
## port. The quay deck and the quay yard are ground decals (z -1), under everybody.
func test_docker_on_ship_deck_sorts_over_ship_and_plank() -> void:
	for orientation: int in 2:
		var sim := SimFixture.make_sim(Vector2i(48, 48))
		SimFixture.coast(sim, 30, 33)
		if orientation == 1:
			# Sea to the east instead: the mirrored port faces it.
			var land := sim.data.get_terrain(&"grass")
			var shallow := sim.data.get_terrain(&"sea_shallow")
			var deep := sim.data.get_terrain(&"sea_deep")
			for y: int in 48:
				for x: int in 48:
					var t := land if x < 30 else (shallow if x < 33 else deep)
					sim.province.grid.set_terrain(Vector2i(x, y), t.index)
			sim.province.rebuild_nav()
		var origin := Vector2i(20, 28) if orientation == 0 else Vector2i(28, 20)
		assert_str(String(sim.execute(PlaceBuildingCommand.new(&"port", origin, true, orientation)))).is_empty()
		var port := sim.province.buildings.get_building(sim.province.grid.occupant(origin))
		var ship_y := IsoMath.grid_to_screen(IsoMath.tile_center(port.berth_tile())).y
		var on_deck := IsoMath.grid_to_screen(Harbour.gangway_points(port)[2]).y
		assert_float(on_deck).is_greater(ship_y + 1.0)
		# He still stands on the berth tile (the hold is handed over there).
		var feet := Harbour.gangway_points(port)[2]
		assert_vector(Vector2i(floori(feet.x), floori(feet.y))).is_equal(port.berth_tile())
