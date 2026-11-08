class_name BridgeLayer
extends QuayLayer
## Bridges over rivers, fords and lakes (B1): the deck and the sides down to the water are
## drawn like quays (a timber bridge like a pier on piles, a stone bridge with an arch in each
## tile side), flat under the y-sorted world, the deck at ground level. Railings (timber) and
## parapets (stone) stand along the sides over the water: each side is a node of its own in
## the y-sorted world ([member rails]), so people walking on the bridge pass in front of the
## back railing and behind the front one. A diagonal bridge (8 directions, decision
## 2026-11-08) has its wedges cut like a diagonal quay, so its railings run straight.

const RAIL_HEIGHT := 7.0
const PARAPET_HEIGHT := 9.0

## Railings and parapets: add it to the y-sorted world.
var rails: Node2D = Node2D.new()


## Rereads bridges and bridge orders from the simulation and redraws.
func refresh() -> void:
	_tiles.clear()
	_ordered.clear()
	if province == null:
		return
	var grid := province.grid
	if grid.bridge_count() > 0:
		for y: int in grid.size.y:
			for x: int in grid.size.x:
				var kind := grid.bridge(Vector2i(x, y))
				if kind != 0:
					_tiles[Vector2i(x, y)] = TileGrid.STONE_QUAY if kind == TileGrid.STONE_BRIDGE else TileGrid.PIER
	for paving_site: PavingSite in province.paving.values():
		if paving_site.is_bridge():
			_ordered.append_array(paving_site.tiles)
	queue_redraw()
	_build_rails()


## Every side of a bridge tile with a railing, as [tile, from point, to point, outward normal]
## in screen space: all along the bridge, over the water and over the banks, but not across
## its ends where people come on to it from the land. A diagonal bridge's long sides are the
## cut sides of its wedges; it is entered from the land at its axis sides.
func rail_sides() -> Array[Array]:
	var sides: Array[Array] = []
	var axes := _axes()
	for tile: Vector2i in _tiles:
		var cut := cut_corner(tile)
		var corners: Array[int] = []
		for c: int in 4:
			if c != cut:
				corners.append(c)
		var axis: int = axes[tile]
		for i: int in corners.size():
			var a := corners[i]
			var b := corners[(i + 1) % corners.size()]
			var normal: Vector2i
			var railed := false
			if (a + 1) % 4 == b:
				normal = _SIDE_NORMALS[a]
				var next := tile + normal
				if _tiles.has(next):
					continue
				if _is_water(next):
					railed = true
				elif axis == AXIS_X:
					railed = normal.y != 0
				elif axis == AXIS_Y:
					railed = normal.x != 0
			else:
				normal = _CORNER_DIRS[cut]
				railed = true
			if not railed:
				continue
			var p := IsoMath.grid_to_screen(Vector2(tile) + _CORNERS[a])
			var q := IsoMath.grid_to_screen(Vector2(tile) + _CORNERS[b])
			sides.append([tile, p, q, normal, _rise(tile + Vector2i(_CORNERS[a])), _rise(tile + Vector2i(_CORNERS[b]))])
	return sides


## How high a railing stands at the grid point [param point], 0-1: full over the water, lower
## down the ramp on the bank, still a low post at its end.
func _rise(point: Vector2i) -> float:
	return lerpf(0.35, 1.0, _bank_height(point, false) / PIER_ABOVE)


## A bridge's side comes down the ramp within one tile of the water: full at the water, nothing
## where the ramp meets the ground (owner's request 2026-11-08).
func _bank_height(point: Vector2i, stone: bool) -> float:
	var full := STONE_ABOVE if stone else PIER_ABOVE
	var best := 2.0
	for ty: int in range(point.y - 2, point.y + 2):
		for tx: int in range(point.x - 2, point.x + 2):
			if not _is_water(Vector2i(tx, ty)):
				continue
			var dx := maxf(maxf(tx - point.x, point.x - (tx + 1)), 0.0)
			var dy := maxf(maxf(ty - point.y, point.y - (ty + 1)), 0.0)
			best = minf(best, maxf(dx, dy))
	return full * clampf(1.0 - best, 0.0, 1.0)


const AXIS_X := 0
const AXIS_Y := 1
const AXIS_DIAGONAL := 2


## Which way each bridge runs (tile -> AXIS_*), by its joined tiles: diagonal when any of its
## tiles is a cut wedge, else along its longer extent (a one-tile bridge: towards the land on
## both sides).
func _axes() -> Dictionary[Vector2i, int]:
	var axes: Dictionary[Vector2i, int] = {}
	for start: Vector2i in _tiles:
		if axes.has(start):
			continue
		var group: Array[Vector2i] = [start]
		var seen: Dictionary[Vector2i, bool] = {start: true}
		var head := 0
		var lo := start
		var hi := start
		var diagonal := false
		while head < group.size():
			var t := group[head]
			head += 1
			lo = Vector2i(mini(lo.x, t.x), mini(lo.y, t.y))
			hi = Vector2i(maxi(hi.x, t.x), maxi(hi.y, t.y))
			if cut_corner(t) >= 0:
				diagonal = true
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var n := t + Vector2i(dx, dy)
					if not seen.has(n) and _tiles.has(n):
						seen[n] = true
						group.append(n)
		var axis := AXIS_DIAGONAL
		if not diagonal:
			var size := hi - lo
			if size.x != size.y:
				axis = AXIS_X if size.x > size.y else AXIS_Y
			else:
				var land_x := not _is_water(start + Vector2i(1, 0)) and not _is_water(start - Vector2i(1, 0))
				axis = AXIS_X if land_x else AXIS_Y
		for t: Vector2i in group:
			axes[t] = axis
	return axes


func _build_rails() -> void:
	for child: Node in rails.get_children():
		rails.remove_child(child)
		child.queue_free()
	for side: Array in rail_sides():
		var piece := RailPiece.new()
		var p: Vector2 = side[1]
		var q: Vector2 = side[2]
		piece.position = (p + q) * 0.5
		piece.from = p - piece.position
		piece.to = q - piece.position
		piece.stone = _tiles[side[0]] == TileGrid.STONE_QUAY
		piece.rise_from = side[4]
		piece.rise_to = side[5]
		var normal: Vector2i = side[3]
		piece.light = 0.82 if normal == Vector2i(1, 0) else (0.68 if normal == Vector2i(0, 1) else 0.75)
		rails.add_child(piece)


## A ford is water under a bridge too.
func _is_water(tile: Vector2i) -> bool:
	if not province.grid.is_inside(tile):
		return true
	var terrain := province.terrain_at(tile)
	return terrain != null and (terrain.is_kind(&"water") or terrain.id == &"ford")


## A stone bridge's side: dressed stone from the deck down to the water with one round arch
## in each tile side, the water showing dark through it, a string course under the deck and
## the wall going on under the water, fading.
func _stone_side(p: Vector2, q: Vector2, light: float, _tile: Vector2i, _out: Vector2) -> void:
	var down := Vector2(0, STONE_ABOVE)
	var shade := Color(light, light, light)
	var wall := STONE_DARK * shade
	var face := PackedVector2Array([p, q, q + down, p + down])
	draw_colored_polygon(face, wall)
	var length := p.distance_to(q)
	var along := (q - p) / maxf(length, 0.001)
	# Courses of blocks, the joints offset row by row.
	for row: int in 4:
		var y := 4.0 * (row + 1) + 1.0
		_clipped_line(p + Vector2(0, y), q + Vector2(0, y), face, wall.darkened(0.2))
		var x := 4.0 if row % 2 == 0 else 9.0
		while x < length:
			var at := p + along * x
			_clipped_line(at + Vector2(0, 4.0 * row + 1.0), at + Vector2(0, 4.0 * row + 5.0), face, wall.darkened(0.16))
			x += 10.0
	# The arch: a half ellipse standing on the water, its ring of voussoirs a shade lighter.
	var mid := p.lerp(q, 0.5) + down
	var half := length * 0.32
	var rise := STONE_ABOVE - 5.0
	var opening := PackedVector2Array()
	var ring := PackedVector2Array()
	var steps := 12
	for k: int in steps + 1:
		var t := PI * k / steps
		var x := -cos(t) * half
		var y := -sin(t) * rise
		opening.append(mid + along * x + Vector2(0, y))
		ring.append(mid + along * x * 1.18 + Vector2(0, y * 1.12 - 0.5))
	draw_polyline(ring, (STONE * shade).lightened(0.08), 2.0)
	var dark := WATER.darkened(0.55)
	draw_colored_polygon(opening, dark)
	# Light on the water through the arch.
	var glint := WATER.lightened(0.15)
	glint.a = 0.6
	draw_line(mid - along * half * 0.6 - Vector2(0, 1), mid + along * half * 0.6 - Vector2(0, 1), glint, 1.0)
	# String course under the deck.
	draw_line(p + Vector2(0, 1), q + Vector2(0, 1), (STONE * shade).lightened(0.1), 2.0)
	_under_water(p + down, q + down, wall)


## One railing (timber bridge) or parapet (stone bridge) along a side of a bridge tile, placed
## at the middle of the side so the y-sort puts it behind or in front of people on the deck.
class RailPiece:
	extends Node2D

	var from: Vector2
	var to: Vector2
	var stone: bool = false
	var light: float = 0.8
	## Height of the railing at each end, 0-1 (lower down a ramp).
	var rise_from: float = 1.0
	var rise_to: float = 1.0

	func _draw() -> void:
		var shade := Color(light + 0.1, light + 0.1, light + 0.1)
		if stone:
			var up_a := Vector2(0, -BridgeLayer.PARAPET_HEIGHT * rise_from)
			var up_b := Vector2(0, -BridgeLayer.PARAPET_HEIGHT * rise_to)
			var up := Vector2(0, -BridgeLayer.PARAPET_HEIGHT)
			var wall := QuayLayer.STONE_DARK * shade
			var face := PackedVector2Array([from, to, to + up_b, from + up_a])
			draw_colored_polygon(face, wall)
			# Joints and the coping stones on top.
			var length := from.distance_to(to)
			var along := (to - from) / maxf(length, 0.001)
			var x := 6.0
			while x < length:
				var at := from + along * x
				var h := lerpf(up_a.y, up_b.y, x / length)
				draw_line(at + Vector2(0, -1), at + Vector2(0, h + 2.0), wall.darkened(0.25), 1.0)
				x += 8.0
			for y: float in [-3.0, -6.0]:
				for seg: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(
						PackedVector2Array([from + Vector2(0, y), to + Vector2(0, y)]), face):
					draw_polyline(seg, wall.darkened(0.2), 1.0)
			# Coping: a lighter top with a dark line under it, sloping down a ramp.
			draw_line(from + up_a + Vector2(0, 1), to + up_b + Vector2(0, 1), QuayLayer.STONE_EDGE * shade, 3.0)
			draw_line(from + up_a + Vector2(0, 3), to + up_b + Vector2(0, 3), wall.darkened(0.3), 1.0)
			return
		var wood := QuayLayer.BEAM * shade
		var up_a := Vector2(0, -BridgeLayer.RAIL_HEIGHT * rise_from)
		var up_b := Vector2(0, -BridgeLayer.RAIL_HEIGHT * rise_to)
		# Posts at both ends and in the middle, a top rail and a lower one, sloping down a ramp.
		for t: float in [0.0, 0.5, 1.0]:
			var foot := from.lerp(to, t)
			draw_line(foot, foot + up_a.lerp(up_b, t) - Vector2(0, 1), wood.darkened(0.1), 2.0)
		draw_line(from + up_a, to + up_b, wood.lightened(0.15), 2.0)
		draw_line(from + up_a * 0.45, to + up_b * 0.45, wood, 1.0)
