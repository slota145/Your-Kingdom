class_name TileOverlay
extends Node2D
## Tinted tile diamonds drawn over the ground: the reach of a service (well) or the
## footprint under the build cursor (green = fits, red = does not). Below the y-sorted world.

var _textures: Dictionary[String, Texture2D] = {}
## Tile -> art name ("range", "ok", "bad").
var _tiles: Dictionary[Vector2i, String] = {}


func show_tiles(tiles: Dictionary[Vector2i, String]) -> void:
	_tiles = tiles
	queue_redraw()


func clear() -> void:
	if not _tiles.is_empty():
		_tiles = {}
		queue_redraw()


func _draw() -> void:
	var tile_origin := Vector2(IsoMath.TILE_SIZE.x / 2.0, 0.0)
	for tile: Vector2i in _tiles:
		draw_texture(_texture(_tiles[tile]), IsoMath.grid_to_screen(Vector2(tile)) - tile_origin)


func _texture(name: String) -> Texture2D:
	if not _textures.has(name):
		var path := "terrain/range/a.png" if name == "range" else "terrain/cursor/%s.png" % name
		_textures[name] = ArtPaths.texture(path)
	return _textures[name]
