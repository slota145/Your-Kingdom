class_name SetBuyUpToCommand
extends Command
## Sets how much of a good the sea merchant may sell to the kingdom (M5 part 2): while the
## kingdom holds less than [member amount], dockers unload his goods. 0 or less stops buying.

var good: StringName
var amount: int


func _init(good_id: StringName, units: int) -> void:
	good = good_id
	amount = units


func validate(sim: Simulation) -> StringName:
	if sim.data.get_good(good) == null:
		return &"unknown_good"
	if not SeaMerchant.OFFER.has(good):
		return &"not_offered"
	if amount > SeaMerchant.MAX_BUY_UP_TO:
		return &"invalid_value"
	return &""


func apply(sim: Simulation) -> void:
	var trader := sim.province.sea_merchant
	if amount <= 0:
		trader.buy_up_to.erase(good)
	else:
		trader.buy_up_to[good] = amount
	sim.events.emit(&"buy_up_to_changed", {"good": good, "amount": amount})


func get_name() -> StringName:
	return &"set_buy_up_to"
