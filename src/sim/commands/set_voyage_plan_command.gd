class_name SetVoyagePlanCommand
extends Command
## Sets one line of the voyage plan of the player's cog (M5 part 3, port panel): units of a
## good to sell over the horizon ([member order] false) or to order from the sea merchant's
## offer ([member order] true). 0 removes the line. Each list must fit into the hold.

var ship_id: int
var good: StringName
var amount: int
var order: bool


func _init(ship: int, good_id: StringName, units: int, is_order: bool = false) -> void:
	ship_id = ship
	good = good_id
	amount = units
	order = is_order


func validate(sim: Simulation) -> StringName:
	var ship := sim.province.ships.get(ship_id) as ShipUnit
	if ship == null or ship.voyage == null:
		return &"unknown_ship"
	if sim.data.get_good(good) == null:
		return &"unknown_good"
	if amount < 0:
		return &"invalid_value"
	if order and not SeaMerchant.OFFER.has(good):
		return &"not_offered"
	if not order and not Voyage.can_sell(sim.province, good):
		return &"cannot_sell"
	var plan: Dictionary = (ship.voyage.order if order else ship.voyage.sell).duplicate()
	plan[good] = amount
	if Voyage.slots_needed(plan, ship.hold) > ship.def.hold_slots:
		return &"hold_full"
	return &""


func apply(sim: Simulation) -> void:
	var voyage := (sim.province.ships[ship_id] as ShipUnit).voyage
	var plan := voyage.order if order else voyage.sell
	if amount == 0:
		plan.erase(good)
	else:
		plan[good] = amount
	sim.events.emit(&"voyage_plan_changed", {"ship": ship_id, "good": good, "amount": amount,
			"order": order})


func get_name() -> StringName:
	return &"set_voyage_plan"
