class_name BuildingDef
extends GameDef
## Animals one pen tile holds (Z1, owner's survey 2026-11-10).
const PEN_ANIMALS := 2
## A placeable building. Visual data lives separately in data/visuals (ARCHITECTURE §3.3).

## Handcarts the player can buy for this storage's porters (M4b-3, GDD §5.2).
@export_range(0, 9) var max_carts: int = 0

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
## Storage only: each slot holds this many times a good's stack size (E1, owner 2026-11-10:
## the stockpile and harbour stores hold twice as much, so a town needs fewer of them).
@export_range(1, 4) var stack_multiplier: int = 1
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
## Built only in a province with this rare resource (a vineyard: vines, M6 part 3).
@export var needs_rare: StringName = &""
## Stands only in a province with this trait (ProvinceDef.TRAITS, ROADMAP E3); empty = anywhere.
@export var needs_trait: StringName = &""
## Each worker runs the recipe on his own (the stone pit's three stonecutters, E3): the
## simplified mode's estimate counts a cycle per worker, not one for the whole building.
@export var parallel_work: bool = false
## Fields on this terrain grow [member field_bonus] times as fast (vines on vine soil).
@export var field_bonus_terrain: StringName = &""
@export_range(1.0, 4.0) var field_bonus: float = 1.0
## Seconds a sown field tile needs to ripen.
@export_range(0.0, 3600.0) var field_grow_time: float = 0.0
## Path length (cost units) a service reaches from the entrance; 0 = no service.
@export_range(0, 128) var service_radius: int = 0
## The service reaches houses only while its workers keep serving goods (a tavern needs beer
## and mead, see ServeStepDef); false = always while finished.
@export var service_needs_supply: bool = false
## Non-empty for houses: level 1, 2... (GDD §3.3).
@export var house_levels: Array[HouseLevelDef] = []
## Market (M4b-2): goods its stallholders bring from storages to the stalls; householders in
## its range buy them there instead of going to a storage. Empty = no stalls.
@export var stall_goods: Array[StringName] = []
## Live animals the building keeps and breeds (a pigsty, M4b-2): its herd is a store of
## this good that anybody may take from, never below [member herd_keep]. Empty = none.
@export var herd_good: StringName = &""
## Animals the herd holds at most.
@export_range(0, 99) var herd_capacity: int = 0
## Animals always left for breeding (owner's decision 2026-11-05: the last 2 pigs stay). The
## default of the per-building setting (BuildingState.herd_keep, Z1: the player may raise it).
@export_range(0, 99) var herd_keep: int = 2
## Pen tiles the building may own (Z1, animal pens): placed like field tiles within
## [member work_radius]; each holds [member pen_animals] animals, so the herd's room is
## pens × pen_animals.
## 0 = the old herd inside the building ([member herd_capacity]).
@export_range(0, 64) var max_pens: int = 0
## Animals one pen tile holds (Z1: 2 pigs or sheep; a horse needs a tile of its own, owner's
## decision 2026-11-10).
@export_range(1, 8) var pen_animals: int = PEN_ANIMALS
## The work of a cycle goes faster with a bigger herd (Z1 part 2: the shepherd shears wool;
## owner's survey 2026-11-10): see BuildingState.work_factor. No animals, no work.
@export var herd_work: bool = false
## Hive tiles the building may own (Z1 part 3, an apiary): placed like field tiles within
## [member work_radius]; the beekeeper goes from hive to hive, and the more hives, the faster
## the honey (BuildingState.work_factor). 0 = none.
@export_range(0, 64) var max_hives: int = 0
## Seconds for one young animal with 2 in the herd; a bigger herd breeds faster (the time is
## divided by half the herd). Breeding needs at least 2 animals and a worker at work.
@export_range(1.0, 3600.0) var breed_time: float = 90.0
## Which sides have doors (M4b-1.5, owner's decision): &"one" (only the door the player
## turns), &"opposite" (also the side across, so it can face a road on either side),
## &"all" (every side). Empty = by kind: houses one, storages all, the rest opposite.
## People need only one door with free ground in front of it.
@export var door_sides: StringName = &""
## Footprint tiles (as drawn) that stand on the sea (M5): a pier, a slipway. They must be
## sea water, the others land. Empty = a building on land.
@export var water_tiles: Array[Vector2i] = []
## Footprint tile (as drawn, relative to the origin) left free in the art, where the stack of
## the production yard grows (review fix 2026-11-07). (-1, -1) = the tile beside the entrance
## along the door's wall, towards the back (yard_at).
@export var yard_tile: Vector2i = Vector2i(-1, -1)
## Water tile (as drawn, relative to the origin, outside the footprint) where this building's
## ships moor or are launched; (-1, -1) = none.
@export var berth: Vector2i = Vector2i(-1, -1)
## The berth needs a fairway to deep water (cogs, M5): shipyards and ports.
@export var berth_fairway: bool = false
## Ship kinds the player can order here (a shipyard, M5).
@export var ship_kinds: Array[StringName] = []
## Kind of ship this building's workers use (a fishing wharf's boat, M5); empty = none.
@export var uses_ship: StringName = &""
## Port (M5 part 2): slots of the quay yard where goods wait to be loaded onto a ship or to
## go to a storage. A private store: only requests that name the port bring or take goods.
@export_range(0, 16) var quay_slots: int = 0
## Port: the quay tile (as drawn) at the foot of the gangway to a ship moored at the berth;
## dockers walk from the entrance over the quay to it, then up the gangway. (-1, -1) = none.
@export var gangway: Vector2i = Vector2i(-1, -1)
## May stand on a quay (N1): harbour buildings, on their water tiles or their land tiles.
@export var on_quay: bool = false
## Stands only on a quay, every tile (a mooring, N1).
@export var quay_only: bool = false
## May stand with one edge row of its tiles over shallow water, on piles (B1 part 2, owner's
## survey 2026-11-08: the angler's hut, the clay pit, the crane and the port warehouse):
## shallow sea, a lake or a river, never deep sea; the door on the land side.
@export var stilts_row: bool = false
## Has no dockers of its own: those of the nearest port within Harbour.SERVE_RADIUS carry
## its cargo (a mooring, N1). Needs such a port to be placed.
@export var served_by_port: bool = false

## Stands only on a stone quay, every tile (a bollard, P2 part 1).
@export var stone_quay_only: bool = false
## Has no quay yard of its own: its cargo goes to and comes from the nearest port warehouse
## within Harbour.SERVE_RADIUS, or any storage when there is none (a bollard, P2 part 1;
## owner's decision 2026-11-09: no warehouse needed to place it).
@export var uses_port_storage: bool = false
## People walk over its tiles (a bollard on the quay, P2 part 1).
@export var walk_through: bool = false
## How many edge rows may stand over the water on piles (with stilts_row; P2 part 1, owner's
## request: harbour buildings further out on the water). At most footprint - 1.
@export_range(1, 3) var stilts_rows: int = 1

## A cargo crane (N1 part 2) when > 0: the berth of a port or a mooring must lie within this
## many tiles (Chebyshev) of the footprint; its workers lift cargo between that berth's quay
## yard and the moored ship (Cranes).
@export_range(0, 8) var crane_reach: int = 0

## At most one per province (the pioneer camp, M5 part 3; owner's decision 2026-11-06).
@export var unique: bool = false

## M7: other work cycles the player may switch to (a blacksmith: spears or swords). The
## first is usually [member recipe]; empty = only [member recipe].
@export var recipe_choices: Array[RecipeDef] = []
## Animals a finished building's herd starts with (a stud farm's pair of horses, M7). With
## pens (Z1) the pair comes when the first pen tile is placed.
@export_range(0, 99) var herd_start: int = 0
## Resource node that must lie within [member work_radius] of the footprint (a mine needs
## an ore vein, M7); empty = none.
@export var needs_node_near: StringName = &""
## Storage only: good categories it takes (an armoury: weapons, M7). Empty = every category
## but those some storage of the data lists (weapons go only to an armoury).
@export var storage_accepts: Array[StringName] = []
## Barracks (M7): beds for soldiers; > 0 makes the building a barracks.
@export_range(0, 99) var soldier_beds: int = 0
## Fortification (M7 part 2): &"gatehouse" (a passage through its middle column, along its
## doors, open to its owner) or &"tower". Its tiles join stone walls and carry a wall-walk.
## &"palisade_gate" (M7 part 3, owner's request): a wooden gate in a palisade, a passage like
## a gatehouse's, without a wall-walk.
@export var fort_kind: StringName = &""
## Life of the building in a fight (M7 part 2): gatehouse, tower, the door of a town hall.
## 0 = cannot be attacked.
@export_range(0, 99999) var max_hp: int = 0
## Siege workshop (M7 part 2): the engines (unit ids) it builds on order.
@export var siege_engines: Array[StringName] = []


func is_fort() -> bool:
	return fort_kind != &""


func is_gatehouse() -> bool:
	return fort_kind == &"gatehouse"


## A gate of either kind: a gatehouse or a palisade gate (a passage open to its owner).
func is_gate() -> bool:
	return fort_kind == &"gatehouse" or fort_kind == &"palisade_gate"


## Whether its tiles are stone mass with a wall-walk (gatehouse, tower; not a palisade gate).
func has_crown() -> bool:
	return is_fort() and fort_kind != &"palisade_gate"


## Tiles of the gatehouse passage (relative to the origin) turned to [param orientation]: the
## line through its entrance along its door.
func passage_at(orientation: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if walk_through:
		for y: int in footprint.y:
			for x: int in footprint.x:
				result.append(Vector2i(x, y))
		return result
	if not is_gate():
		return result
	var e := entrance_at(orientation)
	var d := door_dir(orientation)
	for y: int in footprint.y:
		for x: int in footprint.x:
			var t := Vector2i(x, y)
			if (d.x != 0 and t.y == e.y) or (d.y != 0 and t.x == e.x):
				result.append(t)
	return result


func get_kind() -> StringName:
	return &"building"


## The recipe and its choices, each once.
func all_recipes() -> Array[RecipeDef]:
	var result: Array[RecipeDef] = []
	if recipe != null:
		result.append(recipe)
	for choice: RecipeDef in recipe_choices:
		if choice != null and not result.has(choice):
			result.append(choice)
	return result


func worker_count() -> int:
	return worker_kinds.size()


func is_house() -> bool:
	return not house_levels.is_empty()


## Whether its workers plant trees (a forester): the player may mark where.
func plants_trees() -> bool:
	if recipe == null:
		return false
	for step: StepDef in recipe.steps:
		if step is PlantStepDef:
			return true
	return false


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


## The doors of the building turned to [param orientation], each given as the orientation
## whose main door it is (entrance_at, door_dir, door_front); the main door first.
func door_orientations(orientation: int) -> Array[int]:
	var sides := door_sides
	if sides == &"":
		sides = &"one" if is_house() else (&"all" if storage_slots > 0 else &"opposite")
	match sides:
		&"all":
			return [orientation, (orientation + 1) % 4, (orientation + 2) % 4, (orientation + 3) % 4]
		&"opposite":
			return [orientation, (orientation + 2) % 4]
	return [orientation]


## A tile given relative to the origin as drawn, for the building turned to
## [param orientation] (like entrance_at; also for tiles outside the footprint).
func turned(tile: Vector2i, orientation: int) -> Vector2i:
	var n := footprint.x - 1
	match orientation:
		1:
			return Vector2i(tile.y, tile.x)
		2:
			return Vector2i(n - tile.x, n - tile.y)
		3:
			return Vector2i(n - tile.y, n - tile.x)
	return tile


## The yard tile (relative to the origin) of the building turned to [param orientation].
func yard_at(orientation: int) -> Vector2i:
	var tile := yard_tile
	if tile == Vector2i(-1, -1):
		var d := door_dir(0)
		tile = entrance - Vector2i(d.y, d.x)
	return turned(tile, orientation)


func is_on_water() -> bool:
	return not water_tiles.is_empty()


func has_berth() -> bool:
	return berth != Vector2i(-1, -1)


## Footprint tiles on the sea for a building at [param origin] turned to [param orientation].
func water_tiles_at(origin: Vector2i, orientation: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for tile: Vector2i in water_tiles:
		tiles.append(origin + turned(tile, orientation))
	return tiles


func berth_at(origin: Vector2i, orientation: int) -> Vector2i:
	return origin + turned(berth, orientation)


## A harbour storage (port warehouse of any size, P2): where a bollard's cargo waits.
func is_port_storage() -> bool:
	return storage_slots > 0 and category == &"harbour"


## A house of dockers (P2 part 1): dockers who are not a port's own; they serve every dock and
## harbour storage within Harbour.SERVE_RADIUS.
func is_docker_house() -> bool:
	return not is_port() and worker_kinds.has(&"docker")


## Whether ships moored here are loaded and unloaded over a gangway (a port, M5 part 2).
func is_port() -> bool:
	return gangway != Vector2i(-1, -1) and has_berth()


func gangway_at(origin: Vector2i, orientation: int) -> Vector2i:
	return origin + turned(gangway, orientation)


func is_entrance_on_edge() -> bool:
	var inside: bool = entrance.x >= 0 and entrance.y >= 0 \
			and entrance.x < footprint.x and entrance.y < footprint.y
	var on_edge: bool = entrance.x == 0 or entrance.y == 0 \
			or entrance.x == footprint.x - 1 or entrance.y == footprint.y - 1
	return inside and on_edge


## Whether the herd lives in pen tiles placed by the player (Z1).
func has_pens() -> bool:
	return max_pens > 0 and herd_good != &""


## Tiles of the field kind the building may own: fields of a farm, pens of a herd or hives of
## an apiary (Z1).
func field_limit() -> int:
	if max_fields > 0:
		return max_fields
	return max_pens if max_pens > 0 else max_hives


## Whether the building keeps hives on hive tiles (Z1 part 3).
func has_hives() -> bool:
	return max_hives > 0


## Pen or hive tiles (Z1): tiles of the field kind that are not fields of a farm.
func has_tiles() -> bool:
	return has_pens() or has_hives()


## The work of a cycle goes faster with a bigger herd or more hives (Z1).
func paced_work() -> bool:
	return herd_work or has_hives()
