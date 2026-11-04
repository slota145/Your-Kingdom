class_name BuildingDef
extends GameDef
## A placeable building. Visual data lives separately in data/visuals (ARCHITECTURE §3.3).

## Build menu category, e.g. &"housing", &"food", &"resources".
@export var category: StringName = &""
## Size in tiles (grid space).
@export var footprint: Vector2i = Vector2i(2, 2)
## Entrance tile, relative to the footprint origin; must lie on the footprint edge.
@export var entrance: Vector2i = Vector2i(1, 1)
## Goods required to construct: good id -> amount.
@export var build_cost: Dictionary[StringName, int] = {}
## Number of worker slots.
@export_range(0, 64) var workers: int = 0


func get_kind() -> StringName:
	return &"building"


func is_entrance_on_edge() -> bool:
	var inside: bool = entrance.x >= 0 and entrance.y >= 0 \
			and entrance.x < footprint.x and entrance.y < footprint.y
	var on_edge: bool = entrance.x == 0 or entrance.y == 0 \
			or entrance.x == footprint.x - 1 or entrance.y == footprint.y - 1
	return inside and on_edge
