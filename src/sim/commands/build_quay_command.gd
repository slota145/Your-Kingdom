class_name BuildQuayCommand
extends Command
## Orders a timber pier or a stone quay on sea tiles (N1, GDD §5.4): 2 planks or 3 stones a
## tile, laid by a builder from the shore outwards (ProvinceSim.quay_plan). Tiles that cannot
## take a quay are skipped; the command is rejected only when none can.

var tiles: Array[Vector2i]
## TileGrid.PIER or TileGrid.STONE_QUAY.
var quay: int


func _init(quay_tiles: Array[Vector2i], kind: int = TileGrid.PIER) -> void:
	tiles = quay_tiles
	quay = kind


func validate(sim: Simulation) -> StringName:
	if quay != TileGrid.PIER and quay != TileGrid.STONE_QUAY:
		return &"bad_quay"
	var plan := sim.province.quay_plan(tiles)
	if not (plan["tiles"] as Array).is_empty():
		return &""
	var errors: Dictionary = plan["errors"]
	return errors.values()[0] if not errors.is_empty() else &"no_tiles"


func apply(sim: Simulation) -> void:
	var plan := sim.province.quay_plan(tiles)
	var accepted: Array[Vector2i] = []
	accepted.assign(plan["tiles"])
	sim.province.order_quay(accepted, quay)


func get_name() -> StringName:
	return &"build_quay"
