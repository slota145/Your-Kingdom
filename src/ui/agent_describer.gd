class_name AgentDescriber
extends RefCounted
## What a person is doing, in the player's language, derived from the same state the view
## animates (activity, current step, carried good), so the text matches what is seen.


## "Baker: bakes bread (60%)".
static func describe(province: ProvinceSim, agent: Agent) -> String:
	return "%s: %s" % [kind_name(agent.kind), doing(province, agent)]


static func kind_name(kind: StringName) -> String:
	return TranslationServer.translate(StringName("ui.kind.%s" % kind))


static func doing(province: ProvinceSim, agent: Agent) -> String:
	var task := agent.task
	if task == null:
		if agent.cooldown > 0 and agent.last_fail == &"no_source" and agent.last_fail_good != &"":
			return _f("ui.doing.waiting_for", [_good(agent.last_fail_good)])
		if agent.cooldown > 0 and agent.last_fail == &"kept_for_building" and agent.last_fail_good != &"":
			return _f("ui.doing.kept_for_building", [_good(agent.last_fail_good)])
		if agent.cooldown > 0 and agent.last_fail != &"":
			return _f("ui.doing.waiting", [TranslationServer.translate(
					StringName("ui.reason.%s" % agent.last_fail))])
		var workplace := province.buildings.get_building(agent.workplace_id)
		if workplace != null and workplace.paused:
			return _t("ui.doing.paused")
		return _t("ui.doing.idle")
	var step := task.current_step()
	var walking := agent.path_state == Agent.PathState.MOVING or agent.path_state == Agent.PathState.WAITING
	if not walking and agent.activity != &"idle" and agent.activity != &"walk":
		return _with_progress(_t("ui.activity.%s" % agent.activity), task, step)
	if task.kind == Task.KIND_MOVE_IN:
		return _f("ui.doing.move_in", [_building_name(province, agent.home_id)])
	if task.kind == Task.KIND_BUILD and province.paving.has(int(task.bb.get("site", 0))):
		return _t("ui.doing.go_pave")
	if task.kind == Task.KIND_BUILD:
		var site := province.sites.get(int(task.bb.get("site", 0))) as ConstructionSite
		return _f("ui.doing.go_build", [_building_name(province, site.building_id if site != null else 0)])
	if step is FetchStepDef:
		var good := StringName(String(task.bb.get("good", (step as FetchStepDef).good)))
		return _f("ui.doing.fetch", [_good(good)])
	if step is DeliverStepDef:
		if task.bb.has("_yard_full"):
			return _t("ui.doing.yard_full")
		if not agent.is_carrying():
			return _t("ui.doing.idle")
		var to := int(task.bb.get("_dst", task.bb.get("to", 0)))
		return _f("ui.doing.deliver", [_good(agent.carry_good), _storage_name(province, to)])
	if step is GoToStepDef:
		var go := step as GoToStepDef
		if go.target == &"shore":
			return _t("ui.doing.go_to_shore")
		if go.target == &"plant_spot":
			return _t("ui.doing.go_plant")
		if go.target == &"resource":
			return _f("ui.doing.go_to", [TranslationServer.translate(
					StringName("resource_node.%s.name" % go.resource))])
		return _t("ui.doing.go_to_work")
	if step is FieldStepDef:
		return _t("ui.doing.go_to_field")
	return _t("ui.doing.walk")


static func _with_progress(text: String, task: Task, step: StepDef) -> String:
	var total := 0
	if step is WorkStepDef:
		total = SimClock.seconds_to_ticks((step as WorkStepDef).duration)
	elif step is FieldStepDef:
		var field := step as FieldStepDef
		var seconds: float = {"plow": field.plow_time, "sow": field.sow_time,
				"harvest": field.harvest_time, "bind": field.bind_time}.get(String(task.bb.get("_action", "")), 0.0)
		total = SimClock.seconds_to_ticks(seconds) if seconds > 0.0 else 0
	if total > 0 and task.bb.has("_work_left"):
		var done := clampf(1.0 - float(task.bb["_work_left"]) / total, 0.0, 1.0)
		return "%s (%d%%)" % [text, roundi(done * 100.0)]
	return text


static func _storage_name(province: ProvinceSim, id: int) -> String:
	if province.sites.has(id):
		return _f("ui.doing.site_of", [_building_name(province, province.sites[id].building_id)])
	if province.paving.has(id):
		return _t("ui.doing.paving")
	if province.piles.has(id):
		return _t("ui.doing.ground")
	if id < 0:
		return _t("ui.doing.yard")
	return _building_name(province, id)


static func _building_name(province: ProvinceSim, id: int) -> String:
	var building := province.buildings.get_building(id)
	if building == null:
		return "?"
	if building.house != null:
		return TranslationServer.translate(StringName(building.level_def().name_key()))
	return TranslationServer.translate(StringName(building.def.name_key()))


static func _good(good: StringName) -> String:
	return TranslationServer.translate(StringName("good.%s.name" % good))


static func _t(key: String) -> String:
	return TranslationServer.translate(StringName(key))


static func _f(key: String, args: Array) -> String:
	return _t(key) % args
