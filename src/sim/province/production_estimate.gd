class_name ProductionEstimate
extends RefCounted
## How much a building makes and uses per minute (ROADMAP UI-3 part 1): the time of one work
## cycle from its recipe (work, walks to a storage, the way to a tree or a herd, crops
## growing), the same estimate the simplified mode works with (ARCHITECTURE §7.1). The build
## menu shows it for a full crew; the building panel next to what the building really made.


## Seconds of one work cycle of [param def]: the work (sped up by [param work_speed], slowed or
## sped by [param work_factor] for a flock or hives), [param walk] tiles to a storage and back
## for every fetch and delivery, the way out to a tree, rock, herd or sapling spot and back,
## sailing for a boat, and for a farm the grow time shared by its [param field_count] field
## tiles. INF for a farm without fields. [param trips] (-1 = the cycle's own) counts the walks.
static func cycle_seconds(def: BuildingDef, cycle: WorkCycle, walk: float, work_speed: float = 1.0,
		work_factor: float = 1.0, field_count: int = 0, trips: int = -1) -> float:
	var work := cycle.work_seconds / work_speed
	if def.paced_work():
		work *= work_factor
	var walks := cycle.trips if trips < 0 else trips
	var seconds := work + walks * 2.0 * walk / Movement.BASE_SPEED
	var reach := 2.0 * maxf(def.work_radius / 2.0, 1.0) / Movement.BASE_SPEED
	if cycle.hunts:
		seconds += reach
	if cycle.gather != &"" and not cycle.by_sea:
		seconds += reach
	if cycle.by_sea:
		seconds += ProvinceAbstract.SAIL_SECONDS
	if cycle.plants != &"":
		seconds += reach
	if cycle.fields:
		# One field tile gives a harvest every grow time plus its jobs; a farmer works one at a
		# time (see ProvinceAbstract.estimated_cycle_seconds).
		if field_count <= 0:
			return INF
		seconds = maxf(seconds, (def.field_grow_time + cycle.work_seconds) / field_count)
	return maxf(seconds, 1.0)


## Units per minute of [param def] at full crew, all its fields, hives or a full flock, a
## storage [constant ProvinceAbstract.DEFAULT_WALK] tiles away: {"made": {good: float},
## "used": {good: float}}. Both empty for a building without a work cycle of goods (houses,
## storages, saplings planted).
static func full_crew(def: BuildingDef, data: DataRegistry, work_speed: float = 1.0) -> Dictionary:
	var made: Dictionary[StringName, float] = {}
	var used: Dictionary[StringName, float] = {}
	var cycle := WorkCycle.of(def, data)
	if def.recipe == null:
		return {"made": made, "used": used}
	var factor := 1.0
	if def.has_hives():
		factor = sqrt(BuildingState.HIVE_WORK_BASE / float(maxi(def.max_hives, 1)))
	elif def.herd_work:
		factor = sqrt(BuildingState.HERD_WORK_BASE / float(maxi(def.herd_capacity, 1)))
	# A workshop's worker puts what he made on the yard by the door (M4b-2, UI-2 part 2):
	# that delivery is no walk to a storage.
	var trips := cycle.trips
	if not BuildingState.yard_goods(def, data).is_empty():
		for step: StepDef in def.recipe.steps:
			if step is DeliverStepDef:
				trips -= 1
	var seconds := cycle_seconds(def, cycle, ProvinceAbstract.DEFAULT_WALK, work_speed, factor,
			def.field_limit(), maxi(trips, 0))
	if is_inf(seconds):
		return {"made": made, "used": used}
	var workers := def.worker_kinds.size() if def.parallel_work else 1
	var per_minute := workers * 60.0 / seconds
	for good: StringName in cycle.outputs:
		if data.get_good(good) != null:
			made[good] = cycle.outputs[good] * per_minute
	var uses: Dictionary[StringName, int] = cycle.inputs.duplicate()
	for good: StringName in cycle.serves:
		uses[good] = uses.get(good, 0) + cycle.serves[good]
	# A hunter cuts up the game he shot himself: nothing from the storages.
	if not cycle.hunts:
		for step: StepDef in def.recipe.steps:
			if step is ProduceStepDef:
				var consume := (step as ProduceStepDef).consume
				for good: StringName in consume:
					uses[good] = uses.get(good, 0) + consume[good]
	for good: StringName in uses:
		if data.get_good(good) != null:
			used[good] = uses[good] * per_minute
	return {"made": made, "used": used}
