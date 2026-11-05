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


func get_kind() -> StringName:
	return &"resource_node"
