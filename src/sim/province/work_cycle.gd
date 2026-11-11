class_name WorkCycle
extends RefCounted
## What one work cycle of a building's recipe takes and gives, read from its steps (M6, the
## simplified mode of ARCHITECTURE §7.1): inputs, outputs, the main output measured by the
## ProductionLog, the time spent working and the walks it needs. Built once per BuildingDef.

## Pseudo outputs measured for cycles that make no good: a sapling planted, a round served.
const SERVED := &"serve"

static var _cache: Dictionary[StringName, WorkCycle] = {}

## Goods fetched per cycle (they are used up by it).
var inputs: Dictionary[StringName, int] = {}
## Goods made per cycle.
var outputs: Dictionary[StringName, int] = {}
## The output whose units the ProductionLog measures; &"" = nothing measured.
var primary: StringName = &""
## Units of [member primary] per cycle.
var primary_amount: int = 1
## Seconds of work (work steps, field work) per cycle.
var work_seconds: float = 0.0
## Walks to a storage and back per cycle (fetches and the delivery).
var trips: int = 0
## Resource node gathered (trees, rocks, shoals); &"" = none.
var gather: StringName = &""
## Gathered by ship (a fishing wharf's boat).
var by_sea: bool = false
## Sapling planted (a forester); &"" = none.
var plants: StringName = &""
## Works fields (a farm).
var fields: bool = false
## Hunting (E2 part 2): each cycle takes one animal of a wild herd in the work radius.
var hunts: bool = false
## A service: goods it uses up per round and seconds a round keeps the service going.
var serves: Dictionary[StringName, int] = {}
var serve_hold: float = 0.0


static func of(def: BuildingDef, data: DataRegistry) -> WorkCycle:
	if _cache.has(def.id):
		return _cache[def.id]
	var cycle := WorkCycle.new()
	if def.recipe != null:
		cycle._read(def, data)
	_cache[def.id] = cycle
	return cycle


## Whether a worker of this cycle makes or does anything the simplified mode counts.
func is_productive() -> bool:
	return primary != &""


func _read(def: BuildingDef, data: DataRegistry) -> void:
	for step: StepDef in def.recipe.steps:
		if step is FetchStepDef:
			var fetch := step as FetchStepDef
			inputs[fetch.good] = inputs.get(fetch.good, 0) + fetch.amount
			trips += 1
		elif step is WorkStepDef:
			work_seconds += (step as WorkStepDef).duration
		elif step is ProduceStepDef:
			var produce := step as ProduceStepDef
			_add_output(produce.output, produce.amount)
		elif step is FieldStepDef:
			var field := step as FieldStepDef
			fields = true
			work_seconds += field.plow_time + field.sow_time + field.harvest_time + field.bind_time
			_add_output(field.harvest_good, field.harvest_amount)
		elif step is HuntStepDef:
			var hunt := step as HuntStepDef
			hunts = true
			work_seconds += hunt.aim_time + hunt.pick_time
		elif step is GoToStepDef and (step as GoToStepDef).target == &"resource":
			_gather_from((step as GoToStepDef).resource, data)
		elif step is SailStepDef and (step as SailStepDef).target == &"shoal":
			by_sea = true
			_gather_from((step as SailStepDef).resource, data)
		elif step is PlantStepDef:
			plants = (step as PlantStepDef).sapling
		elif step is ServeStepDef:
			var serve := step as ServeStepDef
			serves = serve.consume.duplicate()
			serve_hold = serve.hold
		elif step is DeliverStepDef:
			trips += 1
	if primary == &"" and plants != &"":
		primary = plants
	if primary == &"" and serve_hold > 0.0:
		primary = SERVED


func _gather_from(node_id: StringName, data: DataRegistry) -> void:
	gather = node_id
	var node := data.get_resource_node(node_id)
	if node != null:
		_add_output(node.good, node.per_gather)


func _add_output(good: StringName, amount: int) -> void:
	outputs[good] = outputs.get(good, 0) + amount
	if primary == &"":
		primary = good
		primary_amount = amount
