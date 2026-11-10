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
## The AI rulers may buy it too (M8 part 3, owner's survey 2026-11-10: whoever comes first):
## what each ruler gave is kept apart ([member rivals]); the first to give it all gets the
## settlement, and what the others gave is lost, as when the time runs out.

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
## What the AI rulers gave towards the demand now: owner -> {"gold": int, "goods": {good: n}}.
var rivals: Dictionary[StringName, Dictionary] = {}


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
	rivals = {}
	state = State.ASKING
	until = now + SimClock.seconds_to_ticks(def.demand_minutes * 60.0)


## Units of [param good] still missing (from the player, or from AI ruler [param buyer]).
func missing(good: StringName, buyer: StringName = ProvinceDef.OWNER_PLAYER) -> int:
	return maxi(int(goods.get(good, 0)) - int(_given(buyer).get(good, 0)), 0)


func gold_missing(buyer: StringName = ProvinceDef.OWNER_PLAYER) -> int:
	return maxi(gold - _gold_given(buyer), 0)


## Whether the whole demand is given (by the player, or by [param buyer]).
func is_met(buyer: StringName = ProvinceDef.OWNER_PLAYER) -> bool:
	if state != State.ASKING or gold_missing(buyer) > 0:
		return false
	for good: StringName in goods:
		if missing(good, buyer) > 0:
			return false
	return true


## [param amount] of [param good] arrived from [param buyer]: what the demand still needs is
## counted, the rest is returned (it goes into the town's storages).
func take(good: StringName, amount: int, buyer: StringName = ProvinceDef.OWNER_PLAYER) -> int:
	if state != State.ASKING:
		return amount
	var counted := mini(amount, missing(good, buyer))
	if counted > 0:
		var given := _given(buyer)
		given[good] = int(given.get(good, 0)) + counted
		if buyer != ProvinceDef.OWNER_PLAYER:
			_rival(buyer)["goods"] = given
	return amount - counted


## [param buyer] pays [param amount] gold towards the demand.
func pay(amount: int, buyer: StringName = ProvinceDef.OWNER_PLAYER) -> void:
	if buyer == ProvinceDef.OWNER_PLAYER:
		gold_paid += amount
	else:
		_rival(buyer)["gold"] = int(_rival(buyer).get("gold", 0)) + amount


## Who gave the whole demand first: the player, an AI ruler, or &"" (nobody yet).
func winner() -> StringName:
	if is_met():
		return ProvinceDef.OWNER_PLAYER
	var owners: Array[StringName] = []
	owners.assign(rivals.keys())
	owners.sort()
	for owner: StringName in owners:
		if is_met(owner):
			return owner
	return &""


func _given(buyer: StringName) -> Dictionary:
	if buyer == ProvinceDef.OWNER_PLAYER:
		return delivered
	return rivals[buyer].get("goods", {}) if rivals.has(buyer) else {}


func _gold_given(buyer: StringName) -> int:
	if buyer == ProvinceDef.OWNER_PLAYER:
		return gold_paid
	return int(rivals[buyer].get("gold", 0)) if rivals.has(buyer) else 0


func _rival(buyer: StringName) -> Dictionary:
	if not rivals.has(buyer):
		rivals[buyer] = {"gold": 0, "goods": {}}
	return rivals[buyer]


func to_dict() -> Dictionary:
	var d := {"province": province, "state": state, "round": round, "gold": gold,
			"goods": Expedition.goods_to_dict(goods), "gold_paid": gold_paid,
			"delivered": Expedition.goods_to_dict(delivered), "until": until}
	if not guards.is_empty():
		d["guards"] = Expedition.goods_to_dict(guards)
	if fortified:
		d["fortified"] = true
	if not rivals.is_empty():
		var r := {}
		var owners: Array[StringName] = []
		owners.assign(rivals.keys())
		owners.sort()
		for owner: StringName in owners:
			var goods_given: Dictionary[StringName, int] = Expedition.goods_from(rivals[owner].get("goods", {}))
			r[String(owner)] = {"gold": int(rivals[owner].get("gold", 0)),
					"goods": Expedition.goods_to_dict(goods_given)}
		d["rivals"] = r
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
	var r: Dictionary = d.get("rivals", {})
	for owner: Variant in r:
		var given: Dictionary = {}
		var goods_d: Dictionary[StringName, int] = Expedition.goods_from(r[owner].get("goods", {}))
		for good: StringName in goods_d:
			given[good] = goods_d[good]
		s.rivals[StringName(String(owner))] = {"gold": int(r[owner].get("gold", 0)), "goods": given}
	return s
