class_name Raids
extends RefCounted
## Bandit raids on the viewed province (M7 part 2, GDD §9, owner's decision 2026-11-08):
## rare, with a warning a minute ahead. Bandits come in at the edge of the map and make for
## the door of the town hall (or the pioneer camp): they break what stands in their way (a
## palisade, a wall, a gate; laddermen lean ladders on stone walls, a ram breaks the gate in
## a bigger raid) and fight the soldiers they meet. When the door falls and no soldier
## defends it, they loot (gold and goods), the town loses heart (happiness -30 for 10 minutes)
## and they leave. Townsfolk near bandits drop their work and hide in the town hall.
##
## The province itself stays the player's; a full take-over (Raids.capture) is ready for
## part 3 and M8 (armies of other rulers).

enum State { WAITING, WARNED, ACTIVE, LEAVING }

## First raid after 40 minutes of play, then every 25 to 40 minutes (ROADMAP M7).
const FIRST_SECONDS := 40.0 * 60.0
const GAP_MIN_SECONDS := 25.0 * 60.0
const GAP_MAX_SECONDS := 40.0 * 60.0
const WARNING_SECONDS := 60.0
const SIZE_MIN := 4
const SIZE_MAX := 8
## Every third raid is a bigger one with a ram (when the town has a gate to break).
const RAM_EVERY := 3
## Loot: a share of the gold (at most), and of the goods the storages hold most of.
const LOOT_GOLD_SHARE := 0.3
const LOOT_GOLD_MAX := 300
const LOOT_GOODS := 3
const LOOT_UNITS := 12
## Happiness lost after a looting, and for how long.
const MOOD_PENALTY := 30.0
const MOOD_SECONDS := 600.0
## Townsfolk this close to a bandit (tiles) run for shelter; a door this close to soldiers is
## defended.
const DANGER_RADIUS := 7.0
const DEFEND_RADIUS := 6.0

var state: State = State.WAITING
## Tick of the next raid (its warning comes WARNING_SECONDS earlier).
var next_tick: int = -1
## Raids so far.
var count: int = 0
## Where the bandits come in (and leave).
var entry: Vector2i = Vector2i(-1, -1)
var members: Array[int] = []
## Until this tick happiness is lower after a looting.
var mood_until: int = 0
## The bandits' army on the world map this raid came from (M7 part 3; 0 = a raid of a
## single-province game) and the gold it took, handed to the army when the raid is over.
var army: int = 0
var loot_gold: int = 0


func is_active() -> bool:
	return state == State.ACTIVE or state == State.LEAVING


# --- Every second ---------------------------------------------------------------------------

## [param scheduled]: raids come on their own schedule (a single-province game); in a world
## they come as armies from the bandits' camp (Armies).
static func update(province: ProvinceSim, rng: RandomNumberGenerator, scheduled: bool = true) -> void:
	var raids := province.raids
	if not scheduled and raids.state == State.WAITING:
		return
	if raids.next_tick < 0:
		raids.next_tick = province.tick + SimClock.seconds_to_ticks(FIRST_SECONDS)
	match raids.state:
		State.WAITING:
			if province.tick >= raids.next_tick - SimClock.seconds_to_ticks(WARNING_SECONDS) \
					and province.has_seat():
				raids.entry = choose_entry(province, rng)
				if raids.entry == Agent.NO_TILE:
					raids.next_tick += SimClock.seconds_to_ticks(GAP_MIN_SECONDS)
					return
				raids.state = State.WARNED
				province.events.emit(&"raid_warning", {"seconds": WARNING_SECONDS, "tile": raids.entry})
		State.WARNED:
			if province.tick >= raids.next_tick:
				start(province, rng)
		State.ACTIVE, State.LEAVING:
			_drive(province, rng)
	if raids.is_active():
		_shelter_townsfolk(province)


## Sends the raid now (the tools menu's "raid now" and the schedule).
static func start(province: ProvinceSim, rng: RandomNumberGenerator) -> void:
	var raids := province.raids
	if raids.entry == Agent.NO_TILE or raids.entry.x < 0:
		raids.entry = choose_entry(province, rng)
		if raids.entry == Agent.NO_TILE:
			return
	raids.count += 1
	var size := rng.randi_range(SIZE_MIN, SIZE_MAX)
	var kinds: Array[StringName] = []
	for k: int in size:
		kinds.append(&"bandit_archer" if k % 3 == 2 else &"bandit")
	if has_stone_walls(province):
		kinds.append(&"ladderman")
		kinds.append(&"ladderman")
	if raids.count % RAM_EVERY == 0 and has_gate(province):
		kinds.append(&"ram")
	_spawn(province, kinds, 0)


## The bandits of army [param army_id] (unit id -> men) come in at the edge (M7 part 3).
static func start_army(province: ProvinceSim, rng: RandomNumberGenerator, units: Dictionary[StringName, int],
		army_id: int) -> Vector2i:
	var raids := province.raids
	if raids.entry == Agent.NO_TILE or raids.entry.x < 0:
		raids.entry = choose_entry(province, rng)
		if raids.entry == Agent.NO_TILE:
			return Agent.NO_TILE
	raids.count += 1
	var kinds: Array[StringName] = []
	var ids: Array[StringName] = []
	ids.assign(units.keys())
	ids.sort()
	for unit: StringName in ids:
		for k: int in units[unit]:
			kinds.append({&"spearman": &"bandit", &"archer": &"bandit_archer"}.get(unit, unit))
	_spawn(province, kinds, army_id)
	return raids.entry


static func _spawn(province: ProvinceSim, kinds: Array[StringName], army_id: int) -> void:
	var raids := province.raids
	raids.state = State.ACTIVE
	raids.members.clear()
	raids.army = army_id
	raids.loot_gold = 0
	var spots := Troops.formation(province, raids.entry, MilitaryNav.GROUND, kinds.size(), CombatState.BANDITS)
	for k: int in kinds.size():
		var at: Vector2 = spots[k % spots.size()] if not spots.is_empty() else IsoMath.tile_center(raids.entry)
		var agent := province.spawn_agent(kinds[k], Vector2i(at.floor()))
		agent.pos = at
		agent.prev_pos = at
		var unit_id: StringName = {&"bandit": &"spearman", &"bandit_archer": &"archer"}.get(kinds[k], kinds[k])
		agent.combat = CombatState.new(province.data.get_unit(unit_id).combat.hp)
		agent.combat.unit = unit_id
		agent.combat.faction = CombatState.BANDITS
		agent.combat.army = army_id
		Troops.take_command(agent)
		agent.combat.order = CombatState.Order.NONE
		raids.members.append(agent.id)
	province.events.emit(&"raid_started", {"tile": raids.entry, "size": kinds.size()})


## A land tile at the edge of the map, far from the town hall, from which the town can be
## reached by breaking through: null-tile when none.
static func choose_entry(province: ProvinceSim, rng: RandomNumberGenerator) -> Vector2i:
	var hall := province.seat()
	if hall == null:
		return Agent.NO_TILE
	var target := hall.entrance_tile()
	var size := province.grid.size
	var candidates: Array[Vector2i] = []
	for i: int in range(2, size.x - 2, 3):
		candidates.append(Vector2i(i, 1))
		candidates.append(Vector2i(i, size.y - 2))
	for i: int in range(2, size.y - 2, 3):
		candidates.append(Vector2i(1, i))
		candidates.append(Vector2i(size.x - 2, i))
	var siege := province.mil.siege_nav
	var area := -1
	for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 1)]:
		var t := province.door_tile(hall)
		if t != Agent.NO_TILE and siege.is_walkable(t):
			area = siege.area_of(t)
			break
		t = target + d
		if siege.is_walkable(t):
			area = siege.area_of(t)
			break
	var good: Array[Vector2i] = []
	var far := maxi(size.x, size.y) / 3
	for t: Vector2i in candidates:
		if siege.is_walkable(t) and siege.area_of(t) == area and (t - target).length() >= far:
			good.append(t)
	if good.is_empty():
		return Agent.NO_TILE
	return good[rng.randi_range(0, good.size() - 1)]


static func has_stone_walls(province: ProvinceSim) -> bool:
	for tile: Vector2i in province.walls.tiles():
		if province.walls.is_stone(tile):
			return true
	return false


static func has_gate(province: ProvinceSim) -> bool:
	for building: BuildingState in province.buildings.all():
		if building.def.is_gate() and not building.is_broken():
			return true
	return false


# --- The raid ---------------------------------------------------------------------------------

static func _drive(province: ProvinceSim, rng: RandomNumberGenerator) -> void:
	var raids := province.raids
	var alive: Array[Agent] = []
	for id: int in raids.members:
		var agent := province.agents.get_agent(id)
		if agent != null and agent.combat != null and agent.combat.hp > 0:
			alive.append(agent)
	raids.members.clear()
	for agent: Agent in alive:
		raids.members.append(agent.id)
	if alive.is_empty():
		_end(province, rng, &"raid_defeated")
		return
	if raids.state == State.LEAVING:
		for agent: Agent in alive:
			if agent.tile().distance_to(raids.entry) <= 2.0:
				if agent.combat.army != 0:
					Troops.march_off(province, agent)
				else:
					province.remove_agent(agent)
		if raids.members.all(func(id: int) -> bool: return not province.agents.has_agent(id)):
			_end(province, rng, &"raid_left")
		return
	var hall := province.seat()
	if hall == null:
		_leave(province)
		return
	if hall.is_broken() and not defended(province, hall):
		loot(province, hall)
		_leave(province)
		return
	for agent: Agent in alive:
		_command(province, agent, hall)


## Gives a bandit without work his next aim: the hall's door, or what stands in the way.
static func _command(province: ProvinceSim, agent: Agent, hall: BuildingState) -> void:
	var c := agent.combat
	if c.target_id != 0:
		return   # fighting
	if c.order == CombatState.Order.STRUCTURE and Troops.structure_standing(province, c.target_tile) \
			and (c.has_path() or province.tick - c.path_tick < Troops.REPATH_TICKS * 3):
		return
	var unit := Troops.unit_of(province, agent)
	var door := hall.entrance_tile()
	var aim := door
	var stand := Troops.stand_by(province, door, agent)
	if unit.siege == &"ladder" or stand == Agent.NO_TILE \
			or province.mil.route(province, agent.tile(), agent.level, stand, 0, CombatState.BANDITS).is_empty():
		aim = obstacle(province, agent, door, unit.siege)
	if unit.siege == &"ladder" and not province.walls.is_stone(aim):
		# Nothing to lean a ladder on: he stays out of the way.
		c.order = CombatState.Order.NONE
		return
	if aim == Agent.NO_TILE:
		return
	c.order = CombatState.Order.STRUCTURE
	c.target_tile = aim
	c.clear_path()
	c.path_tick = -1000


## The first wall, palisade or closed gate on the way an enemy would break through to
## [param door]; a ram goes for gates and walls only, a ladderman for stone walls.
static func obstacle(province: ProvinceSim, agent: Agent, door: Vector2i, siege: StringName) -> Vector2i:
	var from := agent.tile()
	if agent.level != MilitaryNav.GROUND:
		return door
	# The way to a tile beside the door, walls and gates counted as passable (at a cost).
	var grid := province.mil.siege_nav
	var path: Array[Vector2i] = []
	for step: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var t := door + step
		if grid.is_walkable(t) and province.grid.occupant(t) == 0:
			var p := grid.find_path(from, t)
			if not p.is_empty() and (path.is_empty() or p.size() < path.size()):
				path = p
	for tile: Vector2i in path:
		if province.mil.enemy_nav.is_walkable(tile):
			continue
		if siege == &"ladder":
			return tile if province.walls.is_stone(tile) else Agent.NO_TILE
		if province.walls.kind(tile) != Walls.NONE:
			return tile
		var building := province.buildings.get_building(province.grid.occupant(tile))
		if building != null and building.def.max_hp > 0:
			return tile
	return door


## Whether a soldier of the town stands near [param hall] (the door holds while he does).
static func defended(province: ProvinceSim, hall: BuildingState) -> bool:
	var door := IsoMath.tile_center(hall.entrance_tile())
	for agent: Agent in province.agents.all():
		if agent.combat != null and agent.combat.faction == province.home_faction and agent.combat.hp > 0 \
				and agent.kind != Barracks.RECRUIT_KIND and agent.pos.distance_to(door) <= DEFEND_RADIUS:
			return true
	return false


## The bandits take a share of the gold and of the goods most in store; the town loses heart.
## Returns the gold taken.
static func loot(province: ProvinceSim, hall: BuildingState) -> int:
	var gold := mini(floori(province.treasury.gold * LOOT_GOLD_SHARE), LOOT_GOLD_MAX)
	if gold > 0:
		province.treasury.pay(gold)
	var totals: Dictionary[StringName, int] = {}
	for building: BuildingState in province.storage_buildings():
		for good: StringName in building.stock.totals():
			totals[good] = totals.get(good, 0) + building.stock.available(good)
	var goods: Array[StringName] = []
	goods.assign(totals.keys())
	goods.sort_custom(func(a: StringName, b: StringName) -> bool:
		return totals[a] > totals[b] or (totals[a] == totals[b] and String(a) < String(b)))
	var taken: Dictionary = {}
	for good: StringName in goods.slice(0, LOOT_GOODS):
		var amount := province.take_from_storages(good, LOOT_UNITS, hall.entrance_tile(), false)
		if amount > 0:
			taken[String(good)] = amount
	province.raids.mood_until = province.tick + SimClock.seconds_to_ticks(MOOD_SECONDS)
	province.raids.loot_gold += gold
	province.events.emit(&"raid_looted", {"gold": gold, "goods": taken})
	return gold


static func _leave(province: ProvinceSim) -> void:
	var raids := province.raids
	raids.state = State.LEAVING
	var agents: Array[Agent] = []
	for id: int in raids.members:
		var agent := province.agents.get_agent(id)
		if agent != null:
			agent.combat.order = CombatState.Order.MOVE
			agent.combat.target_tile = Vector2i(-1, -1)
			agent.combat.stance = CombatState.Stance.DEFENSIVE
			agents.append(agent)
	if not agents.is_empty():
		var slots := Troops.formation(province, raids.entry, MilitaryNav.GROUND, agents.size(), CombatState.BANDITS)
		for k: int in agents.size():
			var c := agents[k].combat
			c.goal = slots[k % slots.size()] if not slots.is_empty() else IsoMath.tile_center(raids.entry)
			c.post = c.goal
			c.goal_level = MilitaryNav.GROUND
			c.clear_path()
			c.path_tick = -1000


## The raid is over (beaten or gone): broken doors and gates are mended, ladders go, the
## next raid is set.
static func _end(province: ProvinceSim, rng: RandomNumberGenerator, event: StringName) -> void:
	call_off(province)
	province.raids.next_tick = province.tick + SimClock.seconds_to_ticks(
			rng.randf_range(GAP_MIN_SECONDS, GAP_MAX_SECONDS))
	province.events.emit(event, {})


## Ends the raid now (its bandits are gone from the map): ladders go, broken doors and gates
## are mended. The army it came from (if any) is kept in [member army].
static func call_off(province: ProvinceSim) -> void:
	var raids := province.raids
	raids.state = State.WAITING
	raids.members.clear()
	raids.entry = Vector2i(-1, -1)
	for foot: Vector2i in province.mil.ladders.keys():
		Troops.remove_ladder(province, foot)
	for building: BuildingState in province.buildings.all():
		if building.def.max_hp > 0 and building.hp < building.def.max_hp:
			building.hp = building.def.max_hp
			for tile: Vector2i in building.passage_tiles():
				province.refresh_tile(tile)


# --- Townsfolk --------------------------------------------------------------------------------

## Townsfolk near a bandit drop their work and run for the town hall (or the camp).
static func _shelter_townsfolk(province: ProvinceSim) -> void:
	var raids := province.raids
	var hall := province.seat()
	if hall == null:
		return
	var bandits: Array[Vector2] = []
	for id: int in raids.members:
		var agent := province.agents.get_agent(id)
		if agent != null:
			bandits.append(agent.pos)
	shelter_near(province, bandits)


## Townsfolk within DANGER_RADIUS of [param enemies] (positions) run for the town hall.
static func shelter_near(province: ProvinceSim, enemies: Array[Vector2]) -> void:
	var bandits := enemies
	if bandits.is_empty() or province.seat() == null:
		return
	for agent: Agent in province.agents.all():
		if agent.combat != null or agent.kind == Barracks.RECRUIT_KIND or agent.kind == Merchant.AGENT_KIND:
			continue
		if agent.vehicle == Carriers.WAGON or agent.vehicle == Ships.ABOARD or agent.vehicle == Carriers.SETTLER_WAGON:
			continue
		if agent.task != null and agent.task.kind == Task.KIND_SHELTER:
			continue
		var near := false
		for at: Vector2 in bandits:
			if at.distance_squared_to(agent.pos) <= DANGER_RADIUS * DANGER_RADIUS:
				near = true
				break
		if near:
			shelter(province, agent)


static var _shelter_steps: Array[StepDef] = []


static func shelter(province: ProvinceSim, agent: Agent) -> void:
	if agent.task != null:
		TaskRunner.fail(province, agent)
	province.drop_carried(agent)
	agent.cooldown = 0
	var task := Task.new()
	task.kind = Task.KIND_SHELTER
	task.steps = shelter_steps()
	agent.task = task
	province.events.emit(&"agent_fled", {"agent": agent.id})


static func shelter_steps() -> Array[StepDef]:
	if _shelter_steps.is_empty():
		_shelter_steps = [ShelterStepDef.new()]
	return _shelter_steps


# --- Taking a province over (ready for part 3 and M8) ------------------------------------------

## Whether an attacker holds the province's seat: its door broken and no defender at it.
static func can_capture(province: ProvinceSim) -> bool:
	var hall := province.seat()
	return hall != null and hall.is_broken() and not defended(province, hall)


## The province passes to [param owner] (ProvinceDef.OWNER_*): its people and buildings stay,
## their happiness drops (ROADMAP M7: -30 for 10 minutes).
static func capture(sim: Simulation, province_id: int, owner: StringName) -> void:
	var world_province := sim.world.get_province(province_id)
	if world_province == null:
		return
	world_province.owner = owner
	var runtime := sim.province_state(province_id)
	if runtime != null:
		runtime.raids.mood_until = runtime.tick + SimClock.seconds_to_ticks(MOOD_SECONDS)
	sim.events.emit(&"province_captured", {"province": province_id, "owner": owner})


func to_dict() -> Dictionary:
	var d := {"state": state, "next": next_tick, "count": count}
	if entry.x >= 0:
		d["entry"] = SimCodec.vec2i(entry)
	if not members.is_empty():
		d["members"] = members.duplicate()
	if mood_until != 0:
		d["mood_until"] = mood_until
	if army != 0:
		d["army"] = army
	if loot_gold != 0:
		d["loot_gold"] = loot_gold
	return d


static func from_dict(d: Dictionary) -> Raids:
	var raids := Raids.new()
	raids.state = int(d.get("state", 0)) as State
	raids.next_tick = int(d.get("next", -1))
	raids.count = int(d.get("count", 0))
	raids.entry = SimCodec.to_vec2i(d.get("entry", [-1, -1]))
	raids.members = SimCodec.int_array(d.get("members", []))
	raids.mood_until = int(d.get("mood_until", 0))
	raids.army = int(d.get("army", 0))
	raids.loot_gold = int(d.get("loot_gold", 0))
	return raids
