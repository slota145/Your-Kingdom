class_name PileLayer
extends Node2D
## Goods lying on the ground (GroundPile), drawn as stacks. Child of the y-sorted world.

var _sprites: Dictionary[int, StackSprite] = {}


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
