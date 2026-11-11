class_name FieldBattles
extends RefCounted
## Battles in the field (ROADMAP M8 part 2, owner's survey 2026-11-09): when the player's army
## meets an enemy army on the land, both stand still and the player chooses (the game pauses):
## - AUTO: BattleResolver decides it at once (FIELD, with the chances shown before),
## - LIVE: the battle is fought on the battlefield: the map of the province where they met,
##   without its town (Simulation.BATTLEFIELD); the armies stand facing each other about
##   2 * GAP tiles apart; the player commands his men as in M7, the enemy goes for them. It ends
##   when one side has nobody left on the map (fallen, or marched off: the player's retreat,
##   the enemy's rout below ROUT_SHARE); the survivors are their armies again and the province
##   viewed before comes back.
## Static helpers like Armies.

const AUTO := &"auto"
const LIVE := &"live"
## A pending battle is decided at once after this (only in a game nobody plays: the game pauses
## while the player chooses).
const PENDING_SECONDS := 120
## Tiles from the middle of the battlefield to each army.
const GAP := 10
## The enemy flees below this share of its men.
const ROUT_SHARE := 0.25


static func begin(sim: Simulation, mine: Army, enemy: Army) -> FieldBattle:
	var battle := FieldBattle.new()
	battle.id = sim.ids.take()
	battle.a = mine.id
	battle.b = enemy.id
	battle.pos = ArmyOrders._savable((mine.pos + enemy.pos) / 2.0)
	battle.province = ArmyOrders.nav(sim).province_at(battle.pos)
	if battle.province == 0:
		battle.province = mine.at if mine.at != 0 else enemy.at
	battle.until = sim.clock.tick + SimClock.seconds_to_ticks(PENDING_SECONDS)
	for army: Army in [mine, enemy]:
		army.state = Army.State.ENGAGED
		army.battle = battle.id
	sim.world.battles[battle.id] = battle
	sim.events.emit(&"field_battle_pending", {"battle": battle.id, "province": battle.province,
			"army": mine.id, "enemy": enemy.id})
	return battle


## The battle of [param army] (its FieldBattle), or null.
static func of(sim: Simulation, army: Army) -> FieldBattle:
	return sim.world.battles.get(army.battle) as FieldBattle if army != null else null


## The chance (0..1) the player's army has in battle [param battle] decided at once.
static func chances(sim: Simulation, battle: FieldBattle) -> float:
	var a := sim.world.armies.get(battle.a) as Army
	var b := sim.world.armies.get(battle.b) as Army
	if a == null or b == null:
		return 0.0
	return BattleResolver.chances(sim.data, a.side(), b.side(), BattleResolver.Kind.FIELD)


## The live battle being fought on the battlefield, or null.
static func live(sim: Simulation) -> FieldBattle:
	for battle: FieldBattle in sim.world.battles.values():
		if battle.state == FieldBattle.State.LIVE:
			return battle
	return null


## The province viewed before the battlefield (0 when not on it).
static func prev_view(sim: Simulation) -> int:
	var battle := live(sim)
	return battle.prev_view if battle != null else 0


static func choose_error(sim: Simulation, id: int, how: StringName) -> StringName:
	var battle := sim.world.battles.get(id) as FieldBattle
	if battle == null or battle.state != FieldBattle.State.PENDING:
		return &"no_battle"
	if how != AUTO and how != LIVE:
		return &"bad_order"
	if not sim.world.armies.has(battle.a) or not sim.world.armies.has(battle.b):
		return &"no_battle"
	if how == LIVE:
		if live(sim) != null:
			return &"army_in_battle"
		if _map_of(sim, battle.province) == null:
			return &"no_battlefield"
	return &""


static func choose(sim: Simulation, id: int, how: StringName) -> void:
	var battle := sim.world.battles[id]
	if how == LIVE:
		go_live(sim, battle)
	else:
		resolve(sim, battle)


## Decided at once (the "automatic" button).
static func resolve(sim: Simulation, battle: FieldBattle) -> BattleResult:
	var a := sim.world.armies.get(battle.a) as Army
	var b := sim.world.armies.get(battle.b) as Army
	sim.world.battles.erase(battle.id)
	if a == null or b == null:
		for army: Army in [a, b]:
			if army != null:
				ArmyMeetings.release(army)
		return null
	var result := Armies.battle(sim, a, b.side(), BattleResolver.Kind.FIELD, null, battle.province, b.owner, battle.pos)
	b.lose(result.lost_b)
	sim.events.emit(&"field_battle_over", {"battle": battle.id, "province": battle.province,
			"won": result.a_won(), "live": false})
	ArmyMeetings.after_battle(sim, a, b, result.a_won())
	return result


## Once a second: a pending battle nobody chose is decided; a live one ends when a side is gone.
static func update(sim: Simulation) -> void:
	var keys: Array[int] = []
	keys.assign(sim.world.battles.keys())
	keys.sort()
	for key: int in keys:
		var battle := sim.world.battles.get(key) as FieldBattle
		if battle == null:
			continue
		if battle.state == FieldBattle.State.PENDING:
			if sim.clock.tick >= battle.until or not sim.world.armies.has(battle.a) \
					or not sim.world.armies.has(battle.b):
				resolve(sim, battle)
		elif sim.viewed_id == Simulation.BATTLEFIELD:
			_update_live(sim, battle)


# --- On the battlefield ------------------------------------------------------------------------

static func _map_of(sim: Simulation, id: int) -> MapDef:
	var province := sim.world.get_province(id)
	return sim.data.get_map(province.map_id) if province != null else null


## The battle goes to the battlefield: the province viewed so far goes to the simplified mode,
## the map of the province where the armies met comes without its town, the armies stand on it.
static func go_live(sim: Simulation, battle: FieldBattle) -> void:
	var a := sim.world.armies[battle.a]
	var b := sim.world.armies[battle.b]
	var map := _map_of(sim, battle.province)
	var def := sim.world.def_of(battle.province, sim.data)
	var mirrored := def.mirrored if def != null else false
	var field := ProvinceSim.new(sim.data, map.size_for(mirrored), sim.events, sim.ids)
	field.treasury = sim.treasury
	field.tick = sim.clock.tick
	field.load_map(map, mirrored, def.richness if def != null else 2, true, def.rare_resource if def != null else &"",
			ProvinceDef.own_traits(def))
	field.first_building = &""
	field.landing = null
	battle.prev_view = sim.viewed_id
	battle.state = FieldBattle.State.LIVE
	battle.start_a = a.units.duplicate()
	battle.start_b = b.units.duplicate()
	sim.enter_battlefield(field)
	var middle := _open_ground(field, field.grid.size / 2, -1)
	var nav := field.mil.ground_nav(field, CombatState.PLAYER)
	var area := nav.area_of(middle) if middle != Agent.NO_TILE else -1
	var mine_at := _open_ground(field, middle + Vector2i(-GAP, 0), area)
	var theirs_at := _open_ground(field, middle + Vector2i(GAP, 0), area)
	_spawn(sim, field, a, mine_at, CombatState.PLAYER, Vector2(-1, -1))
	var faction := CombatState.BANDITS if b.owner == Army.BANDITS else CombatState.TOWN
	_spawn(sim, field, b, theirs_at, faction, IsoMath.tile_center(mine_at))
	sim.events.emit(&"battlefield_entered", {"battle": battle.id, "province": battle.province})


## The walkable ground tile nearest [param near] (in the part [param area] of the map; -1: any).
static func _open_ground(field: ProvinceSim, near: Vector2i, area: int) -> Vector2i:
	var nav := field.mil.ground_nav(field, CombatState.PLAYER)
	var size := field.grid.size
	near = near.clamp(Vector2i(2, 2), size - Vector2i(3, 3))
	for r: int in maxi(size.x, size.y):
		for y: int in range(near.y - r, near.y + r + 1):
			for x: int in range(near.x - r, near.x + r + 1):
				if absi(x - near.x) != r and absi(y - near.y) != r:
					continue
				var t := Vector2i(x, y)
				if nav.is_walkable(t) and (area < 0 or nav.area_of(t) == area):
					return t
	return near


## The men of [param army] stand on the battlefield in ranks round [param tile].
static func _spawn(sim: Simulation, field: ProvinceSim, army: Army, tile: Vector2i, faction: int,
		attack: Vector2) -> void:
	var kinds: Array[StringName] = []
	var ids: Array[StringName] = []
	ids.assign(army.units.keys())
	ids.sort()
	for unit: StringName in ids:
		for k: int in army.units[unit]:
			kinds.append(unit)
	army.units.clear()
	var spots := Troops.formation(field, tile, MilitaryNav.GROUND, kinds.size(), faction)
	for k: int in kinds.size():
		var at: Vector2 = spots[k % spots.size()] if not spots.is_empty() else IsoMath.tile_center(tile)
		var unit := kinds[k]
		var kind := unit
		if faction == CombatState.BANDITS:
			kind = {&"spearman": &"bandit", &"archer": &"bandit_archer"}.get(unit, unit)
		var agent := field.spawn_agent(kind, Vector2i(at.floor()))
		agent.pos = at
		agent.prev_pos = at
		agent.combat = CombatState.new(sim.data.get_unit(unit).combat.hp)
		agent.combat.unit = unit
		agent.combat.faction = faction
		agent.combat.army = army.id
		Troops.take_command(agent)
		agent.combat.order = CombatState.Order.MOVE
		agent.combat.stance = CombatState.Stance.AGGRESSIVE
		agent.combat.post = at
		agent.combat.goal = at
		if attack.x >= 0.0:
			agent.combat.goal = attack


## Men of army [param id] alive on the battlefield.
static func _on_field(field: ProvinceSim, id: int) -> Array[Agent]:
	var result: Array[Agent] = []
	for agent: Agent in field.agents.all():
		if agent.combat != null and agent.combat.army == id and agent.combat.hp > 0:
			result.append(agent)
	return result


static func _update_live(sim: Simulation, battle: FieldBattle) -> void:
	var field := sim.province
	var mine := _on_field(field, battle.a)
	var theirs := _on_field(field, battle.b)
	if mine.is_empty() or theirs.is_empty():
		finish(sim, battle, not mine.is_empty())
		return
	var start_b := 0
	for unit: StringName in battle.start_b:
		start_b += battle.start_b[unit]
	if not battle.routed and theirs.size() < start_b * ROUT_SHARE:
		battle.routed = true
		Troops.order_march(field, theirs, battle.b, Armies.exit_tile(field, theirs[0].tile(), theirs[0].combat.faction))
		sim.events.emit(&"enemy_routed", {"battle": battle.id})
		return
	if battle.routed:
		return
	# The enemy goes for the nearest of the player's men.
	for agent: Agent in theirs:
		if agent.combat.target_id != 0 or not Troops.fights_people(Troops.unit_of(field, agent)):
			continue
		var best: Agent = null
		var best_d := INF
		for other: Agent in mine:
			var d := other.pos.distance_squared_to(agent.pos)
			if d < best_d:
				best_d = d
				best = other
		if best != null:
			Troops.order_attack([agent], best)


## Why the player cannot call his men off the battlefield now, or &"".
static func retreat_error(sim: Simulation) -> StringName:
	var battle := live(sim)
	if battle == null or sim.viewed_id != Simulation.BATTLEFIELD:
		return &"no_battle"
	if _on_field(sim.province, battle.a).is_empty():
		return &"no_soldiers"
	return &""


## The player's men march off the battlefield (the battle is lost when the last one is off).
static func retreat(sim: Simulation) -> void:
	var battle := live(sim)
	var mine := _on_field(sim.province, battle.a)
	Troops.order_march(sim.province, mine, battle.a, Armies.exit_tile(sim.province, mine[0].tile(), CombatState.PLAYER))


## The live battle ends: the men left on the field are their armies again, the battle is
## reported, the province viewed before comes back.
static func finish(sim: Simulation, battle: FieldBattle, won: bool) -> void:
	var field := sim.province
	for agent: Agent in field.agents.all():
		var c := agent.combat
		if c == null or c.hp <= 0 or c.army == 0:
			continue
		var army := sim.world.armies.get(c.army) as Army
		var unit := Troops.unit_of(field, agent)
		if army != null and unit != null:
			army.add(unit.id)
	for entry: Dictionary in field.marched:
		var army := sim.world.armies.get(int(entry["army"])) as Army
		if army != null and entry.has("unit"):
			army.add(StringName(entry["unit"]))
	field.marched.clear()
	var a := sim.world.armies.get(battle.a) as Army
	var b := sim.world.armies.get(battle.b) as Army
	var result := BattleResult.new()
	result.winner = 0 if won else 1
	for unit: StringName in battle.start_a:
		var left: int = a.units.get(unit, 0) if a != null else 0
		result.left_a[unit] = left
		result.lost_a[unit] = maxi(battle.start_a[unit] - left, 0)
	for unit: StringName in battle.start_b:
		var left: int = b.units.get(unit, 0) if b != null else 0
		result.left_b[unit] = left
		result.lost_b[unit] = maxi(battle.start_b[unit] - left, 0)
	sim.world.report({"tick": sim.clock.tick, "province": battle.province, "kind": BattleResolver.Kind.FIELD,
			"attacker": String(ProvinceDef.OWNER_PLAYER), "defender": String(b.owner if b != null else &""),
			"result": result.to_dict(), "pos": [battle.pos.x, battle.pos.y], "live": true})
	sim.world.battles.erase(battle.id)
	sim.leave_battlefield(battle.prev_view)
	sim.events.emit(&"field_battle_over", {"battle": battle.id, "province": battle.province,
			"won": won, "live": true})
	if a != null and b != null:
		ArmyMeetings.after_battle(sim, a, b, won)
	else:
		for army: Army in [a, b]:
			if army != null:
				ArmyMeetings.release(army)
