class_name SetGoodsLimitCommand
extends Command
## Sets the player's limit of a good in the province (E5): once the kingdom holds
## [member amount] units, workshops and gatherers making it stop until the stock drops below.
## A negative amount removes the limit.

const MAX_LIMIT := 999

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
		return &"not_limited"
	if amount > MAX_LIMIT:
		return &"invalid_value"
	return &""


func apply(sim: Simulation) -> void:
	if amount < 0:
		sim.province.goods_limits.erase(good)
	else:
		sim.province.goods_limits[good] = amount
	sim.events.emit(&"goods_limit_changed", {"good": good, "amount": amount})


func get_name() -> StringName:
	return &"set_goods_limit"
