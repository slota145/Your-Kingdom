class_name FieldBattle
extends RefCounted
## A battle in the field on the world map (ROADMAP M8 part 2): the player's army [member a]
## met the enemy army [member b]. PENDING: both stand still while the player chooses how to
## fight (the game is paused meanwhile); LIVE: it is fought on the battlefield, the map of
## province [member province] without its town, viewed now (Simulation.BATTLEFIELD).

enum State { PENDING, LIVE }

var id: int = 0
var a: int = 0
var b: int = 0
## The province where they met (its map is the battlefield; 0 when none is there).
var province: int = 0
var pos: Vector2 = Vector2.ZERO
var state: State = State.PENDING
## PENDING: decided at once on this tick if the player did not choose (a safety for a game
## nobody plays; the game is paused while the player chooses).
var until: int = 0
## LIVE: the province viewed before, viewed again after the battle.
var prev_view: int = 0
## LIVE: men of each side when the battle began.
var start_a: Dictionary[StringName, int] = {}
var start_b: Dictionary[StringName, int] = {}
## LIVE: the enemy fled (marches off the map).
var routed: bool = false


func to_dict() -> Dictionary:
	var d := {"id": id, "a": a, "b": b, "province": province,
			"pos": [SimCodec.savable(pos.x), SimCodec.savable(pos.y)], "state": state, "until": until}
	if state == State.LIVE:
		d["prev_view"] = prev_view
		d["start_a"] = Expedition.goods_to_dict(start_a)
		d["start_b"] = Expedition.goods_to_dict(start_b)
		if routed:
			d["routed"] = true
	return d


static func from_dict(d: Dictionary) -> FieldBattle:
	var battle := FieldBattle.new()
	battle.id = int(d["id"])
	battle.a = int(d.get("a", 0))
	battle.b = int(d.get("b", 0))
	battle.province = int(d.get("province", 0))
	var p: Array = d.get("pos", [0, 0])
	battle.pos = Vector2(float(p[0]), float(p[1]))
	battle.state = clampi(int(d.get("state", 0)), State.PENDING, State.LIVE) as State
	battle.until = int(d.get("until", 0))
	battle.prev_view = int(d.get("prev_view", 0))
	battle.start_a = Expedition.goods_from(d.get("start_a", {}))
	battle.start_b = Expedition.goods_from(d.get("start_b", {}))
	battle.routed = bool(d.get("routed", false))
	return battle
