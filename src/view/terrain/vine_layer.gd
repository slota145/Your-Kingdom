class_name VineLayer
extends Node2D
## Trellis rows standing on vineyard fields (review fix 2026-11-07): posts, wires and vines
## that bud, leaf out, set green grapes and ripen with the field (nature/vines/<state>.png,
## tools/generate_goods.gd). Child of the y-sorted world, one sprite per field tile sorted
## at the tile centre, so people walking between the rows are drawn in front or behind.
## Owner 2026-11-11: wheat and hops stand on their fields the same way (SpriteKiln,
## nature/crops/<crop>/<state>.png from tools/spritekiln/gen_crops.py and export_crops.py).

## Vine art by field stage; sown fields by their growth stage (1..3); a field waiting for the
## rest of the vineyard to be tended (E1 part 2, growth stage 0) stays pruned.
const STATE_FALLOW := "pruned"
const STATE_SOWN: Array[String] = ["pruned", "bud", "leaf", "full"]
const STATE_RIPE := "ripe"
## The tile centre on the ground in the vine images.
const FOOT := Vector2(32, 44)
## Harvested good -> [art folder, art while fallow, art by growth stage 0..3, art when ripe,
## tile centre in the images]; "" = nothing stands on the tile.
const CROPS: Dictionary[StringName, Array] = {
	&"grapes": ["nature/vines", STATE_FALLOW, STATE_SOWN, STATE_RIPE, FOOT],
	&"grain": ["nature/crops/grain", "", ["", "sprout", "young", "green"], "ripe", Vector2(32, 48)],
	&"hops": ["nature/crops/hops", "poles", ["poles", "shoot", "half", "full"], "ripe", Vector2(32, 96)],
}

var province: ProvinceSim
var _sprites: Dictionary[Vector2i, Sprite2D] = {}
var _textures: Dictionary[String, Texture2D] = {}


func _init() -> void:
	y_sort_enabled = true


func setup(source: ProvinceSim) -> void:
	province = source
	refresh()


## Re-reads every field of a crop that stands (fields grow without events; called now and then).
func refresh() -> void:
	var seen: Dictionary[Vector2i, bool] = {}
	var crops: Dictionary[int, StringName] = {}
	for building: BuildingState in province.buildings.all():
		var crop := crop_of(building.def)
		if crop != &"":
			crops[building.id] = crop
	if not crops.is_empty():
		for tile: Vector2i in province.fields.all_tiles():
			if _show(tile, crops.get(province.fields.farm_of(tile), &"")):
				seen[tile] = true
	for tile: Vector2i in _sprites.keys():
		if not seen.has(tile):
			_sprites[tile].queue_free()
			_sprites.erase(tile)


## Updates the plants on one tile at once (sown, reaped, removed: owner 2026-11-11).
func refresh_tile(tile: Vector2i) -> void:
	var farm := province.buildings.get_building(province.fields.farm_of(tile)) \
			if province.fields.has_field(tile) else null
	if not _show(tile, crop_of(farm.def) if farm != null else &"") and _sprites.has(tile):
		_sprites[tile].queue_free()
		_sprites.erase(tile)


## Shows [param crop] on [param tile] in its state; false when nothing stands there.
func _show(tile: Vector2i, crop: StringName) -> bool:
	if crop == &"":
		return false
	var state := state_of(province.fields, tile, province.tick, crop)
	if state == "":
		return false
	var sprite: Sprite2D = _sprites.get(tile)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.position = IsoMath.tile_center_screen(tile)
		add_child(sprite)
		_sprites[tile] = sprite
	var spec: Array = CROPS[crop]
	sprite.offset = -(spec[4] as Vector2)
	sprite.texture = _texture("%s/%s" % [spec[0], state])
	return true


## Art name of [param crop] (grapes by default) for the field on [param tile] at [param tick];
## "" when nothing stands there.
static func state_of(fields: FieldStore, tile: Vector2i, tick: int, crop: StringName = &"grapes") -> String:
	var spec: Array = CROPS[crop]
	match fields.stage(tile, tick):
		FieldStore.Stage.SOWN:
			var sown: Array = spec[2]
			return sown[clampi(fields.growth_stage(tile, tick), 0, sown.size() - 1)]
		FieldStore.Stage.RIPE:
			return spec[3]
	return spec[1]


## The crop standing on the fields of [param def] (a key of CROPS), &"" for none.
static func crop_of(def: BuildingDef) -> StringName:
	if def.recipe == null:
		return &""
	for step: StepDef in def.recipe.steps:
		if step is FieldStepDef and CROPS.has((step as FieldStepDef).harvest_good):
			return (step as FieldStepDef).harvest_good
	return &""


## Whether the fields of [param def] grow grapes on trellises.
static func is_vineyard(def: BuildingDef) -> bool:
	if def.recipe == null:
		return false
	for step: StepDef in def.recipe.steps:
		if step is FieldStepDef and (step as FieldStepDef).harvest_good == &"grapes":
			return true
	return false


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = ArtPaths.texture("%s.png" % path)
	return _textures[path]
