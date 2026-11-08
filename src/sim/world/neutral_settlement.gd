class_name NeutralSettlement
extends RefCounted
## A neutral settlement the player can buy (ROADMAP M6 part 3, GDD §2.1 "Zdobywanie
## prowincji"): a small town (NeutralTown) that joins the kingdom for gold and goods delivered
## within a time limit.
##
## ASKING: the demand stands: gold (paid from the world map panel) and goods (brought by a
##   trade route or a voyage "to my province"; what comes counts towards the demand). When
##   all is there before the deadline, the settlement joins the player with its people and
##   buildings.
## RESTING: the time ran out: what was given is lost, and a new demand, DEARER dearer, comes
##   after REST_MINUTES.

enum State { ASKING, RESTING }

## Each new demand after a failed one costs this much more (ROADMAP M6: +25%).
const DEARER := 1.25
const REST_MINUTES := 10.0

var province: int = 0
var state: State = State.ASKING
## Demands made so far (0 = the first): the price grows with each failed one.
var round: int = 0
## The demand now: gold and goods (good -> units), and what was given towards it.
var gold: int = 0
var goods: Dictionary[StringName, int] = {}
var gold_paid: int = 0
var delivered: Dictionary[StringName, int] = {}
## ASKING: tick the time runs out; RESTING: tick the new demand comes.
var until: int = 0
## The guards left (unit id -> men; M7 part 3) and whether the town got its walls
## (NeutralTown.fortify).
var guards: Dictionary[StringName, int] = {}
var fortified: bool = false


## The first demand of province [param id] of [param def], from tick [param now].
static func first(id: int, def: ProvinceDef, now: int) -> NeutralSettlement:
	var s := NeutralSettlement.new()
	s.province = id
	s.ask(def, now)
	return s


## A new demand, [constant DEARER] times dearer for each one that failed before.
func ask(def: ProvinceDef, now: int) -> void:
	var factor := pow(DEARER, round)
	gold = roundi(def.demand_gold * factor)
	goods = {}
	for good: StringName in def.demand_goods:
		goods[good] = roundi(int(def.demand_goods[good]) * factor)
	gold_paid = 0
	delivered = {}
	state = State.ASKING
	until = now + SimClock.seconds_to_ticks(def.demand_minutes * 60.0)


## Units of [param good] still missing.
func missing(good: StringName) -> int:
	return maxi(int(goods.get(good, 0)) - int(delivered.get(good, 0)), 0)


func gold_missing() -> int:
	return maxi(gold - gold_paid, 0)


## Whether the whole demand is given.
func is_met() -> bool:
	if state != State.ASKING or gold_missing() > 0:
		return false
	for good: StringName in goods:
		if missing(good) > 0:
			return false
	return true


## [param amount] of [param good] arrived: what the demand still needs is counted, the rest is
## returned (it goes into the town's storages).
func take(good: StringName, amount: int) -> int:
	if state != State.ASKING:
		return amount
	var counted := mini(amount, missing(good))
	if counted > 0:
		delivered[good] = int(delivered.get(good, 0)) + counted
	return amount - counted


func to_dict() -> Dictionary:
	var d := {"province": province, "state": state, "round": round, "gold": gold,
			"goods": Expedition.goods_to_dict(goods), "gold_paid": gold_paid,
			"delivered": Expedition.goods_to_dict(delivered), "until": until}
	if not guards.is_empty():
		d["guards"] = Expedition.goods_to_dict(guards)
	if fortified:
		d["fortified"] = true
	return d


static func from_dict(d: Dictionary) -> NeutralSettlement:
	var s := NeutralSettlement.new()
	s.province = int(d["province"])
	s.state = clampi(int(d.get("state", 0)), State.ASKING, State.RESTING) as State
	s.round = int(d.get("round", 0))
	s.gold = int(d.get("gold", 0))
	s.goods = Expedition.goods_from(d.get("goods", {}))
	s.gold_paid = int(d.get("gold_paid", 0))
	s.delivered = Expedition.goods_from(d.get("delivered", {}))
	s.until = int(d.get("until", 0))
	s.guards = Expedition.goods_from(d.get("guards", {}))
	s.fortified = bool(d.get("fortified", false))
	return s
