class_name EnlistStep
extends TaskStep
## A recruit (M7) walks for each piece of his gear to where it was reserved for him (the
## armoury, a stud farm's herd, a workshop's yard) and takes it; with the last piece he
## changes into a soldier of his unit and walks into the barracks, where he lives from then on.
## Blackboard: "unit", "picks" (source id and reservation id per gear good, in
## Barracks.gear_goods order; 0 0 = not reserved), "pick" (pieces taken so far).
## A reservation lost on the way (a demolished armoury, a loaded game) is made again from
## the nearest source; while there is none, or no way leads there, he waits and tries again
## (the step fails only when his barracks is gone).


func run(province: ProvinceSim, agent: Agent, _def: StepDef) -> Status:
	var bb := agent.task.bb
	var barracks := province.buildings.get_building(agent.home_id)
	if barracks == null or barracks.def.soldier_beds <= 0:
		return failed(agent, &"no_barracks")
	var unit := province.data.get_unit(StringName(String(bb.get("unit", ""))))
	if unit == null:
		return failed(agent, &"unknown_unit")
	if province.tick < int(bb.get("_retry", 0)):
		return Status.RUNNING
	var goods := Barracks.gear_goods(unit)
	var pick := int(bb.get("pick", 0))
	if pick < goods.size():
		return _fetch(province, agent, unit, goods, pick)
	# All gear taken: into the barracks.
	var status := Movement.walk(province, agent, barracks.entrance_tile())
	if status == Status.FAILED:
		return _wait(province, agent)
	if status != Status.DONE:
		return status
	barracks.recruits.erase(agent.id)
	if not barracks.soldiers.has(agent.id):
		barracks.soldiers.append(agent.id)
	province.events.emit(&"soldier_enlisted", {"agent": agent.id, "barracks": barracks.id,
			"unit": unit.id})
	return Status.DONE


func _fetch(province: ProvinceSim, agent: Agent, unit: UnitDef, goods: Array[StringName],
		pick: int) -> Status:
	var bb := agent.task.bb
	var good := goods[pick]
	var amount: int = unit.gear[good]
	var picks: Array = bb.get("picks", [])
	while picks.size() < goods.size() * 2:
		picks.append(0)
	var src := int(picks[pick * 2])
	var res := int(picks[pick * 2 + 1])
	var stock := province.storage(src) if src != 0 else null
	if stock == null or not stock.has_reservation(res):
		# Reserve again from the nearest source; wait while there is none.
		agent.clear_path()
		src = province.nearest_source(good, amount, agent.tile())
		stock = province.storage(src)
		res = stock.reserve_out(good, amount, agent.id) if stock != null else 0
		if res == 0:
			picks[pick * 2] = 0
			picks[pick * 2 + 1] = 0
			bb["picks"] = picks
			agent.last_fail = &"no_gear"
			agent.last_fail_good = good
			return _wait(province, agent)
		picks[pick * 2] = src
		picks[pick * 2 + 1] = res
		bb["picks"] = picks
	var status := Movement.walk(province, agent, Carriers.stop_for(province, agent, src))
	if status == Status.FAILED:
		stock.cancel(res)
		picks[pick * 2] = 0
		picks[pick * 2 + 1] = 0
		bb["picks"] = picks
		return _wait(province, agent)
	if status != Status.DONE:
		return status
	stock.commit(res)
	province.ledger.used(good, amount, province.tick)
	province.events.emit(&"good_taken", {"agent": agent.id, "storage": src, "good": good,
			"amount": amount})
	agent.last_fail = &""
	bb["pick"] = pick + 1
	if pick + 1 >= goods.size():
		# The last piece: he puts it on and is a soldier now (GDD §6.1: he changes his looks).
		agent.carry_good = &""
		agent.carry_amount = 0
		agent.kind = unit.id
		agent.combat = CombatState.new(unit.combat.hp if unit.combat != null else 100)
		province.events.emit(&"recruit_armed", {"agent": agent.id, "unit": unit.id})
	else:
		# Carried to the next stop, so everybody sees what he got.
		agent.carry_good = good
		agent.carry_amount = amount
	agent.clear_path()
	return Status.RUNNING


static func _wait(province: ProvinceSim, agent: Agent) -> Status:
	agent.clear_path()
	agent.activity = &"idle"
	agent.task.bb["_retry"] = province.tick + Barracks.WAIT_TICKS
	return Status.RUNNING


## Finishes the walk of [param agent] at once (the province is frozen, ProvinceAbstract): the
## gear still reserved for him is taken, the rest from the nearest sources if there is any.
static func take_rest_at_once(province: ProvinceSim, agent: Agent, unit: UnitDef) -> void:
	var goods := Barracks.gear_goods(unit)
	var bb := agent.task.bb
	var picks: Array = bb.get("picks", [])
	for i: int in range(int(bb.get("pick", 0)), goods.size()):
		var stock := province.storage(int(picks[i * 2])) if i * 2 + 1 < picks.size() else null
		if stock != null and stock.has_reservation(int(picks[i * 2 + 1])):
			stock.commit(int(picks[i * 2 + 1]))
		else:
			province.take_from_storages(goods[i], unit.gear[goods[i]], agent.tile())
	agent.carry_good = &""
	agent.carry_amount = 0
