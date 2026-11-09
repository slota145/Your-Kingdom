class_name BattleSide
extends RefCounted
## One side: men by unit id, whether they ate, warships (a sea battle).

var units: Dictionary[StringName, int] = {}
var fed: bool = true
var ships: int = 0
## The warships by ship id (J1 part 3): their hp, bolts and room come from their ShipDef. Empty:
## [member ships] equal warships of the starting values (BattleResolver.SHIP_*).
var fleet: Dictionary[StringName, int] = {}


func _init(men: Dictionary[StringName, int] = {}, has_food: bool = true, warships: int = 0) -> void:
	units = men.duplicate()
	fed = has_food
	ships = warships


func count() -> int:
	var total := 0
	for unit: StringName in units:
		total += units[unit]
	return total
