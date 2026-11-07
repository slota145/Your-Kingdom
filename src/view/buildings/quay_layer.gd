class_name QuayLayer
extends Node2D
## Quays on the sea (N1): the player's timber piers and stone quays, and the over-water strip
## of harbour buildings (a port's quay, a fishing wharf's pier, the quay beside a slipway),
## drawn by the same code so they join into one mass, like a harbour in Anno. A tile shows
## its side only towards open water, so neighbouring quay tiles and building strips merge.
## Flat on the water under the y-sorted world (people walk on it, ships lie beside it).
## Tiles ordered but not laid yet are drawn as a faint outline.

const DECK := 4.0
## How far the sides reach into the water.
const UNDER := 4.0
const PLANK := Color(0.6, 0.45, 0.29)
const PLANK_DARK := Color(0.46, 0.34, 0.21)
const BEAM := Color(0.33, 0.24, 0.15)
const STONE := Color(0.62, 0.6, 0.55)
const STONE_DARK := Color(0.47, 0.45, 0.41)
const STONE_EDGE := Color(0.72, 0.7, 0.64)
const WET := Color(0.27, 0.32, 0.3)
const ORDERED := Color(0.95, 0.88, 0.6, 0.55)

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
		var c := _corners(tile, 0.0)
		c.append(c[0])
		draw_polyline(c, ORDERED, 1.0)
	# Back to front, so a front tile's side covers nothing it should not.
	var sorted: Array[Vector2i] = _tiles.keys()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x + a.y < b.x + b.y)
	for tile: Vector2i in sorted:
		_draw_tile(tile, _tiles[tile])


func _draw_tile(tile: Vector2i, kind: int) -> void:
	var stone := kind == TileGrid.STONE_QUAY
	# Sides towards open water only: the +x (screen right-down) and +y (left-down) edges.
	for side: Array in [[Vector2i(1, 0), 1, 2, 0.82], [Vector2i(0, 1), 3, 2, 0.68]]:
		var next := tile + (side[0] as Vector2i)
		if _tiles.has(next) or not _is_water(next):
			continue
		var top := _corners(tile, DECK)
		var a: Vector2 = top[side[1]]
		var b: Vector2 = top[side[2]]
		var face := PackedVector2Array([a, b, b + Vector2(0, DECK + UNDER), a + Vector2(0, DECK + UNDER)])
		var shade := float(side[3])
		draw_colored_polygon(face, (STONE_DARK if stone else PLANK_DARK) * Color(shade, shade, shade))
		draw_line(a + Vector2(0, DECK + UNDER - 1.0), b + Vector2(0, DECK + UNDER - 1.0), WET, 2.0)
		if stone:
			# Courses of stone blocks.
			draw_line(a + Vector2(0, DECK * 0.5 + 1.0), b + Vector2(0, DECK * 0.5 + 1.0), STONE_DARK.darkened(0.25), 1.0)
		else:
			# Posts standing in the water.
			for k: int in 3:
				var p := a.lerp(b, (k + 0.5) / 3.0)
				draw_line(p, p + Vector2(0, DECK + UNDER + 2.0), BEAM, 2.0)
	var top := _corners(tile, DECK)
	draw_colored_polygon(top, STONE if stone else PLANK)
	if stone:
		# Flagstones in two rows, the joints across offset like bricks, some stones a shade
		# lighter or darker (by position, the same every frame).
		for row: int in 2:
			var y0 := row * 0.5
			var shift := 0.25 if (tile.x + tile.y + row) % 2 == 0 else 0.0
			var cuts: Array[float] = [0.0]
			for c: float in [0.5 + shift - 0.25, 1.0 - 0.0001]:
				cuts.append(clampf(c, 0.0, 1.0))
			for i: int in range(1, cuts.size()):
				var h := absi(tile.x * 7 + tile.y * 13 + row * 5 + i * 3) % 3
				var shade := STONE.darkened(0.05 * h) if h != 1 else STONE.lightened(0.04)
				var quad := PackedVector2Array([_at(tile, Vector2(cuts[i - 1], y0)), _at(tile, Vector2(cuts[i], y0)),
						_at(tile, Vector2(cuts[i], y0 + 0.5)), _at(tile, Vector2(cuts[i - 1], y0 + 0.5))])
				draw_colored_polygon(quad, shade)
				draw_line(_at(tile, Vector2(cuts[i], y0)), _at(tile, Vector2(cuts[i], y0 + 0.5)), STONE_DARK, 1.0)
			draw_line(_at(tile, Vector2(0.0, y0 + 0.5)), _at(tile, Vector2(1.0, y0 + 0.5)), STONE_DARK, 1.0)
	else:
		# Planks across the tile (along y), with a beam under every tile edge.
		for k: int in range(1, 4):
			draw_line(_at(tile, Vector2(k / 4.0, 0.0)), _at(tile, Vector2(k / 4.0, 1.0)), PLANK_DARK, 1.0)
	# Edge of the deck towards water: a light coping on stone, a dark beam on timber.
	for side: Array in [[Vector2i(1, 0), 1, 2], [Vector2i(0, 1), 3, 2], [Vector2i(-1, 0), 0, 3], [Vector2i(0, -1), 0, 1]]:
		var next := tile + (side[0] as Vector2i)
		if _tiles.has(next) or not _is_water(next):
			continue
		draw_line(top[side[1]], top[side[2]], STONE_EDGE if stone else BEAM, 1.0)


func _is_water(tile: Vector2i) -> bool:
	if not province.grid.is_inside(tile):
		return true
	var terrain := province.terrain_at(tile)
	return terrain != null and terrain.is_kind(&"water")


## Screen corners of [param tile] raised by [param height]: back, right, front, left.
func _corners(tile: Vector2i, height: float) -> PackedVector2Array:
	var up := Vector2(0, -height)
	return PackedVector2Array([
		IsoMath.grid_to_screen(Vector2(tile)) + up,
		IsoMath.grid_to_screen(Vector2(tile + Vector2i(1, 0))) + up,
		IsoMath.grid_to_screen(Vector2(tile + Vector2i(1, 1))) + up,
		IsoMath.grid_to_screen(Vector2(tile + Vector2i(0, 1))) + up])


## A point inside [param tile] (0-1 on both axes) on the deck.
func _at(tile: Vector2i, f: Vector2) -> Vector2:
	return IsoMath.grid_to_screen(Vector2(tile) + f) + Vector2(0, -DECK)
