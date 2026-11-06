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
## Whether farms may lay fields here (stony ground: no, M4b-3).
@export var farmable: bool = true
## Another terrain this one counts as for buildings that need it nearby (a lake is water for
## anglers and clay pits, M4b-3); empty = none.
@export var counts_as: StringName = &""
## A second map colour: this terrain with [member extra_node] on it (stony ground with a rock).
@export var extra_map_color: Color = Color(0, 0, 0, 0)
@export var extra_node: StringName = &""
## Which ships sail here (M5): 0 = none, 1 = shallow water (boats only), 2 = deep water
## (boats and cogs).
@export_range(0, 2) var sail_depth: int = 0


## Whether this terrain is [param terrain_id] or counts as it.
func is_kind(terrain_id: StringName) -> bool:
	return id == terrain_id or (counts_as != &"" and counts_as == terrain_id)


func get_kind() -> StringName:
	return &"terrain"
