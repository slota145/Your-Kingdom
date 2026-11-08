class_name UnitDef
extends GameDef
## A kind of soldier (GDD §6.2, M7): what a recruit takes from the armoury (and the stud
## farm), what the barracks charge and how he fights. Starting values: ROADMAP M7.

## Goods handed to the recruit: good id -> units (a spear; a sword and a mail shirt; a horse).
@export var gear: Dictionary[StringName, int] = {}
## Gold paid for the recruitment.
@export_range(0, 9999) var gold_cost: int = 10
## Combat (used from M7 part 2 on): life, damage of one blow or arrow, seconds between
## attacks, reach in tiles (1 = melee) and walking speed against a civilian.
@export var combat: CombatStatsDef
## Order in the barracks panel and in a drill rank (lower first).
@export_range(0, 9) var order: int = 0
## Siege engine (M7 part 2): &"ram" (breaks walls and gates, never fights people) or
## &"ladder" (a ladderman: leans his ladder on a stone wall). Built in a siege workshop, not
## recruited in the barracks.
@export var siege: StringName = &""
## Siege engines: materials the workshop needs, residents who man it, work time (s).
@export var build_cost: Dictionary[StringName, int] = {}
@export_range(0, 9) var crew: int = 0
@export_range(0.0, 600.0) var build_time: float = 0.0


func get_kind() -> StringName:
	return &"unit"
