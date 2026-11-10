class_name NatureLayer
extends Node2D
## Sprites of resource nodes (trees: grown, felled, stump in old saves; saplings). Child of the y-sorted world;
## refreshed from simulation events, not every frame.

var _field: ResourceField
var _sprites: Dictionary[Vector2i, Sprite2D] = {}
var _textures: Dictionary[String, Texture2D] = {}
var _variant_counts: Dictionary[StringName, int] = {}


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
	var look := variant_suffix(tile, _variant_count(def.id))
	sprite.texture = _texture("nature/%s/%s%s.png" % [def.id, state, look])
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


## The look of the natural object on a tile, as a file name suffix ("" = the first look, "_2"...):
## fixed by the tile, so a tree keeps its species through felling and after loading a game
## (owner 2026-11-10: a mixed forest; the simulation and the save do not know about looks).
static func variant_suffix(tile: Vector2i, count: int) -> String:
	if count <= 1:
		return ""
	var h := absi((tile.x * 73856093) ^ (tile.y * 19349663)) % count
	return "" if h == 0 else "_%d" % (h + 1)


## How many looks an object has: grown.png, grown_2.png... (ART_SPEC §8); cached per id.
func _variant_count(id: StringName) -> int:
	if not _variant_counts.has(id):
		var n := 1
		while ResourceLoader.exists(ArtPaths.resolve("nature/%s/grown_%d.png" % [id, n + 1])):
			n += 1
		_variant_counts[id] = n
	return _variant_counts[id]


func _texture(relative: String) -> Texture2D:
	if not _textures.has(relative):
		_textures[relative] = ArtPaths.texture(relative)
	return _textures[relative]
