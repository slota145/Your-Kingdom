class_name Expedition
extends RefCounted
## An expedition of settlers on the world map (ROADMAP M6 part 2): it left its province
## (Departure) and travels by the clock, by ship between coasts or by wagon to a land
## neighbour (WorldSim.travel_seconds).
##
## TRAVELLING: on its way. WAITING: at the border of the new province (owner's decision
## 2026-11-06: it waits for the player; the landing starts when he enters). LANDED: the
## landing is under way there. RETURNING: the cog sails home empty (owner's decision: the cog
## comes back); a wagon stays with the settlers, so a land expedition ends when it lands.

enum State { TRAVELLING, WAITING, LANDED, RETURNING }

var id: int = 0
var from: int = 0
var to: int = 0
var by_sea: bool = false
var state: State = State.TRAVELLING
## Settler kinds and the start kit it carries.
var settlers: Array[StringName] = []
var kit: Dictionary[StringName, int] = {}
## The player's cog (an entity of the province [member from]) that carries it by sea.
var ship_id: int = 0
## Ticks it set out and arrives (TRAVELLING), or the cog set out home and is back (RETURNING).
var depart_at: int = 0
var arrive_at: int = 0


## How far along its way it is (0..1), for the world map.
func progress(tick: int) -> float:
	if state == State.WAITING or state == State.LANDED:
		return 1.0
	if arrive_at <= depart_at:
		return 1.0
	return clampf(float(tick - depart_at) / float(arrive_at - depart_at), 0.0, 1.0)


func to_dict() -> Dictionary:
	var kinds: Array = []
	for kind: StringName in settlers:
		kinds.append(String(kind))
	var d := {"id": id, "from": from, "to": to, "sea": by_sea, "state": state, "settlers": kinds,
			"kit": goods_to_dict(kit), "depart": depart_at, "arrive": arrive_at}
	if ship_id != 0:
		d["ship"] = ship_id
	return d


static func from_dict(d: Dictionary) -> Expedition:
	var e := Expedition.new()
	e.id = int(d["id"])
	e.from = int(d["from"])
	e.to = int(d["to"])
	e.by_sea = bool(d.get("sea", false))
	e.state = int(d.get("state", 0)) as State
	for kind: Variant in d.get("settlers", []):
		e.settlers.append(StringName(String(kind)))
	e.kit = goods_from(d.get("kit", {}))
	e.ship_id = int(d.get("ship", 0))
	e.depart_at = int(d.get("depart", 0))
	e.arrive_at = int(d.get("arrive", 0))
	return e


static func goods_to_dict(goods: Dictionary[StringName, int]) -> Dictionary:
	var d := {}
	var keys: Array[StringName] = []
	keys.assign(goods.keys())
	keys.sort()
	for good: StringName in keys:
		d[String(good)] = goods[good]
	return d


static func goods_from(d: Variant) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	if d is Dictionary:
		for good: Variant in d:
			result[StringName(String(good))] = int(d[good])
	return result
