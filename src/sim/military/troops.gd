class_name Troops
extends RefCounted
## Fighters under orders (M7 part 2, GDD §8, ARCHITECTURE §10): soldiers the player commands
## and bandits. Every tick each fighter picks a target by his stance, walks (on the ground
## and on the wall-walk, MilitaryNav.route), strikes or shoots; arrows fly for a while before
## they hit. Fighters that die leave the map. Soldiers in the ranks of their barracks
## (not commanded) are left to their task (SoldierStep).
##
## Orders: move in formation (two to a tile), attack a fighter, break a structure (a wall
## tile, a gate, a town hall's door). Stances: attack on sight, defend the post (chase only
## near it, then come back), hold the place (only strike what comes in reach).

## How far a fighter sees an enemy (tiles), how far a defender leaves his post for one.
const SIGHT := 9.0
const DEFEND_REACH := 5.0
## A sword's reach (tiles from foot to foot).
const MELEE_REACH := 1.15
## Ticks between route searches while chasing.
const REPATH_TICKS := 10
## How long a fighter leaves an enemy he found no way to (5 s).
const BLOCKED_TICKS := 50
## Arrows: tiles per second; a fighter on the wall-walk shoots 2 tiles farther and takes half
## the damage from arrows (ROADMAP M7).
const ARROW_SPEED := 14.0
const WALL_RANGE_BONUS := 2
const WALL_COVER := 0.5
## Formation places on one tile.
const PER_TILE := 2
const _SLOT_OFFSETS: Array[Vector2] = [Vector2(-0.2, 0.2), Vector2(0.2, -0.2)]

## The ballista (J1 part 2): a siege engine that fights like an archer from far away, and
## hurts walls and gates only by this share of its bolt.
const BALLISTA := &"ballista"
const BALLISTA_WALL_SHARE := 0.2

## Arrows in flight: shooter faction, target agent id, from and to (grid), ticks left, damage.
## A ballista's bolt (J1 part 2) is drawn heavier; one shot at a wall or a gate lands on
## [member wall] instead of a man.
class Arrow:
	extends RefCounted
	var target_id: int
	var bolt: bool = false
	var wall: Vector2i = Vector2i(-1, -1)
	var from: Vector2
	var from_level: int
	var to: Vector2
	var to_level: int
	var ticks: int
	var total: int
	var damage: int

	func to_dict() -> Dictionary:
		var d := {"t": target_id, "f": SimCodec.vec2(from), "fl": from_level, "to": SimCodec.vec2(to),
				"tl": to_level, "n": ticks, "of": total, "d": damage}
		if bolt:
			d["b"] = 1
		if wall.x >= 0:
			d["w"] = SimCodec.vec2i(wall)
		return d

	static func from_dict(d: Dictionary) -> Arrow:
		var a := Arrow.new()
		a.target_id = int(d["t"])
		a.from = SimCodec.to_vec2(d["f"])
		a.from_level = int(d["fl"])
		a.to = SimCodec.to_vec2(d["to"])
		a.to_level = int(d["tl"])
		a.ticks = int(d["n"])
		a.total = int(d["of"])
		a.damage = int(d["d"])
		a.bolt = int(d.get("b", 0)) == 1
		a.wall = SimCodec.to_vec2i(d["w"]) if d.has("w") else Vector2i(-1, -1)
		return a


# --- Orders (commands call these) -----------------------------------------------------------

## Whether the player may command [param agent]: one of his soldiers, out of the barracks and
## not aboard a ship (P2 part 2).
static func is_soldier(province: ProvinceSim, agent: Agent) -> bool:
	return agent != null and agent.combat != null and agent.combat.faction == CombatState.PLAYER \
			and agent.kind != Barracks.RECRUIT_KIND and province.data.get_unit(agent.kind) != null \
			and agent.vehicle != Ships.ABOARD


## Whether [param unit] fights people: soldiers, and of the siege engines only the ballista.
static func fights_people(unit: UnitDef) -> bool:
	return unit != null and unit.combat.attack > 0 and (unit.siege == &"" or unit.siege == BALLISTA)


static func unit_of(province: ProvinceSim, agent: Agent) -> UnitDef:
	var id := agent.combat.unit if agent.combat.unit != &"" else agent.kind
	return province.data.get_unit(id)


## Takes [param agent] out of the ranks (or out of an earlier order): Troops drives him now.
static func take_command(agent: Agent) -> void:
	var c := agent.combat
	if not c.commanded:
		c.commanded = true
		agent.clear_path()
		agent.path_state = Agent.PathState.NONE
		if agent.task != null:
			agent.task.bb.erase("_placed")
	c.target_id = 0
	c.target_tile = Vector2i(-1, -1)
	c.aim = Vector2i(-1, -1)
	c.clear_path()
	c.path_tick = -1000


## Sends [param agents] to [param tile] on [param level] in formation. Returns how many got
## a place (0: the place cannot be reached on that level).
static func order_move(province: ProvinceSim, agents: Array[Agent], tile: Vector2i, level: int) -> int:
	var slots := formation(province, tile, level, agents.size(), CombatState.PLAYER)
	if slots.is_empty():
		return 0
	var free: Array[Agent] = agents.duplicate()
	var placed := 0
	for slot: Vector2 in slots:
		var best: Agent = null
		for agent: Agent in free:
			if best == null or agent.pos.distance_squared_to(slot) < best.pos.distance_squared_to(slot):
				best = agent
		if best == null:
			break
		free.erase(best)
		take_command(best)
		best.combat.order = CombatState.Order.MOVE
		best.combat.post = slot
		best.combat.post_level = level
		best.combat.goal = slot
		best.combat.goal_level = level
		placed += 1
	return placed


static func order_attack(agents: Array[Agent], target: Agent) -> void:
	for agent: Agent in agents:
		take_command(agent)
		agent.combat.order = CombatState.Order.ATTACK
		agent.combat.target_id = target.id


## Sends [param agents] back to the ranks of their barracks.
static func order_return(province: ProvinceSim, agents: Array[Agent]) -> void:
	for agent: Agent in agents:
		var barracks := province.buildings.get_building(agent.home_id)
		take_command(agent)
		agent.combat.order = CombatState.Order.RETURN
		var door := province.door_tile(barracks) if barracks != null else Agent.NO_TILE
		if door == Agent.NO_TILE:
			_release(agent)
			continue
		agent.combat.goal = IsoMath.tile_center(door)
		agent.combat.goal_level = MilitaryNav.GROUND


## Sends [param agents] to break [param tile] (a wall, a gate or a door; M7 part 3): each goes
## for what stands in his way to it first; laddermen lean their ladders on stone walls.
static func order_break(province: ProvinceSim, agents: Array[Agent], tile: Vector2i) -> void:
	var building := province.buildings.get_building(province.grid.occupant(tile))
	if building != null and building == province.seat():
		tile = building.entrance_tile()
	for agent: Agent in agents:
		take_command(agent)
		var unit := unit_of(province, agent)
		var aim := tile
		var stand := stand_by(province, tile, agent)
		if unit.siege == &"ladder" or stand == Agent.NO_TILE or province.mil.route(province, agent.tile(),
				agent.level, stand, 0, agent.combat.faction).is_empty():
			aim = Raids.obstacle(province, agent, tile, unit.siege)
		if aim == Agent.NO_TILE or not structure_standing(province, aim):
			continue
		agent.combat.order = CombatState.Order.STRUCTURE
		agent.combat.target_tile = aim
		agent.combat.aim = tile


static func set_stance(agents: Array[Agent], stance: CombatState.Stance) -> void:
	for agent: Agent in agents:
		agent.combat.stance = stance


static func _release(agent: Agent) -> void:
	var c := agent.combat
	c.commanded = false
	c.order = CombatState.Order.NONE
	c.target_id = 0
	c.clear_path()
	agent.level = MilitaryNav.GROUND
	agent.activity = &"idle"


## Places for [param count] fighters around [param tile] on [param level]: the nearest
## walkable tiles first, two to a tile. Empty when the tile (or a tile near it) is not
## walkable on that level.
static func formation(province: ProvinceSim, tile: Vector2i, level: int, count: int, faction: int) -> Array[Vector2]:
	var nav := province.mil.nav_of(province, level, faction)
	var start := tile
	if not nav.is_walkable(start):
		start = Agent.NO_TILE
		for r: int in range(1, 3):
			for dy: int in range(-r, r + 1):
				for dx: int in range(-r, r + 1):
					var t := tile + Vector2i(dx, dy)
					if start == Agent.NO_TILE and nav.is_walkable(t):
						start = t
		if start == Agent.NO_TILE:
			return []
	var slots: Array[Vector2] = []
	var seen: Dictionary[Vector2i, bool] = {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	var area := nav.area_of(start)
	while head < queue.size() and slots.size() < count:
		var t := queue[head]
		head += 1
		for k: int in PER_TILE:
			if slots.size() < count:
				slots.append(IsoMath.tile_center(t) + (_SLOT_OFFSETS[k] if count > 1 else Vector2.ZERO))
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var n := t + step
			if not seen.has(n) and nav.is_walkable(n) and nav.area_of(n) == area:
				seen[n] = true
				queue.append(n)
	return slots


# --- Every tick -----------------------------------------------------------------------------

static func update(province: ProvinceSim) -> void:
	var fighters: Array[Agent] = []
	for agent: Agent in province.agents.all():
		if agent.combat != null and agent.combat.commanded and agent.vehicle != Ships.ABOARD:
			fighters.append(agent)
	if fighters.is_empty() and province.arrows.is_empty():
		return
	var buckets := _buckets(province)
	var dead: Array[Agent] = []
	for agent: Agent in fighters:
		if agent.combat.hp > 0:
			_think(province, agent, buckets, dead)
	_fly_arrows(province, dead)
	for agent: Agent in fighters:
		if agent.combat.hp > 0:
			_move(province, agent)
	for agent: Agent in dead:
		kill(province, agent)
	if province.tick % SimClock.TICKS_PER_SECOND == 0 and not province.mil.ladders.is_empty():
		_push_ladders(province, buckets)


## Fighters (commanded or in the ranks) by 4x4-tile cell, for finding the nearest enemy.
static func _buckets(province: ProvinceSim) -> Dictionary[Vector2i, Array]:
	var result: Dictionary[Vector2i, Array] = {}
	for agent: Agent in province.agents.all():
		if agent.combat == null or agent.combat.hp <= 0 or agent.kind == Barracks.RECRUIT_KIND \
				or agent.vehicle == Ships.ABOARD:
			continue
		var cell := Vector2i(floori(agent.pos.x / 4.0), floori(agent.pos.y / 4.0))
		if not result.has(cell):
			result[cell] = []
		result[cell].append(agent)
	return result


## The nearest enemy of [param agent] within [param reach] tiles of [param around].
## Faction -> whether it has a way between the ground and the wall-walk, this tick.
static var _climb: Dictionary[int, bool] = {}
static var _climb_tick: int = -1


static func _can_climb(province: ProvinceSim, faction: int) -> bool:
	if _climb_tick != province.tick:
		_climb.clear()
		_climb_tick = province.tick
	if not _climb.has(faction):
		_climb[faction] = province.walls.is_empty() or not province.mil.portals(province, faction).is_empty()
	return _climb[faction]


## [param walk]: the grid he walks on (his level); then an enemy farther than [param shoot]
## (his reach) counts only when he can get to him: in the same part of his level, or on the
## other level when his side has a way up or down (stairs, ladders). [param skip]: an enemy he
## found no way to a moment ago.
static func nearest_enemy(agent: Agent, around: Vector2, reach: float, buckets: Dictionary[Vector2i, Array],
		walk: NavGrid = null, shoot: float = 0.0, climb: bool = true, skip: int = 0) -> Agent:
	var area := walk.area_of(agent.tile()) if walk != null else -1
	var best: Agent = null
	var best_d := reach
	var r := ceili(reach / 4.0)
	var cell := Vector2i(floori(around.x / 4.0), floori(around.y / 4.0))
	for dy: int in range(-r, r + 1):
		for dx: int in range(-r, r + 1):
			for other: Agent in buckets.get(cell + Vector2i(dx, dy), []):
				if other.combat.faction == agent.combat.faction or other.combat.hp <= 0 or other.id == skip:
					continue
				var d := other.pos.distance_to(around)
				if walk != null and other.pos.distance_to(agent.pos) > shoot:
					if other.level != agent.level:
						if not climb:
							continue
					elif walk.area_of(other.tile()) != area:
						continue
				if d < best_d:
					best_d = d
					best = other
	return best


static func _think(province: ProvinceSim, agent: Agent, buckets: Dictionary[Vector2i, Array], dead: Array[Agent]) -> void:
	var c := agent.combat
	var unit := unit_of(province, agent)
	if c.cooldown > 0:
		c.cooldown -= 1
	var target := province.agents.get_agent(c.target_id) if c.target_id != 0 else null
	if target != null and (target.combat == null or target.combat.hp <= 0 or target.combat.faction == c.faction):
		target = null
	if target == null:
		c.target_id = 0
		if c.order == CombatState.Order.ATTACK:
			c.order = CombatState.Order.MOVE
			c.goal = c.post
			c.goal_level = c.post_level
			c.clear_path()
	if not fights_people(unit):
		# Rams and laddermen never fight people (a ballista does, J1 part 2).
		target = null
		c.target_id = 0
	var reach := float(unit.combat.attack_range) + (WALL_RANGE_BONUS if agent.level == MilitaryNav.WALL and unit.combat.attack_range > 1 else 0)
	var ranged := unit.combat.attack_range > 1
	# Looking for a fight.
	if target == null and fights_people(unit) and c.order != CombatState.Order.RETURN and c.order != CombatState.Order.MARCH and (c.order != CombatState.Order.MOVE or not c.has_path()):
		var climb := _can_climb(province, c.faction)
		var skip := c.blocked_id if province.tick < c.blocked_until else 0
		var walk := province.mil.nav_of(province, agent.level, c.faction)
		var shoot := reach if ranged else MELEE_REACH
		match c.stance:
			CombatState.Stance.AGGRESSIVE:
				target = nearest_enemy(agent, agent.pos, maxf(SIGHT, reach), buckets, walk, shoot, climb, skip)
			CombatState.Stance.DEFENSIVE:
				var home := c.post if c.post.x >= 0.0 else agent.pos
				target = nearest_enemy(agent, home, DEFEND_REACH + (reach if ranged else 0.0), buckets,
						walk, shoot, climb, skip)
			CombatState.Stance.HOLD:
				target = nearest_enemy(agent, agent.pos, shoot, buckets, walk, shoot, climb, skip)
		if target != null:
			c.target_id = target.id
	if target != null:
		var d := agent.pos.distance_to(target.pos)
		var in_reach := d <= reach if ranged else (d <= MELEE_REACH and agent.level == target.level)
		if in_reach:
			c.clear_path()
			_face(agent, target.pos)
			agent.activity = &"drill" if c.cooldown > SimClock.seconds_to_ticks(unit.combat.attack_cooldown) - 6 else &"idle"
			if c.cooldown == 0:
				_strike(province, agent, unit, target, ranged, dead)
			return
		var leash := c.stance == CombatState.Stance.DEFENSIVE and c.post.x >= 0.0 \
				and target.pos.distance_to(c.post) > DEFEND_REACH + (reach if ranged else 0.0) + 1.0
		if c.stance == CombatState.Stance.HOLD or leash:
			c.target_id = 0
			if c.order == CombatState.Order.ATTACK:
				c.order = CombatState.Order.MOVE
			c.goal = c.post
			c.goal_level = c.post_level
			c.clear_path()
			return
		# Chase: a new route now and then, towards where the target is.
		if not c.has_path() or province.tick - c.path_tick >= REPATH_TICKS:
			var to := Vector2i(target.pos.floor())
			if not _route(province, agent, to, target.level, target.pos) and not c.has_path():
				# No way to him: leave him be for a while (an archer on a wall without a way up).
				c.blocked_id = target.id
				c.blocked_until = province.tick + BLOCKED_TICKS
				c.target_id = 0
		return
	# No enemy: carry out the order.
	if c.order == CombatState.Order.STRUCTURE:
		_siege(province, agent, unit)
		return
	if c.goal.x < 0.0:
		agent.activity = &"idle"
		return
	var at_goal := agent.pos.distance_to(c.goal) < 0.05 and agent.level == c.goal_level
	if at_goal:
		agent.activity = &"idle"
		if c.order == CombatState.Order.RETURN:
			_release(agent)
		elif c.order == CombatState.Order.MARCH:
			march_off(province, agent)
		return
	if not c.has_path() and province.tick - c.path_tick >= REPATH_TICKS:
		_route(province, agent, Vector2i(c.goal.floor()), c.goal_level, c.goal)


## Looks for a walk to [param tile] on [param level], ending at [param exact].
static func _route(province: ProvinceSim, agent: Agent, tile: Vector2i, level: int, exact: Vector2) -> bool:
	var c := agent.combat
	c.path_tick = province.tick
	var here := agent.tile()
	if here == tile and agent.level == level:
		c.clear_path()
		c.path = [tile]
		c.levels = PackedByteArray([level])
		c.goal = exact
		return true
	# Standing in a doorway or where a wall has just been laid: out by the nearest free tile.
	var lead: Array[Vector2i] = []
	var nav := province.mil.nav_of(province, agent.level, c.faction)
	if not nav.is_walkable(here):
		var out := _way_out(province, agent, nav)
		if out == Agent.NO_TILE:
			c.clear_path()
			return false
		lead = [here]
		here = out
	var found := province.mil.route(province, here, agent.level, tile, level, c.faction)
	if not found.is_empty() and not lead.is_empty():
		(found[0] as Array).push_front(lead[0])
		var levels: PackedByteArray = found[1]
		levels.insert(0, agent.level)
		found[1] = levels
	if found.is_empty():
		c.clear_path()
		return false
	c.path = found[0]
	c.levels = found[1]
	c.path_index = 1 if c.path.size() > 1 else 0
	if c.order != CombatState.Order.ATTACK and c.target_id == 0:
		c.goal = exact
		c.goal_level = level
	return true


## A walkable tile next to where [param agent] stands (the front of a door first).
static func _way_out(province: ProvinceSim, agent: Agent, nav: NavGrid) -> Vector2i:
	var building := province.building_entered_at(agent.tile())
	if building != null:
		for door: Vector2i in province.door_tiles(building):
			if nav.is_walkable(door):
				return door
	var best := Agent.NO_TILE
	for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var t := agent.tile() + step
		if nav.is_walkable(t) and (best == Agent.NO_TILE or agent.pos.distance_squared_to(IsoMath.tile_center(t)) \
				< agent.pos.distance_squared_to(IsoMath.tile_center(best))):
			best = t
	return best


static func _face(agent: Agent, at: Vector2) -> void:
	var dir := IsoMath.screen_dir(at - agent.pos)
	if dir >= 0:
		agent.facing = dir


## A blow or a shot at [param target].
static func _strike(province: ProvinceSim, agent: Agent, unit: UnitDef, target: Agent, ranged: bool,
		dead: Array[Agent]) -> void:
	var c := agent.combat
	c.cooldown = maxi(SimClock.seconds_to_ticks(unit.combat.attack_cooldown), 1)
	var damage := float(unit.combat.attack)
	var target_unit := unit_of(province, target)
	if target_unit != null:
		damage *= float(unit.combat.bonus_vs.get(target_unit.id, 1.0))
	if ranged:
		var arrow := Arrow.new()
		arrow.target_id = target.id
		arrow.from = agent.pos
		arrow.from_level = agent.level
		arrow.to = target.pos
		arrow.to_level = target.level
		arrow.total = maxi(roundi(agent.pos.distance_to(target.pos) / ARROW_SPEED * SimClock.TICKS_PER_SECOND), 2)
		arrow.ticks = arrow.total
		arrow.damage = roundi(damage)
		arrow.bolt = unit.siege == BALLISTA
		province.arrows.append(arrow)
		province.events.emit(&"arrow_shot", {"agent": agent.id})
		return
	hurt(province, target, roundi(damage), dead)
	province.events.emit(&"unit_struck", {"agent": agent.id, "target": target.id})


## Takes life off [param target]; he joins [param dead] when it runs out.
static func hurt(province: ProvinceSim, target: Agent, damage: int, dead: Array[Agent]) -> void:
	if target.combat == null or target.combat.hp <= 0:
		return
	target.combat.hp -= damage
	if target.combat.hp <= 0:
		target.combat.hp = 0
		dead.append(target)
	elif target.combat.faction == CombatState.PLAYER and not target.combat.commanded:
		# A soldier in the ranks who is attacked fights back.
		take_command(target)
		target.combat.order = CombatState.Order.MOVE
		target.combat.post = target.pos
		target.combat.goal = target.pos


static func _fly_arrows(province: ProvinceSim, dead: Array[Agent]) -> void:
	if province.arrows.is_empty():
		return
	var left: Array[Arrow] = []
	for arrow: Arrow in province.arrows:
		arrow.ticks -= 1
		if arrow.ticks > 0:
			left.append(arrow)
			continue
		if arrow.wall.x >= 0:
			# A ballista's bolt at a wall or a gate.
			if structure_standing(province, arrow.wall):
				damage_structure(province, arrow.wall, arrow.damage)
			continue
		var target := province.agents.get_agent(arrow.target_id)
		if target == null or target.combat == null:
			continue
		# A target that ran far from where it was aimed at is missed.
		if target.pos.distance_to(arrow.to) > 1.2:
			continue
		var damage := arrow.damage
		var target_unit := unit_of(province, target)
		if target_unit != null:
			damage = roundi(damage * target_unit.combat.ranged_taken)
		if target.level == MilitaryNav.WALL:
			damage = roundi(damage * WALL_COVER)
		hurt(province, target, maxi(damage, 1), dead)
	province.arrows = left


## A fighter dies: he falls where he stands and leaves the map (the view shows him lying).
static func kill(province: ProvinceSim, agent: Agent) -> void:
	if not province.agents.has_agent(agent.id):
		return
	var barracks := province.buildings.get_building(agent.home_id)
	if barracks != null:
		barracks.soldiers.erase(agent.id)
		barracks.recruits.erase(agent.id)
	province.events.emit(&"unit_died", {"agent": agent.id, "kind": agent.kind, "pos": agent.pos,
			"level": agent.level, "facing": agent.facing, "faction": agent.combat.faction})
	province.remove_agent(agent)


## Sends [param agents] to [param exit] at the edge of the map, where they leave to join army
## [param army] on the world map (M7 part 3): out of the ranks and out of their barracks.
static func order_march(province: ProvinceSim, agents: Array[Agent], army: int, exit: Vector2i) -> void:
	var slots := formation(province, exit, MilitaryNav.GROUND, agents.size(), agents[0].combat.faction) \
			if not agents.is_empty() else []
	for k: int in agents.size():
		var agent := agents[k]
		var barracks := province.buildings.get_building(agent.home_id)
		if barracks != null and barracks.def.soldier_beds > 0:
			barracks.soldiers.erase(agent.id)
			agent.home_id = 0
		take_command(agent)
		var c := agent.combat
		c.army = army
		c.order = CombatState.Order.MARCH
		c.stance = CombatState.Stance.DEFENSIVE
		c.goal = slots[k] if k < slots.size() else IsoMath.tile_center(exit)
		c.post = c.goal
		c.goal_level = MilitaryNav.GROUND
		c.post_level = MilitaryNav.GROUND


## A marching soldier at the edge leaves the map: Simulation adds him to his army.
static func march_off(province: ProvinceSim, agent: Agent) -> void:
	var c := agent.combat
	province.marched.append({"army": c.army, "unit": unit_of(province, agent).id, "hp": c.hp,
			"faction": c.faction})
	province.events.emit(&"unit_marched_off", {"agent": agent.id, "army": c.army})
	province.remove_agent(agent)


# --- Walking ----------------------------------------------------------------------------------

static func _move(province: ProvinceSim, agent: Agent) -> void:
	var c := agent.combat
	if not c.has_path():
		# Last steps to the exact place in the formation.
		if c.goal.x >= 0.0 and agent.level == c.goal_level and agent.tile() == Vector2i(c.goal.floor()) \
				and c.target_id == 0:
			var delta := c.goal - agent.pos
			var reach := Movement.BASE_SPEED * SimClock.TICK * 0.8
			if delta.length() > 0.01:
				agent.pos += delta if delta.length() <= reach else delta.normalized() * reach
				_face(agent, c.goal)
				agent.activity = &"walk"
			elif agent.activity == &"walk":
				agent.activity = &"idle"
		return
	var unit := unit_of(province, agent)
	var budget := Movement.BASE_SPEED * unit.combat.speed * SimClock.TICK
	while budget > 0.0 and c.has_path():
		var tile := c.path[c.path_index]
		var level := int(c.levels[c.path_index])
		if level != agent.level and agent.tile() != tile:
			# A step between levels: inner stairs are taken out of sight at once.
			var portal := province.mil.portal_between(province, agent.tile(), tile, c.faction)
			if portal == null:
				c.clear_path()   # the stairs or the ladder are gone: look again
				return
			if portal.kind == MilitaryNav.INSIDE:
				agent.pos = IsoMath.tile_center(tile)
				agent.level = level
				c.path_index += 1
				continue
		var nav := province.mil.nav_of(province, level, c.faction)
		if not nav.is_walkable(tile):
			c.clear_path()   # blocked meanwhile (a gate shut, a wall laid)
			return
		var target := IsoMath.tile_center(tile)
		if c.path_index == c.path.size() - 1 and c.target_id == 0 and c.goal.x >= 0.0 \
				and Vector2i(c.goal.floor()) == tile:
			target = c.goal
		var delta := target - agent.pos
		var length := delta.length()
		var cost := nav.get_cost(tile) if level == MilitaryNav.GROUND else 1.0
		var step := budget / cost
		if length <= step:
			agent.pos = target
			budget -= length * cost
			agent.level = level
			c.path_index += 1
		else:
			agent.pos += delta / length * step
			budget = 0.0
			if agent.tile() == tile:
				agent.level = level
		_face(agent, target)
	agent.activity = &"walk"


# --- Breaking structures (bandits, and in part 3 the player's army) ---------------------------

## Order STRUCTURE: walks next to [param c.target_tile] and strikes it.
static func _siege(province: ProvinceSim, agent: Agent, unit: UnitDef) -> void:
	var c := agent.combat
	var tile := c.target_tile
	if not structure_standing(province, tile):
		# The obstacle fell: on to what he was sent to break.
		if c.aim != tile and c.aim.x >= 0 and structure_standing(province, c.aim) and c.faction != CombatState.BANDITS:
			var aim := c.aim
			order_break(province, [agent], aim)
			if c.order == CombatState.Order.STRUCTURE:
				return
		c.order = CombatState.Order.NONE
		c.target_tile = Vector2i(-1, -1)
		c.aim = Vector2i(-1, -1)
		agent.activity = &"idle"
		return
	if unit.siege == BALLISTA and agent.level == MilitaryNav.GROUND \
			and agent.pos.distance_to(IsoMath.tile_center(tile)) <= float(unit.combat.attack_range):
		# A ballista shoots at the wall or the gate from where it stands (J1 part 2).
		c.clear_path()
		_face(agent, IsoMath.tile_center(tile))
		agent.activity = &"drill" if c.cooldown > SimClock.seconds_to_ticks(unit.combat.attack_cooldown) - 6 else &"idle"
		if c.cooldown == 0:
			c.cooldown = maxi(SimClock.seconds_to_ticks(unit.combat.attack_cooldown), 1)
			var bolt := Arrow.new()
			bolt.target_id = 0
			bolt.wall = tile
			bolt.bolt = true
			bolt.from = agent.pos
			bolt.from_level = agent.level
			bolt.to = IsoMath.tile_center(tile)
			bolt.to_level = MilitaryNav.GROUND
			bolt.total = maxi(roundi(agent.pos.distance_to(bolt.to) / ARROW_SPEED * SimClock.TICKS_PER_SECOND), 2)
			bolt.ticks = bolt.total
			bolt.damage = maxi(roundi(unit.combat.attack * BALLISTA_WALL_SHARE), 1)
			province.arrows.append(bolt)
			province.events.emit(&"arrow_shot", {"agent": agent.id})
		return
	if agent.level == MilitaryNav.GROUND and _at_structure(province, agent.pos, tile):
		c.clear_path()
		_face(agent, IsoMath.tile_center(tile))
		if unit.siege == &"ladder":
			_place_ladder(province, agent, tile)
			return
		agent.activity = &"drill"
		if c.cooldown == 0:
			c.cooldown = maxi(SimClock.seconds_to_ticks(unit.combat.attack_cooldown), 1)
			damage_structure(province, tile, unit.combat.attack)
		return
	if not c.has_path() and province.tick - c.path_tick >= REPATH_TICKS:
		var stand := stand_by(province, tile, agent)
		# Not all on one spot: a little towards the structure, a little aside, by his id.
		var jitter := Vector2(float((agent.id * 37) % 7 - 3), float((agent.id * 53) % 7 - 3)) * 0.08
		if stand != Agent.NO_TILE and _route(province, agent, stand, MilitaryNav.GROUND,
				IsoMath.tile_center(stand) + jitter) and c.path[c.path.size() - 1] == stand:
			return
		if c.faction == CombatState.BANDITS:
			return   # their raid aims them anew (Raids)
		# No way to it: what stands in the way first, or nothing to do.
		var aim := Raids.obstacle(province, agent, tile, unit.siege)
		if aim != tile and aim != Agent.NO_TILE and structure_standing(province, aim):
			c.target_tile = aim
		else:
			c.order = CombatState.Order.NONE
			c.target_tile = Vector2i(-1, -1)
			agent.activity = &"idle"


## A ladderman next to stone wall [param tile] leans his ladder on it (from his own tile,
## orthogonally): it becomes a way up for everybody (MilitaryNav portals).
static func _place_ladder(province: ProvinceSim, agent: Agent, tile: Vector2i) -> void:
	var c := agent.combat
	var foot := agent.tile()
	var d := tile - foot
	if absi(d.x) + absi(d.y) != 1 or not province.walls.is_stone(tile) or province.mil.ladders.has(foot):
		# Only straight against the wall: step to a tile beside it first.
		var stand := Agent.NO_TILE
		for step: Vector2i in Walls.DIRS:
			var t := tile - step
			if province.mil.ground_nav(province, c.faction).is_walkable(t) and not province.mil.ladders.has(t):
				stand = t
				break
		if stand == Agent.NO_TILE or stand == foot:
			c.order = CombatState.Order.NONE
			return
		_route(province, agent, stand, MilitaryNav.GROUND, IsoMath.tile_center(stand))
		return
	province.mil.ladders[foot] = tile
	c.order = CombatState.Order.NONE
	c.target_tile = Vector2i(-1, -1)
	agent.activity = &"idle"
	province.events.emit(&"ladder_placed", {"tile": foot, "wall": tile, "agent": agent.id})


## A defender standing on the wall where a ladder leans, with no enemy on or at it, pushes
## it down.
static func _push_ladders(province: ProvinceSim, buckets: Dictionary[Vector2i, Array]) -> void:
	for foot: Vector2i in province.mil.ladders.keys():
		var top: Vector2i = province.mil.ladders[foot]
		var defender := false
		var climbing := false
		var cell := Vector2i(floori(top.x / 4.0), floori(top.y / 4.0))
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				for other: Agent in buckets.get(cell + Vector2i(dx, dy), []):
					var near_top := other.pos.distance_to(IsoMath.tile_center(top)) < 1.0 and other.level == MilitaryNav.WALL
					var near_foot := other.pos.distance_to(IsoMath.tile_center(foot)) < 0.8 and other.level == MilitaryNav.GROUND
					if other.combat.faction == province.home_faction and near_top:
						defender = true
					elif other.combat.faction != province.home_faction and (near_top or near_foot):
						climbing = true
		if defender and not climbing:
			remove_ladder(province, foot)


## Ladders whose wall fell or that defenders pushed down go (M7 part 2).
static func remove_ladder(province: ProvinceSim, foot: Vector2i) -> void:
	if province.mil.ladders.erase(foot):
		province.events.emit(&"ladder_removed", {"tile": foot})


static func _next_to(pos: Vector2, tile: Vector2i) -> bool:
	var d := pos - IsoMath.tile_center(tile)
	return absf(d.x) <= 1.05 and absf(d.y) <= 1.05


## Men breaking one structure spread over this many of the nearest places around it.
const STAND_SPREAD := 4


## The tiles a blow at [param tile] can land on: the whole building (a gatehouse, a tower, a
## town hall) or the one wall tile.
static func strike_tiles(province: ProvinceSim, tile: Vector2i) -> Array[Vector2i]:
	var building := province.buildings.get_building(province.grid.occupant(tile))
	if building != null and building.def.max_hp > 0 and province.walls.kind(tile) == Walls.NONE:
		return building.tiles()
	return [tile]


## A ground tile next to [param tile] (to any tile of its building) [param agent] can walk to:
## one of the STAND_SPREAD nearest (by his id, so a crowd spreads round it), or NO_TILE.
static func stand_by(province: ProvinceSim, tile: Vector2i, agent: Agent) -> Vector2i:
	var nav := province.mil.ground_nav(province, agent.combat.faction)
	var area := nav.area_of(agent.tile())
	var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	if unit_of(province, agent).siege != &"ladder":
		steps.append_array([Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)])
	var targets := strike_tiles(province, tile)
	var seen: Dictionary[Vector2i, bool] = {}
	var places: Array[Vector2i] = []
	for target: Vector2i in targets:
		for step: Vector2i in steps:
			var t := target + step
			if seen.has(t) or targets.has(t):
				continue
			seen[t] = true
			if nav.is_walkable(t) and nav.area_of(t) == area and not province.mil.ladders.has(t):
				places.append(t)
	if places.is_empty():
		return Agent.NO_TILE
	places.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := agent.pos.distance_squared_to(IsoMath.tile_center(a))
		var db := agent.pos.distance_squared_to(IsoMath.tile_center(b))
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	return places[agent.id % mini(places.size(), STAND_SPREAD)]


## Whether [param pos] is next to (any tile of) the structure at [param tile].
static func _at_structure(province: ProvinceSim, pos: Vector2, tile: Vector2i) -> bool:
	for t: Vector2i in strike_tiles(province, tile):
		if _next_to(pos, t):
			return true
	return false


## Whether something breakable stands at [param tile]: a wall tile or stairs, or a building
## with life (a gatehouse, a tower, a town hall's door) that is not broken.
static func structure_standing(province: ProvinceSim, tile: Vector2i) -> bool:
	if province.walls.kind(tile) != Walls.NONE:
		return true
	var building := province.buildings.get_building(province.grid.occupant(tile))
	return building != null and building.def.max_hp > 0 and building.hp > 0


## Strikes the structure at [param tile].
static func damage_structure(province: ProvinceSim, tile: Vector2i, amount: int) -> void:
	if province.walls.kind(tile) != Walls.NONE:
		province.damage_wall(tile, amount)
		province.events.emit(&"wall_damaged", {"tile": tile})
		return
	var building := province.buildings.get_building(province.grid.occupant(tile))
	if building == null or building.def.max_hp <= 0 or building.hp <= 0:
		return
	building.hp = maxi(building.hp - amount, 0)
	province.events.emit(&"building_damaged", {"building": building.id, "hp": building.hp})
	if building.hp == 0:
		province.break_building(building)


static func arrows_to_list(province: ProvinceSim) -> Array:
	var list := []
	for arrow: Arrow in province.arrows:
		list.append(arrow.to_dict())
	return list
