class_name TileGrid
extends RefCounted
## Per-tile map state of a province (ARCHITECTURE §4.1): terrain, roads, blocked tiles and
## building occupancy. Walkability for pathfinding is derived from it into NavGrid.

var size: Vector2i

## TerrainDef.index per tile. Part of the map, saved.
var _terrain: PackedByteArray = PackedByteArray()
## 0 = none, 1 = dirt road, 2 = paved road (GDD §5.2, M4b-3). Saved.
var _road: PackedByteArray = PackedByteArray()
## 1 = impassable regardless of terrain (walls in prototypes, tests). Saved.
var _blocked: PackedByteArray = PackedByteArray()
## Quay over the sea (N1): 0 = none, 1 = timber pier, 2 = stone quay. Saved.
var _quay: PackedByteArray = PackedByteArray()
## Entity id of the building covering the tile, 0 = none. Rebuilt from buildings on load.
var _occupant: PackedInt32Array = PackedInt32Array()


func _init(grid_size: Vector2i) -> void:
	size = grid_size
	_terrain.resize(size.x * size.y)
	_road.resize(size.x * size.y)
	_blocked.resize(size.x * size.y)
	_quay.resize(size.x * size.y)
	_occupant.resize(size.x * size.y)


func is_inside(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y


func index(tile: Vector2i) -> int:
	return tile.y * size.x + tile.x


func terrain(tile: Vector2i) -> int:
	return _terrain[index(tile)] if is_inside(tile) else 0


func set_terrain(tile: Vector2i, terrain_index: int) -> void:
	if is_inside(tile):
		_terrain[index(tile)] = terrain_index


const DIRT_ROAD := 1
const PAVED_ROAD := 2


## Any road, dirt or paved.
func has_road(tile: Vector2i) -> bool:
	return is_inside(tile) and _road[index(tile)] != 0


func is_paved(tile: Vector2i) -> bool:
	return is_inside(tile) and _road[index(tile)] == PAVED_ROAD


## Lays dirt road (or removes any road).
func set_road(tile: Vector2i, road: bool) -> void:
	if is_inside(tile):
		_road[index(tile)] = DIRT_ROAD if road else 0


## Paves a road tile, or turns it back into dirt road.
func set_paved(tile: Vector2i, paved: bool) -> void:
	if is_inside(tile):
		_road[index(tile)] = PAVED_ROAD if paved else DIRT_ROAD


func road_count() -> int:
	return _road.size() - _road.count(0)


func paved_count() -> int:
	return _road.count(PAVED_ROAD)


const PIER := 1
const STONE_QUAY := 2


## 0 none, PIER or STONE_QUAY (N1).
func quay(tile: Vector2i) -> int:
	return _quay[index(tile)] if is_inside(tile) else 0


func has_quay(tile: Vector2i) -> bool:
	return is_inside(tile) and _quay[index(tile)] != 0


func set_quay(tile: Vector2i, kind: int) -> void:
	if is_inside(tile):
		_quay[index(tile)] = kind


func quay_count() -> int:
	return _quay.size() - _quay.count(0)


func is_blocked(tile: Vector2i) -> bool:
	return is_inside(tile) and _blocked[index(tile)] == 1


func set_blocked(tile: Vector2i, blocked: bool) -> void:
	if is_inside(tile):
		_blocked[index(tile)] = 1 if blocked else 0


func occupant(tile: Vector2i) -> int:
	return _occupant[index(tile)] if is_inside(tile) else 0


func set_occupant(tile: Vector2i, entity_id: int) -> void:
	if is_inside(tile):
		_occupant[index(tile)] = entity_id


func to_dict() -> Dictionary:
	return {
		"size": SimCodec.vec2i(size),
		"terrain": Marshalls.raw_to_base64(_terrain),
		"roads": Marshalls.raw_to_base64(_road),
		"blocked": Marshalls.raw_to_base64(_blocked),
		"quays": Marshalls.raw_to_base64(_quay),
	}


static func from_dict(d: Dictionary) -> TileGrid:
	var grid := TileGrid.new(SimCodec.to_vec2i(d["size"]))
	var cells := grid.size.x * grid.size.y
	for key: String in ["terrain", "roads", "blocked", "quays"]:
		var raw := Marshalls.base64_to_raw(String(d.get(key, "")))
		if raw.size() != cells:
			continue
		match key:
			"terrain": grid._terrain = raw
			"roads": grid._road = raw
			"blocked": grid._blocked = raw
			"quays": grid._quay = raw
	return grid
