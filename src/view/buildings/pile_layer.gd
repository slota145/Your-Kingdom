class_name PileLayer
extends Node2D
## Goods lying on the ground (GroundPile) and the production yards of workshops (M4b-2),
## drawn as stacks. Child of the y-sorted world.

## A yard stack sorts this far below the centre of its tile (just past the front corner of
## the building), so the building never hides it and people in front still cover it.
const YARD_SORT_SHIFT := 17.0

var _sprites: Dictionary[int, StackSprite] = {}
## Yard stacks by "<building id>:<slot>".
var _yard_sprites: Dictionary[String, StackSprite] = {}


func _init() -> void:
	y_sort_enabled = true


func update_view(piles: Dictionary[int, GroundPile]) -> void:
	for id: int in _sprites.keys():
		if not piles.has(id):
			_sprites[id].queue_free()
			_sprites.erase(id)
	for pile: GroundPile in piles.values():
		var sprite: StackSprite = _sprites.get(pile.id)
		if sprite == null:
			sprite = StackSprite.new()
			sprite.position = IsoMath.tile_center_screen(pile.tile)
			add_child(sprite)
			_sprites[pile.id] = sprite
		var visual := StockpileLayout.visual_for(pile.stock, 0)
		sprite.show_stack(visual["good"], visual["fill_stage"])


## Stacks of every production yard, on the front tiles of its building.
func update_yards(buildings: BuildingStore) -> void:
	var seen: Dictionary[String, bool] = {}
	for building: BuildingState in buildings.all():
		var yard := building.yard
		if yard == null or yard.total_amount() == 0:
			continue
		var tiles := yard_tiles(building)
		for slot: int in yard.slot_count():
			var visual := StockpileLayout.visual_for(yard, slot)
			if visual["good"] == &"":
				continue
			var key := "%d:%d" % [building.id, slot]
			seen[key] = true
			var sprite: StackSprite = _yard_sprites.get(key)
			if sprite == null:
				sprite = StackSprite.new()
				add_child(sprite)
				_yard_sprites[key] = sprite
			sprite.position = IsoMath.tile_center_screen(tiles[slot % tiles.size()]) \
					+ Vector2(0.0, YARD_SORT_SHIFT)
			sprite.show_stack(visual["good"], visual["fill_stage"], YARD_SORT_SHIFT)
	for key: String in _yard_sprites.keys():
		if not seen.has(key):
			_yard_sprites[key].queue_free()
			_yard_sprites.erase(key)


## Footprint tiles of [param building] nearest the camera that are no entrance: where its
## yard stacks stand.
static func yard_tiles(building: BuildingState) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for tile: Vector2i in building.tiles():
		if not building.is_entrance(tile):
			tiles.append(tile)
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x + a.y > b.x + b.y or (a.x + a.y == b.x + b.y and a.x > b.x))
	return tiles
