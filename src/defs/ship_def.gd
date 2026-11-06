class_name ShipDef
extends GameDef
## A kind of ship (GDD §5.4, M5): where it sails, how fast, what it holds and what a shipyard
## needs to build it. Visual data lives in assets/ships/<id>/ (ART_SPEC).

## Sails only on deep water and fairways (a cog); false = shallow water too (a boat).
@export var deep_only: bool = false
## Tiles per second.
@export_range(0.1, 10.0) var speed: float = 1.5
## Hold: slots and units per slot.
@export_range(1, 16) var hold_slots: int = 1
@export_range(1, 99) var hold_stack: int = 8
## Goods a shipyard needs, split evenly between the stages (like construction phases).
@export var build_cost: Dictionary[StringName, int] = {}
## Shipwright work in seconds for the whole ship, split evenly between the stages.
@export_range(1.0, 3600.0) var build_time: float = 60.0
## Visible building stages on the slipway (frame, planking, mast with sail...).
@export_range(1, 8) var stages: int = 2
## Goods of each stage when they are not split evenly (the cog, M5 part 3: the frame takes
## planks, the planking planks and tar, the mast cloth for the sail, the launch tar); one
## dictionary per stage, summing to [member build_cost]. Empty = split evenly.
@export var stage_goods: Array[Dictionary] = []
## A trading ship of the player (the cog, M5 part 3): it has a home port, waits at anchor
## and sails on trade voyages over the horizon (Voyage).
@export var trades: bool = false


func get_kind() -> StringName:
	return &"ship"


## Goods used by stage [param stage] (0-based): the cost split as evenly as possible, earlier
## stages taking the remainder.
func stage_cost(stage: int) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	if stage < stage_goods.size():
		for good: Variant in stage_goods[stage]:
			result[StringName(String(good))] = int(stage_goods[stage][good])
		return result
	for good: StringName in build_cost:
		var total := build_cost[good]
		var amount := total / stages + (1 if stage < total % stages else 0)
		if amount > 0:
			result[good] = amount
	return result


## Hold capacity in units.
func capacity() -> int:
	return hold_slots * hold_stack
