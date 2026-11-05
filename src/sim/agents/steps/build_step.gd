class_name BuildStep
extends TaskStep
## Walks to the construction site, starts the current phase when its materials are there
## (using them up) and hammers until the phase is done. Ends when the phase is finished or
## there is nothing to do, so the builder can pick the next site. On a paving site (M4b-3)
## he walks onto the next tile and lays its cobbles.


func run(province: ProvinceSim, agent: Agent, _def: StepDef) -> Status:
	var bb := agent.task.bb
	var paving_site := province.paving.get(int(bb.get("site", 0))) as PavingSite
	if paving_site != null:
		return _pave(province, agent, paving_site)
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


## One tile at a time: the task ends after each tile, so a building site placed meanwhile
## gets the builder first.
func _pave(province: ProvinceSim, agent: Agent, paving_site: PavingSite) -> Status:
	var bb := agent.task.bb
	var tile := paving_site.next_tile()
	# Saved as two numbers: a Vector2i in the blackboard would not survive JSON.
	if not bb.has("_tx"):
		if not paving_site.is_workable():
			agent.activity = &"idle"
			return Status.DONE
		bb["_tx"] = tile.x
		bb["_ty"] = tile.y
	elif Vector2i(int(bb["_tx"]), int(bb["_ty"])) != tile:
		# The tile was taken off the order (road removed): start over with the next one.
		agent.activity = &"idle"
		return Status.DONE
	var status := Movement.walk(province, agent, tile)
	if status != Status.DONE:
		return status
	if paving_site.stock.available(PavingSite.GOOD) < PavingSite.STONE_PER_TILE:
		agent.activity = &"idle"
		return Status.DONE
	agent.activity = &"build"
	paving_site.work_left -= 1
	if paving_site.work_left <= 0:
		province.pave_next(paving_site)
		agent.activity = &"idle"
		return Status.DONE
	return Status.RUNNING
