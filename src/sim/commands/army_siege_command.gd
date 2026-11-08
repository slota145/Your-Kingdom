class_name ArmySiegeCommand
extends Command
## The player's army at a neutral settlement (M7 part 3): fight in the province's view
## (ENTER: the player goes in with it) or let BattleResolver decide at once (AUTO).

const ENTER := &"enter"
const AUTO := &"auto"

var army_id: int
var mode: StringName


func _init(army: int, how: StringName) -> void:
	army_id = army
	mode = how


func validate(sim: Simulation) -> StringName:
	if mode != ENTER and mode != AUTO:
		return &"bad_order"
	return Armies.siege_error(sim, sim.world.armies.get(army_id) as Army)


func apply(sim: Simulation) -> void:
	var army := sim.world.armies[army_id]
	if mode == ENTER:
		Armies.enter_fight(sim, army)
	else:
		Armies.resolve_siege(sim, army)


func get_name() -> StringName:
	return &"army_siege"
