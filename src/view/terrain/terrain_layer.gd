class_name TerrainLayer
extends Node2D
## Ground drawn in chunks of CHUNK x CHUNK tiles. Each chunk is one canvas item, so
## off-screen chunks are culled by the renderer. Drawn below the y-sorted world.
##
## The ground is organic (ART_SPEC §8.1): tiles only rasterise their diamond and the
## organic_ground shader picks each pixel's colour from a per-tile map texture read at a
## noise-warped position, so terrain borders and roads are round instead of diamond-shaped.
## Above the ground come flower decals (off-grid) and the tile overlays: fields (growth
## stages included) and the debug grid. Changed tiles redraw only their chunk.

const CHUNK := 16
const FIELD_ART: Dictionary[int, String] = {
	FieldStore.Stage.FALLOW: "fallow", FieldStore.Stage.PLOWED: "plowed", FieldStore.Stage.RIPE: "ripe",
}
## Art slots known to the shader (order matches its constants).
enum Slot { GRASS, MEADOW, FOREST, WATER, FORD, SEA, SAND }
const SLOT_BY_TERRAIN: Dictionary[StringName, Slot] = {
	&"grass": Slot.GRASS, &"meadow": Slot.MEADOW, &"forest": Slot.FOREST, &"water": Slot.WATER,
	&"ford": Slot.FORD, &"sea": Slot.SEA, &"sand": Slot.SAND,
}
## Shader texture uniform -> art file.
const TEXTURES: Dictionary[String, String] = {
	"grass_tex": "terrain/grass/a.png", "grass_light_tex": "terrain/grass/light.png",
	"grass_dark_tex": "terrain/grass/dark.png", "meadow_tex": "terrain/meadow/a.png",
	"forest_tex": "terrain/forest/a.png", "water_tex": "terrain/water/a.png",
	"water_alt_tex": "terrain/water/b.png", "sea_alt_tex": "terrain/sea/b.png",
	"road_alt_tex": "terrain/road/b.png",
	"paving_tex": "terrain/paving/a.png", "paving_alt_tex": "terrain/paving/b.png",
	"ford_tex": "terrain/ford/a.png", "sea_tex": "terrain/sea/a.png",
	"shallow_tex": "terrain/sea/shallow.png", "sand_tex": "terrain/sand/a.png",
	"bank_tex": "terrain/bank/a.png", "road_tex": "terrain/road/a.png",
}
const DECOR_NAMES: PackedStringArray = ["flowers_white", "flowers_yellow", "flowers_purple", "clover"]
## Share of plain grass tiles that get a flower decal.
const DECOR_CHANCE := 0.06
const MEADOW_DECOR_CHANCE := 0.2

var map_size: Vector2i
var show_grid: bool = false:
	set(value):
		show_grid = value
		for chunk: _Overlay in _overlays:
			chunk.queue_redraw()
## Off: plain tiles without warped borders (debug comparison).
var organic: bool = true:
	set(value):
		organic = value
		if _material != null:
			_material.set_shader_parameter("organic", value)

var province: ProvinceSim
## Terrain index -> art slot.
var _slot_by_index: PackedInt32Array = []
var _map_image: Image
var _map_texture: ImageTexture
var _material: ShaderMaterial
var _mask: Texture2D
var _grid: Texture2D
var _decor: Array[Texture2D] = []
var _fields: Dictionary[String, Texture2D] = {}
var _grounds: Array[_Ground] = []
var _decors: Array[_Decor] = []
var _overlays: Array[_Overlay] = []
var _chunk_cols: int = 1


class _Ground:
	extends Node2D
	var layer: TerrainLayer
	var tiles: Rect2i

	func _draw() -> void:
		for y: int in range(tiles.position.y, tiles.end.y):
			for x: int in range(tiles.position.x, tiles.end.x):
				draw_texture(layer._mask, TerrainLayer.tile_top(Vector2i(x, y)))


## Decals have their own chunks above all ground chunks, so a decal crossing a chunk border is
## never covered by the neighbouring chunk's ground.
class _Decor:
	extends Node2D
	var layer: TerrainLayer
	var tiles: Rect2i

	func _draw() -> void:
		for y: int in range(tiles.position.y, tiles.end.y):
			for x: int in range(tiles.position.x, tiles.end.x):
				var tile := Vector2i(x, y)
				var chance := layer._decor_chance(tile)
				var h := TerrainLayer.tile_hash(tile)
				if h % 1000 >= int(chance * 1000.0):
					continue
				var tex: Texture2D = layer._decor[(h / 1000) % layer._decor.size()]
				# Random point inside the tile (-0.3..0.3 tiles on each axis).
				var offset := Vector2(((h >> 12) % 61 - 30) / 100.0, ((h >> 20) % 61 - 30) / 100.0)
				var centre := IsoMath.grid_to_screen(IsoMath.tile_center(tile) + offset)
				draw_texture(tex, (centre - tex.get_size() / 2.0).round())


class _Overlay:
	extends Node2D
	var layer: TerrainLayer
	var tiles: Rect2i
	var has_fields: bool = false

	func _draw() -> void:
		has_fields = false
		for y: int in range(tiles.position.y, tiles.end.y):
			for x: int in range(tiles.position.x, tiles.end.x):
				var tile := Vector2i(x, y)
				var top := TerrainLayer.tile_top(tile)
				var field := layer._field(tile)
				if field != null:
					draw_texture(field, top)
					has_fields = true
				if layer.show_grid:
					draw_texture(layer._grid, top)


## Plain grass map (prototypes).
func setup(size: Vector2i) -> void:
	_map_image = Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	_build(size)


func setup_province(source: ProvinceSim) -> void:
	province = source
	_slot_by_index = slot_table(province.terrains)
	_map_image = build_map_image(province.grid, _slot_by_index)
	for folder: String in ["field", "field_hops"]:
		for name: String in ["fallow", "plowed", "sown_1", "sown_2", "sown_3", "ripe"]:
			_fields["%s/%s" % [folder, name]] = ArtPaths.texture("terrain/%s/%s.png" % [folder, name])
	_build(province.grid.size)


## Redraws the chunk holding [param tile] (roads, fields, felled forest...).
func refresh_tile(tile: Vector2i) -> void:
	if province != null and province.grid.is_inside(tile):
		_map_image.set_pixelv(tile, map_texel(province.grid, _slot_by_index, tile))
		_map_texture.update(_map_image)
	var index := (tile.y / CHUNK) * _chunk_cols + tile.x / CHUNK
	if index >= 0 and index < _overlays.size():
		_decors[index].queue_redraw()
		_overlays[index].queue_redraw()


## Prototypes without a province: sets the look of one tile. Call apply_paint() afterwards.
func paint(tile: Vector2i, slot: Slot, road: bool = false) -> void:
	_map_image.set_pixelv(tile, Color(slot / 255.0, 1.0 if road else 0.0, 0.0))


func apply_paint() -> void:
	_map_texture.update(_map_image)
	for chunk: _Decor in _decors:
		chunk.queue_redraw()


## Replaces one ground texture (shader uniform name from TEXTURES), e.g. for art trials.
func override_texture(uniform: String, texture: Texture2D) -> void:
	_material.set_shader_parameter(uniform, texture)


## Fields grow without events: chunks with fields are redrawn now and then.
func refresh_fields() -> void:
	for chunk: _Overlay in _overlays:
		if chunk.has_fields:
			chunk.queue_redraw()


## Top-left corner of the 64x32 image of [param tile].
static func tile_top(tile: Vector2i) -> Vector2:
	return IsoMath.grid_to_screen(Vector2(tile)) - Vector2(IsoMath.HALF_W, 0.0)


static func tile_hash(tile: Vector2i) -> int:
	var h := (tile.x * 73856093) ^ (tile.y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


## Art slot per terrain index; unknown terrains look like grass.
static func slot_table(terrains: Array[TerrainDef]) -> PackedInt32Array:
	var table := PackedInt32Array()
	table.resize(terrains.size())
	for i: int in terrains.size():
		var terrain := terrains[i]
		table[i] = SLOT_BY_TERRAIN.get(terrain.id, Slot.GRASS) if terrain != null else Slot.GRASS
	return table


## Map texel of one tile: R = art slot / 255, G = 1 on roads, B = 1 on paved roads.
static func map_texel(grid: TileGrid, slots: PackedInt32Array, tile: Vector2i) -> Color:
	var index := grid.terrain(tile)
	var slot := slots[index] if index < slots.size() else Slot.GRASS
	return Color(slot / 255.0, 1.0 if grid.has_road(tile) else 0.0, 1.0 if grid.is_paved(tile) else 0.0)


static func build_map_image(grid: TileGrid, slots: PackedInt32Array) -> Image:
	var image := Image.create(grid.size.x, grid.size.y, false, Image.FORMAT_RGB8)
	for y: int in grid.size.y:
		for x: int in grid.size.x:
			image.set_pixel(x, y, map_texel(grid, slots, Vector2i(x, y)))
	return image


func _build(size: Vector2i) -> void:
	map_size = size
	_mask = ArtPaths.texture("terrain/grass/a.png")
	_grid = ArtPaths.texture("terrain/grid/a.png")
	for name: String in DECOR_NAMES:
		_decor.append(ArtPaths.texture("terrain/grass_decor/%s.png" % name))
	_map_texture = ImageTexture.create_from_image(_map_image)
	_material = ShaderMaterial.new()
	_material.shader = load("res://src/view/terrain/organic_ground.gdshader") as Shader
	_material.set_shader_parameter("map_tex", _map_texture)
	_material.set_shader_parameter("map_size", Vector2(size))
	_material.set_shader_parameter("organic", organic)
	for uniform: String in TEXTURES:
		_material.set_shader_parameter(uniform, ArtPaths.texture(TEXTURES[uniform]))
	_chunk_cols = ceili(size.x / float(CHUNK))
	var rects: Array[Rect2i] = []
	for cy: int in ceili(size.y / float(CHUNK)):
		for cx: int in _chunk_cols:
			rects.append(Rect2i(cx * CHUNK, cy * CHUNK, CHUNK, CHUNK).intersection(Rect2i(Vector2i.ZERO, size)))
	for rect: Rect2i in rects:
		var ground := _Ground.new()
		ground.layer = self
		ground.tiles = rect
		ground.material = _material
		add_child(ground)
		_grounds.append(ground)
	for rect: Rect2i in rects:
		var decor := _Decor.new()
		decor.layer = self
		decor.tiles = rect
		add_child(decor)
		_decors.append(decor)
	for rect: Rect2i in rects:
		var overlay := _Overlay.new()
		overlay.layer = self
		overlay.tiles = rect
		add_child(overlay)
		_overlays.append(overlay)


## Flowers only on plain grass or meadow, away from water, roads and fields.
func _decor_chance(tile: Vector2i) -> float:
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var t := tile + offset
		if not Rect2i(Vector2i.ZERO, map_size).has_point(t):
			continue
		var texel := _map_image.get_pixelv(t)
		var slot := roundi(texel.r * 255.0)
		if slot != Slot.GRASS and slot != Slot.MEADOW or texel.g > 0.5:
			return 0.0
		if province != null and province.fields.has_field(t):
			return 0.0
	var own := roundi(_map_image.get_pixelv(tile).r * 255.0)
	return MEADOW_DECOR_CHANCE if own == Slot.MEADOW else DECOR_CHANCE


func _field(tile: Vector2i) -> Texture2D:
	if province == null or not province.fields.has_field(tile):
		return null
	var stage := province.fields.stage(tile, province.tick)
	var folder := _crop_folder(province.fields.farm_of(tile))
	if stage == FieldStore.Stage.SOWN:
		return _fields["%s/sown_%d" % [folder, province.fields.growth_stage(tile, province.tick)]]
	return _fields["%s/%s" % [folder, FIELD_ART[stage]]]


## Art folder of a farm's crop: "field" for grain, "field_<good>" for others (hops).
func _crop_folder(farm_id: int) -> String:
	var farm := province.buildings.get_building(farm_id)
	if farm == null or farm.def.recipe == null:
		return "field"
	for step: StepDef in farm.def.recipe.steps:
		if step is FieldStepDef and (step as FieldStepDef).harvest_good != &"grain":
			var folder := "field_%s" % (step as FieldStepDef).harvest_good
			if _fields.has(folder + "/fallow"):
				return folder
	return "field"
