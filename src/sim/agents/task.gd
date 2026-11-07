class_name Task
extends RefCounted
## A running sequence of steps (ARCHITECTURE §5.2). The step list is rebuilt from data on
## load; only the kind, the step index and the blackboard are saved.

const KIND_RECIPE := &"recipe"
const KIND_TRANSPORT := &"transport"
## Carrying goods left over from a failed task to a storage (or the ground).
const KIND_STASH := &"stash"
## A builder working at a construction site (bb "site").
const KIND_BUILD := &"build"
## A householder fetching goods for the pantry (bb "good", "amount", "to").
const KIND_ERRAND := &"errand"
## A newcomer walking to their new house (agent.home_id).
const KIND_MOVE_IN := &"move_in"
## The travelling merchant's visit (M4b-2, ProvinceSim.merchant).
const KIND_MERCHANT := &"merchant"
## A carter taking his wagon back to the stable, or walking to it (M4b-3).
const KIND_PARK := &"park"
## A worker aboard a ship whose trip ended at sea sailing it home (M5).
const KIND_SAIL_HOME := &"sail_home"
## A settler wading ashore from the ship that brought him (M5 part 3, bb "from", "to", "t").
const KIND_LAND := &"land"
## Walking (or driving the settlers' wagon) to a tile for an expedition of settlers (M6 part 2,
## bb "to"; "wait": stand until the expedition sets off; "leave": vanish on arrival, gone with
## the expedition).
const KIND_TRAVEL := &"travel"

## A recruit fetching his gear and walking to the barracks (M7, bb "unit", "picks": source
## and reservation id pairs, one per gear good in sorted order, "pick": goods taken so far).
const KIND_ENLIST := &"enlist"
## A soldier at his barracks: drilling on the parade ground or resting inside (M7).
const KIND_SOLDIER := &"soldier"

var kind: StringName
## Recipe id for KIND_RECIPE.
var recipe_id: StringName = &""
## TransportRequest id for KIND_TRANSPORT.
var request_id: int = 0
var step_index: int = 0
## Step-local and shared values (targets, reservation ids, timers). JSON-safe values only.
var bb: Dictionary = {}
var steps: Array[StepDef] = []


func current_step() -> StepDef:
	return steps[step_index] if step_index < steps.size() else null


func to_dict() -> Dictionary:
	return {"kind": String(kind), "recipe": String(recipe_id), "request": request_id,
			"step": step_index, "bb": bb.duplicate(true)}


static func from_dict(d: Dictionary) -> Task:
	var task := Task.new()
	task.kind = StringName(String(d["kind"]))
	task.recipe_id = StringName(String(d.get("recipe", "")))
	task.request_id = int(d.get("request", 0))
	task.step_index = int(d.get("step", 0))
	task.bb = _ints_back(d.get("bb", {}))
	return task


## JSON turns ints into floats; blackboard values are ints, strings or arrays of ints.
static func _ints_back(d: Dictionary) -> Dictionary:
	var result := {}
	for key: Variant in d:
		var v: Variant = d[key]
		if v is float:
			result[String(key)] = int(v)
		elif v is Array:
			result[String(key)] = SimCodec.int_array(v)
		else:
			result[String(key)] = v
	return result
