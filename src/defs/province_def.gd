class_name ProvinceDef
extends GameDef
## One province of a hand-made world (ROADMAP M6): which map template it is played on, its
## riches, its rare resource, who owns it at the start and where it lies on the world map.

## Who holds a province (WorldSim.owner_of): nobody, the player or a neutral settlement.
const OWNER_NONE := &""
const OWNER_PLAYER := &"player"
const OWNER_NEUTRAL := &"neutral"
## Province traits (ROADMAP E3, owner's survey 2026-11-11): endless sources and richer land,
## apart from the rare resource. A province with iron ore as its rare resource is rich in iron.
const RICH_STONE := &"rich_stone"
const RICH_IRON := &"rich_iron"
const TRAITS: Array[StringName] = [RICH_STONE, RICH_IRON]

## Province map template (a MapDef id): riverlands, lakeland, coast (islands in part 2).
@export var template: StringName = &""
## The template is mirrored (part 2: variants of templates).
@export var mirrored: bool = false
## Wealth of raw materials 1-3 (GDD §2.1): forests, rocks, shoals and fertile fields.
@export_range(1, 3) var richness: int = 2
## Rare resource marked on the world map (iron_ore, salt, vines, horses); empty = none.
@export var rare_resource: StringName = &""
## Traits of the province (TRAITS) besides the one its rare resource gives (all_traits()).
@export var traits: Array[StringName] = []
## Owner at the start of a new game: OWNER_NONE, OWNER_PLAYER or OWNER_NEUTRAL.
@export var owner: StringName = &""
## Provinces sharing a land border (wagons and settlers on foot go only there).
@export var neighbours: Array[StringName] = []
## Has a coast reached by ships (cogs sail between coastal provinces).
@export var coastal: bool = false
## An island: reached only by ship.
@export var island: bool = false
## Where the town lies on the world map, in parchment pixels (WorldDef.size).
@export var world_pos: Vector2 = Vector2.ZERO
## The province border on the world map, in parchment pixels.
@export var outline: PackedVector2Array = PackedVector2Array()
## A generated province's name (M8): translation keys of its words (GeneratedNames).
@export var name_parts: PackedStringArray = PackedStringArray()
## A generated province's description: translation keys of its parts (by its map template).
@export var desc_parts: PackedStringArray = PackedStringArray()

@export_group("Neutral settlement (M6 part 3)")
## Buildings of the neutral town (building id -> count), placed by NeutralTown.
@export var town_buildings: Dictionary[StringName, int] = {}
## How many of the town's houses are burgher houses (the rest peasant houses).
@export var town_burghers: int = 0
## The first demand for joining the kingdom: gold, goods (good -> units) and minutes to give
## them in (NeutralSettlement).
@export var demand_gold: int = 0
@export var demand_goods: Dictionary[StringName, int] = {}
@export var demand_minutes: float = 20.0
## Defences (M7 part 3): the ring around the town centre (Walls.NONE, PALISADE or STONE, with a
## gatehouse), towers on it, and the guards (unit id -> men).
@export_range(0, 2) var town_wall: int = 0
@export_range(0, 4) var town_towers: int = 0
@export var town_guards: Dictionary[StringName, int] = {}


## The traits of the province: its own and rich_iron where iron ore is its rare resource.
func all_traits() -> Array[StringName]:
	return traits_of(traits, rare_resource)


## [param own] traits and the one rare resource [param rare] gives, in TRAITS order.
static func traits_of(own: Array[StringName], rare: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for t: StringName in TRAITS:
		if own.has(t) or (t == RICH_IRON and rare == &"iron_ore"):
			result.append(t)
	return result


## The own traits of [param def]; none without a def (a single-province game).
static func own_traits(def: ProvinceDef) -> Array[StringName]:
	var none: Array[StringName] = []
	return def.traits if def != null else none


func get_kind() -> StringName:
	return &"province"
