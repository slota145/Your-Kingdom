extends RefCounted
## WALLS PROTOTYPE: "block" model of stone walls (docs/IDEAS.md, thick walls).
##
## Every wall tile is a solid block. Faces and crown rims are drawn only where the
## neighbour is not a wall, so neighbouring blocks merge into one mass of any thickness.
## Diagonal runs can get wedges in the free orthogonal tiles between two diagonal blocks
## (leg length = wedge_leg: 0 = plain stairs, 0.5 = chamfer, 1 = straight face).
## Geometry only: shared by the sandbox view and the headless sort check.

## JOINED: continues into a neighbouring piece (no face, no rim line, no corner line).
## EXPOSED: side face (if facing the camera), rim line and battlements.
## FACE_ONLY: side face but no rim (gate pillar sides under the deck).
## COVERED: hidden by a wedge; no face or rim, but a corner line where it starts.
enum Edge { JOINED, EXPOSED, FACE_ONLY, COVERED }

const HEIGHT := 56.0
const TALL_HEIGHT := 72.0
const LINTEL_BOTTOM := 44.0
## Gatehouse: 3x3 tiles, passage through the middle column, taller than the wall.
const GATEHOUSE_SIZE := 3
const GATEHOUSE_EXTRA := 32.0
const GATEHOUSE_LINTEL := 50.0
const PILLAR := 0.2
## Battlements: a parapet flush with the outer face, merlons standing on it (about
## shoulder height of a 42 px person in total), three merlons per tile edge.
const PARAPET_HEIGHT := 16.0
const PARAPET_DEPTH := 0.16
const MERLON_HEIGHT := 14.0
const MERLON_WIDTH := 0.2
const MERLON_DEPTH := PARAPET_DEPTH
const MERLON_PERIOD := 1.0 / 3.0
## Smallest crenel between a corner merlon and the next ordinary one.
const CORNER_GAP := 0.05
## Screen px an object on the crown sorts after the piece it stands on. People use three
## times this, so they come after the parapet (+1) and merlons (+2) behind them.
const CROWN_BIAS := 1.0

const ORTHO: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


class Piece:
	extends RefCounted
	var kind: StringName
	var tile: Vector2i
	## Convex ground polygon in absolute grid coordinates.
	var poly: PackedVector2Array
	## State (Edge) of edge i, from poly[i] to poly[i + 1].
	var edges: PackedByteArray
	var z0: float
	var z1: float
	## Node position: screen x of the centroid, screen y of the sort point (rounded).
	var sort_point: Vector2

	func _init(piece_kind: StringName, at: Vector2i, ground: PackedVector2Array,
			states: PackedByteArray, bottom: float, top: float) -> void:
		kind = piece_kind
		tile = at
		poly = ground
		edges = states
		z0 = bottom
		z1 = top
		var s := IsoMath.grid_to_screen(centroid())
		sort_point = Vector2(roundf(s.x), roundf(s.y))

	func centroid() -> Vector2:
		var sum := Vector2.ZERO
		for p: Vector2 in poly:
			sum += p
		return sum / poly.size()


## tile -> true when the tile is a gate.
var walls: Dictionary[Vector2i, bool] = {}
var wedge_leg: float = 0.5
var battlements: bool = true
var height: float = HEIGHT

## Filled by build(): tiles covered by wedges, and the sort key (screen y) of the crown
## surface over each tile that people can stand on.
var wedge_tiles: Dictionary[Vector2i, bool] = {}
var crown_keys: Dictionary[Vector2i, float] = {}
## Gatehouse origin (top tile of its 3x3 footprint) -> passage direction, (0, 1) or (1, 0).
var gatehouses: Dictionary[Vector2i, Vector2i] = {}
## Every gatehouse tile -> its origin. Kept in sync by add_gatehouse / remove_gatehouse.
var gatehouse_tiles: Dictionary[Vector2i, Vector2i] = {}


func is_wall(tile: Vector2i) -> bool:
	return walls.has(tile) or gatehouse_tiles.has(tile)


func gatehouse_height() -> float:
	return height + GATEHOUSE_EXTRA


## Places a gatehouse, removing the walls under it. Passage runs along [param along].
func add_gatehouse(origin: Vector2i, along: Vector2i) -> void:
	gatehouses[origin] = along
	for x: int in GATEHOUSE_SIZE:
		for y: int in GATEHOUSE_SIZE:
			var tile := origin + Vector2i(x, y)
			walls.erase(tile)
			gatehouse_tiles[tile] = origin


func remove_gatehouse(origin: Vector2i) -> void:
	gatehouses.erase(origin)
	for x: int in GATEHOUSE_SIZE:
		for y: int in GATEHOUSE_SIZE:
			gatehouse_tiles.erase(origin + Vector2i(x, y))


## Passage tiles of a gatehouse: the middle column along its passage.
func is_passage(tile: Vector2i) -> bool:
	if not gatehouse_tiles.has(tile):
		return false
	var origin: Vector2i = gatehouse_tiles[tile]
	var along: Vector2i = gatehouses[origin]
	var local := tile - origin
	return (local.x if along.y != 0 else local.y) == 1


func is_gate(tile: Vector2i) -> bool:
	return walls.get(tile, false)


## Tiles nobody can walk through on the ground: walls except gates, plus tiles that wide
## wedges cover so much that a person would stand inside the wall.
func blocked_tiles() -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for tile: Vector2i in walls:
		if not walls[tile]:
			result[tile] = true
	for tile: Vector2i in gatehouse_tiles:
		if not is_passage(tile):
			result[tile] = true
	if wedge_leg > 0.5:
		for tile: Vector2i in wedge_tiles:
			result[tile] = true
	return result


func build() -> Array[Piece]:
	var pieces: Array[Piece] = []
	wedge_tiles.clear()
	crown_keys.clear()
	var tops: Array[Piece] = []
	for tile: Vector2i in walls:
		var axis := _gate_axis(tile) if walls[tile] else Vector2i.ZERO
		if axis != Vector2i.ZERO:
			tops.append_array(_gate(tile, axis))
		else:
			tops.append(_core(tile))
	for origin: Vector2i in gatehouses:
		tops.append_array(_gatehouse(origin, gatehouses[origin]))
	if wedge_leg > 0.0:
		for tile: Vector2i in walls:
			for d: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1)]:
				if not is_wall(tile + d):
					continue
				var sides: Array[Vector2i] = [tile + Vector2i(d.x, 0), tile + Vector2i(0, d.y)]
				for k: int in 2:
					if _needs_wedge(tile, tile + d, sides[k], sides[1 - k]):
						tops.append(_wedge(sides[k], tile, tile + d))
						wedge_tiles[sides[k]] = true
	for piece: Piece in tops:
		pieces.append(piece)
		if piece.kind == &"pillar":
			continue
		var key := piece.sort_point.y
		crown_keys[piece.tile] = maxf(crown_keys.get(piece.tile, -INF), key)
	if battlements:
		for piece: Piece in tops:
			pieces.append_array(_merlons(piece))
		pieces.append_array(_inner_corners())
	return pieces


## Sort key (screen y) of a person standing on the crown at grid point [param p].
func crown_sort_key(p: Vector2, radius: float = 0.16) -> float:
	var key := IsoMath.grid_to_screen(p).y
	for offset: Vector2 in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0),
			Vector2(0, radius), Vector2(0, -radius)]:
		var tile := Vector2i((p + offset).floor())
		if crown_keys.has(tile):
			key = maxf(key, crown_keys[tile] + CROWN_BIAS * 3.0)
	return key


# --- Pieces --------------------------------------------------------------------------

func _core(tile: Vector2i) -> Piece:
	var c := IsoMath.tile_center(tile)
	var corners: Array[Vector2] = [c + Vector2(-0.5, -0.5), c + Vector2(0.5, -0.5),
			c + Vector2(0.5, 0.5), c + Vector2(-0.5, 0.5)]
	var poly := PackedVector2Array()
	var states := PackedByteArray()
	for i: int in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var side: Vector2i = ORTHO[i]
		if is_wall(tile + side):
			poly.append(a)
			states.append(Edge.JOINED)
			continue
		# A wedge in the free neighbour covers this edge from a corner whose diagonal
		# neighbour is a wall.
		var from_a := wedge_leg if _wedge_at_corner(tile, side, a - c) else 0.0
		var from_b := wedge_leg if _wedge_at_corner(tile, side, b - c) else 0.0
		if from_a + from_b >= 1.0:
			poly.append(a)
			states.append(Edge.COVERED)
			continue
		poly.append(a)
		if from_a > 0.0:
			states.append(Edge.COVERED)
			poly.append(a.lerp(b, from_a))
		states.append(Edge.EXPOSED)
		if from_b > 0.0:
			poly.append(a.lerp(b, 1.0 - from_b))
			states.append(Edge.COVERED)
	return Piece.new(&"core", tile, poly, states, 0.0, height)


## Whether a wedge lies in neighbour tile + [param side] at the corner [param half]
## (offset of that corner from the tile center).
func _wedge_at_corner(tile: Vector2i, side: Vector2i, half: Vector2) -> bool:
	if wedge_leg <= 0.0:
		return false
	var diagonal := tile + Vector2i(half * 2.0)
	if not is_wall(diagonal):
		return false
	return _needs_wedge(tile, diagonal, tile + side, diagonal - side)


## Wedge in free tile [param n] between diagonal walls [param a] and [param b]; [param m]
## is the other tile between them. When m is a wall, a and b only form a diagonal if the
## wall does not run straight on through m (that would be a 90° corner or a T junction).
func _needs_wedge(a: Vector2i, b: Vector2i, n: Vector2i, m: Vector2i) -> bool:
	if is_wall(n):
		return false
	if not is_wall(m):
		return true
	return not is_wall(a - (m - a)) and not is_wall(b + (b - m))


## Triangle in free tile [param n] filling the notch between diagonal walls [param a], [param b].
func _wedge(n: Vector2i, a: Vector2i, b: Vector2i) -> Piece:
	var a_dir := Vector2(a - n)
	var b_dir := Vector2(b - n)
	var corner := IsoMath.tile_center(n) + (a_dir + b_dir) * 0.5
	var poly := PackedVector2Array([corner, corner - b_dir * wedge_leg, corner - a_dir * wedge_leg])
	var states := PackedByteArray([Edge.JOINED, Edge.EXPOSED, Edge.JOINED])
	return Piece.new(&"wedge", n, poly, states, 0.0, height)


## Passage direction of a gate (its walls continue on both sides across it), or ZERO.
func _gate_axis(tile: Vector2i) -> Vector2i:
	if is_wall(tile + Vector2i(1, 0)) and is_wall(tile + Vector2i(-1, 0)):
		return Vector2i(0, 1)
	if is_wall(tile + Vector2i(0, 1)) and is_wall(tile + Vector2i(0, -1)):
		return Vector2i(1, 0)
	return Vector2i.ZERO


## Gate: two pillars (each split in two along the passage so people inside sort right)
## and a deck over the passage carrying the crown. The deck sorts at the front end of the
## passage, so a person inside the passage is always drawn under it.
func _gate(tile: Vector2i, along: Vector2i) -> Array[Piece]:
	var across := Vector2i(along.y, along.x)
	var back := Edge.JOINED if is_wall(tile - along) else Edge.EXPOSED
	var front := Edge.JOINED if is_wall(tile + along) else Edge.EXPOSED
	var pieces: Array[Piece] = []
	var inner := 0.5 - PILLAR
	for side: float in [-1.0, 1.0]:
		var u0 := -0.5 if side < 0.0 else inner
		var u1 := -inner if side < 0.0 else 0.5
		# The outer side joins the wall, the inner side faces the passage.
		var u0_edge := Edge.JOINED if side < 0.0 else Edge.FACE_ONLY
		var u1_edge := Edge.FACE_ONLY if side < 0.0 else Edge.JOINED
		pieces.append(_box(&"pillar", tile, along, across, u0, u1, -0.5, 0.0,
				[back, u1_edge, Edge.JOINED, u0_edge], 0.0, height))
		pieces.append(_box(&"pillar", tile, along, across, u0, u1, 0.0, 0.5,
				[Edge.JOINED, u1_edge, front, u0_edge], 0.0, height))
	var deck := _box(&"deck", tile, along, across, -inner, inner, -0.5, 0.5,
			[back, Edge.JOINED, front, Edge.JOINED], LINTEL_BOTTOM, height)
	var front_mid := IsoMath.tile_center(tile) + Vector2(along) * 0.5
	deck.sort_point.y = roundf(IsoMath.grid_to_screen(front_mid).y)
	pieces.append(deck)
	return pieces


## Gatehouse: side tiles are full-height blocks, the middle column is a passage with a
## deck from the lintel up. Each deck tile sorts at its front edge, like the tunnel gate.
func _gatehouse(origin: Vector2i, along: Vector2i) -> Array[Piece]:
	var across := Vector2i(along.y, along.x)
	var top := gatehouse_height()
	var last := GATEHOUSE_SIZE - 1
	var pieces: Array[Piece] = []
	for i: int in GATEHOUSE_SIZE:          # across the passage
		for j: int in GATEHOUSE_SIZE:      # along the passage
			var tile := origin + across * i + along * j
			var back := Edge.EXPOSED if j == 0 else Edge.JOINED
			var front := Edge.EXPOSED if j == last else Edge.JOINED
			if i == 1:
				var deck := _box(&"gh_deck", tile, along, across, -0.5, 0.5, -0.5, 0.5,
						[back, Edge.JOINED, front, Edge.JOINED], GATEHOUSE_LINTEL, top)
				deck.sort_point.y = roundf(IsoMath.grid_to_screen(
						IsoMath.tile_center(tile) + Vector2(along) * 0.5).y)
				pieces.append(deck)
				continue
			var u0 := Edge.EXPOSED if i == 0 else Edge.FACE_ONLY
			var u1 := Edge.FACE_ONLY if i == 0 else Edge.EXPOSED
			pieces.append(_box(&"gh_side", tile, along, across, -0.5, 0.5, -0.5, 0.5,
					[back, u1, front, u0], 0.0, top))
	return pieces


## Box in tile-local (u across, v along) coordinates. Edge states in order:
## v = v0 (back), u = u1, v = v1 (front), u = u0.
func _box(kind: StringName, tile: Vector2i, along: Vector2i, across: Vector2i,
		u0: float, u1: float, v0: float, v1: float, states: Array, z0: float, z1: float) -> Piece:
	var c := IsoMath.tile_center(tile)
	var to_grid := func(u: float, v: float) -> Vector2:
		return c + Vector2(across) * u + Vector2(along) * v
	var poly := PackedVector2Array([to_grid.call(u0, v0), to_grid.call(u1, v0),
			to_grid.call(u1, v1), to_grid.call(u0, v1)])
	var packed := PackedByteArray()
	for s: int in states:
		packed.append(s)
	return Piece.new(kind, tile, poly, packed, z0, z1)


## Parapet along every exposed rim of a crown piece, merlons on top of it. Each sorts
## after the piece it stands on.
func _merlons(support: Piece) -> Array[Piece]:
	var result: Array[Piece] = []
	var base := support.z1 + PARAPET_HEIGHT
	var center := support.centroid()
	var n := support.poly.size()
	for i: int in n:
		if support.edges[i] != Edge.EXPOSED:
			continue
		var a := support.poly[i]
		var b := support.poly[(i + 1) % n]
		var dir := (b - a).normalized()
		var inward := dir.orthogonal()
		if inward.dot(center - (a + b) * 0.5) < 0.0:
			inward = -inward
		# At an outer corner the previous rim's parapet owns the corner square: this one
		# starts after it, so the two neither overlap nor cut into each other.
		var owned := support.edges[(i + n - 1) % n] == Edge.EXPOSED
		var start := a + dir * PARAPET_DEPTH if owned else a
		# The parapet owning the corner at its end shows its end face there.
		var owns_end := Edge.EXPOSED if support.edges[(i + 1) % n] == Edge.EXPOSED else Edge.JOINED
		var parapet := Piece.new(&"parapet", support.tile, PackedVector2Array([start, b,
				b + inward * PARAPET_DEPTH, start + inward * PARAPET_DEPTH]),
				PackedByteArray([Edge.EXPOSED, owns_end, Edge.EXPOSED, Edge.JOINED]),
				support.z1, base)
		parapet.sort_point.y = maxf(parapet.sort_point.y, support.sort_point.y + CROWN_BIAS)
		result.append(parapet)
		var length := a.distance_to(b)
		var ends_at_corner := support.edges[(i + 1) % n] == Edge.EXPOSED
		# Outer corners get an L-shaped corner merlon (as on a real wall); ordinary merlons
		# keep at least a crenel's width away from it.
		var keep_off := MERLON_WIDTH + CORNER_GAP
		if owned:
			result.append_array(_corner_merlon(support, i, base))
		for t: float in _merlon_positions(a, b):
			if owned and t * length - MERLON_WIDTH * 0.5 < keep_off:
				continue
			if ends_at_corner and (1.0 - t) * length - MERLON_WIDTH * 0.5 < keep_off:
				continue
			var m := a.lerp(b, t)
			var w := dir * MERLON_WIDTH * 0.5
			var poly := PackedVector2Array([m - w, m + w, m + w + inward * MERLON_DEPTH,
					m - w + inward * MERLON_DEPTH])
			var states := PackedByteArray([Edge.EXPOSED, Edge.EXPOSED, Edge.EXPOSED, Edge.EXPOSED])
			var merlon := Piece.new(&"merlon", support.tile, poly, states, base, base + MERLON_HEIGHT)
			result.append(merlon)
	# A merlon sorts after every parapet it touches: at an outer corner the parapet of the
	# next rim would otherwise cut into the corner merlon of the previous one. Only touching
	# ones, so back merlons stay behind people standing on the crown.
	for merlon: Piece in result:
		if merlon.kind != &"merlon":
			continue
		var c := merlon.centroid()
		for parapet: Piece in result:
			if parapet.kind == &"parapet" and _distance(c, parapet.poly) < MERLON_WIDTH:
				merlon.sort_point.y = maxf(merlon.sort_point.y, parapet.sort_point.y + CROWN_BIAS)
	return result


## L-shaped merlon on the outer corner where rim [param i] of [param support] starts: one
## arm along the previous rim (it owns the corner square), one along rim i.
func _corner_merlon(support: Piece, i: int, base: float) -> Array[Piece]:
	var n := support.poly.size()
	var v := support.poly[i]
	var prev := support.poly[(i + n - 1) % n]
	var next := support.poly[(i + 1) % n]
	var dir_prev := (v - prev).normalized()
	var dir := (next - v).normalized()
	var in_prev := _inward(support, prev, v)
	var in_cur := _inward(support, v, next)
	var w := MERLON_WIDTH
	var d := MERLON_DEPTH
	var all_exposed := PackedByteArray([Edge.EXPOSED, Edge.EXPOSED, Edge.EXPOSED, Edge.EXPOSED])
	var arm_a := Piece.new(&"merlon", support.tile, PackedVector2Array([v - dir_prev * w, v,
			v + in_prev * d, v - dir_prev * w + in_prev * d]), all_exposed, base, base + MERLON_HEIGHT)
	var arm_b := Piece.new(&"merlon", support.tile, PackedVector2Array([v + dir * d, v + dir * w,
			v + dir * w + in_cur * d, v + dir * d + in_cur * d]),
			PackedByteArray([Edge.EXPOSED, Edge.EXPOSED, Edge.EXPOSED, Edge.JOINED]), base, base + MERLON_HEIGHT)
	return [arm_a, arm_b]


func _inward(support: Piece, a: Vector2, b: Vector2) -> Vector2:
	var inward := (b - a).normalized().orthogonal()
	if inward.dot(support.centroid() - (a + b) * 0.5) < 0.0:
		inward = -inward
	return inward


static func _distance(p: Vector2, poly: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(p, poly):
		return 0.0
	var best := INF
	for i: int in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		best = minf(best, p.distance_to(q))
	return best


## Parapet blocks filling inner (concave) corners: there the parapets of the two rims end
## at the corner and would leave a square hole between them.
func _inner_corners() -> Array[Piece]:
	var result: Array[Piece] = []
	for tile: Vector2i in walls:
		if walls[tile] or not crown_keys.has(tile):
			continue
		for d: Vector2i in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var corner_tile := tile + d
			if is_wall(corner_tile) or wedge_tiles.has(corner_tile):
				continue
			if not walls.has(tile + Vector2i(d.x, 0)) or not walls.has(tile + Vector2i(0, d.y)):
				continue
			var c := IsoMath.tile_center(tile) + Vector2(d) * 0.5
			var k := -Vector2(d) * PARAPET_DEPTH
			var poly := PackedVector2Array([c, c + Vector2(k.x, 0), c + k, c + Vector2(0, k.y)])
			var block := Piece.new(&"parapet", tile, poly,
					PackedByteArray([Edge.EXPOSED, Edge.EXPOSED, Edge.EXPOSED, Edge.EXPOSED]),
					height, height + PARAPET_HEIGHT)
			block.sort_point.y = maxf(block.sort_point.y, crown_keys[tile] + CROWN_BIAS)
			result.append(block)
	return result


## Merlon centers along edge a-b as fractions. Axis-aligned edges use a world-aligned
## rhythm so merlons line up across tiles; diagonal ones are spread evenly.
func _merlon_positions(a: Vector2, b: Vector2) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	var length := a.distance_to(b)
	var half := MERLON_WIDTH * 0.5
	if is_equal_approx(a.x, b.x) or is_equal_approx(a.y, b.y):
		var axis := 1 if is_equal_approx(a.x, b.x) else 0
		var s0 := minf(a[axis], b[axis])
		var s1 := maxf(a[axis], b[axis])
		var k := ceili((s0 + half - MERLON_PERIOD * 0.5) / MERLON_PERIOD - 0.001)
		var s := k * MERLON_PERIOD + MERLON_PERIOD * 0.5
		while s + half <= s1 + 0.001:
			result.append((s - a[axis]) / (b[axis] - a[axis]))
			s += MERLON_PERIOD
		return result
	var count := maxi(1, floori(length / MERLON_PERIOD + 0.001))
	for i: int in count:
		result.append((i + 0.5) / count)
	return result
