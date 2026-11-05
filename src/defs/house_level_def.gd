class_name HouseLevelDef
extends GameDef
## One level of a house (GDD §3.1, §3.3): who lives there, what they need, how it grows.

@export_range(1, 3) var level: int = 1
@export_range(1, 64) var capacity: int = 4
@export var needs: Array[NeedDef] = []
## Units of each needed good the house keeps (its small pantry).
@export_range(1, 99) var supply_units: int = 3
## Goods delivered to reach this level from the one below (empty for level 1).
@export var upgrade_cost: Dictionary[StringName, int] = {}
## Builder work, in seconds, to finish the upgrade once the goods are there.
@export_range(0.0, 600.0) var upgrade_time: float = 0.0


func get_kind() -> StringName:
	return &"house_level"
