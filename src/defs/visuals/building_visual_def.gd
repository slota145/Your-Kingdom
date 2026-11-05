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
## Number of looks of the "base" art: "base", "base_2", "base_3"... Each building picks one
## by its position, so a village of huts is not a row of copies.
@export_range(1, 8) var base_variants: int = 1
## Number of looks of each town-house row piece (gable shapes, M4b-1.5): "<piece>",
## "<piece>_2"... picked by position along the row, so neighbours differ.
@export_range(1, 8) var row_variants: int = 1
## Work spot name -> pixel offset from the entrance tile centre where the worker is drawn.
@export var spot_offsets: Dictionary[StringName, Vector2] = {}


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


static func for_building(id: StringName) -> BuildingVisualDef:
	var path := "res://data/visuals/buildings/%s.tres" % id
	return load(path) as BuildingVisualDef if ResourceLoader.exists(path) else null
