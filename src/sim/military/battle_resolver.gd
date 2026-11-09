class_name BattleResolver
extends RefCounted
## Battles nobody watches (GDD §7, §8, ARCHITECTURE §10, ROADMAP M7 part 3): a pure function
## (side A, side B, kind, fortifications, rng) -> result, with no province and no agents.
##
## The fight goes in rounds of ROUND_SECONDS. Each kind of unit is a pool (count and life
## left); its damage in a round is what its men would deal in that time with the live fight's
## values (UnitDef.combat: blow, seconds between blows, bonus against some units), times
## EFFICIENCY (walking, missing, waiting for a gap), spread over the enemy pools by their
## numbers. Phases:
## - FIELD: the archers shoot while the lines close (APPROACH_ROUNDS), then everyone fights.
## - SIEGE: side A attacks side B behind [class BattleFort]: while the attackers break in (rounds the
##   ram needs for the gate, the ladders to climb a stone wall, the men to hack through a
##   palisade or a wall), only archers shoot; defenders on the walls take WALL_COVER of the
##   arrows and shoot WALL_RANGE_ROUNDS before the attackers can answer. Then the storm:
##   everyone fights; the door of the town hall falls when no defender is left.
## - NAVAL: the warships' ballistae and the archers shoot (APPROACH_ROUNDS + 1), then the
##   crews board. A side's ships go down with the life its men lost.
## A side whose men fall below ROUT_SHARE of what it started with flees: the other wins. After
## MAX_ROUNDS the defender (side B) holds.

enum Kind { FIELD, SIEGE, NAVAL }
enum Phase { VOLLEY, BREACH, MELEE }

const ROUND_SECONDS := 5.0
const EFFICIENCY := 0.5
const APPROACH_ROUNDS := 2
## Rounds the defenders on walls shoot before the attackers' archers are near enough.
const WALL_RANGE_ROUNDS := 2
## Share of the arrows' damage that hurts a man on the walls (the live fight: Troops.WALL_COVER).
const WALL_COVER := 0.5
## Men that can hack at one breach at a time.
const BREACH_WIDTH := 4
## Rounds to climb ladders on a stone wall (when the attackers bring any).
const LADDER_ROUNDS := 3
const ROUT_SHARE := 0.25
const MAX_ROUNDS := 80
## Damage of a hungry army (ROADMAP M7 part 3: -30%).
const HUNGRY := 0.7
## Random spread of a side's damage in a round (+-).
const NOISE := 0.1
## A warship in a sea battle: life, ballista bolt, seconds between bolts.
const SHIP_HP := 800
const SHIP_ATTACK := 30
const SHIP_COOLDOWN := 4.0
## Soldiers a warship carries (ROADMAP M7).
const SHIP_CAPACITY := 30


## A unit kind of one side in the fight.
class _Pool:
	extends RefCounted
	var unit: StringName
	var stats: CombatStatsDef
	var siege: StringName
	var start: int
	var life: float

	func alive() -> int:
		return ceili(life / float(stats.hp) - 0.0001) if life > 0.0 else 0


static func resolve(data: DataRegistry, a: BattleSide, b: BattleSide, kind: Kind, rng: RandomNumberGenerator,
		fort: BattleFort = null) -> BattleResult:
	var pools_a := _pools(data, a)
	var pools_b := _pools(data, b)
	var start_a := _men(pools_a)
	var start_b := _men(pools_b)
	# Each side's warships (J1 part 3: by kind, from their ShipDef): full life, damage of a
	# round at full life, soldiers they carry.
	var fleet_a := _fleet(data, a)
	var fleet_b := _fleet(data, b)
	var ship_life_a: float = fleet_a[0] if kind == Kind.NAVAL else 0.0
	var ship_life_b: float = fleet_b[0] if kind == Kind.NAVAL else 0.0
	var result := BattleResult.new()
	var phase := Phase.VOLLEY
	var phase_rounds := 0
	var breach_left := 0
	var breach_progress := 0.0
	if kind == Kind.SIEGE:
		breach_left = _breach_rounds(pools_a, fort)
		# Nobody to stop them: the walls only take time.
		result.breached = breach_left == 0 or start_b == 0
		phase = Phase.BREACH if breach_left > 0 else Phase.VOLLEY
	var volley_rounds := APPROACH_ROUNDS + (1 if kind == Kind.NAVAL else 0)
	var round := 0
	while round < MAX_ROUNDS:
		var men_a := _men(pools_a)
		var men_b := _men(pools_b)
		if men_a == 0 or men_b == 0:
			break
		if men_a < start_a * ROUT_SHARE or men_b < start_b * ROUT_SHARE:
			break
		var melee := phase == Phase.MELEE
		var walls := kind == Kind.SIEGE and not result.breached and fort != null and fort.wall != Walls.NONE
		var mul_a := _noise(rng) * (1.0 if a.fed else HUNGRY)
		var mul_b := _noise(rng) * (1.0 if b.fed else HUNGRY)
		# The attackers' archers cannot reach the walls in the first rounds of a siege.
		var a_shoots := not (walls and round < WALL_RANGE_ROUNDS)
		var hit_a := _damage(pools_b, pools_a, melee, true) * mul_b
		var hit_b := _damage(pools_a, pools_b, melee, a_shoots) * mul_a
		if walls:
			hit_b *= WALL_COVER
		if kind == Kind.NAVAL:
			var bolts_a := _fleet_damage(fleet_a, ship_life_a, a.fleet.is_empty()) * mul_a
			var bolts_b := _fleet_damage(fleet_b, ship_life_b, b.fleet.is_empty()) * mul_b
			# Bolts hit the ships first, then the men on deck.
			var to_ship_b := minf(bolts_a * 0.5, ship_life_b)
			var to_ship_a := minf(bolts_b * 0.5, ship_life_a)
			ship_life_b -= to_ship_b
			ship_life_a -= to_ship_a
			hit_b += bolts_a - to_ship_b
			hit_a += bolts_b - to_ship_a
		_take(pools_a, hit_a)
		_take(pools_b, hit_b)
		round += 1
		phase_rounds += 1
		var next := phase
		match phase:
			Phase.VOLLEY:
				if phase_rounds >= volley_rounds:
					next = Phase.MELEE
			Phase.BREACH:
				breach_progress += 1.0
				if breach_progress >= breach_left:
					result.breached = true
					next = Phase.MELEE
		if next != phase:
			_note(result, phase, phase_rounds, pools_a, pools_b)
			phase = next
			phase_rounds = 0
	if phase_rounds > 0:
		_note(result, phase, phase_rounds, pools_a, pools_b)
	result.rounds = round
	var left_a := _men(pools_a)
	var left_b := _men(pools_b)
	var a_holds := left_a > 0 and left_a >= start_a * ROUT_SHARE
	var b_holds := left_b > 0 and left_b >= start_b * ROUT_SHARE
	if kind == Kind.NAVAL:
		a_holds = a_holds and (a.ships == 0 or ship_life_a > 0.0)
		b_holds = b_holds and (b.ships == 0 or ship_life_b > 0.0)
	if kind == Kind.SIEGE:
		result.winner = 0 if a_holds and not b_holds and result.breached else 1
	elif a_holds and not b_holds:
		result.winner = 0
	elif b_holds and not a_holds:
		result.winner = 1
	else:
		# Both stand after MAX_ROUNDS (or both broke): the stronger share holds the field.
		var share_a := float(left_a) / maxf(start_a, 1.0)
		var share_b := float(left_b) / maxf(start_b, 1.0)
		result.winner = 0 if share_a > share_b else 1
	for pool: _Pool in pools_a:
		result.left_a[pool.unit] = pool.alive()
		result.lost_a[pool.unit] = pool.start - pool.alive()
	for pool: _Pool in pools_b:
		result.left_b[pool.unit] = pool.alive()
		result.lost_b[pool.unit] = pool.start - pool.alive()
	if kind == Kind.NAVAL:
		result.ships_left_a = _ships_left(a, fleet_a, ship_life_a)
		result.ships_left_b = _ships_left(b, fleet_b, ship_life_b)
		if a.ships > 0:
			_drown(result.left_a, result.lost_a, _room(fleet_a, ship_life_a, result.ships_left_a, a.fleet.is_empty()))
		if b.ships > 0:
			_drown(result.left_b, result.lost_b, _room(fleet_b, ship_life_b, result.ships_left_b, b.fleet.is_empty()))
	else:
		result.ships_left_a = a.ships
		result.ships_left_b = b.ships
	return result


## Share of [param tries] fights side A wins (the chances shown before an automatic battle).
static func chances(data: DataRegistry, a: BattleSide, b: BattleSide, kind: Kind, fort: BattleFort = null,
		tries: int = 20) -> float:
	var rng := RandomNumberGenerator.new()
	var won := 0
	for i: int in tries:
		rng.seed = 7919 * (i + 1)
		if resolve(data, a, b, kind, rng, fort).a_won():
			won += 1
	return float(won) / float(maxi(tries, 1))


static func _pools(data: DataRegistry, side: BattleSide) -> Array[_Pool]:
	var pools: Array[_Pool] = []
	var ids: Array[StringName] = []
	ids.assign(side.units.keys())
	ids.sort()
	for id: StringName in ids:
		var def := data.get_unit(id)
		if def == null or def.combat == null or side.units[id] <= 0:
			continue
		var pool := _Pool.new()
		pool.unit = id
		pool.stats = def.combat
		pool.siege = def.siege
		pool.start = side.units[id]
		pool.life = float(pool.start * def.combat.hp)
		pools.append(pool)
	return pools


## Men able to fight (siege engines and their crews do not count towards the rout).
static func _men(pools: Array[_Pool]) -> int:
	var total := 0
	for pool: _Pool in pools:
		if pool.siege == &"":
			total += pool.alive()
	return total


static func _noise(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(1.0 - NOISE, 1.0 + NOISE)


## Damage [param from] deals to [param to] in a round; in the volley and breach phases only the
## archers (reach > 1) shoot.
static func _damage(from: Array[_Pool], to: Array[_Pool], melee: bool, archers: bool) -> float:
	var targets := 0
	for pool: _Pool in to:
		if pool.siege != &"ram":
			targets += pool.alive()
	if targets == 0:
		return 0.0
	var total := 0.0
	for pool: _Pool in from:
		# Of the siege engines only the ballista fights men (J1 part 2): like an archer.
		if (pool.siege != &"" and pool.siege != Troops.BALLISTA) or pool.stats.attack <= 0:
			continue
		var ranged := pool.stats.attack_range > 1
		if not melee and not ranged:
			continue
		if ranged and not archers:
			continue
		var per_man := pool.stats.attack * ROUND_SECONDS / pool.stats.attack_cooldown * EFFICIENCY
		# The bonus against a kind of enemy counts by how many of them there are.
		var bonus := 0.0
		for target: _Pool in to:
			if target.siege == &"ram":
				continue
			bonus += float(target.alive()) / targets * float(pool.stats.bonus_vs.get(target.unit, 1.0))
		total += per_man * pool.alive() * bonus
	return total


## Spreads [param amount] of damage over the pools by their numbers (a ram takes arrows badly).
static func _take(pools: Array[_Pool], amount: float) -> void:
	var men := 0
	for pool: _Pool in pools:
		men += pool.alive()
	if men == 0 or amount <= 0.0:
		return
	for pool: _Pool in pools:
		var share := amount * pool.alive() / men
		pool.life = maxf(pool.life - share * pool.stats.ranged_taken, 0.0) if pool.siege == &"ram" \
				or pool.siege == Troops.BALLISTA else maxf(pool.life - share, 0.0)


## A side's warships: [full life, damage of a round at full life, soldiers they carry]. Ships
## without a fleet by kind are war cogs of the starting values.
static func _fleet(data: DataRegistry, side: BattleSide) -> Array[float]:
	if side.fleet.is_empty():
		return [float(side.ships * SHIP_HP), float(side.ships * SHIP_ATTACK), float(side.ships * SHIP_CAPACITY)]
	var life := 0.0
	var attack := 0.0
	var room := 0.0
	for id: StringName in side.fleet:
		var def := data.get_ship(id)
		var n := float(side.fleet[id])
		life += n * (def.hp if def != null else SHIP_HP)
		attack += n * (def.attack if def != null else SHIP_ATTACK)
		room += n * (def.troops if def != null and def.troops > 0 else SHIP_CAPACITY)
	return [life, attack, room]


## Bolts of a fleet in a round: as its hull life wears down, fewer of its ships still shoot.
static func _fleet_damage(fleet: Array[float], life: float, legacy: bool) -> float:
	if legacy:
		return _ship_damage(life)
	if life <= 0.0 or fleet[0] <= 0.0:
		return 0.0
	return fleet[1] * (life / fleet[0]) * ROUND_SECONDS / SHIP_COOLDOWN * EFFICIENCY


static func _ships_left(side: BattleSide, fleet: Array[float], life: float) -> int:
	if life <= 0.0 or side.ships == 0:
		return 0
	if side.fleet.is_empty():
		return mini(ceili(life / SHIP_HP - 0.0001), side.ships)
	return mini(ceili(side.ships * life / fleet[0] - 0.0001), side.ships)


## Soldiers the ships still afloat can carry.
static func _room(fleet: Array[float], life: float, left: int, legacy: bool) -> int:
	if legacy:
		return left * SHIP_CAPACITY
	if fleet[0] <= 0.0:
		return 0
	return roundi(fleet[2] * life / fleet[0])


static func _ship_damage(life: float) -> float:
	if life <= 0.0:
		return 0.0
	var ships := ceili(life / SHIP_HP - 0.0001)
	return ships * SHIP_ATTACK * ROUND_SECONDS / SHIP_COOLDOWN * EFFICIENCY


## Rounds the attackers need to get past [param fort]: the ram at the gate, ladders on a stone
## wall or men hacking at it, whichever is quickest; 0 when there are no walls.
static func _breach_rounds(pools: Array[_Pool], fort: BattleFort) -> int:
	if fort == null or fort.wall == Walls.NONE:
		return 0
	var best := INF
	var hackers := 0
	var hack := 0.0
	for pool: _Pool in pools:
		if pool.alive() == 0:
			continue
		match pool.siege:
			&"ram":
				if fort.gate_hp > 0:
					var per := pool.stats.attack * ROUND_SECONDS / pool.stats.attack_cooldown
					best = minf(best, ceilf(fort.gate_hp / (per * pool.alive())))
				var per_wall := pool.stats.attack * ROUND_SECONDS / pool.stats.attack_cooldown
				best = minf(best, ceilf(fort.wall_hp / (per_wall * pool.alive())))
			&"ladder":
				if fort.wall == Walls.STONE:
					best = minf(best, LADDER_ROUNDS)
			&"ballista":
				# Bolts chip at the wall or the gate from far away (J1 part 2): slowly.
				var per_bolt := pool.stats.attack * Troops.BALLISTA_WALL_SHARE * ROUND_SECONDS / pool.stats.attack_cooldown
				var weakest: float = fort.wall_hp if fort.gate_hp <= 0 else minf(fort.wall_hp, fort.gate_hp)
				best = minf(best, ceilf(weakest / (per_bolt * pool.alive())))
			&"":
				if pool.stats.attack_range == 1:
					var take := mini(pool.alive(), BREACH_WIDTH - hackers)
					hackers += take
					hack += take * pool.stats.attack * ROUND_SECONDS / pool.stats.attack_cooldown * EFFICIENCY
	if hack > 0.0:
		# The men must also get to the wall under the arrows: at least the approach.
		best = minf(best, maxf(ceilf(fort.wall_hp / hack), APPROACH_ROUNDS))
	return int(best) if best < INF else MAX_ROUNDS


static func _note(result: BattleResult, phase: Phase, rounds: int, a: Array[_Pool], b: Array[_Pool]) -> void:
	result.report.append({"phase": phase, "rounds": rounds, "a": _men(a), "b": _men(b)})


## A side whose ships afloat carry [param room] soldiers loses the men they cannot carry.
static func _drown(left: Dictionary[StringName, int], lost: Dictionary[StringName, int], room: int) -> void:
	var ids: Array[StringName] = []
	ids.assign(left.keys())
	ids.sort()
	for id: StringName in ids:
		var keep := mini(left[id], room)
		lost[id] = lost.get(id, 0) + left[id] - keep
		left[id] = keep
		room -= keep
