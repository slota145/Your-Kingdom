class_name SendArmyCommand
extends Command
## The player sends his army (or fleet) on the world map (M7 part 3, M8 part 2): to the town of
## a province (through the land, or by sea on its warships), to any spot of the map (an army
## over the land, a fleet over the sea; it stops there), or after an enemy army.

var army_id: int
## The province whose town it goes to; 0 with [member spot] or [member enemy].
var target: int
var spot: Vector2 = Vector2.INF
var enemy: int = 0


func _init(army: int, to: int = 0) -> void:
	army_id = army
	target = to


## To a spot of the world map (parchment pixels).
static func to_spot(army: int, at: Vector2) -> SendArmyCommand:
	var command := SendArmyCommand.new(army)
	command.spot = Vector2(SimCodec.savable(at.x), SimCodec.savable(at.y))
	return command


## After the enemy army [param enemy_id].
static func after(army: int, enemy_id: int) -> SendArmyCommand:
	var command := SendArmyCommand.new(army)
	command.enemy = enemy_id
	return command


func validate(sim: Simulation) -> StringName:
	var army := sim.world.armies.get(army_id) as Army
	if enemy != 0:
		return ArmyOrders.chase_error(sim, army, enemy)
	if target != 0:
		return Armies.send_error(sim, army, target)
	if spot == Vector2.INF:
		return &"no_way"
	return ArmyOrders.order_error(sim, army, 0, spot)


func apply(sim: Simulation) -> void:
	var army := sim.world.armies[army_id]
	if enemy != 0:
		ArmyOrders.order_chase(sim, army, enemy)
	else:
		ArmyOrders.order(sim, army, target, spot)


func get_name() -> StringName:
	return &"send_army"
