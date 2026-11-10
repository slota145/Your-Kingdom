class_name Army
extends RefCounted
## An army on the world map (GDD §6.3, ROADMAP M7 part 3): the player's soldiers who marched
## out of a province, or bandits from their camp.
##
## INSIDE: its men are people in the viewed province [member at] (marching out, fighting a
##   siege or a raid there); Armies counts them back when none is left on the map.
## IDLE: it stands at [member pos] (beside a town, in the field, or a fleet at sea).
## MOVING: on its way along [member path] (M8 part 2: to any point of the world map, to a town
##   [member target] or after an enemy army [member chase]).
## WAITING: at the border of a neutral settlement [member at], for the player to choose how to
##   fight (in the province's view, or at once by BattleResolver).
## ENGAGED: met an enemy army in the field (M8 part 2): stands still in battle [member battle]
##   while the player chooses how to fight it, or while it is fought on the battlefield.
##
## A fleet (M8 part 2) is an army whose [member ships] are at sea ([member by_sea]); its
## [member units] are the soldiers aboard.

enum State { INSIDE, IDLE, MOVING, WAITING, ENGAGED }

## Bread an army eats: 1 per 10 men per minute (ROADMAP M7).
const FOOD_PER_MAN_MINUTE := 0.1
## Minutes of food an army takes along (and tops up to in the player's provinces).
const FOOD_MINUTES := 10.0
## Owner of the bandits' armies (ProvinceDef.OWNER_* for the player's).
const BANDITS := &"bandits"

var id: int = 0
var owner: StringName = ProvinceDef.OWNER_PLAYER
var state: State = State.INSIDE
## The province it is in (the land under [member pos]); 0 at sea.
var at: int = 0
## Where it is on the world map (parchment pixels); Vector2.INF: not placed yet (a save from
## before M8 part 2, placed on the next second).
var pos: Vector2 = Vector2.INF
## MOVING: the points it goes through, its goal last.
var path: Array[Vector2] = []
## The province whose town it goes to (0: a spot in the field or at sea).
var target: int = 0
## The enemy army it goes after (0: none).
var chase: int = 0
## A fleet with soldiers sent to the land: where they go ashore (Vector2.INF: nowhere), and the
## spot they walk to from there.
var ashore: Vector2 = Vector2.INF
var ashore_goal: Vector2 = Vector2.INF
## A fleet going into the port of its province [member target] (not ashore).
var docking: bool = false
## A fleet at sea (its ships carry it).
var by_sea: bool = false
## ENGAGED: the battle (FieldBattle id) it stands in.
var battle: int = 0
## Beaten: no enemy catches it before this tick (it walks away).
var safe_until: int = 0
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
## Raiders of a wave that only plunders (M8 part 5, the Invasion): they loot like bandits and
## sail away instead of taking the town.
var plunder: bool = false


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


## Whether it is a fleet (warships at sea).
func is_fleet() -> bool:
	return by_sea and ships > 0


## The province it is heading for in the end (its own province when standing or going to a spot).
func goal() -> int:
	if state != State.MOVING or target == 0:
		return at
	return target


## Where its way ends (its position when standing).
func goal_point() -> Vector2:
	return path[path.size() - 1] if not path.is_empty() else pos


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
	if pos != Vector2.INF:
		d["pos"] = [SimCodec.savable(pos.x), SimCodec.savable(pos.y)]
	if not path.is_empty():
		var points: Array = []
		for p: Vector2 in path:
			points.append([SimCodec.savable(p.x), SimCodec.savable(p.y)])
		d["path"] = points
	if target != 0:
		d["target"] = target
	if chase != 0:
		d["chase"] = chase
	if ashore != Vector2.INF:
		d["ashore"] = [SimCodec.savable(ashore.x), SimCodec.savable(ashore.y)]
		d["ashore_goal"] = [SimCodec.savable(ashore_goal.x), SimCodec.savable(ashore_goal.y)]
	if docking:
		d["docking"] = true
	if by_sea:
		d["sea"] = true
	if battle != 0:
		d["battle"] = battle
	if safe_until != 0:
		d["safe_until"] = safe_until
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
	if plunder:
		d["plunder"] = true
	return d


static func from_dict(d: Dictionary) -> Army:
	var a := Army.new()
	a.id = int(d["id"])
	a.owner = StringName(String(d.get("owner", "player")))
	a.state = clampi(int(d.get("state", 0)), State.INSIDE, State.ENGAGED) as State
	a.at = int(d.get("at", 0))
	a.units = Expedition.goods_from(d.get("units", {}))
	a.food = float(d.get("food", 0.0))
	a.home = int(d.get("home", 0))
	if d.has("pos"):
		a.pos = _point(d["pos"])
	for p: Variant in d.get("path", []):
		a.path.append(_point(p))
	a.target = int(d.get("target", 0))
	a.chase = int(d.get("chase", 0))
	if d.has("ashore"):
		a.ashore = _point(d["ashore"])
		a.ashore_goal = _point(d.get("ashore_goal", d["ashore"]))
	a.docking = bool(d.get("docking", false))
	a.by_sea = bool(d.get("sea", false))
	a.battle = int(d.get("battle", 0))
	a.safe_until = int(d.get("safe_until", 0))
	a.ships = int(d.get("ships", 0))
	a.fleet_home = int(d.get("fleet_home", 0))
	a.fleet = Expedition.goods_from(d.get("fleet", {}))
	if a.fleet.is_empty() and a.ships > 0:
		a.fleet[&"warship"] = a.ships   # saved before J1 part 3: war cogs
	a.entry = SimCodec.to_vec2i(d.get("entry", [-1, -1]))
	a.loot_gold = int(d.get("loot_gold", 0))
	a.warned = bool(d.get("warned", false))
	a.landed_by_sea = bool(d.get("landed_by_sea", false))
	a.plunder = bool(d.get("plunder", false))
	return a


static func _point(v: Variant) -> Vector2:
	var list := v as Array
	return Vector2(float(list[0]), float(list[1]))
