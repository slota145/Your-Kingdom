class_name BuyAnimalCommand
extends Command
## Buys one animal (a pig, a sheep or a horse, Merchant.ANIMALS) from the travelling merchant
## while he trades at the market (M4b-2, Z1 part 2): paid at once, then a porter leads it to the
## nearest pen of its kind with room.

var good: StringName


func _init(animal: StringName) -> void:
	good = animal


func validate(sim: Simulation) -> StringName:
	return sim.province.merchant.animal_error(sim.province, good)


func apply(sim: Simulation) -> void:
	sim.province.merchant.buy_animal(sim.province, good)


func get_name() -> StringName:
	return &"buy_animal"
