class_name TerrainLayer
extends Node2D
## Ground tiles drawn in chunks of CHUNK x CHUNK tiles. Each chunk is one canvas item, so
## off-screen chunks are culled by the renderer. Drawn below the y-sorted world.
## With a province it draws its terrain, roads and field tiles (growth stages included);
## changed tiles redraw only their chunk.

const CHUNK := 16
const FIELD_ART: Dictionary[int, String] = {
	FieldStore.Stage.FALLOW: "fallow", FieldStore.Stage.PLOWED: "plowed", FieldStore.Stage.RIPE: "ripe",
}

var map_size: Vector2i
var show_grid: bool = false:
	set(value):
		show_grid = value
		for chunk: _Chunk in _chunks:
			chunk.queue_redraw()

var province: ProvinceSim
## Terrain index -> texture variants.
var _terrain_art: Array[Array] = []
var _variants: Array[Texture2D] = []
var _grid: Texture2D
var _road: Texture2D
var _fields: Dictionary[String, Texture2D] = {}
var _chunks: Array[_Chunk] = []
var _chunk_cols: int = 1


class _Chunk:
	extends Node2D
	var layer: TerrainLayer
	var tiles: Rect2i
	var has_fields: bool = false

	func _draw() -> void:
		has_fields = false
		var tile_origin := Vector2(IsoMath.TILE_SIZE.x / 2.0, 0.0)
		for y: int in range(tiles.position.y, tiles.end.y):
			for x: int in range(tiles.position.x, tiles.end.x):
				var tile := Vector2i(x, y)
				var top := IsoMath.grid_to_screen(Vector2(x, y)) - tile_origin
				draw_texture(layer._ground(tile), top)
				var overlay := layer._overlay(tile)
				if overlay != null:
					draw_texture(overlay, top)
					has_fields = has_fields or layer.province.fields.has_field(tile)
				if layer.show_grid:
					draw_texture(layer._grid, top)


## Plain grass map (prototypes).
func setup(size: Vector2i) -> void:
	_variants = [ArtPaths.texture("terrain/grass/a.png"), ArtPaths.texture("terrain/grass/b.png")]
	_make_chunks(size)


func setup_province(source: ProvinceSim) -> void:
	province = source
	for terrain: TerrainDef in province.terrains:
		var art: Array[Texture2D] = []
		if terrain != null:
			for variant: String in ["a", "b"]:
				var path := "terrain/%s/%s.png" % [terrain.id, variant]
				if ResourceLoader.exists(ArtPaths.resolve(path)):
					art.append(ArtPaths.texture(path))
		_terrain_art.append(art)
	_variants = [ArtPaths.texture("terrain/grass/a.png"), ArtPaths.texture("terrain/grass/b.png")]
	_road = ArtPaths.texture("terrain/road/a.png")
	for name: String in ["fallow", "plowed", "sown_1", "sown_2", "sown_3", "ripe"]:
		_fields[name] = ArtPaths.texture("terrain/field/%s.png" % name)
	_make_chunks(province.grid.size)


## Redraws the chunk holding [param tile] (roads, fields, felled forest...).
func refresh_tile(tile: Vector2i) -> void:
	var index := (tile.y / CHUNK) * _chunk_cols + tile.x / CHUNK
	if index >= 0 and index < _chunks.size():
		_chunks[index].queue_redraw()


## Fields grow without events: chunks with fields are redrawn now and then.
func refresh_fields() -> void:
	for chunk: _Chunk in _chunks:
		if chunk.has_fields:
			chunk.queue_redraw()


func _make_chunks(size: Vector2i) -> void:
	map_size = size
	_grid = ArtPaths.texture("terrain/grid/a.png")
	_chunk_cols = ceili(size.x / float(CHUNK))
	for cy: int in ceili(size.y / float(CHUNK)):
		for cx: int in _chunk_cols:
			var chunk := _Chunk.new()
			chunk.layer = self
			chunk.tiles = Rect2i(cx * CHUNK, cy * CHUNK, CHUNK, CHUNK).intersection(Rect2i(Vector2i.ZERO, size))
			add_child(chunk)
			_chunks.append(chunk)


func _ground(tile: Vector2i) -> Texture2D:
	var art: Array = _variants
	if province != null:
		var index := province.grid.terrain(tile)
		if index < _terrain_art.size() and not _terrain_art[index].is_empty():
			art = _terrain_art[index]
	return art[(tile.x * 7 + tile.y * 13) % art.size()]


func _overlay(tile: Vector2i) -> Texture2D:
	if province == null:
		return null
	if province.grid.has_road(tile):
		return _road
	if province.fields.has_field(tile):
		var stage := province.fields.stage(tile, province.tick)
		if stage == FieldStore.Stage.SOWN:
			return _fields["sown_%d" % province.fields.growth_stage(tile, province.tick)]
		return _fields[FIELD_ART[stage]]
	return null
