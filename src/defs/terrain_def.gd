class_name TerrainDef
extends GameDef
## Ground type of a map tile (GDD §5.2): how fast people walk on it and whether it can be built on.

## Index stored per tile in TileGrid; 0 is the default terrain. Stable, saved.
@export_range(0, 254) var index: int = 0
@export var walkable: bool = true
## Path cost multiplier: > 1 is slower (forest), < 1 faster.
@export_range(0.1, 10.0) var move_cost: float = 1.0
@export var buildable: bool = true
## Pixel colour of this terrain in map images (data/maps/*.png).
@export var map_color: Color = Color.BLACK
## Resource node placed on every tile of this terrain when a map is loaded (forest -> tree).
@export var resource_node: StringName = &""


func get_kind() -> StringName:
	return &"terrain"
