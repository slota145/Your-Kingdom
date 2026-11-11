class_name RulerWar
extends RefCounted
## The AI rulers at war (ROADMAP M8 part 4, owner's survey 2026-11-10):
## - recruitment: a ruler's barracks take a free resident and twice the player's price in gold
##   for a soldier (no smith or bowyer behind it), up to an army that grows with the difficulty
##   and his provinces; his shipyards build warships once a cog is there,
## - the "commander" (every [constant EVERY] s per ruler): his strays and fleets go home, a
##   province threatened by an enemy army calls its campaign back and sallies against an enemy
##   waiting at its border when the odds are good; otherwise, once the time of grace is over,
##   he weighs the provinces nearest his strongest one (BattleResolver chances, walls counted)
##   and marches on the best he dares to take: another ruler, a neutral settlement or the
##   player (never on the peaceful level), by land or on his warships,
## - at the town: the player's viewed province is stormed live (as a raid of bandits, but the
##   hall taken means the town is taken), any other one is decided by BattleResolver against
##   its guards (a settlement's) or the soldiers of its barracks; taken, the province passes to
##   the ruler with its people and buildings (take_province), the defenders lay down their arms.
## The player takes a ruler's town the way he takes a neutral settlement (Armies), the
## ruler's barracks soldiers defending it. A ruler left without provinces is out of the game.
## Static helpers like Armies.

## The commander looks at the war every this many seconds (each ruler in his own second).
const EVERY := 10
## A province may recruit every this many seconds.
const RECRUIT_EVERY := 10
## A ruler's soldier costs this many times the player's gold (he has no smith; survey).
const COST_FACTOR := 2
## Gold a ruler keeps after paying a recruit.
const RESERVE_GOLD := 150
## By growth level (easy, normal, hard; peaceful = easy): minutes before the first attack,
## between two campaigns, soldiers he keeps (plus [constant PER_PROVINCE] for each further
## province), the chance of winning he needs to attack, the share of a province's soldiers
## that stays home, warships he wants.
const FIRST_MINUTES: Array[float] = [45.0, 30.0, 20.0]
const GAP_MINUTES: Array[float] = [12.0, 8.0, 5.0]
const ARMY_SIZE: Array[int] = [12, 20, 30]
const PER_PROVINCE := 6
const DARE: Array[float] = [0.8, 0.65, 0.5]
const KEEP_HOME: Array[float] = [0.5, 0.3, 0.2]
const WARSHIPS: Array[int] = [0, 1, 2]
## Men a campaign needs at least.
const MIN_FORCE := 6
## Provinces nearest the ruler's strongest one weighed for an attack.
const CANDIDATES := 4
## The units a ruler recruits in turn, by growth level.
const MIX: Array[Array] = [
	[&"spearman", &"spearman", &"archer"],
	[&"spearman", &"archer", &"spearman", &"swordsman", &"crossbowman"],
	[&"spearman", &"archer", &"swordsman", &"crossbowman", &"halberdier", &"man_at_arms", &"knight"],
]
## An enemy army this many seconds away from a province threatens it.
const THREAT_SECONDS := 90.0


static func level(sim: Simulation) -> int:
	return RulerPlanner.difficulty(sim)


static func peaceful(sim: Simulation) -> bool:
	return sim.world.settings != null and sim.world.settings.is_peaceful()


## Ticks of the time of grace before a ruler's first attack.
static func first_ticks(growth: int) -> int:
	return SimClock.seconds_to_ticks(FIRST_MINUTES[growth] * 60.0)


# --- Every second ----------------------------------------------------------------------------

static func update(sim: Simulation) -> void:
	if sim.world.is_single():
		return
	var second := sim.clock.tick / SimClock.TICKS_PER_SECOND
	var owners: Array[StringName] = []
	owners.assign(sim.world.rulers.keys())
	owners.sort()
	for k: int in owners.size():
		if not Rulers.is_raiders(owners[k]):   # (Invasion drives the raiders, M8 part 5)
			update_owner(sim, sim.world.rulers[owners[k]], second, k)


## Recruits and the commander of [param ruler], the [param k]-th ruler (the automatic player of
## the test games too, M8 part 5).
static func update_owner(sim: Simulation, ruler: RulerState, second: int, k: int) -> void:
	var provinces := Rulers.provinces_of(sim.world, ruler.owner)
	if provinces.is_empty():
		if Rulers.is_ruler(ruler.owner):
			_out_of_game(sim, ruler)
		return
	for id: int in provinces:
		if (second + id) % RECRUIT_EVERY == 0:
			recruit(sim, ruler, id)
	if (second + k * 3) % EVERY == 0:
		command(sim, ruler)


## A ruler without provinces: his armies and fleets are gone, the player is told once.
static func _out_of_game(sim: Simulation, ruler: RulerState) -> void:
	if ruler.defeated:
		return
	ruler.defeated = true
	ruler.campaign = 0
	for id: int in sim.world.armies.keys().duplicate():
		var army := sim.world.armies[id]
		if army.owner == ruler.owner and army.state != Army.State.ENGAGED and army.state != Army.State.INSIDE:
			sim.world.armies.erase(id)
	sim.events.emit(&"ruler_defeated", {"owner": ruler.owner})


# --- Soldiers and warships -------------------------------------------------------------------

## Soldiers of [param owner]: in his barracks and in his armies.
static func strength(sim: Simulation, owner: StringName) -> int:
	var total := 0
	for id: int in Rulers.provinces_of(sim.world, owner):
		total += _count(defenders(sim, id))
	for army: Army in sim.world.armies.values():
		if army.owner == owner:
			total += army.men()
	return total


## The soldiers a ruler wants: by difficulty, more with more provinces.
static func wanted(sim: Simulation, owner: StringName) -> int:
	var n := ARMY_SIZE[level(sim)] + PER_PROVINCE * maxi(Rulers.provinces_of(sim.world, owner).size() - 1, 0)
	# In the Merchant islands they save for the gold race (M8 part 5): half the army.
	return n / 2 if RulerExpansion.trader(sim) else n


## One recruit in province [param id] of [param ruler] when his barracks have a bed, he is
## short of soldiers and can pay; returns the unit, or &"".
static func recruit(sim: Simulation, ruler: RulerState, id: int) -> StringName:
	var town := sim.province_state(id)
	if town == null:
		return &""
	var have := strength(sim, ruler.owner)
	if have >= wanted(sim, ruler.owner):
		return &""
	var mix: Array = MIX[level(sim)]
	var unit := sim.data.get_unit(mix[have % mix.size()])
	if unit == null:
		return &""
	# A bed for him (E4 part 4: the small barracks house archers and spearmen only); else any
	# unit a barracks with a bed takes, in the order of the mix.
	var barracks := Barracks.with_bed_for(town, unit.id)
	var k := 1
	while barracks == null and k < mix.size():
		unit = sim.data.get_unit(mix[(have + k) % mix.size()])
		barracks = Barracks.with_bed_for(town, unit.id) if unit != null else null
		k += 1
	if barracks == null:
		return &""
	var cost := unit.gold_cost * COST_FACTOR
	if ruler.treasury.gold < cost + RESERVE_GOLD:
		return &""
	var house: BuildingState = null
	for building: BuildingState in town.buildings.all():
		if building.house != null and building.house.residents >= 2 \
				and (house == null or building.house.residents > house.house.residents):
			house = building
	if house == null:
		return &""
	house.house.residents -= 1
	ruler.treasury.pay(cost)
	enlist(sim, town, barracks, unit.id, id == sim.viewed_id)
	sim.events.emit(&"ruler_recruited", {"owner": ruler.owner, "province": id, "unit": unit.id})
	_warships(sim, ruler, town)
	return unit.id


## A soldier of [param unit] moves into [param barracks]: by number, or (the province viewed)
## as a person at its door.
static func enlist(sim: Simulation, town: ProvinceSim, barracks: BuildingState, unit: StringName, viewed: bool) -> void:
	if not viewed:
		barracks.garrison.append(unit)
		return
	var def := sim.data.get_unit(unit)
	var agent := town.spawn_agent(unit, barracks.entrance_tile())
	agent.home_id = barracks.id
	agent.combat = CombatState.new(def.combat.hp if def.combat != null else 100)
	agent.combat.faction = town.home_faction
	barracks.soldiers.append(agent.id)


## The ruler's shipyard lays down a warship when he has fewer than he wants (and a cog for
## his expeditions already, RulerPlanner.steward).
static func _warships(sim: Simulation, ruler: RulerState, town: ProvinceSim) -> void:
	var want: int = WARSHIPS[level(sim)]
	if want <= 0:
		return
	var have := 0
	var cogs := 0
	for ship: ShipUnit in town.ships.values():
		if ship.def.troops > 0:
			have += 1
		elif ship.def.id == &"cog":
			cogs += 1
	for army: Army in sim.world.armies.values():
		if army.owner == ruler.owner:
			have += army.ships
	if have >= want or cogs == 0:
		return
	for building: BuildingState in town.buildings.all():
		if building.def.id == &"shipyard" and building.is_complete() and building.ship_orders.is_empty() \
				and Ships.build_at(town, building) == null:
			building.ship_orders.append(&"warship")
			return


## The soldiers defending province [param id]: a settlement's guards, or the soldiers of its
## barracks (by number, and the ones walking about while it is viewed).
static func defenders(sim: Simulation, id: int) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	var settlement := sim.world.settlements.get(id) as NeutralSettlement
	if settlement != null:
		return settlement.guards.duplicate()
	var town := sim.province_state(id)
	if town == null:
		return result
	for building: BuildingState in town.buildings.all():
		if building.def.soldier_beds <= 0:
			continue
		for unit: StringName in building.garrison:
			result[unit] = result.get(unit, 0) + 1
		if id == sim.viewed_id:
			for agent_id: int in building.soldiers:
				var agent := town.agents.get_agent(agent_id)
				if agent != null and agent.combat != null and agent.combat.hp > 0:
					result[agent.kind] = result.get(agent.kind, 0) + 1
	return result


## Takes [param lost] (unit -> men) off the defenders of province [param id].
static func lose_defenders(sim: Simulation, id: int, lost: Dictionary[StringName, int]) -> void:
	var settlement := sim.world.settlements.get(id) as NeutralSettlement
	if settlement != null:
		for unit: StringName in lost:
			settlement.guards[unit] = maxi(settlement.guards.get(unit, 0) - lost[unit], 0)
			if settlement.guards[unit] == 0:
				settlement.guards.erase(unit)
		return
	var town := sim.province_state(id)
	if town == null:
		return
	for unit: StringName in lost:
		var left := lost[unit]
		for building: BuildingState in town.buildings.all():
			while left > 0 and building.garrison.has(unit):
				building.garrison.erase(unit)
				left -= 1
			if id != sim.viewed_id:
				continue
			for agent_id: int in building.soldiers.duplicate():
				if left <= 0:
					break
				var agent := town.agents.get_agent(agent_id)
				if agent != null and agent.kind == unit:
					building.soldiers.erase(agent_id)
					town.remove_agent(agent)
					left -= 1


# --- The commander ---------------------------------------------------------------------------

static func command(sim: Simulation, ruler: RulerState) -> void:
	var campaign := sim.world.armies.get(ruler.campaign) as Army
	if ruler.campaign != 0 and (campaign == null or campaign.state == Army.State.IDLE):
		ruler.campaign = 0   # gone, or done (it stands about now and goes home with the rest)
		ruler.war_target = 0
	_tidy(sim, ruler)
	if _defend(sim, ruler):
		return
	if ruler.campaign == 0 and sim.clock.tick >= ruler.next_war:
		attack(sim, ruler)


## Armies standing about away from home and fleets idle at sea go home.
static func _tidy(sim: Simulation, ruler: RulerState) -> void:
	var keys: Array[int] = []
	keys.assign(sim.world.armies.keys())
	keys.sort()
	for key: int in keys:
		var army := sim.world.armies.get(key) as Army
		if army == null or army.owner != ruler.owner or army.state != Army.State.IDLE or army.id == ruler.campaign:
			continue
		if army.is_fleet():
			var port := army.fleet_home if sim.world.owner_of(army.fleet_home) == ruler.owner \
					else _nearest_own(sim, ruler.owner, army.pos, true)
			if port != 0:
				go(sim, army, port)
			continue
		if sim.world.owner_of(army.at) == ruler.owner:
			if Armies.join_barracks(sim, army):
				continue
			if army.at == army.home or sim.world.owner_of(army.home) != ruler.owner:
				continue   # (no bed left: it stands by the town)
		var home := army.home if sim.world.owner_of(army.home) == ruler.owner \
				else _nearest_own(sim, ruler.owner, army.pos, false)
		if home != 0:
			go(sim, army, home)


static func _nearest_own(sim: Simulation, owner: StringName, from: Vector2, coastal: bool) -> int:
	var best := 0
	var best_d := INF
	for id: int in Rulers.provinces_of(sim.world, owner):
		var def := sim.world.def_of(id, sim.data)
		if def == null or (coastal and not def.coastal):
			continue
		var d := from.distance_to(def.world_pos)
		if d < best_d:
			best_d = d
			best = id
	return best


## A province of the ruler threatened by an enemy army: the campaign comes back to it, and its
## soldiers sally against an enemy waiting at its border when they are likely to win. Returns
## whether there was a threat.
static func _defend(sim: Simulation, ruler: RulerState) -> bool:
	var threatened := false
	var keys: Array[int] = []
	keys.assign(sim.world.armies.keys())
	keys.sort()
	for key: int in keys:
		var enemy := sim.world.armies.get(key) as Army
		if enemy == null or enemy.owner == ruler.owner or enemy.owner == Army.BANDITS or enemy.by_sea:
			continue
		var id := 0
		if enemy.state == Army.State.WAITING and sim.world.owner_of(enemy.at) == ruler.owner:
			id = enemy.at
		elif enemy.state == Army.State.MOVING and enemy.target != 0 \
				and sim.world.owner_of(enemy.target) == ruler.owner \
				and ArmyOrders.seconds_left(sim, enemy) <= THREAT_SECONDS:
			id = enemy.target
		if id == 0:
			continue
		threatened = true
		var campaign := sim.world.armies.get(ruler.campaign) as Army
		if campaign != null and campaign.state == Army.State.MOVING and not campaign.by_sea \
				and campaign.target != id:
			go(sim, campaign, id)
			ruler.war_target = id
		if enemy.state == Army.State.WAITING and id != sim.viewed_id:
			_sally(sim, ruler, id, enemy)
	return threatened


static func _sally(sim: Simulation, ruler: RulerState, id: int, enemy: Army) -> void:
	var men := defenders(sim, id)
	if _count(men) < MIN_FORCE:
		return
	var odds := BattleResolver.chances(sim.data, BattleSide.new(men), enemy.side(), BattleResolver.Kind.FIELD)
	if odds < DARE[level(sim)]:
		return
	var army := _raise(sim, ruler, id, men)
	if army == null:
		return
	army.chase = enemy.id
	ArmyOrders.order_chase(sim, army, enemy.id)
	sim.events.emit(&"ruler_sallied", {"owner": ruler.owner, "province": id, "army": army.id})


## Weighs the provinces nearest the ruler's strongest one and marches on the best he dares to
## take. Returns the army sent, or null.
static func attack(sim: Simulation, ruler: RulerState) -> Army:
	var growth := level(sim)
	var source := 0
	var most := 0
	for id: int in Rulers.provinces_of(sim.world, ruler.owner):
		if id == sim.viewed_id and Rulers.is_ruler(ruler.owner):
			continue   # (the player watches it: nobody marches off under his eyes)
		var n := _count(defenders(sim, id))
		if n > most:
			most = n
			source = id
	if source == 0:
		return null
	var force := _force(defenders(sim, source), 1.0 - KEEP_HOME[growth])
	if _count(force) < MIN_FORCE:
		return null
	var from := sim.world.def_of(source, sim.data).world_pos
	var candidates: Array[int] = []
	for id: int in sim.world.ids():
		if target_ok(sim, ruler.owner, id):
			candidates.append(id)
	candidates.sort_custom(func(a: int, b: int) -> bool:
		var da := from.distance_to(sim.world.def_of(a, sim.data).world_pos)
		var db := from.distance_to(sim.world.def_of(b, sim.data).world_pos)
		return da < db or (da == db and a < b))
	var probe := Army.new()
	probe.owner = ruler.owner
	probe.at = source
	probe.home = source
	probe.state = Army.State.IDLE
	probe.pos = ArmyOrders.stand_point(sim, source)
	probe.units = force
	var best := 0
	var best_odds := 0.0
	var best_way := {}
	var best_units: Dictionary[StringName, int] = {}
	for id: int in candidates.slice(0, CANDIDATES):
		var way := ArmyOrders.plan(sim, probe, id, Vector2.INF)
		if way["error"] != &"":
			continue
		var town := sim.province_state(id)
		var units := force.duplicate()
		_engines(town, units)
		var odds := BattleResolver.chances(sim.data, BattleSide.new(units), BattleSide.new(defenders(sim, id)),
				BattleResolver.Kind.SIEGE, Armies.fort_of(town))
		if odds >= DARE[growth] and odds > best_odds:
			best = id
			best_odds = odds
			best_way = way
			best_units = units
	if best == 0:
		ruler.next_war = sim.clock.tick + SimClock.seconds_to_ticks(60.0)
		return null
	var army := _raise(sim, ruler, source, force)
	if army == null:
		return null
	for unit: StringName in best_units:
		if not force.has(unit):
			army.add(unit, best_units[unit])   # laddermen and a ram come along
	army.food = army.food_cap()
	ArmyOrders.follow(sim, army, ArmyOrders.plan(sim, army, best, Vector2.INF), best)
	ruler.campaign = army.id
	ruler.war_target = best
	ruler.next_war = sim.clock.tick + SimClock.seconds_to_ticks(GAP_MINUTES[growth] * 60.0)
	sim.events.emit(&"ruler_marched", {"owner": ruler.owner, "province": best, "from": source,
			"army": army.id, "against": sim.world.owner_of(best),
			"seconds": ArmyOrders.seconds_left(sim, army)})
	return army


## Whether [param owner] may attack province [param id]: someone else's town with a seat (the
## player's not on the peaceful level, nor in its time of grace).
static func target_ok(sim: Simulation, owner: StringName, id: int) -> bool:
	var other := sim.world.owner_of(id)
	if other == owner or other == ProvinceDef.OWNER_NONE or other == Army.BANDITS:
		return false
	var town := sim.province_state(id)
	# The raiders go for any town of the player (its town hall, or its pioneer camp), in the
	# time of grace too (M8 part 5).
	if Rulers.is_raiders(owner):
		return other == ProvinceDef.OWNER_PLAYER and town != null
	if town == null or not town.has_stronghold():
		return false
	if other == ProvinceDef.OWNER_PLAYER:
		if peaceful(sim) or town.grace_until > sim.clock.tick:
			return false
	elif other == ProvinceDef.OWNER_NEUTRAL and not sim.world.settlements.has(id):
		return false
	return true


## [param share] of [param men], each kind rounded down (at least one of the biggest kind).
static func _force(men: Dictionary[StringName, int], share: float) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	var keys: Array[StringName] = []
	keys.assign(men.keys())
	keys.sort()
	for unit: StringName in keys:
		var n := floori(men[unit] * share)
		if n > 0:
			result[unit] = n
	return result


## Laddermen at stone walls, a ram at a gate (they come with the army, as with the bandits).
static func _engines(town: ProvinceSim, units: Dictionary[StringName, int]) -> void:
	if town == null:
		return
	if Raids.has_stone_walls(town):
		units[&"ladderman"] = units.get(&"ladderman", 0) + 2
	if Raids.has_gate(town):
		units[&"ram"] = units.get(&"ram", 0) + 1


## An army of [param men] out of the barracks of province [param id], standing by its town.
static func _raise(sim: Simulation, ruler: RulerState, id: int, men: Dictionary[StringName, int]) -> Army:
	var town := sim.province_state(id)
	if town == null:
		return null
	var army := Army.new()
	army.id = sim.ids.take()
	army.owner = ruler.owner
	army.at = id
	army.home = id
	army.state = Army.State.IDLE
	army.pos = ArmyOrders.stand_point(sim, id)
	for unit: StringName in men:
		var want := men[unit]
		for building: BuildingState in town.buildings.all():
			while want > 0 and building.garrison.has(unit):
				building.garrison.erase(unit)
				army.add(unit)
				want -= 1
		if want > 0 and id == sim.viewed_id:
			for building: BuildingState in town.buildings.all():
				for agent_id: int in building.soldiers.duplicate():
					var agent := town.agents.get_agent(agent_id)
					if want > 0 and agent != null and agent.kind == unit:
						building.soldiers.erase(agent_id)
						town.remove_agent(agent)
						army.add(unit)
						want -= 1
	if army.is_empty():
		return null
	army.food = army.food_cap()
	sim.world.armies[army.id] = army
	return army


## Sends a ruler's army (or fleet) to the town of [param to]; false when it has no way.
static func go(sim: Simulation, army: Army, to: int) -> bool:
	var way := ArmyOrders.plan(sim, army, to, Vector2.INF)
	if way["error"] != &"":
		return false
	army.chase = 0
	ArmyOrders.follow(sim, army, way, to)
	return true


# --- At the town -----------------------------------------------------------------------------

## A ruler's army at the end of its way to a town (Armies.arrive_on_land): at home it goes into
## the barracks; at a town it may attack, it storms it; otherwise it turns home.
static func arrive(sim: Simulation, army: Army) -> void:
	var ruler := sim.world.rulers.get(army.owner) as RulerState
	var owner := sim.world.owner_of(army.at)
	army.state = Army.State.IDLE
	if owner == army.owner:
		Armies.join_barracks(sim, army)
		return
	if not target_ok(sim, army.owner, army.at):
		_home(sim, army)
		return
	assault(sim, army)
	if ruler != null and not sim.world.armies.has(ruler.campaign):
		ruler.campaign = 0
		ruler.war_target = 0


## The army storms the town it stands at: live in the player's viewed province, at once
## (BattleResolver) anywhere else.
static func assault(sim: Simulation, army: Army) -> void:
	var id := army.at
	var owner := sim.world.owner_of(id)
	var town := sim.province_state(id)
	if owner == ProvinceDef.OWNER_PLAYER and id == sim.viewed_id and not town.raids.is_active():
		var entry := Raids.start_army(town, sim.rng.stream(&"raids"), army.units, army.id, not army.plunder, true)
		if entry != Agent.NO_TILE:
			army.units.clear()
			army.entry = entry
			army.state = Army.State.INSIDE
			sim.events.emit(&"ruler_storming", {"owner": army.owner, "province": id, "plunder": army.plunder})
			return
	var result := Armies.battle(sim, army, BattleSide.new(defenders(sim, id)), BattleResolver.Kind.SIEGE,
			Armies.fort_of(town), id, owner)
	lose_defenders(sim, id, result.lost_b)
	if result.a_won() and not army.is_empty() and army.plunder:
		# A wave that only plunders (the Invasion): it loots like bandits and sails away.
		army.loot_gold += Raids.loot(town, town.stronghold()) if town.stronghold() != null else 0
		town.raids.loot_gold = 0
		sim.events.emit(&"province_raided", {"province": id, "gold": army.loot_gold})
		army.state = Army.State.IDLE
		return
	if result.a_won() and not army.is_empty():
		take_province(sim, id, army.owner)
		army.state = Army.State.IDLE
		Armies.join_barracks(sim, army)
		return
	if owner == ProvinceDef.OWNER_PLAYER:
		sim.events.emit(&"raid_beaten_off", {"province": id})
	if army.is_empty():
		Armies._disband(sim, army, &"army_lost")
		return
	army.safe_until = sim.clock.tick + SimClock.seconds_to_ticks(ArmyMeetings.SAFE_SECONDS)
	_home(sim, army)


static func _home(sim: Simulation, army: Army) -> void:
	var home := army.home if sim.world.owner_of(army.home) == army.owner \
			else _nearest_own(sim, army.owner, army.pos, false)
	if home == 0 or not go(sim, army, home):
		army.state = Army.State.IDLE


## Province [param id] passes to [param owner] by force (a ruler's or the player's army took
## its hall): people and buildings stay and lose heart (Raids.capture), the defenders lay
## down their arms, the door is mended, routes of the former owner through it end.
static func take_province(sim: Simulation, id: int, owner: StringName) -> void:
	var before := sim.world.owner_of(id)
	sim.world.settlements.erase(id)
	var town := sim.province_state(id)
	var viewed := id == sim.viewed_id
	if town != null:
		for building: BuildingState in town.buildings.all():
			if building.def.soldier_beds <= 0:
				continue
			building.garrison.clear()
			if viewed:
				for agent_id: int in building.soldiers + building.recruits:
					var agent := town.agents.get_agent(agent_id)
					if agent != null:
						town.remove_agent(agent)
			building.soldiers.clear()
			building.recruits.clear()
		if viewed:
			for agent: Agent in town.agents.all():
				if agent.combat != null and agent.combat.faction == town.home_faction and agent.combat.army == 0:
					town.remove_agent(agent)
	Raids.capture(sim, id, owner)
	if town != null:
		town.home_faction = sim.faction_of(id)
		town.treasury = sim.treasury_of(owner)
		if viewed:
			for agent: Agent in town.agents.all():
				if agent.task != null and agent.task.kind == Task.KIND_SHELTER:
					TaskRunner.fail(town, agent)
		var hall := town.stronghold()
		if hall != null and hall.def.max_hp > 0:
			hall.hp = hall.def.max_hp
	for route: TradeRoute in sim.world.routes.values().duplicate():
		if route.from == id or route.to == id:
			if sim.world.owner_of(route.from) != sim.world.owner_of(route.to) \
					or sim.world.owner_of(route.from) != before:
				TradeRoutes.remove(sim, route)
	var ruler := sim.world.rulers.get(before) as RulerState
	if ruler != null:
		ruler.next_build.erase(id)
		if ruler.saving_for == id:
			ruler.saving_for = 0
	sim.events.emit(&"province_taken", {"province": id, "owner": owner, "from": before})


# --- The ruler's soldiers in the viewed town ----------------------------------------------------

## The soldiers of the barracks of the viewed ruler's town come out as its guards (the player's
## army storms it): they stand at the hall's door like a settlement's guards.
static func guards_out(sim: Simulation, id: int) -> Dictionary[StringName, int]:
	var men: Dictionary[StringName, int] = {}
	if id != sim.viewed_id or not Rulers.is_ruler(sim.world.owner_of(id)):
		return men
	var town := sim.province
	for building: BuildingState in town.buildings.all():
		if building.def.soldier_beds <= 0:
			continue
		for unit: StringName in building.garrison:
			men[unit] = men.get(unit, 0) + 1
		building.garrison.clear()
		for agent_id: int in building.soldiers:
			var agent := town.agents.get_agent(agent_id)
			if agent != null and agent.combat != null and agent.combat.hp > 0:
				men[agent.kind] = men.get(agent.kind, 0) + 1
			if agent != null:
				town.remove_agent(agent)
		building.soldiers.clear()
	return men


## A guard of a ruler's town (no home) goes back into a barracks as the province is folded.
static func guard_home(town: ProvinceSim, unit: StringName) -> bool:
	var home: BuildingState = null
	for building: BuildingState in town.buildings.all():
		if building.def.soldier_beds > 0 and building.is_complete():
			if building.def.houses_unit(unit):
				home = building
				break
			if home == null:
				home = building   # no barracks of his kind: any (he must not be lost)
	if home == null:
		return false
	home.garrison.append(unit)
	return true


## Soldiers of the barracks of the province just viewed fight for its owner (a ruler's town:
## the town's side).
static func set_factions(town: ProvinceSim) -> void:
	for building: BuildingState in town.buildings.all():
		if building.def.soldier_beds <= 0:
			continue
		for agent_id: int in building.soldiers + building.recruits:
			var agent := town.agents.get_agent(agent_id)
			if agent != null and agent.combat != null:
				agent.combat.faction = town.home_faction


static func _count(units: Dictionary[StringName, int]) -> int:
	var total := 0
	for unit: StringName in units:
		total += units[unit]
	return total
