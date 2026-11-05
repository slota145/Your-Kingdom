class_name BuyPigCommand
extends Command
## Buys one pig from the travelling merchant while he trades at the market (M4b-2): paid at
## once, then a porter leads it to the nearest pigsty with room.


func validate(sim: Simulation) -> StringName:
	return sim.province.merchant.pig_error(sim.province)


func apply(sim: Simulation) -> void:
	sim.province.merchant.buy_pig(sim.province)


func get_name() -> StringName:
	return &"buy_pig"
