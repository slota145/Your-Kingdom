class_name GoodDef
extends GameDef
## A tradeable, carryable good (wood, grain, bread...).

## Grouping used by UI and needs, e.g. &"building_material", &"food".
@export var category: StringName = &""
## How a person carries it; selects the walk_carry_<category> animation (ART_SPEC §4.3).
@export_enum("sack", "crate", "barrel", "log", "basket", "bundle", "stone")
var carry_category: String = "crate"
## Units per stockpile slot.
@export_range(1, 999) var stack_size: int = 20
## Reference price in gold for trade.
@export_range(0, 9999) var base_price: int = 1
## Rare goods exist only in some provinces.
@export var is_rare: bool = false


func get_kind() -> StringName:
	return &"good"


## Localization keys for counted amounts ("5 chlebów"); used with translate_plural.
func count_key() -> String:
	return "good.%s.count" % id


func count_plural_key() -> String:
	return "good.%s.count_plural" % id
