class_name BuildingVisualDef
extends Resource
## How a building looks (ARCHITECTURE §3.3): which art folder, per-level art, and where
## workers are drawn while working at a named spot. Not a GameDef: the simulation never
## reads it. File: data/visuals/buildings/<building id>.tres.

## Folder under buildings/ (ART_SPEC §2) with base, site_1, site_2 and level art.
@export var art_id: String = ""
## Art name per house level (index 0 = level 1). Empty = always "base".
@export var level_art: Array[String] = []
## From this house level on, neighbours of the same level join into a row
## (art "<level art>_<single|end_a|middle|end_b>_<x|y>"); 0 = never.
@export_range(0, 3) var row_from_level: int = 0
## Drawn as an open yard with stacks instead of a box (stockpiles).
@export var yard: bool = false
## People inside the footprint stand on open ground (a pen): they are drawn over the
## building's art and do not fade out as at a door (owner feedback 2026-11-06: swineherds
## and porters vanished under the pigsty's pens).
@export var open_ground: bool = false
## Number of looks of the "base" art: "base", "base_2", "base_3"... Each building picks one
## by its position, so a village of huts is not a row of copies.
@export_range(1, 8) var base_variants: int = 1
## Number of looks of each town-house row piece (gable shapes, M4b-1.5): "<piece>",
## "<piece>_2"... picked by position along the row, so neighbours differ.
@export_range(1, 8) var row_variants: int = 1
## Harbour buildings (N1): which water tiles (as drawn) are drawn as the shared quay strip
## that joins the player's quays (QuayLayer). Empty = all of BuildingDef.water_tiles; a
## shipyard leaves its slipway out.
@export var quay_tiles: Array[Vector2i] = []
## When it stands over the water, it stands on a stone quay under its whole footprint (land
## part too), not on a timber deck, so it joins a stone quay beside it (the dockers' house,
## owner's request 2026-11-09).
@export var stone_strip: bool = false
## Work spot name -> pixel offset from the entrance tile centre where the worker is drawn.
## "<spot>_<n>" is the spot of the building's n-th worker (from 1), used before "<spot>".
@export var spot_offsets: Dictionary[StringName, Vector2] = {}
## Work spots out of sight (the deep mine's "below", E3 part 2): a worker there is not drawn.
@export var hidden_spots: Array[StringName] = []


## Art name of the variant of [param name] for a building at [param origin] ("base" only).
## [param look] > 0 is the look the player chose (BuildingState.look).
func variant_name(name: String, origin: Vector2i, look: int = 0) -> String:
	if name != "base" or base_variants <= 1:
		return name
	var pick := absi(origin.x * 73856093 ^ origin.y * 19349663) % base_variants
	if look > 0:
		pick = (look - 1) % base_variants
	return name if pick == 0 else "%s_%d" % [name, pick + 1]


## Art name of the look of row piece [param name] for a house at [param origin].
func row_variant_name(name: String, origin: Vector2i, look: int = 0) -> String:
	if row_variants <= 1:
		return name
	# Houses are 2 tiles wide: consecutive houses along a row get consecutive looks.
	var pick := posmod((origin.x + origin.y) / 2 + absi(origin.x * 7 - origin.y * 3) / 2, row_variants)
	if look > 0:
		pick = (look - 1) % row_variants
	return name if pick == 0 else "%s_%d" % [name, pick + 1]


## How many looks a house of [param level] can choose from (T key, house panel).
func look_count(level: int) -> int:
	if row_from_level > 0 and level >= row_from_level:
		return row_variants
	return base_variants


## Visual defs by building id, null kept too (looked up once: checking the file on disk for
## each of 400 buildings took ~80 ms, a visible stutter on every building change; review fix
## 2026-11-07).
static var _cache: Dictionary[StringName, BuildingVisualDef] = {}


static func for_building(id: StringName) -> BuildingVisualDef:
	if not _cache.has(id):
		var path := "res://data/visuals/buildings/%s.tres" % id
		_cache[id] = load(path) as BuildingVisualDef if ResourceLoader.exists(path) else null
	return _cache[id]
