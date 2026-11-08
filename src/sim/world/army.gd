class_name Army
extends RefCounted
## An army on the world map (GDD §6.3, ROADMAP M7 part 3): the player's soldiers who marched
## out of a province, or bandits from their camp.
##
## INSIDE: its men are people in the viewed province [member at] (marching out, fighting a
##   siege or a raid there); Armies counts them back when none is left on the map.
## IDLE: it stands in province [member at] (beside the town, or in an empty province).
## MOVING: on its way from [member at] to [member next] (by the clock), then along
##   [member route] to its goal.
## WAITING: at the border of a neutral settlement [member at], for the player to choose how to
##   fight (in the province's view, or at once by BattleResolver).

enum State { INSIDE, IDLE, MOVING, WAITING }

## Bread an army eats: 1 per 10 men per minute (ROADMAP M7).
const FOOD_PER_MAN_MINUTE := 0.1
## Minutes of food an army takes along (and tops up to in the player's provinces).
const FOOD_MINUTES := 10.0
## Owner of the bandits' armies (ProvinceDef.OWNER_* for the player's).
const BANDITS := &"bandits"

var id: int = 0
var owner: StringName = ProvinceDef.OWNER_PLAYER
var state: State = State.INSIDE
## Where it is (or set out from while MOVING).
var at: int = 0
## MOVING: the province it is walking to now, and the ones after it to its goal.
var next: int = 0
var route: Array[int] = []
var by_sea: bool = false
var depart_at: int = 0
var arrive_at: int = 0
## Men by unit id (ram and laddermen too; not the ones on the map while INSIDE).
var units: Dictionary[StringName, int] = {}
## Units of bread it carries (fractions eaten on the way).
var food: float = 0.0
## Warships carrying it by sea (M7 part 3), taken from province [member fleet_home]; when
## it lands they sail back there.
var ships: int = 0
var fleet_home: int = 0
## Those warships by ship id (J1 part 3: caravels, carracks and galleons are bigger than the
## war cog); [member ships] is their number.
var fleet: Dictionary[StringName, int] = {}
## The province it came from: the player's home town, or the bandits' camp.
var home: int = 0
## Where its men came onto the map of [member at] (and leave again when they retreat).
var entry: Vector2i = Vector2i(-1, -1)
## Bandits: the gold they took, brought back to the camp.
var loot_gold: int = 0
## Bandits: warned the viewed province they are about to arrive at.
var warned: bool = false
## It came by sea: its men land on the beach (not at the edge of the map).
var landed_by_sea: bool = false


func men() -> int:
	var total := 0
	for unit: StringName in units:
		total += units[unit]
	return total


func is_empty() -> bool:
	return men() == 0


func add(unit: StringName, count: int = 1) -> void:
	units[unit] = units.get(unit, 0) + count
	if units[unit] <= 0:
		units.erase(unit)


## Takes losses (unit -> men lost) off its men.
func lose(lost: Dictionary[StringName, int]) -> void:
	for unit: StringName in lost:
		add(unit, -mini(lost[unit], units.get(unit, 0)))


## Bread it takes along and tops up to.
func food_cap() -> float:
	return men() * FOOD_PER_MAN_MINUTE * FOOD_MINUTES


func is_fed() -> bool:
	return food > 0.0 or men() == 0


## Whether it stands somewhere off the map (not walking, not inside a province).
func is_standing() -> bool:
	return state == State.IDLE or state == State.WAITING


## How far along the road to [member next] it is (0..1), for the world map.
func progress(tick: int) -> float:
	if state != State.MOVING or arrive_at <= depart_at:
		return 1.0
	return clampf(float(tick - depart_at) / float(arrive_at - depart_at), 0.0, 1.0)


## The province it is heading for in the end (its own province when standing).
func goal() -> int:
	if state != State.MOVING:
		return at
	return route[route.size() - 1] if not route.is_empty() else next


func side() -> BattleSide:
	var s := BattleSide.new(units, is_fed(), ships)
	s.fleet = fleet.duplicate()
	return s


## Warships sunk in a sea battle (J1 part 3): only [param left] of them stay, the biggest
## numbers of one kind going first.
func sink_to(left: int) -> void:
	while ships > maxi(left, 0) and not fleet.is_empty():
		var most: StringName = fleet.keys()[0]
		for id: StringName in fleet:
			if fleet[id] > fleet[most]:
				most = id
		fleet[most] -= 1
		if fleet[most] <= 0:
			fleet.erase(most)
		ships -= 1
	ships = mini(ships, maxi(left, 0))


func to_dict() -> Dictionary:
	var d := {"id": id, "owner": String(owner), "state": state, "at": at,
			"units": Expedition.goods_to_dict(units), "food": SimCodec.savable(food), "home": home}
	if state == State.MOVING:
		d["next"] = next
		d["route"] = route.duplicate()
		d["depart"] = depart_at
		d["arrive"] = arrive_at
		if by_sea:
			d["sea"] = true
	if ships != 0:
		d["ships"] = ships
		d["fleet_home"] = fleet_home
		if not fleet.is_empty():
			d["fleet"] = Expedition.goods_to_dict(fleet)
	if entry.x >= 0:
		d["entry"] = SimCodec.vec2i(entry)
	if loot_gold != 0:
		d["loot_gold"] = loot_gold
	if warned:
		d["warned"] = true
	if landed_by_sea:
		d["landed_by_sea"] = true
	return d


static func from_dict(d: Dictionary) -> Army:
	var a := Army.new()
	a.id = int(d["id"])
	a.owner = StringName(String(d.get("owner", "player")))
	a.state = clampi(int(d.get("state", 0)), State.INSIDE, State.WAITING) as State
	a.at = int(d.get("at", 0))
	a.units = Expedition.goods_from(d.get("units", {}))
	a.food = float(d.get("food", 0.0))
	a.home = int(d.get("home", 0))
	a.next = int(d.get("next", 0))
	for p: Variant in d.get("route", []):
		a.route.append(int(p))
	a.depart_at = int(d.get("depart", 0))
	a.arrive_at = int(d.get("arrive", 0))
	a.by_sea = bool(d.get("sea", false))
	a.ships = int(d.get("ships", 0))
	a.fleet_home = int(d.get("fleet_home", 0))
	a.fleet = Expedition.goods_from(d.get("fleet", {}))
	if a.fleet.is_empty() and a.ships > 0:
		a.fleet[&"warship"] = a.ships   # saved before J1 part 3: war cogs
	a.entry = SimCodec.to_vec2i(d.get("entry", [-1, -1]))
	a.loot_gold = int(d.get("loot_gold", 0))
	a.warned = bool(d.get("warned", false))
	a.landed_by_sea = bool(d.get("landed_by_sea", false))
	return a
