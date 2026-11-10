class_name BuyPigCommand
extends BuyAnimalCommand
## Buys one pig from the travelling merchant (M4b-2): BuyAnimalCommand for a pig.


func _init() -> void:
	super(Merchant.PIG)


func get_name() -> StringName:
	return &"buy_pig"
