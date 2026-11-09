class_name Armies
extends RefCounted
## Armies on the world map (GDD §6.3, §7, §8, ROADMAP M7 part 3):
## - the player's soldiers march out of the viewed province (to the edge of the map) and stand
##   by the town as an army; the player sends it to a province (by land through neighbours, by
##   sea on warships); it eats bread on the way and tops it up in his provinces,
## - in his own province with barracks it goes back into them; at a neutral settlement it
##   waits for the player: a fight in the province's view (EnterProvinceCommand with the
##   army) or at once by BattleResolver; taking the town hall takes the settlement,
## - the bandits' camp sends raids as armies; the player's army in their way meets them in
##   the field; a raid on the viewed province is fought there (Raids), on another one
##   BattleResolver decides it; the player's army can break the camp.
## Runs once a second (Simulation._update_world); soldiers who marched off the map join their
## army in the same tick (absorb).

## How often an army standing in the player's province tops its bread up (s).
const REFILL_SECONDS := 10
## The bandits' raid: men (every third an archer), laddermen at stone walls, a ram every
## third raid at a gate (as in part 2).
const RAID_MIN := 4
const RAID_MAX := 8
## Seconds before a raid arrives that the viewed province is warned.
const WARNING_SECONDS := 60.0
## The camp takes back at most this many of its raiders (the rest scatter).
const CAMP_MAX := 12


# --- Marching out --------------------------------------------------------------------------

## Why [param agents] cannot march out of the viewed province now, or &"".
static func march_error(sim: Simulation, agents: Array[Agent]) -> StringName:
	if sim.world.is_single():
		return &"no_world"
	if sim.world.owner_of(sim.viewed_id) != ProvinceDef.OWNER_PLAYER:
		return &"not_your_province"
	if agents.is_empty():
		return &"no_soldiers"
	if exit_tile(sim.province, agents[0].tile(), CombatState.PLAYER) == Agent.NO_TILE:
		return &"no_way_out"
	return &""


## The soldiers walk to the edge of the map; a new army waits for them there (INSIDE until the
## last one is off the map).
static func march_out(sim: Simulation, agents: Array[Agent]) -> Army:
	var province := sim.province
	var army := Army.new()
	army.id = sim.ids.take()
	army.owner = ProvinceDef.OWNER_PLAYER
	army.state = Army.State.INSIDE
	army.at = sim.viewed_id
	army.home = sim.viewed_id
	army.entry = exit_tile(province, agents[0].tile(), CombatState.PLAYER)
	army.pos = ArmyOrders.stand_point(sim, army.at)
	sim.world.armies[army.id] = army
	Troops.order_march(province, agents, army.id, army.entry)
	sim.events.emit(&"army_marching", {"army": army.id, "province": army.at})
	return army


## The edge tile of the map nearest [param from] that [param faction] can walk to.
static func exit_tile(province: ProvinceSim, from: Vector2i, faction: int) -> Vector2i:
	var nav := province.mil.ground_nav(province, faction)
	if not nav.is_walkable(from):
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			if nav.is_walkable(from + step):
				from = from + step
				break
	if not nav.is_walkable(from):
		return Agent.NO_TILE
	var area := nav.area_of(from)
	var size := province.grid.size
	var best := Agent.NO_TILE
	var best_d := INF
	var edge: Array[Vector2i] = []
	for i: int in range(2, size.x - 2):
		edge.append(Vector2i(i, 1))
		edge.append(Vector2i(i, size.y - 2))
	for i: int in range(2, size.y - 2):
		edge.append(Vector2i(1, i))
		edge.append(Vector2i(size.x - 2, i))
	for t: Vector2i in edge:
		if nav.is_walkable(t) and nav.area_of(t) == area:
			var d := Vector2(t - from).length_squared()
			if d < best_d:
				best_d = d
				best = t
	return best


## Soldiers (and bandits) who marched off the viewed map this tick join their armies.
static func absorb(sim: Simulation) -> void:
	for entry: Dictionary in sim.province.marched:
		var army := sim.world.armies.get(int(entry["army"])) as Army
		if army == null:
			continue
		if entry.has("ship"):
			army.ships += 1
			var ship := StringName(entry["ship"])
			army.fleet[ship] = army.fleet.get(ship, 0) + 1
		else:
			army.add(StringName(entry["unit"]))
	sim.province.marched.clear()


# --- Orders ----------------------------------------------------------------------------------

## Why [param army] cannot be sent to the town of province [param to] now, or &"" (the world
## map shows it). Any spot of the map: ArmyOrders.order_error (M8 part 2).
static func send_error(sim: Simulation, army: Army, to: int) -> StringName:
	if sim.world.get_province(to) == null:
		return &"unknown_province"
	return ArmyOrders.order_error(sim, army, to, Vector2.INF)


## Warships of province [param id] ready to carry an army: finished, not under way.
static func warships_at(sim: Simulation, id: int) -> Array[ShipUnit]:
	var result: Array[ShipUnit] = []
	if sim.world.owner_of(id) != ProvinceDef.OWNER_PLAYER:
		return result
	var province := sim.province_state(id)
	if province == null:
		return result
	var keys: Array[int] = []
	keys.assign(province.ships.keys())
	keys.sort()
	for key: int in keys:
		var ship := province.ships[key]
		# A warship with soldiers of the province aboard stays (P2 part 2, survey 2026-11-09).
		if ship.def.troops > 0 and ship.troops.is_empty() and ship.boarding.is_empty() and ship.sail_out == 0:
			result.append(ship)
	return result


## Whether [param army] would sail to [param to] on the warships of its province (there is no
## way by land, or the sea is quicker).
static func goes_by_sea(sim: Simulation, army: Army, to: int) -> bool:
	var way := ArmyOrders.plan(sim, army, to, Vector2.INF)
	return way["error"] == &"" and bool(way["board"])


## Sends [param army] on its way to the town of [param to] (checked with [method send_error]).
static func send(sim: Simulation, army: Army, to: int) -> void:
	ArmyOrders.order(sim, army, to, Vector2.INF)


## Disbanding in the player's province: the men go into its barracks (as many as fit).
static func disband_error(sim: Simulation, army: Army) -> StringName:
	if army == null or army.owner != ProvinceDef.OWNER_PLAYER:
		return &"no_army"
	if army.state != Army.State.IDLE or sim.world.owner_of(army.at) != ProvinceDef.OWNER_PLAYER:
		return &"not_at_home"
	if _free_beds(sim, army.at) <= 0:
		return &"barracks_full"
	return &""


# --- Every second ----------------------------------------------------------------------------

static func update(sim: Simulation) -> void:
	var world := sim.world
	if world.is_single():
		return
	var keys: Array[int] = []
	keys.assign(world.armies.keys())
	keys.sort()
	for id: int in keys:
		var army := world.armies.get(id) as Army
		if army == null:
			continue
		if army.pos == Vector2.INF and army.state != Army.State.INSIDE:
			_place_old(sim, army)
			if not world.armies.has(id):
				continue
		match army.state:
			Army.State.INSIDE:
				_inside(sim, army)
			Army.State.MOVING:
				_eat(army, 1.0)
				var ended := ArmyOrders.step(sim, army, 1.0)
				_warn(sim, army)
				if ended and army.state == Army.State.MOVING:
					_arrive(sim, army)
			Army.State.IDLE, Army.State.WAITING:
				_eat(army, 1.0)
				if not army.by_sea and world.owner_of(army.at) == ProvinceDef.OWNER_PLAYER \
						and sim.clock.tick % SimClock.seconds_to_ticks(REFILL_SECONDS) == 0:
					_refill(sim, army)
			Army.State.ENGAGED:
				_eat(army, 1.0)
	FieldBattles.update(sim)
	ArmyMeetings.update(sim)
	if sim.raids_enabled:
		_update_camp(sim)


## An army from a save of before M8 part 2 (no place on the map yet): it stands by its
## province's town (or at the border of a foreign one), and one on its way goes on to its goal.
static func _place_old(sim: Simulation, army: Army) -> void:
	var goal := army.target
	if army.owner == Army.BANDITS:
		var def := sim.world.def_of(army.at, sim.data)
		army.pos = def.world_pos if def != null else Vector2.ZERO
	elif army.by_sea and army.ships > 0:
		army.pos = ArmyOrders.offshore(sim, army.at)
		if army.pos == Vector2.INF:
			army.pos = ArmyOrders.stand_point(sim, army.at)
	elif army.state == Army.State.WAITING:
		army.pos = ArmyOrders.town_point(sim, army, army.at)
	else:
		army.pos = ArmyOrders.stand_point(sim, army.at)
	if army.state != Army.State.MOVING or goal == army.at:
		return   # (on the spot: arrives on the next second)
	army.state = Army.State.IDLE
	army.target = 0
	if goal == 0:
		return
	if army.owner != ProvinceDef.OWNER_PLAYER:
		if not ArmyOrders.send_over_land(sim, army, goal):
			_go_home(sim, army)
		return
	if ArmyOrders.order_error(sim, army, goal, Vector2.INF) == &"":
		ArmyOrders.order(sim, army, goal, Vector2.INF)


static func _eat(army: Army, seconds: float) -> void:
	army.food = SimCodec.savable(maxf(army.food - army.men() * Army.FOOD_PER_MAN_MINUTE * seconds / 60.0, 0.0))


## Bread from the province's storages up to what the army takes along.
static func _refill(sim: Simulation, army: Army) -> void:
	refill_from(sim, army, army.at)


## Bread from the storages of province [param id] up to what the army takes along.
static func refill_from(sim: Simulation, army: Army, id: int) -> void:
	if army.owner != ProvinceDef.OWNER_PLAYER:
		return
	var province := sim.province_state(id)
	if province == null:
		return
	var missing := floori(army.food_cap() - army.food)
	if missing <= 0:
		return
	var hall := province.seat()
	var near := hall.entrance_tile() if hall != null else province.grid.size / 2
	for good: StringName in Barracks.FOOD:
		if missing <= 0:
			break
		var got := province.take_from_storages(good, missing, near)
		army.food += got
		missing -= got


## An army whose men are on the viewed map: when none is left there (all marched off, or
## fell), it stands outside (or is gone); a siege won takes the settlement.
static func _inside(sim: Simulation, army: Army) -> void:
	if army.by_sea:
		if army.at == sim.viewed_id and Fleets.sailing_out(sim.province, army.id) > 0:
			return
		if army.ships == 0 and army.is_empty():
			sim.world.armies.erase(army.id)
			return
		Fleets.out_of_province(sim, army)
		return
	var on_map := 0
	if army.at == sim.viewed_id:
		for agent: Agent in sim.province.agents.all():
			if agent.combat != null and agent.combat.army == army.id and agent.combat.hp > 0:
				on_map += 1
		if army.owner == ProvinceDef.OWNER_PLAYER and sim.world.owner_of(army.at) == ProvinceDef.OWNER_NEUTRAL:
			var enemies: Array[Vector2] = []
			for agent: Agent in sim.province.agents.all():
				if agent.combat != null and agent.combat.army == army.id:
					enemies.append(agent.pos)
			Raids.shelter_near(sim.province, enemies)
			if on_map > 0 and Raids.can_capture(sim.province):
				capture(sim, army.at)
		if army.owner == Army.BANDITS and sim.province.raids.army == army.id \
				and sim.province.raids.is_active():
			return
	if on_map > 0:
		return
	if army.owner == Army.BANDITS:
		var raids := sim.province.raids if army.at == sim.viewed_id else null
		if raids != null and raids.army == army.id:
			army.loot_gold += raids.loot_gold
			raids.loot_gold = 0
			raids.army = 0
		_go_home(sim, army)
		return
	if army.is_empty():
		_disband(sim, army, &"army_lost")
		return
	army.state = Army.State.IDLE if sim.world.owner_of(army.at) == ProvinceDef.OWNER_PLAYER \
			else Army.State.WAITING
	if army.pos == Vector2.INF:
		army.pos = ArmyOrders.stand_point(sim, army.at) if army.state == Army.State.IDLE \
				else ArmyOrders.town_point(sim, army, army.at)
	sim.events.emit(&"army_out", {"army": army.id, "province": army.at})


## Warns the viewed province a minute before bandits arrive there (the warning of part 2).
static func _warn(sim: Simulation, army: Army) -> void:
	if army.owner != Army.BANDITS or army.warned or army.state != Army.State.MOVING:
		return
	if army.target != sim.viewed_id or sim.world.owner_of(army.target) != ProvinceDef.OWNER_PLAYER:
		return
	if ArmyOrders.seconds_left(sim, army) > WARNING_SECONDS:
		return
	var province := sim.province
	if province.raids.is_active() or not province.has_seat():
		return
	army.warned = true
	province.raids.entry = Raids.choose_entry(province, sim.rng.stream(&"raids"))
	if province.raids.entry == Agent.NO_TILE:
		return
	province.raids.state = Raids.State.WARNED
	province.events.emit(&"raid_warning", {"seconds": WARNING_SECONDS, "tile": province.raids.entry})


## Deep water off the province's coast where a returning warship anchors.
static func _sea_spot(province: ProvinceSim, ship: ShipUnit) -> Vector2i:
	var nav := Ships.nav_for(province, ship.def)
	var size := province.grid.size
	var near := province.landing.anchor if province.landing != null else Agent.NO_TILE
	if near == Agent.NO_TILE or not nav.is_walkable(near):
		for d: int in maxi(size.x, size.y):
			for t: Vector2i in [Vector2i(d, size.y / 2), Vector2i(size.x / 2, d), Vector2i(size.x - 1 - d, size.y / 2),
					Vector2i(size.x / 2, size.y - 1 - d)]:
				if near == Agent.NO_TILE and nav.is_walkable(t) and province.sail_depth(t) >= 2:
					near = t
	if near == Agent.NO_TILE:
		return Agent.NO_TILE
	return Voyage.anchorage(province, ship, near)


## The army (or fleet) reached the end of its way.
static func _arrive(sim: Simulation, army: Army) -> void:
	if army.chase != 0:
		army.state = Army.State.IDLE
		army.chase = 0
		return
	if army.is_fleet():
		Fleets.arrive(sim, army)
		return
	sim.events.emit(&"army_arrived", {"army": army.id, "province": army.target if army.target != 0 else army.at})
	arrive_on_land(sim, army)


## An army on the land at the end of its way: in the field it stands; at a town it does what
## it came for (M7 part 3): bandits raid, the player's men go into the barracks, wait at a
## neutral settlement, break the bandits' camp; enemies standing by the town fight it first.
static func arrive_on_land(sim: Simulation, army: Army) -> void:
	army.path.clear()
	if army.target == 0:
		army.state = Army.State.IDLE
		return
	army.at = army.target
	army.target = 0
	if ArmyMeetings.at_town(sim, army):
		return
	if not sim.world.armies.has(army.id):
		return
	var owner := sim.world.owner_of(army.at)
	if army.owner == Army.BANDITS:
		if army.at == army.home:
			_back_at_camp(sim, army)
		elif owner == ProvinceDef.OWNER_PLAYER:
			_raid(sim, army)
		else:
			_go_home(sim, army)
		return
	var camp := sim.world.camp
	if camp != null and camp.province == army.at and camp.is_up():
		_attack_camp(sim, army)
		return
	match owner:
		ProvinceDef.OWNER_PLAYER:
			army.state = Army.State.IDLE
			join_barracks(sim, army)
		ProvinceDef.OWNER_NEUTRAL:
			army.state = Army.State.WAITING
			sim.events.emit(&"army_at_settlement", {"army": army.id, "province": army.at})
		_:
			army.state = Army.State.IDLE


## A battle by BattleResolver: [param army] attacks [param defender]; losses come off the
## army, the result is reported (world.reports) and returned.
static func battle(sim: Simulation, army: Army, defender: BattleSide, kind: BattleResolver.Kind,
		fort: BattleFort, province: int, defender_owner: StringName, at: Vector2 = Vector2.INF) -> BattleResult:
	var result := BattleResolver.resolve(sim.data, army.side(), defender, kind, sim.rng.stream(&"battles"), fort)
	army.lose(result.lost_a)
	var entry := {"tick": sim.clock.tick, "province": province, "kind": kind,
			"attacker": String(army.owner), "defender": String(defender_owner),
			"result": result.to_dict()}
	if at != Vector2.INF:
		entry["pos"] = [at.x, at.y]
	if kind == BattleResolver.Kind.NAVAL:
		entry["ships_a"] = result.ships_left_a
		entry["ships_b"] = result.ships_left_b
	sim.world.report(entry)
	sim.events.emit(&"battle_resolved", {"province": province, "kind": kind,
			"attacker": army.owner, "won": result.a_won()})
	return result


# --- Neutral settlements ----------------------------------------------------------------------

## What the walls of [param province] give a defender against an attack from its edge: the
## weakest wall on the way from the edge to the town hall (none when there is a way round).
static func fort_of(province: ProvinceSim) -> BattleFort:
	var fort := BattleFort.new()
	var hall := province.seat()
	if hall == null or province.walls.is_empty():
		return fort
	var door := province.door_tile(hall)
	var entry := exit_tile(province, door if door != Agent.NO_TILE else hall.entrance_tile(), province.home_faction)
	if entry == Agent.NO_TILE:
		return fort
	var siege := province.mil.siege_nav
	var path := siege.find_path(entry, door if door != Agent.NO_TILE else hall.entrance_tile())
	for tile: Vector2i in path:
		if province.mil.enemy_nav.is_walkable(tile):
			continue
		var kind := province.walls.kind(tile)
		var building := province.buildings.get_building(province.grid.occupant(tile))
		if building != null and building.def.is_gate():
			fort.gate_hp = building.hp if building.hp > 0 else building.def.max_hp
			var gate_wall := Walls.STONE if building.def.is_gatehouse() else Walls.PALISADE
			if fort.wall == Walls.NONE or gate_wall < fort.wall:
				fort.wall = gate_wall
				fort.wall_hp = Walls.max_hp_of(gate_wall)
		elif kind == Walls.PALISADE or kind == Walls.STONE:
			if fort.wall == Walls.NONE or kind < fort.wall:
				fort.wall = kind
				fort.wall_hp = province.walls.hp(tile)
	if fort.wall != Walls.NONE and fort.gate_hp == 0:
		for building: BuildingState in province.buildings.all():
			if building.def.is_gate() and not building.is_broken():
				fort.gate_hp = building.hp if building.hp > 0 else building.def.max_hp
	if hall.def.max_hp > 0:
		fort.door_hp = hall.hp if hall.hp > 0 else hall.def.max_hp
	return fort


## The chance (0..1) [param army] has to take the settlement at [param id] by BattleResolver.
static func siege_chances(sim: Simulation, army: Army, id: int) -> float:
	var settlement := sim.world.settlements.get(id) as NeutralSettlement
	var province := sim.province_state(id)
	if settlement == null or province == null:
		return 0.0
	return BattleResolver.chances(sim.data, army.side(), BattleSide.new(settlement.guards),
			BattleResolver.Kind.SIEGE, fort_of(province))


## Why [param army] cannot fight for the settlement it waits at, or &"".
static func siege_error(sim: Simulation, army: Army) -> StringName:
	if army == null or army.owner != ProvinceDef.OWNER_PLAYER:
		return &"no_army"
	if sim.viewed_id == Simulation.BATTLEFIELD:
		return &"army_in_battle"
	if army.state != Army.State.WAITING or sim.world.owner_of(army.at) != ProvinceDef.OWNER_NEUTRAL:
		return &"not_at_settlement"
	if not sim.world.settlements.has(army.at) or sim.province_state(army.at) == null:
		return &"not_at_settlement"
	return &""


## The settlement's fate decided at once (the "automatic" button).
static func resolve_siege(sim: Simulation, army: Army) -> BattleResult:
	var id := army.at
	var settlement := sim.world.settlements[id]
	var province := sim.province_state(id)
	var result := battle(sim, army, BattleSide.new(settlement.guards), BattleResolver.Kind.SIEGE,
			fort_of(province), id, ProvinceDef.OWNER_NEUTRAL)
	for unit: StringName in result.lost_b:
		settlement.guards[unit] = maxi(settlement.guards.get(unit, 0) - result.lost_b[unit], 0)
	if result.a_won() and not army.is_empty():
		capture(sim, id)
		army.state = Army.State.IDLE
	elif army.is_empty():
		_disband(sim, army, &"army_lost")
	return result


## The army goes into the settlement it waits at, in the province's view (the player enters
## it): its men come in at the edge, the guards stand on the walls and at the hall.
static func enter_fight(sim: Simulation, army: Army) -> void:
	sim.view_province(army.at)
	var province := sim.province
	var hall := province.seat()
	var door := hall.entrance_tile() if hall != null else province.grid.size / 2
	army.entry = Raids.choose_entry(province, sim.rng.stream(&"raids"))
	if army.landed_by_sea:
		var beach := _beach(sim, army.at)
		if beach != Agent.NO_TILE:
			army.entry = beach
	if army.entry == Agent.NO_TILE:
		army.entry = exit_tile(province, door, CombatState.PLAYER)
	var kinds: Array[StringName] = []
	var ids: Array[StringName] = []
	ids.assign(army.units.keys())
	ids.sort()
	for unit: StringName in ids:
		for k: int in army.units[unit]:
			kinds.append(unit)
	army.units.clear()
	var spots := Troops.formation(province, army.entry, MilitaryNav.GROUND, kinds.size(), CombatState.PLAYER)
	for k: int in kinds.size():
		var at: Vector2 = spots[k % spots.size()] if not spots.is_empty() else IsoMath.tile_center(army.entry)
		var agent := province.spawn_agent(kinds[k], Vector2i(at.floor()))
		agent.pos = at
		agent.prev_pos = at
		agent.combat = CombatState.new(sim.data.get_unit(kinds[k]).combat.hp)
		agent.combat.army = army.id
		Troops.take_command(agent)
		agent.combat.order = CombatState.Order.MOVE
		agent.combat.stance = CombatState.Stance.AGGRESSIVE
		agent.combat.post = at
		agent.combat.goal = at
	army.state = Army.State.INSIDE
	sim.events.emit(&"army_entered", {"army": army.id, "province": army.at})


## The beach of province [param id]'s map, where an army from the sea lands; NO_TILE if none.
static func _beach(sim: Simulation, id: int) -> Vector2i:
	var def := sim.world.def_of(id, sim.data)
	var map := sim.data.get_map(sim.world.get_province(id).map_id)
	if map == null or map.beach_tile == Agent.NO_TILE:
		return Agent.NO_TILE
	var tile := ProvinceSim._variant_tile(map.beach_tile, def.mirrored if def != null else false)
	var nav := sim.province.mil.ground_nav(sim.province, CombatState.PLAYER)
	return tile if nav.is_walkable(tile) else Agent.NO_TILE


## The player calls his men in the settlement back to the edge: they leave the map and the
## army waits at the border again.
static func retreat(sim: Simulation, army: Army) -> void:
	var agents: Array[Agent] = []
	for agent: Agent in sim.province.agents.all():
		if agent.combat != null and agent.combat.army == army.id and agent.combat.hp > 0:
			agents.append(agent)
	if not agents.is_empty():
		Troops.order_march(sim.province, agents, army.id, army.entry if army.entry.x >= 0 \
				else exit_tile(sim.province, agents[0].tile(), CombatState.PLAYER))


## The guards of the neutral settlement viewed now stand at their posts: archers on the walls
## by the gate, spearmen at the gate and at the town hall.
static func spawn_guards(sim: Simulation, id: int) -> void:
	var settlement := sim.world.settlements.get(id) as NeutralSettlement
	if settlement == null or id != sim.viewed_id:
		return
	var province := sim.province
	var hall := province.seat()
	if hall == null:
		return
	var gate: BuildingState = null
	for building: BuildingState in province.buildings.all():
		if building.def.is_gate():
			gate = building
	var kinds: Array[StringName] = []
	var ids: Array[StringName] = []
	ids.assign(settlement.guards.keys())
	ids.sort()
	for unit: StringName in ids:
		for k: int in settlement.guards[unit]:
			kinds.append(unit)
	var archers := kinds.filter(func(u: StringName) -> bool: return u == &"archer")
	var others := kinds.filter(func(u: StringName) -> bool: return u != &"archer")
	var gate_tile := gate.entrance_tile() if gate != null else hall.entrance_tile()
	var on_wall: Array[Vector2] = []
	if not archers.is_empty():
		on_wall = Troops.formation(province, gate_tile, MilitaryNav.WALL, archers.size(), CombatState.TOWN)
	var inner := _inner_gate(province, gate, hall)
	var at_gate := Troops.formation(province, inner, MilitaryNav.GROUND, others.size(), CombatState.TOWN)
	var at_hall := Troops.formation(province, hall.entrance_tile(), MilitaryNav.GROUND, kinds.size(), CombatState.TOWN)
	var k_gate := 0
	var k_hall := 0
	for k: int in archers.size():
		var spot := on_wall[k] if k < on_wall.size() else Vector2(-1, -1)
		var level := MilitaryNav.WALL
		if spot.x < 0.0:
			spot = at_hall[k_hall % maxi(at_hall.size(), 1)] if not at_hall.is_empty() else IsoMath.tile_center(hall.entrance_tile())
			k_hall += 1
			level = MilitaryNav.GROUND
		_guard(sim, province, archers[k], spot, level)
	for k: int in others.size():
		# Two of three at the gate, the rest at the hall's door.
		var spot: Vector2
		if k % 3 != 2 and k_gate < at_gate.size():
			spot = at_gate[k_gate]
			k_gate += 1
		else:
			spot = at_hall[k_hall % maxi(at_hall.size(), 1)] if not at_hall.is_empty() else IsoMath.tile_center(hall.entrance_tile())
			k_hall += 1
		_guard(sim, province, others[k], spot, MilitaryNav.GROUND)
	settlement.guards.clear()


static func _guard(sim: Simulation, province: ProvinceSim, unit: StringName, spot: Vector2, level: int) -> void:
	var agent := province.spawn_agent(unit, Vector2i(spot.floor()))
	agent.pos = spot
	agent.prev_pos = spot
	agent.level = level
	agent.combat = CombatState.new(sim.data.get_unit(unit).combat.hp)
	agent.combat.faction = CombatState.TOWN
	Troops.take_command(agent)
	agent.combat.order = CombatState.Order.MOVE
	agent.combat.stance = CombatState.Stance.DEFENSIVE
	agent.combat.post = spot
	agent.combat.post_level = level
	agent.combat.goal = spot
	agent.combat.goal_level = level


## The ground just inside the gate (towards the hall), or the hall's door without a gate.
static func _inner_gate(province: ProvinceSim, gate: BuildingState, hall: BuildingState) -> Vector2i:
	if gate == null:
		return hall.entrance_tile()
	var passage := gate.passage_tiles()
	if passage.is_empty():
		return gate.entrance_tile()
	var best := passage[0]
	for t: Vector2i in [passage[0], passage[passage.size() - 1]]:
		var d := gate.def.door_dir(gate.orientation)
		for side: Vector2i in [t + d * 2, t - d * 2]:
			if (side - hall.entrance_tile()).length_squared() < (best - hall.entrance_tile()).length_squared():
				best = side
	return best


## Before the viewed province goes to the simplified mode: armies' men leave the map and count
## as their armies again (a raid in progress is decided by BattleResolver at once), guards of
## a settlement count as its guards.
static func fold(sim: Simulation) -> void:
	var province := sim.province
	var settlement := sim.world.settlements.get(sim.viewed_id) as NeutralSettlement
	for agent: Agent in province.agents.all():
		var c := agent.combat
		if c == null or c.hp <= 0:
			continue
		var unit := Troops.unit_of(province, agent)
		if c.faction == CombatState.TOWN:
			if settlement != null and unit != null:
				settlement.guards[unit.id] = settlement.guards.get(unit.id, 0) + 1
			province.remove_agent(agent)
		elif c.army != 0:
			var army := sim.world.armies.get(c.army) as Army
			if army != null and unit != null:
				army.add(unit.id)
			province.remove_agent(agent)
	# Warships on their way out leave at once (M8 part 2).
	for ship: ShipUnit in province.ships.values().duplicate():
		if ship.sail_out != 0:
			Fleets.leave_map(province, ship)
	absorb(sim)
	province.arrows.clear()
	for id: int in sim.world.armies.keys():
		var army := sim.world.armies[id]
		if army.state != Army.State.INSIDE or army.at != sim.viewed_id:
			continue
		if army.by_sea:
			_inside(sim, army)
			continue
		if army.owner == Army.BANDITS and province.raids.army == army.id:
			army.loot_gold += province.raids.loot_gold
			Raids.call_off(province)
			if province.raids.state == Raids.State.WAITING and not army.is_empty():
				# The rest of the raid is decided at once on the next second.
				army.state = Army.State.MOVING
				army.target = army.at
				army.path.clear()
				army.warned = true
				continue
		if army.is_empty():
			if army.owner == Army.BANDITS:
				sim.world.armies.erase(id)
			else:
				_disband(sim, army, &"army_lost")
			continue
		if army.owner == Army.BANDITS:
			army.state = Army.State.IDLE
			_go_home(sim, army)
		else:
			army.state = Army.State.IDLE if sim.world.owner_of(army.at) == ProvinceDef.OWNER_PLAYER \
					else Army.State.WAITING


## The settlement at [param id] falls to the player: its people and buildings stay, they lose
## heart for a while (Raids.capture), the guards left lay down their arms.
static func capture(sim: Simulation, id: int) -> void:
	sim.world.settlements.erase(id)
	Raids.capture(sim, id, ProvinceDef.OWNER_PLAYER)
	var province := sim.province_state(id)
	if province == null:
		return
	province.home_faction = CombatState.PLAYER
	if id == sim.viewed_id:
		for agent: Agent in province.agents.all():
			if agent.combat != null and agent.combat.faction == CombatState.TOWN:
				province.remove_agent(agent)
		for agent: Agent in province.agents.all():
			if agent.task != null and agent.task.kind == Task.KIND_SHELTER:
				TaskRunner.fail(province, agent)
	# The door is mended, the town is the player's.
	var hall := province.seat()
	if hall != null and hall.def.max_hp > 0:
		hall.hp = hall.def.max_hp


# --- Home -------------------------------------------------------------------------------------

static func _free_beds(sim: Simulation, id: int) -> int:
	var province := sim.province_state(id)
	if province == null:
		return 0
	var free := 0
	for building: BuildingState in province.buildings.all():
		if building.def.soldier_beds > 0 and building.is_complete():
			free += building.def.soldier_beds - Barracks.beds_taken(building)
	return free


## The army's men go into the barracks of the player's province it stands in (as many as
## fit; in the viewed province they walk in from the edge). Returns whether it is gone.
static func join_barracks(sim: Simulation, army: Army) -> bool:
	var province := sim.province_state(army.at)
	if province == null or _free_beds(sim, army.at) <= 0:
		return false
	var viewed := army.at == sim.viewed_id
	var ids: Array[StringName] = []
	ids.assign(army.units.keys())
	ids.sort()
	for building: BuildingState in province.buildings.all():
		if building.def.soldier_beds <= 0 or not building.is_complete():
			continue
		var entry := exit_tile(province, building.entrance_tile(), CombatState.PLAYER) if viewed else Agent.NO_TILE
		for unit: StringName in ids:
			var def := sim.data.get_unit(unit)
			if def == null or def.siege != &"":
				continue
			while army.units.get(unit, 0) > 0 and Barracks.beds_taken(building) < building.def.soldier_beds:
				army.add(unit, -1)
				if viewed and entry != Agent.NO_TILE:
					var agent := province.spawn_agent(unit, entry)
					agent.home_id = building.id
					agent.combat = CombatState.new(def.combat.hp)
					building.soldiers.append(agent.id)
					Troops.order_return(province, [agent])
				else:
					building.garrison.append(unit)
	sim.events.emit(&"army_home", {"army": army.id, "province": army.at})
	if army.men() == 0 or _only_engines(sim, army):
		sim.world.armies.erase(army.id)
		return true
	return false


static func _only_engines(sim: Simulation, army: Army) -> bool:
	for unit: StringName in army.units:
		var def := sim.data.get_unit(unit)
		if def != null and def.siege == &"":
			return false
	return true


## The player disbands his army in his province (DisbandArmyCommand): into the barracks.
static func disband_home(sim: Simulation, army: Army) -> void:
	join_barracks(sim, army)


## A beaten army of the player walks back to where it came from.
static func _retreat_home(sim: Simulation, army: Army) -> void:
	if army.is_empty() and army.ships == 0:
		_disband(sim, army, &"army_lost")
		return
	army.state = Army.State.IDLE
	army.path.clear()
	army.target = 0
	var home := army.fleet_home if army.is_fleet() else army.home
	if sim.world.owner_of(home) != army.owner:
		return
	if not army.is_fleet() and home == army.at:
		return
	var way := ArmyOrders.plan(sim, army, home, Vector2.INF)
	if way["error"] == &"" and not bool(way["board"]):
		ArmyOrders._follow(sim, army, way, home)


static func _disband(sim: Simulation, army: Army, event: StringName) -> void:
	sim.world.armies.erase(army.id)
	sim.events.emit(event, {"army": army.id, "province": army.at})


# --- Bandits ----------------------------------------------------------------------------------

static func _update_camp(sim: Simulation) -> void:
	var world := sim.world
	var def := sim.data.get_world(world.world_id)
	if def == null or def.bandit_camp == &"":
		return
	var rng := sim.rng.stream(&"bandits")
	if world.camp == null:
		world.camp = BanditCamp.new()
		var start := world.id_of(def.bandit_camp)
		if _camp_place_ok(sim, start):
			_raise_camp(sim, start)
		else:
			world.camp.respawn_at = sim.clock.tick
	var camp := world.camp
	if not camp.is_up():
		if sim.clock.tick >= camp.respawn_at:
			var places: Array[int] = []
			for id: int in world.ids():
				if _camp_place_ok(sim, id):
					places.append(id)
			if places.is_empty():
				camp.respawn_at = sim.clock.tick + SimClock.seconds_to_ticks(BanditCamp.RESPAWN_SECONDS)
				return
			_raise_camp(sim, places[rng.randi_range(0, places.size() - 1)])
		return
	if not _camp_place_ok(sim, camp.province, true):
		# The province was settled meanwhile: the camp moves on.
		camp.province = 0
		camp.respawn_at = sim.clock.tick
		return
	if sim.clock.tick < camp.next_raid:
		return
	camp.next_raid = sim.clock.tick + SimClock.seconds_to_ticks(
			rng.randf_range(BanditCamp.GAP_MIN_SECONDS, BanditCamp.GAP_MAX_SECONDS))
	var target := _raid_target(sim, camp.province)
	if target == 0:
		return
	camp.raids += 1
	var army := Army.new()
	army.id = sim.ids.take()
	army.owner = Army.BANDITS
	army.at = camp.province
	army.home = camp.province
	army.state = Army.State.IDLE
	var size := rng.randi_range(RAID_MIN, RAID_MAX)
	for k: int in size:
		army.add(&"archer" if k % 3 == 2 else &"spearman")
	var province := sim.province_state(target)
	if province != null and Raids.has_stone_walls(province):
		army.add(&"ladderman", 2)
	if province != null and camp.raids % Raids.RAM_EVERY == 0 and Raids.has_gate(province):
		army.add(&"ram")
	army.food = army.food_cap()
	world.armies[army.id] = army
	send_bandits(sim, army, target)
	if world.armies.has(army.id):
		sim.events.emit(&"bandits_set_out", {"army": army.id, "province": target,
				"seconds": ArmyOrders.seconds_left(sim, army)})


static func send_bandits(sim: Simulation, army: Army, target: int) -> void:
	if army.pos == Vector2.INF:
		var def := sim.world.def_of(army.at, sim.data)
		army.pos = def.world_pos if def != null else Vector2.ZERO
	if not ArmyOrders.send_over_land(sim, army, target):
		sim.world.armies.erase(army.id)


static func _camp_place_ok(sim: Simulation, id: int, standing: bool = false) -> bool:
	var world := sim.world
	if id == 0 or world.owner_of(id) != ProvinceDef.OWNER_NONE or sim.runtimes.has(id):
		return false
	if world.expedition_to(id) != null:
		return false
	var def := world.def_of(id, sim.data)
	if def == null or def.island:
		return false
	if not standing:
		for army: Army in world.armies_at(id):
			if army.owner == ProvinceDef.OWNER_PLAYER:
				return false
	return true


static func _raise_camp(sim: Simulation, id: int) -> void:
	var camp := sim.world.camp
	camp.province = id
	camp.guards = BanditCamp.GUARDS.duplicate()
	camp.respawn_at = 0
	if camp.next_raid < sim.clock.tick:
		camp.next_raid = sim.clock.tick + SimClock.seconds_to_ticks(BanditCamp.FIRST_SECONDS)
	sim.events.emit(&"bandit_camp_raised", {"province": id})


## The player's province the bandits go for: the nearest one they can walk to.
static func _raid_target(sim: Simulation, from: int) -> int:
	var best := 0
	var best_steps := 1 << 30
	for id: int in sim.world.ids():
		if sim.world.owner_of(id) != ProvinceDef.OWNER_PLAYER:
			continue
		var province := sim.province_state(id)
		if province == null or not province.has_seat() or province.grace_until > sim.clock.tick:
			continue
		var a := sim.world.def_of(from, sim.data)
		var b := sim.world.def_of(id, sim.data)
		var n := ArmyOrders.nav(sim)
		if a == null or b == null or n == null:
			continue
		var way := n.find_path(a.world_pos, b.world_pos, false)
		var steps := int(WorldNav.length_of(a.world_pos, way))
		if not way.is_empty() and steps < best_steps:
			best_steps = steps
			best = id
	return best


## Bandits at a province of the player: the raid is fought in the view when the player looks
## at it, decided by BattleResolver otherwise.
static func _raid(sim: Simulation, army: Army) -> void:
	var id := army.at
	var province := sim.province_state(id)
	if province == null or not province.has_seat():
		_go_home(sim, army)
		return
	if id == sim.viewed_id and not province.raids.is_active():
		var entry := Raids.start_army(province, sim.rng.stream(&"raids"), army.units, army.id)
		if entry != Agent.NO_TILE:
			army.units.clear()
			army.entry = entry
			army.state = Army.State.INSIDE
			province.events.emit(&"raid_started", {"tile": entry, "size": province.raids.members.size()})
			return
	var garrison: Dictionary[StringName, int] = {}
	for building: BuildingState in province.buildings.all():
		for unit: StringName in building.garrison:
			garrison[unit] = garrison.get(unit, 0) + 1
	var result := battle(sim, army, BattleSide.new(garrison), BattleResolver.Kind.SIEGE, fort_of(province),
			id, ProvinceDef.OWNER_PLAYER)
	for unit: StringName in result.lost_b:
		var left := result.lost_b[unit]
		for building: BuildingState in province.buildings.all():
			while left > 0 and building.garrison.has(unit):
				building.garrison.erase(unit)
				left -= 1
	if result.a_won() and not army.is_empty():
		var hall := province.seat()
		army.loot_gold += Raids.loot(province, hall)
		province.raids.loot_gold = 0
		sim.events.emit(&"province_raided", {"province": id, "gold": army.loot_gold})
	else:
		sim.events.emit(&"raid_beaten_off", {"province": id})
	_go_home(sim, army)


static func _go_home(sim: Simulation, army: Army) -> void:
	if army.is_empty():
		sim.world.armies.erase(army.id)
		return
	var camp := sim.world.camp
	if camp == null or not camp.is_up() or army.at == camp.province:
		_back_at_camp(sim, army)
		return
	army.home = camp.province
	army.state = Army.State.IDLE
	send_bandits(sim, army, camp.province)


static func _back_at_camp(sim: Simulation, army: Army) -> void:
	var camp := sim.world.camp
	if camp != null and camp.is_up() and camp.province == army.at:
		camp.gold += army.loot_gold
		for unit: StringName in army.units:
			if sim.data.get_unit(unit) != null and sim.data.get_unit(unit).siege == &"" \
					and _count(camp.guards) < CAMP_MAX:
				camp.guards[unit] = camp.guards.get(unit, 0) + mini(army.units[unit], CAMP_MAX - _count(camp.guards))
	sim.world.armies.erase(army.id)


static func _scatter(sim: Simulation, army: Army) -> void:
	sim.world.armies.erase(army.id)
	sim.events.emit(&"bandits_scattered", {"army": army.id, "province": army.at})


static func _count(units: Dictionary[StringName, int]) -> int:
	var total := 0
	for unit: StringName in units:
		total += units[unit]
	return total


## The player's army at the camp: a battle in the field; won, the camp is broken, its hoard
## goes to the treasury and a new camp comes up later elsewhere.
static func _attack_camp(sim: Simulation, army: Army) -> void:
	var camp := sim.world.camp
	var result := battle(sim, army, camp.side(), BattleResolver.Kind.FIELD, null, army.at, Army.BANDITS)
	camp.guards = result.left_b.duplicate()
	if result.a_won() and not army.is_empty():
		var gold := camp.gold
		sim.treasury.add(gold)
		camp.gold = 0
		camp.province = 0
		camp.guards.clear()
		camp.respawn_at = sim.clock.tick + SimClock.seconds_to_ticks(BanditCamp.RESPAWN_SECONDS)
		army.state = Army.State.IDLE
		sim.events.emit(&"bandit_camp_broken", {"province": army.at, "gold": gold})
	else:
		_retreat_home(sim, army)
