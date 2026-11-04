class_name TerrainLayer
extends Node2D
## Ground tiles drawn in chunks of CHUNK x CHUNK tiles. Each chunk is one canvas item, so
## off-screen chunks are culled by the renderer. Drawn below the y-sorted world.

const CHUNK := 16

var map_size: Vector2i
var show_grid: bool = false:
	set(value):
		show_grid = value
		for chunk: _Chunk in _chunks:
			chunk.queue_redraw()

var _variants: Array[Texture2D] = []
var _grid: Texture2D
var _chunks: Array[_Chunk] = []


class _Chunk:
	extends Node2D
	var layer: TerrainLayer
	var tiles: Rect2i

	func _draw() -> void:
		var tile_origin := Vector2(IsoMath.TILE_SIZE.x / 2.0, 0.0)
		for y: int in range(tiles.position.y, tiles.end.y):
			for x: int in range(tiles.position.x, tiles.end.x):
				var top := IsoMath.grid_to_screen(Vector2(x, y)) - tile_origin
				var variant := layer._variants[(x * 7 + y * 13) % layer._variants.size()]
				draw_texture(variant, top)
				if layer.show_grid:
					draw_texture(layer._grid, top)


func setup(size: Vector2i) -> void:
	map_size = size
	_variants = [ArtPaths.texture("terrain/grass/a.png"), ArtPaths.texture("terrain/grass/b.png")]
	_grid = ArtPaths.texture("terrain/grid/a.png")
	for cy: int in ceili(size.y / float(CHUNK)):
		for cx: int in ceili(size.x / float(CHUNK)):
			var chunk := _Chunk.new()
			chunk.layer = self
			chunk.tiles = Rect2i(cx * CHUNK, cy * CHUNK, CHUNK, CHUNK).intersection(Rect2i(Vector2i.ZERO, size))
			add_child(chunk)
			_chunks.append(chunk)
