class_name DisbandArmyCommand
extends Command
## The player's army standing in his province goes into its barracks (M7 part 3).

var army_id: int


func _init(army: int) -> void:
	army_id = army


func validate(sim: Simulation) -> StringName:
	return Armies.disband_error(sim, sim.world.armies.get(army_id) as Army)


func apply(sim: Simulation) -> void:
	Armies.disband_home(sim, sim.world.armies[army_id])


func get_name() -> StringName:
	return &"disband_army"
