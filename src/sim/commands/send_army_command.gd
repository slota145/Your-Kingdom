class_name SendArmyCommand
extends Command
## The player sends his army from the world map to a province (M7 part 3): through land
## neighbours, or by sea on its warships.

var army_id: int
var target: int


func _init(army: int, to: int) -> void:
	army_id = army
	target = to


func validate(sim: Simulation) -> StringName:
	return Armies.send_error(sim, sim.world.armies.get(army_id) as Army, target)


func apply(sim: Simulation) -> void:
	Armies.send(sim, sim.world.armies[army_id], target)


func get_name() -> StringName:
	return &"send_army"
