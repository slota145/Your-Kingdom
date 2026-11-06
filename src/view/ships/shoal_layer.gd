class_name ShoalLayer
extends Node2D
## Fish shoals on the sea (M5): splashes, fish under the surface and a gull over a full
## shoal, animated, fewer as the shoal is fished out. Flat on the water, drawn below the
## y-sorted world. Nodes that grow back (ResourceNodeDef.regrow_time) are drawn here instead
## of the NatureLayer.

const FRAME_PIVOT := Vector2(32, 32)
const FRAMES := 4
const FPS := 3.0

var province: ProvinceSim
var _sprites: Dictionary[Vector2i, Sprite2D] = {}
var _texture: Texture2D


func setup(source: ProvinceSim) -> void:
	province = source
	_texture = ArtPaths.texture("nature/fish_shoal/shoal.png")
	for tile: Vector2i in province.resources.tiles_with_nodes():
		var def := province.resources.def_at(tile)
		if def != null and def.regrow_time > 0.0:
			var sprite := Sprite2D.new()
			sprite.centered = false
			sprite.texture = _texture
			sprite.hframes = FRAMES
			sprite.vframes = 3
			sprite.position = IsoMath.tile_center_screen(tile)
			sprite.offset = -FRAME_PIVOT
			add_child(sprite)
			_sprites[tile] = sprite


func update_view(time: float) -> void:
	for tile: Vector2i in _sprites:
		var def := province.resources.def_at(tile)
		var amount := province.resources.amount(tile)
		var state := 2 if amount == 0 else (0 if def != null and amount * 2 > def.amount else 1)
		var frame := int(time * FPS + tile.x * 0.7 + tile.y * 0.3) % FRAMES
		_sprites[tile].frame = state * FRAMES + frame
