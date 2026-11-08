class_name WorldDef
extends GameDef
## A hand-made world of provinces (ROADMAP M6): the provinces in their world-map order, the
## one the player starts in and the size of the parchment the world map is drawn on.

@export var provinces: Array[StringName] = []
## The province the player lands in at the start (by ship, like the "Coast" map).
@export var start_province: StringName = &""
## World map size in parchment pixels (ProvinceDef.world_pos and outline use it).
@export var size: Vector2 = Vector2(1200, 800)
## World-map distance a cog covers per second of game time (journeys between ports).
@export var ship_speed: float = 2.5
## World-map distance a wagon covers per second of game time (journeys to a neighbour).
@export var wagon_speed: float = 1.4
## Speed of an army on foot (world units per second; M7 part 3).
@export var army_speed: float = 1.1
## Province the bandits' camp stands in at the start (M7 part 3); empty = no bandits.
@export var bandit_camp: StringName = &""


func get_kind() -> StringName:
	return &"world"
