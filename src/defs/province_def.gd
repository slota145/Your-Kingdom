class_name ProvinceDef
extends GameDef
## One province of a hand-made world (ROADMAP M6): which map template it is played on, its
## riches, its rare resource, who owns it at the start and where it lies on the world map.

## Who holds a province (WorldSim.owner_of): nobody, the player or a neutral settlement.
const OWNER_NONE := &""
const OWNER_PLAYER := &"player"
const OWNER_NEUTRAL := &"neutral"

## Province map template (a MapDef id): riverlands, lakeland, coast (islands in part 2).
@export var template: StringName = &""
## The template is mirrored (part 2: variants of templates).
@export var mirrored: bool = false
## Wealth of raw materials 1-3 (GDD §2.1): forests, rocks, shoals and fertile fields.
@export_range(1, 3) var richness: int = 2
## Rare resource marked on the world map (iron_ore, salt, vines, horses); empty = none.
@export var rare_resource: StringName = &""
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


func get_kind() -> StringName:
	return &"province"
