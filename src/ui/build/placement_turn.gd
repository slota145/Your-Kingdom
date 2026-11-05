class_name PlacementTurn
extends RefCounted
## Which way the building the player is placing is turned (GDD §5.1, M4b-1.5). The preview
## turns the door towards a road next to the building by itself; R turns it by hand, and a
## hand-picked side stays until the player picks another tool. With no road next to it the
## building keeps the side used last.

## Orientation of the building under the cursor (BuildingDef.entrance_at).
var orientation: int = 0

var _last: int = 0
var _manual: bool = false


## A new building tool was picked: the automatic choice is back on.
func begin() -> void:
	_manual = false
	orientation = _last


## The orientation for a building of [param def] at [param origin] right now.
func update(province: ProvinceSim, def: BuildingDef, origin: Vector2i) -> int:
	var count := def.orientation_count()
	if _manual:
		orientation = orientation % count
		return orientation
	var to_road := province.orientation_to_road(def, origin, _last % count)
	orientation = to_road if to_road >= 0 else _last % count
	return orientation


## R: the next side, chosen by hand.
func rotate(def: BuildingDef) -> void:
	_manual = true
	orientation = (orientation + 1) % def.orientation_count()


## The building was placed: its side is the one used when no road decides.
func placed() -> void:
	_last = orientation


func is_manual() -> bool:
	return _manual
