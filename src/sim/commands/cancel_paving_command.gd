class_name CancelPavingCommand
extends Command
## Cancels the cobbles ordered on [member tiles] and not laid yet (review fix 2026-11-07): the
## road stays a dirt road; stone already brought stays with the site, and lands on the ground
## when the site has nothing left to lay. Quay orders are cancelled by RemoveQuayCommand.

var tiles: Array[Vector2i]


func _init(tile_list: Array[Vector2i]) -> void:
	tiles = tile_list


func validate(sim: Simulation) -> StringName:
	for tile: Vector2i in tiles:
		if sim.province.cancel_paving_error(tile) == &"":
			return &""
	return &"not_paving"


func apply(sim: Simulation) -> void:
	for tile: Vector2i in tiles:
		if sim.province.cancel_paving_error(tile) == &"":
			sim.province.cancel_paving(tile)


func get_name() -> StringName:
	return &"cancel_paving"
