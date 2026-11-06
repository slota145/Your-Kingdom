class_name NeedDef
extends GameDef
## Something a household needs (GDD §3.2): a good it consumes or a service in range.

## &"good": consumed from the house supply; &"service": a building of [member service] in range.
@export_enum("good", "service") var kind: String = "good"
## Any of these goods satisfies the need (kind good).
@export var goods: Array[StringName] = []
## Building id providing the service (kind service), e.g. &"well".
@export var service: StringName = &""
## Units eaten per resident per minute of game time (kind good).
@export_range(0.0, 10.0) var per_resident_per_minute: float = 0.0
## Happiness points while satisfied; the sum of all needs of a level is 100.
@export_range(0, 100) var weight: int = 0
## Basic needs block upgrades and make the house decline when unmet.
@export var is_basic: bool = true
## An extra need (wine, M6 part 3): not counted in the level's 100 points; while met it adds
## its weight to happiness (still at most 100) and [member tax_bonus] to the tax.
@export var extra: bool = false
@export_range(0.0, 2.0) var tax_bonus: float = 0.0


func get_kind() -> StringName:
	return &"need"


func is_service() -> bool:
	return kind == "service"
