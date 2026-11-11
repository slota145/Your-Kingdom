class_name VineLayer
extends Node2D
## Trellis rows standing on vineyard fields (review fix 2026-11-07): posts, wires and vines
## that bud, leaf out, set green grapes and ripen with the field (nature/vines/<state>.png,
## tools/generate_goods.gd). Child of the y-sorted world, one sprite per field tile sorted
## at the tile centre, so people walking between the rows are drawn in front or behind.

## Vine art by field stage; sown fields by their growth stage (1..3); a field waiting for the
## rest of the vineyard to be tended (E1 part 2, growth stage 0) stays pruned.
const STATE_FALLOW := "pruned"
const STATE_SOWN: Array[String] = ["pruned", "bud", "leaf", "full"]
const STATE_RIPE := "ripe"
## The tile centre on the ground in the vine images.
const FOOT := Vector2(32, 44)

var province: ProvinceSim
var _sprites: Dictionary[Vector2i, Sprite2D] = {}
var _textures: Dictionary[String, Texture2D] = {}


func _init() -> void:
	y_sort_enabled = true


func setup(source: ProvinceSim) -> void:
	province = source
	refresh()


## Re-reads every vineyard field (fields grow without events; called now and then).
func refresh() -> void:
	var seen: Dictionary[Vector2i, bool] = {}
	var vineyards: Dictionary[int, bool] = {}
	for building: BuildingState in province.buildings.all():
		if is_vineyard(building.def):
			vineyards[building.id] = true
	if not vineyards.is_empty():
		for tile: Vector2i in province.fields.all_tiles():
			if not vineyards.has(province.fields.farm_of(tile)):
				continue
			seen[tile] = true
			var sprite: Sprite2D = _sprites.get(tile)
			if sprite == null:
				sprite = Sprite2D.new()
				sprite.centered = false
				sprite.offset = -FOOT
				sprite.position = IsoMath.tile_center_screen(tile)
				add_child(sprite)
				_sprites[tile] = sprite
			sprite.texture = _texture(state_of(province.fields, tile, province.tick))
	for tile: Vector2i in _sprites.keys():
		if not seen.has(tile):
			_sprites[tile].queue_free()
			_sprites.erase(tile)


## Vine art name for the field on [param tile] at [param tick].
static func state_of(fields: FieldStore, tile: Vector2i, tick: int) -> String:
	match fields.stage(tile, tick):
		FieldStore.Stage.SOWN:
			return STATE_SOWN[clampi(fields.growth_stage(tile, tick), 0, STATE_SOWN.size() - 1)]
		FieldStore.Stage.RIPE:
			return STATE_RIPE
	return STATE_FALLOW


## Whether the fields of [param def] grow grapes on trellises.
static func is_vineyard(def: BuildingDef) -> bool:
	if def.recipe == null:
		return false
	for step: StepDef in def.recipe.steps:
		if step is FieldStepDef and (step as FieldStepDef).harvest_good == &"grapes":
			return true
	return false


func _texture(state: String) -> Texture2D:
	if not _textures.has(state):
		_textures[state] = ArtPaths.texture("nature/vines/%s.png" % state)
	return _textures[state]
