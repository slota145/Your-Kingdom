class_name ResourceNodeDef
extends GameDef
## Something on a map tile that workers gather goods from, e.g. a tree giving logs.

## Good obtained by gathering.
@export var good: StringName = &""
## Total amount in a fresh node; when it runs out the node is depleted (a stump).
@export_range(1, 99) var amount: int = 3
## Amount taken by one gathering action (one trip).
@export_range(1, 99) var per_gather: int = 1
## Whether a non-depleted node blocks movement.
@export var solid: bool = true
## Walking cost of the tile while the node stands on it (a forest slows people down, M4b-2);
## 0 = the terrain's cost.
@export_range(0.0, 10.0) var move_cost: float = 0.0
## The last gathering also takes what is left (the stump of a tree goes with the last log),
## so the tile becomes free ground (owner decision 2026-11-05).
@export var remove_when_depleted: bool = false
## A young node (a sapling) turns into this node id after [member grow_time]; empty = never.
@export var grows_into: StringName = &""
## Seconds of game time until the node grows into [member grows_into].
@export_range(0.0, 3600.0) var grow_time: float = 0.0


func get_kind() -> StringName:
	return &"resource_node"
## Terrain the tile turns into when the node is used up (a quarried rock leaves stony ground,
## M4b-3); empty = unchanged.
@export var leaves_terrain: StringName = &""
## Seconds to grow back one unit while below [member amount] (a fish shoal, M5); 0 = never.
## Every node of the kind regrows on the same ticks, so no timer is saved.
@export_range(0.0, 3600.0) var regrow_time: float = 0.0
