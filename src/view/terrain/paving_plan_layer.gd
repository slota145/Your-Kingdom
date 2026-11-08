class_name PavingPlanLayer
extends Node2D
## Tiles ordered paved and not laid yet (review fix 2026-11-07: the player sees clearly which
## tiles wait for cobbles): a dashed stone-grey frame with a few cobbles in the middle; the
## tile the builder lays next is drawn brighter. Drawn over the ground, below the world.
## Reads the paving sites (cobbles only; quay orders are QuayLayer's).

const FRAME := Color(0.86, 0.84, 0.78, 0.9)
const FRAME_NEXT := Color(1.0, 0.93, 0.6, 1.0)
const FILL := Color(0.55, 0.53, 0.5, 0.28)
const COBBLE := Color(0.7, 0.68, 0.63, 0.85)
const COBBLE_EDGE := Color(0.36, 0.34, 0.31, 0.85)
## Dash and gap along the frame, px.
const DASH := 4.0
const GAP := 3.0
## Cobbles in the middle of a tile: offset from its centre (px) and radius.
const _COBBLES: Array[Vector3] = [Vector3(-7, -1, 2.6), Vector3(0, -3, 2.4), Vector3(6, 0, 2.6),
		Vector3(-2, 3, 2.4), Vector3(4, 4, 2.0)]

var province: ProvinceSim
var _tiles: Array[Vector2i] = []
var _next: Dictionary[Vector2i, bool] = {}
## Wall orders (M7 part 2): tile -> PavingSite kind.
var _walls: Dictionary[Vector2i, int] = {}


func setup(source: ProvinceSim) -> void:
	province = source
	refresh()


## Rereads the paving orders and redraws.
func refresh() -> void:
	_tiles.clear()
	_next.clear()
	_walls.clear()
	for paving_site: PavingSite in province.paving.values():
		if paving_site.is_quay() or paving_site.is_bridge() or paving_site.tiles.is_empty():
			continue
		if paving_site.is_wall():
			for tile: Vector2i in paving_site.tiles:
				_walls[tile] = paving_site.kind
			_next[paving_site.tiles[0]] = true
			continue
		_tiles.append_array(paving_site.tiles)
		_next[paving_site.tiles[0]] = true
	queue_redraw()


func on_sim_event(event: Dictionary) -> void:
	match event["type"]:
		&"paving_ordered", &"paving_closed", &"paving_cancelled", &"wall_ordered", &"wall_changed":
			refresh()
		&"road_changed":
			if not _tiles.is_empty():
				refresh()


func _draw() -> void:
	_draw_walls()
	var half := Vector2(IsoMath.TILE_SIZE) / 2.0
	for tile: Vector2i in _tiles:
		var centre := IsoMath.tile_center_screen(tile)
		# Slightly inside the tile, so neighbouring frames do not merge into one line.
		var corners: Array[Vector2] = [centre + Vector2(0, -half.y) * 0.86, centre + Vector2(half.x, 0) * 0.86,
				centre + Vector2(0, half.y) * 0.86, centre + Vector2(-half.x, 0) * 0.86]
		draw_colored_polygon(PackedVector2Array(corners), FILL)
		var colour := FRAME_NEXT if _next.has(tile) else FRAME
		for i: int in 4:
			_dashed(corners[i], corners[(i + 1) % 4], colour)
		for cobble: Vector3 in _COBBLES:
			var at := centre + Vector2(cobble.x, cobble.y)
			draw_circle(at, cobble.z + 0.8, COBBLE_EDGE)
			draw_circle(at, cobble.z, COBBLE)


## A wall order: a dashed frame and a row of foundation stones (or stakes for a palisade).
func _draw_walls() -> void:
	var half := Vector2(IsoMath.TILE_SIZE) / 2.0
	for tile: Vector2i in _walls:
		var centre := IsoMath.tile_center_screen(tile)
		var corners: Array[Vector2] = [centre + Vector2(0, -half.y) * 0.86, centre + Vector2(half.x, 0) * 0.86,
				centre + Vector2(0, half.y) * 0.86, centre + Vector2(-half.x, 0) * 0.86]
		var wooden := _walls[tile] == PavingSite.KIND_PALISADE
		draw_colored_polygon(PackedVector2Array(corners), Color(0.5, 0.36, 0.22, 0.3) if wooden else FILL)
		var colour := FRAME_NEXT if _next.has(tile) else FRAME
		for i: int in 4:
			_dashed(corners[i], corners[(i + 1) % 4], colour)
		for k: int in 5:
			var at := centre + Vector2(-12 + 6 * k, -6 + 3 * k)
			if wooden:
				draw_line(at, at - Vector2(0, 7), COBBLE_EDGE, 3.0)
				draw_line(at, at - Vector2(0, 7), Color(0.62, 0.46, 0.3), 1.5)
			else:
				draw_rect(Rect2(at - Vector2(3, 2), Vector2(6, 4)), COBBLE_EDGE)
				draw_rect(Rect2(at - Vector2(2, 1.5), Vector2(4, 3)), COBBLE)


func _dashed(from: Vector2, to: Vector2, colour: Color) -> void:
	var length := from.distance_to(to)
	var dir := (to - from) / length
	var at := 0.0
	while at < length:
		draw_line(from + dir * at, from + dir * minf(at + DASH, length), colour, 1.5)
		at += DASH + GAP
