class_name ResearchDef
extends GameDef
## A research of the kingdom (ROADMAP E4 part 2, owner's surveys 2026-11-11): studied in a school
## (or, from part 3, a university) for gold and time. It unlocks buildings and ships, or
## improves the work of some buildings in every province of the player.

const SCHOOL := &"school"
const UNIVERSITY := &"university"

## Where it is studied: SCHOOL or UNIVERSITY.
@export var institution: StringName = SCHOOL
## Column in the research tree: 1 basic (cheap and quick) .. 3 advanced (owner 2026-11-11).
@export_range(1, 5) var tier: int = 1
## Row in its column of the tree.
@export_range(0, 20) var row: int = 0
## Gold paid when the research starts.
@export_range(0, 99999) var gold_cost: int = 150
## Seconds of study with one teacher at work (two schools: half).
@export_range(1.0, 7200.0) var time: float = 120.0
## Researches that must be done first (the arrows of the tree).
@export var requires: Array[StringName] = []
## Buildings and ships it unlocks (none of them can be built before).
@export var buildings: Array[StringName] = []
@export var ships: Array[StringName] = []
## Units recruited in barracks (E4 part 3: swordsmen, knights...) and building tools (the stone
## wall: &"stone_wall") it unlocks.
@export var units: Array[StringName] = []
@export var tools: Array[StringName] = []
## Buildings whose work it improves, and how.
@export var affects: Array[StringName] = []
## More field, pen or hive tiles (BuildingDef.field_limit).
@export_range(0, 64) var extra_fields: int = 0
## A longer work radius (the forester plants farther).
@export_range(0, 16) var extra_radius: int = 0
## Work steps take 1 / work_speed of their time (1.25 = 25% faster).
@export_range(1.0, 4.0) var work_speed: float = 1.0
## Units a porter carries more (all porters, not [member affects]).
@export_range(0, 4) var porter_load: int = 0
## Units a handcart carries more (E4 part 3).
@export_range(0, 4) var cart_load: int = 0
## Unlocks the charter of farms and herds (E4 part 3, "Nadanie": fields and pens ×2, a second
## worker; switched per building).
@export var charter: bool = false


func get_kind() -> StringName:
	return &"research"


## An improvement (porters, fields, speed) rather than an unlock.
func is_upgrade() -> bool:
	return extra_fields > 0 or extra_radius > 0 or work_speed > 1.0 or porter_load > 0 or cart_load > 0 \
			or charter
