class_name PileLayer
extends Node2D
## Goods lying on the ground (GroundPile) and the production yards of workshops (M4b-2),
## drawn as stacks. Child of the y-sorted world.

## A herd stack (pigsty pen) sorts this far below the centre of its tile (just past the
## front corner of the building), so the building never hides it.
const HERD_SORT_SHIFT := 17.0
## Several goods on one yard tile stand this far apart along the door's wall (in tiles).
const YARD_SPREAD := 0.24

var _sprites: Dictionary[int, StackSprite] = {}
## Yard stacks by "<building id>:<slot>:<half>" (herds: half 0 only).
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
		sprite.show_stack(visual["good"], visual["amount"], visual["stack_size"])


## Stacks of every production yard: on the free yard tile beside the door (BuildingDef.yard_at),
## or on the pen tiles of a herd.
func update_yards(buildings: BuildingStore) -> void:
	var seen: Dictionary[String, bool] = {}
	for building: BuildingState in buildings.all():
		var yard := building.yard
		if yard == null or yard.total_amount() == 0:
			continue
		var herd := building.def.herd_good != &""
		var tiles: Array[Vector2i] = []
		if herd:
			tiles = herd_tiles(building)
		var spots := yard_spots(building, yard.slot_count())
		for slot: int in yard.slot_count():
			var visual := StockpileLayout.visual_for(yard, slot)
			if visual["good"] == &"":
				continue
			if herd:
				var key := "%d:%d:0" % [building.id, slot]
				seen[key] = true
				var sprite := _yard_sprite(key)
				sprite.position = IsoMath.tile_center_screen(tiles[slot % tiles.size()]) 						+ Vector2(0.0, HERD_SORT_SHIFT)
				sprite.show_stack(visual["good"], visual["amount"], visual["stack_size"], HERD_SORT_SHIFT)
				continue
			var centre := IsoMath.grid_to_screen(spots[slot])
			for half: int in 2:
				var key := "%d:%d:%d" % [building.id, slot, half]
				seen[key] = true
				var sprite := _yard_sprite(key)
				var front := IsoMath.grid_to_screen(Vector2(building.origin + building.def.footprint))
				var sort_y := yard_sort_y(front, centre.x + (half - 0.5) * IsoMath.HALF_W)
				sprite.position = Vector2(centre.x, sort_y)
				sprite.show_stack(visual["good"], visual["amount"], visual["stack_size"],
						sort_y - centre.y, half)
	for key: String in _yard_sprites.keys():
		if not seen.has(key):
			_yard_sprites[key].queue_free()
			_yard_sprites.erase(key)


func _yard_sprite(key: String) -> StackSprite:
	var sprite: StackSprite = _yard_sprites.get(key)
	if sprite == null:
		sprite = StackSprite.new()
		add_child(sprite)
		_yard_sprites[key] = sprite
	return sprite


## Ground points (grid) of the stacks of a yard of [param slots] goods: the centre of the
## yard tile, several goods spread along the door's wall.
static func yard_spots(building: BuildingState, slots: int) -> Array[Vector2]:
	var tile := building.origin + building.def.yard_at(building.orientation)
	var d := building.def.door_dir(building.orientation)
	var along := Vector2(absf(d.y), absf(d.x))
	var spots: Array[Vector2] = []
	for slot: int in slots:
		var shift := (slot - (slots - 1) * 0.5) * YARD_SPREAD * 2.0 if slots > 1 else 0.0
		spots.append(IsoMath.tile_center(tile) + along * shift)
	return spots


## Sort y of the half of a yard stack around screen column [param x]: just after the strip
## of the building drawn over those columns (BuildingSlicer), so the walls behind the yard
## never cover the stack. The art keeps those columns free in front of the yard, and people
## walking outside the building there are still drawn over the stack (test_sorting.gd).
## [param front]: screen point of the front corner of the footprint.
static func yard_sort_y(front: Vector2, x: float) -> float:
	var half_w := IsoMath.HALF_W
	var strip := floorf((x - front.x) / half_w) * half_w + half_w * 0.5
	return front.y + BuildingSlicer.front_edge_y(strip) + 1.0


## Pen tiles of a herd, nearest the camera first, entrances left out.
static func herd_tiles(building: BuildingState) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for tile: Vector2i in building.tiles():
		if not building.is_entrance(tile):
			tiles.append(tile)
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x + a.y > b.x + b.y or (a.x + a.y == b.x + b.y and a.x > b.x))
	return tiles
