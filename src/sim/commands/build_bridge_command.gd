class_name BuildBridgeCommand
extends Command
## Orders a timber or stone bridge over a river, ford or lake (B1, GDD §5.4): dragged from one
## bank to the other in one of 8 directions, 3 planks or 4 stones a tile, laid by a builder
## from the near bank (ProvinceSim.bridge_plan). All of it or nothing.

var from: Vector2i
var to: Vector2i
## TileGrid.TIMBER_BRIDGE or TileGrid.STONE_BRIDGE.
var bridge: int


func _init(from_tile: Vector2i, to_tile: Vector2i, kind: int = TileGrid.TIMBER_BRIDGE) -> void:
	from = from_tile
	to = to_tile
	bridge = kind


func validate(sim: Simulation) -> StringName:
	if bridge != TileGrid.TIMBER_BRIDGE and bridge != TileGrid.STONE_BRIDGE:
		return &"bad_bridge"
	return sim.province.bridge_plan(from, to)["error"]


func apply(sim: Simulation) -> void:
	var tiles: Array[Vector2i] = []
	tiles.assign(sim.province.bridge_plan(from, to)["tiles"])
	sim.province.order_bridge(tiles, bridge)


func get_name() -> StringName:
	return &"build_bridge"
