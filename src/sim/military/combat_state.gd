class_name CombatState
extends RefCounted
## A fighter's state (ARCHITECTURE §10, M7): life, side, the player's orders and the walk the
## Troops system drives him along (M7 part 2). Soldiers of the barracks stand in the ranks
## until the player gives them an order ([member commanded]); bandits are always commanded
## (by their raid).

## MARCH (M7 part 3): to the edge of the map, where he joins his army ([member army]).
enum Order { NONE, MOVE, ATTACK, STRUCTURE, RETURN, MARCH }
enum Stance { AGGRESSIVE, DEFENSIVE, HOLD }

const PLAYER := 0
const BANDITS := 1
## The guards of a neutral settlement (M7 part 3).
const TOWN := 2

var hp: int = 0
## Agent id of the target, 0 = none.
var target_id: int = 0
## Ticks before the next attack.
var cooldown: int = 0
## Side: PLAYER, BANDITS or TOWN.
var faction: int = PLAYER
## Army (world map, M7 part 3) he belongs to while away from his barracks; 0 = none.
var army: int = 0
## UnitDef id of his fighting values (a bandit fights like a spearman or an archer).
var unit: StringName = &""
## Under orders (Troops moves him); false: a soldier in the ranks of his barracks.
var commanded: bool = false
var stance: Stance = Stance.AGGRESSIVE
var order: Order = Order.NONE
## Where he was sent (grid space, sub-tile) and on which level (0 ground, 1 wall-walk); he
## comes back here after a fight unless he attacks freely.
var post: Vector2 = Vector2(-1, -1)
var post_level: int = 0
## Order STRUCTURE: the wall tile, gate or door he breaks.
var target_tile: Vector2i = Vector2i(-1, -1)
## The walk: tiles and their levels, and the next index.
var path: Array[Vector2i] = []
var levels: PackedByteArray = PackedByteArray()
var path_index: int = 0
## Tick of the last route search (a chase searches again now and then).
var path_tick: int = -1000
## An enemy he found no way to, left alone until [member blocked_until] (not saved: a
## search again after loading costs nothing).
var blocked_id: int = 0
var blocked_until: int = 0
## Where the walk ends (sub-tile) and its level.
var goal: Vector2 = Vector2(-1, -1)
var goal_level: int = 0


func _init(life: int = 0) -> void:
	hp = life


func has_path() -> bool:
	return path_index < path.size()


func clear_path() -> void:
	path = []
	levels = PackedByteArray()
	path_index = 0


func to_dict() -> Dictionary:
	var d := {"hp": hp}
	if target_id != 0:
		d["target"] = target_id
	if cooldown != 0:
		d["cooldown"] = cooldown
	if faction != PLAYER:
		d["faction"] = faction
	if unit != &"":
		d["unit"] = String(unit)
	if army != 0:
		d["army"] = army
	if commanded:
		d["commanded"] = true
		d["stance"] = stance
		d["order"] = order
		d["post"] = SimCodec.vec2(post)
		d["post_level"] = post_level
		d["goal"] = SimCodec.vec2(goal)
		d["goal_level"] = goal_level
		d["path_tick"] = path_tick
		if target_tile != Vector2i(-1, -1):
			d["target_tile"] = SimCodec.vec2i(target_tile)
		if has_path():
			d["path"] = SimCodec.tiles(path)
			d["levels"] = Array(levels)
			d["path_index"] = path_index
	return d


static func from_dict(d: Dictionary) -> CombatState:
	var state := CombatState.new(int(d.get("hp", 0)))
	state.target_id = int(d.get("target", 0))
	state.cooldown = int(d.get("cooldown", 0))
	state.faction = int(d.get("faction", PLAYER))
	state.unit = StringName(String(d.get("unit", "")))
	state.army = int(d.get("army", 0))
	state.commanded = bool(d.get("commanded", false))
	if state.commanded:
		state.stance = int(d.get("stance", 0)) as Stance
		state.order = int(d.get("order", 0)) as Order
		state.post = SimCodec.to_vec2(d.get("post", [-1, -1]))
		state.post_level = int(d.get("post_level", 0))
		state.goal = SimCodec.to_vec2(d.get("goal", [-1, -1]))
		state.goal_level = int(d.get("goal_level", 0))
		state.path_tick = int(d.get("path_tick", -1000))
		state.target_tile = SimCodec.to_vec2i(d.get("target_tile", [-1, -1]))
		state.path = SimCodec.to_tiles(d.get("path", []))
		for level: Variant in d.get("levels", []):
			state.levels.append(int(level))
		state.path_index = int(d.get("path_index", 0))
	return state
