class_name BuildingDef
extends GameDef
## A placeable building. Visual data lives separately in data/visuals (ARCHITECTURE §3.3).

## Build menu category, e.g. &"housing", &"food", &"resources".
@export var category: StringName = &""
## Size in tiles (grid space).
@export var footprint: Vector2i = Vector2i(2, 2)
## Entrance tile, relative to the footprint origin; must lie on the footprint edge.
@export var entrance: Vector2i = Vector2i(1, 1)
## Goods required to construct: good id -> amount. Half of each (rounded up) is used by
## construction phase 1, the rest by phase 2 (ROADMAP M3 decisions).
@export var build_cost: Dictionary[StringName, int] = {}
## Builder work in seconds for the whole construction, split evenly between the 2 phases.
@export_range(0.0, 3600.0) var build_time: float = 20.0
## Gold paid when the building is placed (GDD §3.5); 0 = free.
@export_range(0, 9999) var gold_cost: int = 0
## One entry per worker slot: the profession of whoever fills it (&"miller", &"porter").
@export var worker_kinds: Array[StringName] = []
## Lower values are staffed first when free residents are handed out (town hall = 0).
@export_range(0, 9) var staffing_priority: int = 5
## Number of stockpile slots; > 0 makes the building a storage (GDD §4.2).
@export_range(0, 64) var storage_slots: int = 0
## Storage only: units of a good construction deliveries leave in place (the player can change
## it per storage). Keeps firewood for houses when sites want wood (ROADMAP M4 decisions).
@export var default_reserves: Dictionary[StringName, int] = {}
## Goods a workshop keeps in a small private input store (a recipe with two inputs).
@export var input_goods: Array[StringName] = []
## Work cycle of the workers; null for buildings without production.
@export var recipe: RecipeDef
## How far (tiles, Chebyshev from the footprint) workers look for resource nodes and fields.
@export_range(0, 64) var work_radius: int = 0
## Terrain id that must lie within [member work_radius] of the footprint (an angler needs
## water); empty = anywhere.
@export var needs_terrain_near: StringName = &""
## Field tiles a farm may own (placed separately, 1x1 each).
@export_range(0, 64) var max_fields: int = 0
## Seconds a sown field tile needs to ripen.
@export_range(0.0, 3600.0) var field_grow_time: float = 0.0
## Path length (cost units) a service reaches from the entrance; 0 = no service.
@export_range(0, 128) var service_radius: int = 0
## The service reaches houses only while its workers keep serving goods (a tavern needs beer
## and mead, see ServeStepDef); false = always while finished.
@export var service_needs_supply: bool = false
## Non-empty for houses: level 1, 2... (GDD §3.3).
@export var house_levels: Array[HouseLevelDef] = []


func get_kind() -> StringName:
	return &"building"


func worker_count() -> int:
	return worker_kinds.size()


func is_house() -> bool:
	return not house_levels.is_empty()


## Goods used by construction phase [param phase] (1 or 2).
func phase_cost(phase: int) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for good: StringName in build_cost:
		var first := ceili(build_cost[good] / 2.0)
		var amount := first if phase == 1 else build_cost[good] - first
		if amount > 0:
			result[good] = amount
	return result


## Footprint tiles in grid space for a building placed at [param origin].
func footprint_tiles(origin: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for y: int in footprint.y:
		for x: int in footprint.x:
			tiles.append(origin + Vector2i(x, y))
	return tiles


## How many ways the building can be turned (GDD §5.1, M4b-1.5): houses 4 (door on any
## side; 2 and 3 show the back to the camera), other buildings 2 (as drawn and mirrored, so
## the work always faces the camera). Footprints are square, so turning never moves tiles.
func orientation_count() -> int:
	return 4 if is_house() else 2


## Entrance tile (relative to the origin) of the building turned to [param orientation]:
## 0 = as drawn, 1 = mirrored (x and y swapped), 2 = turned half round, 3 = both.
func entrance_at(orientation: int) -> Vector2i:
	var n := footprint.x - 1
	match orientation:
		1:
			return Vector2i(entrance.y, entrance.x)
		2:
			return Vector2i(n - entrance.x, n - entrance.y)
		3:
			return Vector2i(n - entrance.y, n - entrance.x)
	return entrance


## Grid step out of the door of the building turned to [param orientation]. As drawn
## (0) the door is on the side of the entrance tile that lies on the footprint edge, the
## +x side (screen right) winning at a corner, like the art (ART_SPEC §3.2).
func door_dir(orientation: int) -> Vector2i:
	var d := Vector2i(0, 1)
	if entrance.x == footprint.x - 1:
		d = Vector2i(1, 0)
	elif entrance.y == footprint.y - 1:
		d = Vector2i(0, 1)
	elif entrance.x == 0:
		d = Vector2i(-1, 0)
	elif entrance.y == 0:
		d = Vector2i(0, -1)
	match orientation:
		1:
			return Vector2i(d.y, d.x)
		2:
			return -d
		3:
			return -Vector2i(d.y, d.x)
	return d


## The tile just outside the door: people walk in and out of the building only through it.
func door_front(origin: Vector2i, orientation: int) -> Vector2i:
	return origin + entrance_at(orientation) + door_dir(orientation)


func is_entrance_on_edge() -> bool:
	var inside: bool = entrance.x >= 0 and entrance.y >= 0 \
			and entrance.x < footprint.x and entrance.y < footprint.y
	var on_edge: bool = entrance.x == 0 or entrance.y == 0 \
			or entrance.x == footprint.x - 1 or entrance.y == footprint.y - 1
	return inside and on_edge
