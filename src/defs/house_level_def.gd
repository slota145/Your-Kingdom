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
## Need id -> happiness points on this level, overriding NeedDef.weight (needs are shared
## between levels, but each level's weights sum to 100).
@export var need_weights: Dictionary[StringName, int] = {}
## Different kinds of food the diet need asks for (E2 part 3: peasants 1, burghers 2,
## patricians 3); each kind more adds DIET_TAX_BONUS to the house's tax.
@export_range(0, 9) var diet_min: int = 1
## Gold per resident per minute at full happiness and the normal tax rate (GDD §3.5).
@export_range(0.0, 100.0) var tax_per_minute: float = 0.0


func get_kind() -> StringName:
	return &"house_level"


func weight_of(need: NeedDef) -> int:
	return need_weights.get(need.id, need.weight)
