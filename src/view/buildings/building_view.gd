class_name BuildingView
extends Node2D
## A building drawn as half-tile strips, each sorted on its own (ARCHITECTURE §6.2).
## Must be a child of a y-sorted node; its own y_sort makes the strips join that sort.
## Position = front (bottom) vertex B of the footprint, in screen space.

## Fraction of opacity when something of interest is behind the building (visibility a).
const FADED_ALPHA := 0.35
## In "lowered" mode (visibility b) only this many pixels above the footprint stay.
const LOWERED_WALL_PX := 10

var footprint: Vector2i
var origin_tile: Vector2i
var _pivot: Vector2i
var _strips: Array[Sprite2D] = []
var _full_regions: Array[Rect2] = []
var _lowered: bool = false
var _texture: Texture2D

## Texture -> its image, for clicks on the drawn pixels (loaded on the first click).
static var _images: Dictionary[Texture2D, Image] = {}


func _init() -> void:
	y_sort_enabled = true


## [param art]: art path without extension, e.g. "buildings/mill/base" (.png + .json).
func setup(art: String, tile: Vector2i) -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			ArtPaths.resolve(art + ".json")))
	var fp: Array = meta["footprint"]
	var pv: Array = meta["pivot"]
	footprint = Vector2i(int(fp[0]), int(fp[1]))
	_pivot = Vector2i(int(pv[0]), int(pv[1]))
	origin_tile = tile
	position = IsoMath.grid_to_screen(Vector2(tile + footprint))
	var tex := ArtPaths.texture(art + ".png")
	_texture = tex
	for strip: BuildingSlicer.Strip in BuildingSlicer.slices(footprint, _pivot, Vector2i(tex.get_size())):
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_rect = Rect2(strip.region)
		sprite.position = strip.sort_offset
		sprite.offset = Vector2(strip.region.position - _pivot) - strip.sort_offset
		add_child(sprite)
		_strips.append(sprite)
		_full_regions.append(sprite.region_rect)


func get_tile_rect() -> Rect2i:
	return Rect2i(origin_tile, footprint)


## Whether the art has a visible pixel at [param world_pos] (clicks select what is drawn,
## not the tile under the cursor).
func is_opaque_at(world_pos: Vector2) -> bool:
	if _texture == null:
		return false
	var texel := Vector2i((to_local(world_pos) + Vector2(_pivot)).floor())
	if texel.x < 0 or texel.y < 0 or texel.x >= _texture.get_width() or texel.y >= _texture.get_height():
		return false
	if not _images.has(_texture):
		_images[_texture] = _texture.get_image()
	var image := _images[_texture]
	return image != null and image.get_pixelv(texel).a > 0.2


## Screen-space rectangle covered by the art.
func get_screen_rect() -> Rect2:
	var rect := Rect2()
	for i: int in _strips.size():
		var s := _strips[i]
		var r := Rect2(position + s.position + s.offset, s.region_rect.size)
		rect = r if i == 0 else rect.merge(r)
	return rect


func set_faded(faded: bool) -> void:
	modulate.a = FADED_ALPHA if faded else 1.0


func set_lowered(lowered: bool) -> void:
	if lowered == _lowered:
		return
	_lowered = lowered
	for i: int in _strips.size():
		var full := _full_regions[i]
		var s := _strips[i]
		if lowered:
			# Keep only a stub of the front wall: cut each strip just above its own front edge
			# (the edge rises up to 8 px across a strip), so whatever stands behind shows.
			var keep_from := _pivot.y + s.position.y - 8.0 - LOWERED_WALL_PX
			var cut := clampf(keep_from - full.position.y, 0.0, full.size.y)
			s.region_rect = Rect2(full.position.x, full.position.y + cut, full.size.x, full.size.y - cut)
			s.offset.y = full.position.y + cut - _pivot.y - s.position.y
		else:
			s.region_rect = full
			s.offset.y = full.position.y - _pivot.y - s.position.y
