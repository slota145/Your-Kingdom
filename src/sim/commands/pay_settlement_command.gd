class_name PaySettlementCommand
extends Command
## Pays the gold a neutral settlement asks for (ROADMAP M6 part 3, the world map panel): as
## much of what is still missing as the treasury has.

var province_id: int


func _init(id: int) -> void:
	province_id = id


func validate(sim: Simulation) -> StringName:
	var s := sim.world.settlements.get(province_id) as NeutralSettlement
	if s == null or s.state != NeutralSettlement.State.ASKING:
		return &"no_demand"
	if s.gold_missing() <= 0:
		return &"already_paid"
	if sim.treasury.gold <= 0:
		return &"not_enough_gold"
	return &""


func apply(sim: Simulation) -> void:
	var s := sim.world.settlements[province_id] as NeutralSettlement
	var gold := mini(s.gold_missing(), sim.treasury.gold)
	sim.treasury.pay(gold)
	s.gold_paid += gold
	sim.events.emit(&"settlement_paid", {"province": province_id, "gold": gold})


func get_name() -> StringName:
	return &"pay_settlement"
