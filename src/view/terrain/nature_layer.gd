class_name NatureLayer
extends Node2D
## Sprites of resource nodes (trees: grown, felled, stump in old saves; saplings). Child of the y-sorted world;
## refreshed from simulation events, not every frame.

var _field: ResourceField
var _sprites: Dictionary[Vector2i, Sprite2D] = {}
var _textures: Dictionary[String, Texture2D] = {}


func _init() -> void:
	y_sort_enabled = true


func setup(field: ResourceField) -> void:
	_field = field
	for tile: Vector2i in field.tiles_with_nodes():
		refresh(tile)


func refresh(tile: Vector2i) -> void:
	var def := _field.def_at(tile)
	if def != null and def.regrow_time > 0.0:
		return   # fish shoals: ShoalLayer (M5)
	if def == null:
		if _sprites.has(tile):
			_sprites[tile].queue_free()
			_sprites.erase(tile)
		return
	var state := "grown"
	if _field.is_depleted(tile):
		state = "stump"
	elif _field.amount(tile) < def.amount:
		state = "felled"
	var sprite: Sprite2D = _sprites.get(tile)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.position = IsoMath.tile_center_screen(tile)
		add_child(sprite)
		_sprites[tile] = sprite
	sprite.texture = _texture("nature/%s/%s.png" % [def.id, state])
	# The tile diamond sits in the bottom 32 px of nature art (ART_SPEC §2).
	sprite.offset = -Vector2(sprite.texture.get_width() / 2.0, sprite.texture.get_height() - 16.0)


func on_sim_event(event: Dictionary) -> void:
	match event["type"]:
		&"good_gathered", &"resource_depleted", &"resource_planted", &"resource_grown":
			refresh(event["tile"])
		&"building_placed":
			var def := Data.registry.get_building(event["def"])
			for t: Vector2i in def.footprint_tiles(event["origin"]):
				if _sprites.has(t):
					refresh(t)


func _texture(relative: String) -> Texture2D:
	if not _textures.has(relative):
		_textures[relative] = ArtPaths.texture(relative)
	return _textures[relative]
