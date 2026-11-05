class_name TileGrid
extends RefCounted
## Per-tile map state of a province (ARCHITECTURE §4.1): blocked terrain and building
## occupancy. Walkability for pathfinding is derived from it into NavGrid.

var size: Vector2i

## 1 = impassable terrain (water, rock). Part of the map, saved.
var _blocked: PackedByteArray = PackedByteArray()
## Entity id of the building covering the tile, 0 = none. Rebuilt from buildings on load.
var _occupant: PackedInt32Array = PackedInt32Array()


func _init(grid_size: Vector2i) -> void:
	size = grid_size
	_blocked.resize(size.x * size.y)
	_occupant.resize(size.x * size.y)


func is_inside(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y


func index(tile: Vector2i) -> int:
	return tile.y * size.x + tile.x


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
	return {"size": SimCodec.vec2i(size), "blocked": Marshalls.raw_to_base64(_blocked)}


static func from_dict(d: Dictionary) -> TileGrid:
	var grid := TileGrid.new(SimCodec.to_vec2i(d["size"]))
	var blocked := Marshalls.base64_to_raw(String(d.get("blocked", "")))
	if blocked.size() == grid._blocked.size():
		grid._blocked = blocked
	return grid
