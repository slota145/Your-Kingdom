class_name ArmyMeetings
extends RefCounted
## Enemy armies and fleets that meet on the world map fight (ROADMAP M8 part 2): armies of
## different sides on the land, or fleets at sea, nearer than MEET. In the field the player
## chooses how his army fights (FieldBattles: on the battlefield or at once); others fight at
## once (BattleResolver); fleets always fight at once (Fleets.sea_battle). The beaten side
## goes home (the player's, a ruler's), scatters (bandits) or is gone; it cannot be caught
## again for SAFE_SECONDS.

## How near (parchment pixels) two enemy armies or fleets have to be to fight.
const MEET := 24.0
## How near to the town (parchment pixels) an army that comes to it meets the ones standing there.
const AT_TOWN := 90.0
## Seconds a beaten army walks away unhindered.
const SAFE_SECONDS := 40


## Once a second, after the armies moved.
static func update(sim: Simulation) -> void:
	var list: Array[Army] = []
	var keys: Array[int] = []
	keys.assign(sim.world.armies.keys())
	keys.sort()
	for key: int in keys:
		var army := sim.world.armies[key]
		if _can_meet(sim, army):
			list.append(army)
	for i: int in list.size():
		for j: int in range(i + 1, list.size()):
			var a := list[i]
			var b := list[j]
			if not _can_meet(sim, a) or not _can_meet(sim, b) or a.owner == b.owner or a.by_sea != b.by_sea:
				continue
			if a.pos.distance_to(b.pos) > MEET or _at_peace(sim, a, b):
				continue
			# The one on the move attacks.
			if b.state == Army.State.MOVING and a.state != Army.State.MOVING:
				meet(sim, b, a)
			else:
				meet(sim, a, b)


## On the peaceful level (M8 part 4) the rulers' armies pass the player's by, unless the player
## goes after them.
static func _at_peace(sim: Simulation, a: Army, b: Army) -> bool:
	if not RulerWar.peaceful(sim):
		return false
	var player := a if a.owner == ProvinceDef.OWNER_PLAYER else b if b.owner == ProvinceDef.OWNER_PLAYER else null
	var other := b if player == a else a
	if player == null or not Rulers.is_ruler(other.owner):
		return false
	return player.chase != other.id


static func _can_meet(sim: Simulation, army: Army) -> bool:
	if not sim.world.armies.has(army.id) or army.pos == Vector2.INF:
		return false
	if army.state == Army.State.INSIDE or army.state == Army.State.ENGAGED:
		return false
	if army.safe_until > sim.clock.tick:
		return false
	return army.men() > 0 or army.ships > 0


## Enemies standing by the town [param army] came to fight it there (as in M7 part 3).
static func at_town(sim: Simulation, army: Army) -> bool:
	var def := sim.world.def_of(army.at, sim.data)
	if def == null:
		return false
	var keys: Array[int] = []
	keys.assign(sim.world.armies.keys())
	keys.sort()
	for key: int in keys:
		var other := sim.world.armies.get(key) as Army
		if other == null or other == army or other.owner == army.owner or other.by_sea \
				or other.state == Army.State.MOVING or not _can_meet(sim, other):
			continue
		if other.pos.distance_to(def.world_pos) <= AT_TOWN:
			meet(sim, army, other)
			return true
	return false


## [param a] meets the enemy [param b]: a battle now, or (the player's army in the field) the
## player's choice.
static func meet(sim: Simulation, a: Army, b: Army) -> void:
	if a.by_sea:
		Fleets.sea_battle(sim, a, b)
		return
	if a.owner == ProvinceDef.OWNER_PLAYER:
		FieldBattles.begin(sim, a, b)
		return
	if b.owner == ProvinceDef.OWNER_PLAYER:
		FieldBattles.begin(sim, b, a)
		return
	var result := Armies.battle(sim, a, b.side(), BattleResolver.Kind.FIELD, null, a.at, b.owner, a.pos)
	b.lose(result.lost_b)
	after_battle(sim, a, b, result.a_won())


## After a battle of [param a] against [param b]: the beaten one goes, the winner goes on.
static func after_battle(sim: Simulation, a: Army, b: Army, a_won: bool) -> void:
	var winner := a if a_won else b
	var loser := b if a_won else a
	if winner.chase == loser.id:
		winner.chase = 0
		winner.path.clear()
	release(winner)
	if winner.is_empty() and winner.ships == 0:
		beaten(sim, winner)
	beaten(sim, loser)


## An army out of its battle goes on its way (or stands).
static func release(army: Army) -> void:
	if army.state == Army.State.ENGAGED or army.state == Army.State.MOVING:
		army.state = Army.State.MOVING if not army.path.is_empty() else Army.State.IDLE
	army.battle = 0


## A beaten army (or fleet): bandits scatter, the others go home if they can, an empty one is
## gone.
static func beaten(sim: Simulation, army: Army) -> void:
	army.battle = 0
	army.chase = 0
	if army.state == Army.State.ENGAGED:
		army.state = Army.State.IDLE
	if army.is_empty() and army.ships == 0:
		if army.owner == Army.BANDITS:
			Armies._scatter(sim, army)
		else:
			Armies._disband(sim, army, &"army_lost")
		return
	if army.owner == Army.BANDITS and not army.by_sea:
		Armies._scatter(sim, army)
		return
	army.safe_until = sim.clock.tick + SimClock.seconds_to_ticks(SAFE_SECONDS)
	Armies._retreat_home(sim, army)
