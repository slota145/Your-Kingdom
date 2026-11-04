class_name WallLayer
extends Node2D
## Renders wall tiles from pieces (post + half segments, gates) with correct joins in all
## 8 directions (ARCHITECTURE §6.3). Child of the y-sorted world; each piece sorts alone.

var wall_type: String = "stone_wall"

## tile -> true when the tile is a gate.
var _walls: Dictionary[Vector2i, bool] = {}
var _sprites: Dictionary[Vector2i, Array] = {}
var _textures: Dictionary[String, Texture2D] = {}


func _init() -> void:
	y_sort_enabled = true


func has_wall(tile: Vector2i) -> bool:
	return _walls.has(tile)


func is_gate(tile: Vector2i) -> bool:
	return _walls.get(tile, false)


func tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(_walls.keys())
	return result


func set_wall(tile: Vector2i, present: bool, gate: bool = false) -> void:
	if present:
		_walls[tile] = gate
	else:
		_walls.erase(tile)
	_refresh_around(tile)


func _refresh_around(tile: Vector2i) -> void:
	_rebuild(tile)
	for offset: Vector2i in WallConnectivity.OFFSETS:
		_rebuild(tile + offset)


func _rebuild(tile: Vector2i) -> void:
	for sprite: Sprite2D in _sprites.get(tile, []):
		sprite.queue_free()
	_sprites.erase(tile)
	if not _walls.has(tile):
		return
	var mask := WallConnectivity.mask_at(tile, has_wall)
	var center := IsoMath.tile_center_screen(tile)
	var list: Array[Sprite2D] = []
	for piece: WallGeometry.Piece in WallGeometry.pieces_for(mask, _walls[tile]):
		var sprite := Sprite2D.new()
		sprite.texture = _texture(piece.name)
		sprite.centered = false
		var sort := piece.sort_offset()
		sprite.position = center + sort
		sprite.offset = -Vector2(WallGeometry.PIVOT) - sort
		add_child(sprite)
		list.append(sprite)
	_sprites[tile] = list


func _texture(piece_name: String) -> Texture2D:
	if not _textures.has(piece_name):
		_textures[piece_name] = ArtPaths.texture("walls/%s/%s.png" % [wall_type, piece_name])
	return _textures[piece_name]
