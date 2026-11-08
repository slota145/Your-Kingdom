class_name BattleResult
extends RefCounted
## The outcome: who won, what each side lost and has left, the rounds of the report.

## 0 = side A, 1 = side B.
var winner: int = 1
var lost_a: Dictionary[StringName, int] = {}
var lost_b: Dictionary[StringName, int] = {}
var left_a: Dictionary[StringName, int] = {}
var left_b: Dictionary[StringName, int] = {}
var ships_left_a: int = 0
var ships_left_b: int = 0
## A siege: the attackers broke in (or the town had no walls).
var breached: bool = false
var rounds: int = 0
## The report: one entry per phase: {phase, rounds, a, b} (men left at its end).
var report: Array[Dictionary] = []


func a_won() -> bool:
	return winner == 0


func to_dict() -> Dictionary:
	var phases: Array = []
	for entry: Dictionary in report:
		phases.append({"phase": int(entry["phase"]), "rounds": int(entry["rounds"]),
				"a": int(entry["a"]), "b": int(entry["b"])})
	return {"winner": winner, "lost_a": Expedition.goods_to_dict(lost_a),
			"lost_b": Expedition.goods_to_dict(lost_b), "left_a": Expedition.goods_to_dict(left_a),
			"left_b": Expedition.goods_to_dict(left_b), "breached": breached, "rounds": rounds,
			"report": phases}


static func from_dict(d: Dictionary) -> BattleResult:
	var r := BattleResult.new()
	r.winner = int(d.get("winner", 1))
	r.lost_a = Expedition.goods_from(d.get("lost_a", {}))
	r.lost_b = Expedition.goods_from(d.get("lost_b", {}))
	r.left_a = Expedition.goods_from(d.get("left_a", {}))
	r.left_b = Expedition.goods_from(d.get("left_b", {}))
	r.breached = bool(d.get("breached", false))
	r.rounds = int(d.get("rounds", 0))
	for entry: Variant in d.get("report", []):
		r.report.append({"phase": int(entry["phase"]), "rounds": int(entry["rounds"]),
				"a": int(entry["a"]), "b": int(entry["b"])})
	return r
