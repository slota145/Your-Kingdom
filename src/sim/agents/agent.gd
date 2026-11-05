class_name Agent
extends RefCounted
## One person in a province (ARCHITECTURE §5.1). A plain object, not a node; the view picks
## the animation from activity, facing and carried good only.

enum PathState { NONE, WAITING, MOVING, ARRIVED, FAILED }

const NO_TILE := Vector2i(-1, -1)

var id: int
## Profession or type: porter, woodcutter, peasant...
var kind: StringName
var workplace_id: int = 0
## Position in grid space (tile units, float).
var pos: Vector2
## Position at the start of the last tick; the view interpolates prev_pos -> pos. Not saved.
var prev_pos: Vector2
var facing: int = IsoMath.Dir.S
var carry_good: StringName = &""
var carry_amount: int = 0
var activity: StringName = &"idle"
var task: Task
## Ticks to wait before taking a new task (after a failure).
var cooldown: int = 0
## Resource node tile claimed by this agent, NO_TILE if none.
var claimed_node: Vector2i = NO_TILE

var path_state: PathState = PathState.NONE
var path_goal: Vector2i = NO_TILE
var path: Array[Vector2i] = []
var path_index: int = 0
## NavGrid version the path was last checked against. Not saved: -1 forces a re-check.
var path_version: int = -1


func _init(entity_id: int, agent_kind: StringName, at: Vector2) -> void:
	id = entity_id
	kind = agent_kind
	pos = at
	prev_pos = at


func tile() -> Vector2i:
	return Vector2i(floori(pos.x), floori(pos.y))


func is_carrying() -> bool:
	return carry_amount > 0


func is_idle() -> bool:
	return task == null and cooldown == 0


func clear_path() -> void:
	path_state = PathState.NONE
	path_goal = NO_TILE
	path = []
	path_index = 0


func to_dict() -> Dictionary:
	var d := {
		"id": id, "kind": String(kind), "workplace": workplace_id, "pos": SimCodec.vec2(pos),
		"facing": facing, "carry": [String(carry_good), carry_amount], "activity": String(activity),
		"cooldown": cooldown, "claim": SimCodec.vec2i(claimed_node),
		"path": [path_state, SimCodec.vec2i(path_goal), SimCodec.tiles(path), path_index],
	}
	if task != null:
		d["task"] = task.to_dict()
	return d


static func from_dict(d: Dictionary) -> Agent:
	var a := Agent.new(int(d["id"]), StringName(String(d["kind"])), SimCodec.to_vec2(d["pos"]))
	a.workplace_id = int(d.get("workplace", 0))
	a.facing = int(d.get("facing", 0))
	var carry: Array = d.get("carry", ["", 0])
	a.carry_good = StringName(String(carry[0]))
	a.carry_amount = int(carry[1])
	a.activity = StringName(String(d.get("activity", "idle")))
	a.cooldown = int(d.get("cooldown", 0))
	a.claimed_node = SimCodec.to_vec2i(d.get("claim", [-1, -1]))
	var p: Array = d["path"]
	a.path_state = int(p[0]) as PathState
	a.path_goal = SimCodec.to_vec2i(p[1])
	a.path = SimCodec.to_tiles(p[2])
	a.path_index = int(p[3])
	if d.has("task"):
		a.task = Task.from_dict(d["task"])
	return a
