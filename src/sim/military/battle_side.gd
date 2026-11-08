class_name BattleSide
extends RefCounted
## One side: men by unit id, whether they ate, warships (a sea battle).

var units: Dictionary[StringName, int] = {}
var fed: bool = true
var ships: int = 0


func _init(men: Dictionary[StringName, int] = {}, has_food: bool = true, warships: int = 0) -> void:
	units = men.duplicate()
	fed = has_food
	ships = warships


func count() -> int:
	var total := 0
	for unit: StringName in units:
		total += units[unit]
	return total
