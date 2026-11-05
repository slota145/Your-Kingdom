class_name BuildStep
extends TaskStep
## Walks to the construction site, starts the current phase when its materials are there
## (using them up) and hammers until the phase is done. Ends when the phase is finished or
## there is nothing to do, so the builder can pick the next site.


func run(province: ProvinceSim, agent: Agent, _def: StepDef) -> Status:
	var bb := agent.task.bb
	var site := province.sites.get(int(bb.get("site", 0))) as ConstructionSite
	if site == null:
		agent.activity = &"idle"
		return Status.DONE
	var building := province.buildings.get_building(site.building_id)
	var status := Movement.walk(province, agent, building.entrance_tile())
	if status != Status.DONE:
		return status
	if not site.phase_started:
		if not site.has_phase_materials():
			agent.activity = &"idle"
			return Status.DONE
		Construction.start_phase(province, site)
	if not bb.has("_faced"):
		bb["_faced"] = 1
		var center := Vector2(building.origin) + Vector2(building.def.footprint) / 2.0
		var dir := IsoMath.screen_dir(center - agent.pos)
		if dir >= 0:
			agent.facing = dir
	agent.activity = &"build"
	site.work_left -= 1
	if site.work_left <= 0:
		Construction.finish_phase(province, site)
		agent.activity = &"idle"
		return Status.DONE
	return Status.RUNNING
