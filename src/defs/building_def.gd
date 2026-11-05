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
## Number of stockpile slots; > 0 makes the building a storage (GDD §4.2).
@export_range(0, 64) var storage_slots: int = 0
## Work cycle of the workers; null for buildings without production.
@export var recipe: RecipeDef
## How far (tiles, from the entrance) workers look for resource nodes.
@export_range(0, 64) var work_radius: int = 0


func get_kind() -> StringName:
	return &"building"


## Footprint tiles in grid space for a building placed at [param origin].
func footprint_tiles(origin: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y: int in footprint.y:
		for x: int in footprint.x:
			tiles.append(origin + Vector2i(x, y))
	return tiles


func is_entrance_on_edge() -> bool:
	var inside: bool = entrance.x >= 0 and entrance.y >= 0 \
			and entrance.x < footprint.x and entrance.y < footprint.y
	var on_edge: bool = entrance.x == 0 or entrance.y == 0 \
			or entrance.x == footprint.x - 1 or entrance.y == footprint.y - 1
	return inside and on_edge
