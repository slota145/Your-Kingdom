class_name QuayLayer
extends Node2D
## Quays on the sea (N1): the player's timber piers and stone quays, and the over-water strip
## of harbour buildings (a port's quay, a fishing wharf's pier, the quay beside a slipway),
## drawn by the same code so they join into one mass, like a harbour in Anno. A tile shows
## its side only towards open water, so neighbouring quay tiles and building strips merge.
## The deck is at ground level and the side drops to the water below it, then goes on under
## the water, fading (owner's request 2026-11-07: higher quays that are seen going under the
## water). A quay drawn diagonally (8 directions, like walls) has its wedge tiles cut on the
## water side, so its edges run straight. Flat under the y-sorted world (people walk on it,
## ships lie beside it). Tiles ordered but not laid yet are drawn as a faint outline.

## The deck is at ground level (people walk on it as on land); the sea lies lower. How far
## the side shows above the water, and how far it is seen going down under the water.
const STONE_ABOVE := 20.0
const PIER_ABOVE := 14.0
const UNDER := 16.0
const PLANK := Color(0.6, 0.45, 0.29)
const PLANK_DARK := Color(0.46, 0.34, 0.21)
const BEAM := Color(0.33, 0.24, 0.15)
const STONE := Color(0.62, 0.6, 0.55)
const STONE_DARK := Color(0.47, 0.45, 0.41)
const STONE_EDGE := Color(0.72, 0.7, 0.64)
const ALGAE := Color(0.28, 0.36, 0.24)
const WATER := Color(0.16, 0.36, 0.42)
const FOAM := Color(0.92, 0.97, 0.95, 0.75)
const ORDERED := Color(0.95, 0.88, 0.6, 0.55)
## Stone quay profile (owner's reference, Anno 1404, 2026-11-07): buttresses standing out of
## the wall at every tile corner, arched bays between them going down into the water, a
## cornice along the top and a bollard on each buttress.
const BUTTRESS := 7.0       # width along the wall, px
const JUT := 3.0            # how far buttresses stand out of the wall, px
const CORNICE := 3.0        # height of the cornice band, px
const ARCH_TOP := 7.0       # crown of the arches below the deck edge, px
const BAY := 32.0           # about one arched bay per this many px of wall
const BOLLARD := Color(0.22, 0.2, 0.18)
## Tile corners in grid space: back, right, front, left; and the sides between them (from
## corner i to i + 1) with their outward normals.
const _CORNERS: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
const _SIDE_NORMALS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## Direction of each corner (its two neighbours are corner + (x, 0) and corner + (0, y)).
const _CORNER_DIRS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]

var province: ProvinceSim
## Tile -> TileGrid.PIER or STONE_QUAY: everything drawn as quay.
var _tiles: Dictionary[Vector2i, int] = {}
var _ordered: Array[Vector2i] = []


func setup(source: ProvinceSim) -> void:
	province = source
	refresh()


## Rereads quays, buildings and orders from the simulation and redraws.
func refresh() -> void:
	_tiles = quay_tiles(province)
	_ordered.clear()
	for paving_site: PavingSite in province.paving.values():
		if paving_site.is_quay():
			_ordered.append_array(paving_site.tiles)
	queue_redraw()


## Every tile drawn as quay: laid quay, and the strips of harbour buildings (timber unless a
## stone quay lies under them).
static func quay_tiles(source: ProvinceSim) -> Dictionary[Vector2i, int]:
	var tiles: Dictionary[Vector2i, int] = {}
	var grid := source.grid
	if grid.quay_count() > 0:
		for y: int in grid.size.y:
			for x: int in grid.size.x:
				var kind := grid.quay(Vector2i(x, y))
				if kind != 0:
					tiles[Vector2i(x, y)] = kind
	for building: BuildingState in source.buildings.all():
		for tile: Vector2i in building_strip(building):
			if not tiles.has(tile):
				tiles[tile] = TileGrid.PIER
	return tiles


## The over-water tiles of [param building] drawn as quay (BuildingVisualDef.quay_tiles).
static func building_strip(building: BuildingState) -> Array[Vector2i]:
	var def := building.def
	if not def.on_quay or def.water_tiles.is_empty():
		return []
	var drawn: Array[Vector2i] = def.water_tiles
	var visual := BuildingVisualDef.for_building(def.id)
	if visual != null and not visual.quay_tiles.is_empty():
		drawn = visual.quay_tiles
	var tiles: Array[Vector2i] = []
	for tile: Vector2i in drawn:
		tiles.append(building.origin + def.turned(tile, building.orientation))
	return tiles


func _draw() -> void:
	for tile: Vector2i in _ordered:
		var c := _ring(tile, [0, 1, 2, 3])
		c.append(c[0])
		draw_polyline(c, ORDERED, 1.0)
	# Back to front: a tile in front covers the sides hanging down from the tiles behind it.
	var sorted: Array[Vector2i] = _tiles.keys()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x + a.y < b.x + b.y)
	for tile: Vector2i in sorted:
		_draw_tile(tile, _tiles[tile])


## Which corner of [param tile] is cut off (a wedge of a diagonal quay), or -1: the corner
## whose two neighbours are open water while the two opposite ones are quay, and along whose
## cut the diagonal line goes on (the outer corner of a right-angled turn stays square).
func cut_corner(tile: Vector2i) -> int:
	for c: int in 4:
		var d := _CORNER_DIRS[c]
		var out_a := tile + Vector2i(d.x, 0)
		var out_b := tile + Vector2i(0, d.y)
		var in_a := tile - Vector2i(d.x, 0)
		var in_b := tile - Vector2i(0, d.y)
		# Open water or open ground beside the corner (a slanting quay comes up onto the shore too).
		if _tiles.has(out_a) or _tiles.has(out_b):
			continue
		if not (_tiles.has(in_a) and _tiles.has(in_b)):
			continue
		# A diagonal line goes on along the cut (a right-angled turn has water there).
		if _tiles.has(tile + Vector2i(d.x, -d.y)) or _tiles.has(tile + Vector2i(-d.x, d.y)):
			return c
	return -1


func _draw_tile(tile: Vector2i, kind: int) -> void:
	var stone := kind == TileGrid.STONE_QUAY
	var cut := cut_corner(tile)
	var corners: Array[int] = []
	for c: int in 4:
		if c != cut:
			corners.append(c)
	var top := _ring(tile, corners)
	draw_colored_polygon(top, STONE if stone else PLANK)
	_deck_pattern(tile, stone, top)
	# Sides towards open water that face the camera (normal towards +x and +y on screen).
	for i: int in corners.size():
		var a := corners[i]
		var b := corners[(i + 1) % corners.size()]
		var normal: Vector2i
		var open := true
		var ground := false
		if (a + 1) % 4 == b:
			normal = _SIDE_NORMALS[a]
			var next := tile + normal
			open = not _tiles.has(next) and _is_water(next)
			ground = not _tiles.has(next) and not _is_water(next)
		else:
			normal = _CORNER_DIRS[cut]   # the cut side of a wedge looks where the corner was
			var beside_a := tile + Vector2i(normal.x, 0)
			var beside_b := tile + Vector2i(0, normal.y)
			open = _is_water(beside_a) and _is_water(beside_b)
			ground = not open
		var p := IsoMath.grid_to_screen(Vector2(tile) + _CORNERS[a])
		var q := IsoMath.grid_to_screen(Vector2(tile) + _CORNERS[b])
		if ground:
			# On the shore (N1, a quay coming up onto land): where its side faces the camera, the
			# wall runs down the slope of the bank, full height at the water and nothing a couple
			# of tiles inland (owner's request 2026-11-07); a kerb where it meets the ground.
			if normal.x + normal.y > 0:
				var hp := _bank_height(tile + Vector2i(_CORNERS[a]), stone)
				var hq := _bank_height(tile + Vector2i(_CORNERS[b]), stone)
				if maxf(hp, hq) > 0.5:
					var light := 0.82 if normal == Vector2i(1, 0) else (0.68 if normal == Vector2i(0, 1) else 0.75)
					_slope_side(p, q, hp, hq, light, stone)
			draw_line(p, q, (STONE_DARK if stone else BEAM).darkened(0.2), 2.0)
			continue
		if not open or normal.x + normal.y <= 0:
			continue
		var light := 0.82 if normal == Vector2i(1, 0) else (0.68 if normal == Vector2i(0, 1) else 0.75)
		if stone:
			var out := IsoMath.grid_to_screen(Vector2(normal)) - IsoMath.grid_to_screen(Vector2.ZERO)
			_stone_side(p, q, light, tile, out.normalized())
		else:
			var out := IsoMath.grid_to_screen(Vector2(normal)) - IsoMath.grid_to_screen(Vector2.ZERO)
			_pier_side(p, q, light, tile, out.normalized())


func _deck_pattern(tile: Vector2i, stone: bool, top: PackedVector2Array) -> void:
	if stone:
		# Flagstones in two rows, the joints across offset like bricks, some stones a shade
		# lighter or darker (by position, the same every frame).
		for row: int in 2:
			var y0 := row * 0.5
			var shift := 0.25 if (tile.x + tile.y + row) % 2 == 0 else 0.0
			var cuts: Array[float] = [0.0, clampf(0.25 + shift, 0.0, 1.0), 1.0]
			for i: int in range(1, cuts.size()):
				var h := absi(tile.x * 7 + tile.y * 13 + row * 5 + i * 3) % 3
				var shade := STONE.darkened(0.05 * h) if h != 1 else STONE.lightened(0.04)
				var quad := PackedVector2Array([_at(tile, Vector2(cuts[i - 1], y0)), _at(tile, Vector2(cuts[i], y0)),
						_at(tile, Vector2(cuts[i], y0 + 0.5)), _at(tile, Vector2(cuts[i - 1], y0 + 0.5))])
				var clipped := Geometry2D.intersect_polygons(quad, top)
				for poly: PackedVector2Array in clipped:
					draw_colored_polygon(poly, shade)
		var lines: Array[Array] = [[Vector2(0.0, 0.5), Vector2(1.0, 0.5)]]
		for row: int in 2:
			var shift := 0.25 if (tile.x + tile.y + row) % 2 == 0 else 0.0
			lines.append([Vector2(0.25 + shift, row * 0.5), Vector2(0.25 + shift, row * 0.5 + 0.5)])
		for l: Array in lines:
			_clipped_line(_at(tile, l[0]), _at(tile, l[1]), top, STONE_DARK)
	else:
		# Planks across the tile (along y), each a shade of its own, nailed at both ends.
		for k: int in 4:
			var h := absi(tile.x * 11 + tile.y * 5 + k * 7) % 4
			var shade := PLANK.darkened(0.05 * h) if h != 3 else PLANK.lightened(0.05)
			var strip := PackedVector2Array([_at(tile, Vector2(k / 4.0, 0.0)), _at(tile, Vector2((k + 1) / 4.0, 0.0)),
					_at(tile, Vector2((k + 1) / 4.0, 1.0)), _at(tile, Vector2(k / 4.0, 1.0))])
			for poly: PackedVector2Array in Geometry2D.intersect_polygons(strip, top):
				draw_colored_polygon(poly, shade)
			for y: float in [0.12, 0.88]:
				var nail := _at(tile, Vector2((k + 0.5) / 4.0, y))
				if Geometry2D.is_point_in_polygon(nail, top):
					draw_rect(Rect2(nail, Vector2(1, 1)), PLANK_DARK.darkened(0.3))
		for k: int in range(1, 4):
			_clipped_line(_at(tile, Vector2(k / 4.0, 0.0)), _at(tile, Vector2(k / 4.0, 1.0)), top, PLANK_DARK)


## A stone wall from the deck edge [param p]-[param q] down to the water, like the owner's
## Anno 1404 reference: courses of blocks, arched bays sunk into the wall and going on under
## the water, buttresses standing out ([param out]: screen direction away from the quay) at
## both ends with a bollard on top, a cornice along the top, weed at the waterline; under the
## water it all goes on, fading.
func _stone_side(p: Vector2, q: Vector2, light: float, tile: Vector2i, out: Vector2) -> void:
	var down := Vector2(0, STONE_ABOVE)
	var shade := Color(light, light, light)
	var wall := STONE_DARK * shade
	var length := p.distance_to(q)
	var along := (q - p) / maxf(length, 0.001)
	draw_colored_polygon(PackedVector2Array([p, q, q + down, p + down]), wall)
	# Courses: a joint every 4 px, the vertical joints staggered.
	for row: int in 5:
		var y := 4.0 * (row + 1)
		if y < STONE_ABOVE - 1.0:
			draw_line(p + Vector2(0, y), q + Vector2(0, y), wall.darkened(0.22), 1.0)
		var offset := 5.0 if (row + tile.x + tile.y) % 2 == 0 else 0.0
		var x := offset
		while x < length:
			var at := p + along * x
			draw_line(at + Vector2(0, 4.0 * row), at + Vector2(0, minf(4.0 * row + 4.0, STONE_ABOVE)), wall.darkened(0.18), 1.0)
			x += 10.0
	# Arched bays between the buttresses: a dark recess under a ring of lighter stones.
	var bays := maxi(1, roundi(length / BAY))
	var half_b := BUTTRESS * 0.5
	var bay_len := (length - BUTTRESS * (bays + 1)) / bays
	for i: int in bays:
		var x0 := half_b + i * (bay_len + BUTTRESS) + half_b
		var x1 := x0 + bay_len
		_arch(p, along, x0 + 1.0, x1 - 1.0, wall)
	# Weed and wet stone just above the water.
	draw_colored_polygon(PackedVector2Array([p + down - Vector2(0, 3), q + down - Vector2(0, 3), q + down, p + down]),
			ALGAE * shade)
	_under_water(p + down, q + down, wall)
	# Cornice: a band of lighter stone standing out a little along the top, its shadow below.
	var c_out := out * 1.5
	var band := PackedVector2Array([p + c_out, q + c_out, q + c_out + Vector2(0, CORNICE), p + c_out + Vector2(0, CORNICE)])
	draw_colored_polygon(PackedVector2Array([p, q, q + c_out, p + c_out]), STONE_EDGE)
	draw_colored_polygon(band, STONE * Color(light + 0.1, light + 0.1, light + 0.1))
	var cast := WATER.darkened(0.5)
	cast.a = 0.45
	draw_line(p + c_out + Vector2(0, CORNICE + 1.0), q + c_out + Vector2(0, CORNICE + 1.0), cast, 1.0)
	# Buttresses at both ends, with a bollard on each.
	for x: float in [0.0, length]:
		_buttress(p + along * x, along, out, light)


## A recess arched at the top in the wall plane between [param x0] and [param x1] px along
## the wall from [param p]; it goes down into the water (the water covers its foot).
func _arch(p: Vector2, along: Vector2, x0: float, x1: float, wall: Color) -> void:
	if x1 - x0 < 6.0:
		return
	var mid := (x0 + x1) * 0.5
	var r := (x1 - x0) * 0.5
	var spring := ARCH_TOP + minf(r * 0.55, 6.0)
	var rise := spring - ARCH_TOP
	var bottom := STONE_ABOVE + UNDER * 0.6
	var hole := PackedVector2Array()
	var ring := PackedVector2Array()
	hole.append(p + along * x0 + Vector2(0, bottom))
	for k: int in 9:
		var angle := PI - PI * k / 8.0
		var at := p + along * (mid + r * cos(angle)) + Vector2(0, spring - rise * sin(angle))
		hole.append(at)
		ring.append(p + along * (mid + (r + 1.5) * cos(angle)) + Vector2(0, spring - (rise + 1.5) * sin(angle)))
	hole.append(p + along * x1 + Vector2(0, bottom))
	draw_colored_polygon(hole, wall.darkened(0.5))
	draw_polyline(ring, wall.lightened(0.25), 2.0)
	# Keystone.
	var key := p + along * mid + Vector2(0, ARCH_TOP - 2.0)
	draw_line(key, key + Vector2(0, 3), wall.lightened(0.35), 2.0)


## A buttress centred at [param at] on the deck edge: its face stands [param out] JUT px out
## of the wall, its right side shows between face and wall, a cap on top, going down into the
## water and fading there; a bollard stands on it.
func _buttress(at: Vector2, along: Vector2, out: Vector2, light: float) -> void:
	var half := along * BUTTRESS * 0.5
	var jut := out * JUT
	var face_col := STONE * Color(light + 0.05, light + 0.05, light + 0.05)
	var side_col := STONE_DARK * Color(light - 0.12, light - 0.12, light - 0.12)
	var down := Vector2(0, STONE_ABOVE)
	var a := at - half + jut
	var b := at + half + jut
	# The side towards the light-less end, then the face.
	draw_colored_polygon(PackedVector2Array([at + half, b, b + down, at + half + down]), side_col)
	draw_colored_polygon(PackedVector2Array([a, b, b + down, a + down]), face_col)
	for row: int in range(1, 5):
		var y := 4.0 * row + 1.0
		draw_line(a + Vector2(0, y), b + Vector2(0, y), face_col.darkened(0.25), 1.0)
	draw_colored_polygon(PackedVector2Array([a + down - Vector2(0, 3), b + down - Vector2(0, 3), b + down, a + down]),
			ALGAE * Color(light, light, light))
	# Under the water: the buttress goes on, fading.
	var top := face_col.lerp(WATER, 0.3)
	top.a = 0.95
	var bottom := WATER
	bottom.a = 0.0
	var under := Vector2(0, UNDER)
	draw_polygon(PackedVector2Array([a + down, b + down, b + down + under, a + down + under]),
			PackedColorArray([top, top, bottom, bottom]))
	draw_line(a + down, b + down, FOAM, 1.0)
	# Cap: a lighter slab on top, a little wider.
	var cap := PackedVector2Array([at - half * 1.3 - out, at + half * 1.3 - out, at + half * 1.3 + jut * 1.4,
			at - half * 1.3 + jut * 1.4])
	draw_colored_polygon(cap, STONE_EDGE)
	draw_colored_polygon(PackedVector2Array([cap[3], cap[2], cap[2] + Vector2(0, 2), cap[3] + Vector2(0, 2)]),
			STONE * Color(light, light, light))
	# Bollard.
	var foot := at + jut * 0.3
	draw_line(foot, foot - Vector2(0, 5), BOLLARD, 3.0)
	draw_line(foot - Vector2(2, 5), foot - Vector2(-2, 5), BOLLARD.lightened(0.2), 1.0)


## A timber pier side, like the owner's Anno reference (2026-11-07): the ends of the deck
## planks over a thick edge beam and a wale below it, log piles standing a little out
## ([param out]) with cross braces between them, tall mooring posts at the corners, now and
## then a ladder down to the water; under the water the piles go on, fading.
func _pier_side(p: Vector2, q: Vector2, light: float, tile: Vector2i, out: Vector2) -> void:
	var shade := Color(light + 0.1, light + 0.1, light + 0.1)
	var beam := BEAM * shade
	var length := p.distance_to(q)
	var along := (q - p) / maxf(length, 0.001)
	var water := Vector2(0, PIER_ABOVE)
	var piles: Array[float] = []
	var n := maxi(2, roundi(length / 12.0))
	for k: int in n + 1:
		piles.append(length * k / n)
	# Cross braces between the piles, behind them.
	for i: int in piles.size() - 1:
		var a := p + along * piles[i]
		var b := p + along * piles[i + 1]
		draw_line(a + Vector2(0, 6), b + water - Vector2(0, 1), beam.darkened(0.25), 1.0)
		draw_line(b + Vector2(0, 6), a + water - Vector2(0, 1), beam.darkened(0.25), 1.0)
		# Under the water the braces are only a shadow.
		var faint := beam.lerp(WATER, 0.6)
		faint.a = 0.35
		draw_line(a + water, b + water + Vector2(0, UNDER * 0.6), faint, 1.0)
	# Edge beam with the plank ends showing on it, and a wale below.
	draw_colored_polygon(PackedVector2Array([p, q, q + Vector2(0, 3), p + Vector2(0, 3)]), beam)
	var x := 0.0
	var k := 0
	while x < length - 1.0:
		var at := p + along * x
		draw_line(at, at + along * minf(2.0, length - x), PLANK.darkened(0.12 * (k % 2)), 1.0)
		x += 3.0
		k += 1
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, 4), q + Vector2(0, 4), q + Vector2(0, 6), p + Vector2(0, 6)]),
			beam.darkened(0.2))
	# Log piles.
	for i: int in piles.size():
		var foot := p + along * piles[i] + out * 1.5
		var log := PLANK_DARK * shade
		draw_line(foot, foot + water, log, 3.0)
		draw_line(foot - along, foot - along + water, log.lightened(0.2), 1.0)
		for s: int in 4:
			var a := foot + water + Vector2(0, UNDER * s / 4.0)
			var b := foot + water + Vector2(0, UNDER * (s + 1) / 4.0)
			var c := log.lerp(WATER, 0.3 + 0.12 * s)
			c.a = 0.9 - 0.22 * s
			draw_line(a, b, c, 3.0)
		draw_line(foot + water + Vector2(-3, 0), foot + water + Vector2(3, 0), FOAM, 1.0)
		# Tall mooring posts at the ends, with a dark cap.
		if i == 0 or i == piles.size() - 1:
			draw_line(foot, foot - Vector2(0, 7), log.lightened(0.05), 3.0)
			draw_line(foot - Vector2(1, 8), foot - Vector2(-2, 8), BOLLARD, 2.0)
	# A ladder down to the water on some sides.
	if absi(tile.x * 7 + tile.y * 3) % 5 == 0 and length > 20.0:
		var mid := p + along * (length * 0.5) + out * 2.0
		for side: float in [-2.0, 2.0]:
			draw_line(mid + along * side, mid + along * side + water + Vector2(0, 4), BEAM.lightened(0.1), 1.0)
		for r: int in range(1, 6):
			var y := Vector2(0, 3.0 * r)
			draw_line(mid - along * 2.0 + y, mid + along * 2.0 + y, BEAM.lightened(0.2), 1.0)
	draw_line(p, q, BEAM, 1.0)


## The part of a side under the water from the waterline [param p]-[param q]: the wall goes
## on, blue-green and fading with depth, its courses still showing near the surface; a line
## of foam and a darker band of shade where it meets the surface.
func _under_water(p: Vector2, q: Vector2, wall: Color) -> void:
	var down := Vector2(0, UNDER)
	var top := wall.lerp(WATER, 0.3)
	top.a = 0.95
	var bottom := WATER.lerp(wall, 0.15)
	bottom.a = 0.0
	draw_polygon(PackedVector2Array([p, q, q + down, p + down]), PackedColorArray([top, top, bottom, bottom]))
	for row: int in 3:
		var y := 4.0 * (row + 1)
		var joint := wall.lerp(WATER, 0.5).darkened(0.25)
		joint.a = 0.7 - 0.22 * row
		draw_line(p + Vector2(0, y), q + Vector2(0, y), joint, 1.0)
	var shade := WATER.darkened(0.4)
	shade.a = 0.45
	draw_line(p + Vector2(0, 1), q + Vector2(0, 1), shade, 2.0)
	draw_line(p, q, FOAM, 1.0)


func _clipped_line(a: Vector2, b: Vector2, poly: PackedVector2Array, color: Color) -> void:
	for seg: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly):
		draw_polyline(seg, color, 1.0)


## How high the side of a quay stands at the grid point [param point] on the shore: full at
## the water, down to nothing two tiles inland (the bank rises), in px.
func _bank_height(point: Vector2i, stone: bool) -> float:
	var full := STONE_ABOVE if stone else PIER_ABOVE
	var best := 3.0
	for ty: int in range(point.y - 3, point.y + 3):
		for tx: int in range(point.x - 3, point.x + 3):
			if not _is_water(Vector2i(tx, ty)):
				continue
			# Distance from the point to the square of the tile, in tiles (Chebyshev).
			var dx := maxf(maxf(tx - point.x, point.x - (tx + 1)), 0.0)
			var dy := maxf(maxf(ty - point.y, point.y - (ty + 1)), 0.0)
			best = minf(best, maxf(dx, dy))
	return full * clampf(1.0 - best / 2.0, 0.0, 1.0)


## A side of a quay running down the bank from [param p] (height [param hp]) to [param q]
## (height [param hq]): stone courses, or the pier's beam and piles getting shorter.
func _slope_side(p: Vector2, q: Vector2, hp: float, hq: float, light: float, stone: bool) -> void:
	var shade := Color(light, light, light)
	var face := PackedVector2Array([p, q, q + Vector2(0, hq), p + Vector2(0, hp)])
	var length := p.distance_to(q)
	var along := (q - p) / maxf(length, 0.001)
	if stone:
		var wall := STONE_DARK * shade
		draw_colored_polygon(face, wall)
		for row: int in 5:
			var y := 4.0 * (row + 1)
			_clipped_line(p + Vector2(0, y), q + Vector2(0, y), face, wall.darkened(0.22))
			var x := 5.0 if row % 2 == 0 else 0.0
			while x < length:
				var at := p + along * x
				_clipped_line(at + Vector2(0, 4.0 * row), at + Vector2(0, 4.0 * row + 4.0), face, wall.darkened(0.18))
				x += 10.0
		# The cornice goes down the bank too.
		draw_line(p + Vector2(0, 1), q + Vector2(0, 1), STONE * Color(light + 0.1, light + 0.1, light + 0.1), 2.0)
		# Earth piled against its foot.
		draw_line(p + Vector2(0, hp), q + Vector2(0, hq), Color(0.55, 0.47, 0.33), 2.0)
	else:
		var beam := BEAM * Color(light + 0.1, light + 0.1, light + 0.1)
		var n := maxi(2, roundi(length / 12.0))
		for k: int in n + 1:
			var t := float(k) / n
			var h := lerpf(hp, hq, t)
			if h < 2.0:
				continue
			var foot := p.lerp(q, t)
			draw_line(foot, foot + Vector2(0, h), PLANK_DARK * shade, 3.0)
		var band := minf(3.0, maxf(hp, hq))
		draw_colored_polygon(PackedVector2Array([p, q, q + Vector2(0, minf(band, hq + 1.0)),
				p + Vector2(0, minf(band, hp + 1.0))]), beam)


func _is_water(tile: Vector2i) -> bool:
	if not province.grid.is_inside(tile):
		return true
	var terrain := province.terrain_at(tile)
	return terrain != null and terrain.is_kind(&"water")


## Screen points of the given corners of [param tile] (deck level).
func _ring(tile: Vector2i, corners: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for c: int in corners:
		points.append(IsoMath.grid_to_screen(Vector2(tile) + _CORNERS[c]))
	return points


## A point inside [param tile] (0-1 on both axes) on the deck.
func _at(tile: Vector2i, f: Vector2) -> Vector2:
	return IsoMath.grid_to_screen(Vector2(tile) + f)
