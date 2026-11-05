class_name SetSellAboveCommand
extends Command
## Sets what the travelling merchant may buy of a good (M4b-2): everything the storages hold
## above [member amount]. A negative amount stops selling the good.

var good: StringName
var amount: int


func _init(good_id: StringName, units: int) -> void:
	good = good_id
	amount = units


func validate(sim: Simulation) -> StringName:
	var def := sim.data.get_good(good)
	if def == null:
		return &"unknown_good"
	if def.is_live():
		return &"not_for_sale"
	if amount > Merchant.MAX_SELL_ABOVE:
		return &"invalid_value"
	return &""


func apply(sim: Simulation) -> void:
	var merchant := sim.province.merchant
	if amount < 0:
		merchant.sell_above.erase(good)
		if merchant.wagon != null:
			sim.province.jobs.set_amount(good, 0, merchant.wagon_id, 0)
	else:
		merchant.sell_above[good] = amount
	sim.events.emit(&"sell_above_changed", {"good": good, "amount": amount})


func get_name() -> StringName:
	return &"set_sell_above"
