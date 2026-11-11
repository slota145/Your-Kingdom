class_name RulerPlanner
extends RefCounted
## The "planner" of the AI rulers (ROADMAP M8 part 3, owner's survey 2026-11-10): their towns
## live in the simplified mode like the player's provinces nobody looks at, and every so often
## each of their provinces opens a construction site for the next building of [constant PLAN],
## from huts and woodcutters to workshops, a port and barracks (the barracks come early: the
## ruler recruits soldiers there, RulerWar, M8 part 4). A spot is searched the way the neutral towns are laid out (NeutralTown):
## near the town centre, a woodcutter by the forest, a fisherman by the water; a farm gets its
## fields at once. The materials are carried and the site built by the province's own porters
## and builders, in the simplified mode or, while the player looks, by people.
##
## How fast they grow depends on the difficulty (owner's survey: easy about 40% slower, hard
## about 30% faster and with a small store to start with).

## The plan of growth: {building, how many the province should have}, in order. The first
## entries a province lacks are what it builds next (a few are tried, the first one it can pay
## for and find room for goes up). Entries the map cannot take (a port inland) are skipped.
## The rulers' barracks (E4 part 4): the large ones, the small ones where those do not fit.
const LARGE_BARRACKS := &"barracks_large"
const SMALL_BARRACKS := &"barracks_small"
const PLAN: Array[Array] = [
	[&"woodcutter", 2], [&"hut", 3], [&"stockpile", 1], [&"quarry", 1], [&"sawmill", 1],
	[&"fishing_hut", 1], [&"well", 1], [&"hut", 6], [&"farm", 1], [&"mill", 1], [&"bakery", 1],
	# E2 part 4: apples and game, the second and third kinds of food (burghers eat 2 kinds,
	# patricians 3), and food on a map without water.
	[&"orchard", 1], [&"forester", 1], [&"hunter_lodge", 1], [&"hut", 9], [&"town_hall", 1], [&"woodcutter", 3], [&"chapel", 1],
	[&"market", 1], [&"well", 2], [&"hut", 12], [&"stockpile", 2], [&"hop_farm", 1],
	[&"brewery", 1], [&"farm", 2], [&"orchard", 2], [&"hut", 15], [&"barracks_large", 1], [&"trading_post", 1], [&"builders_hut", 1],
	[&"sheep_farm", 1], [&"weaver", 1], [&"tar_kiln", 1], [&"port", 1], [&"shipyard", 1],
	[&"hut", 18], [&"tailor", 1], [&"fishing_hut", 2], [&"tavern", 1], [&"bakery", 2],
	[&"mill", 2], [&"farm", 3], [&"hut", 22], [&"church", 1],
	[&"stockpile", 3], [&"hut", 26], [&"pigsty", 1], [&"slaughterhouse", 1], [&"hut", 30],
	# Z1 part 4: an apiary with its hives (NeutralTown.place gives it 4) and mead for the tavern.
	[&"apiary", 1], [&"meadery", 1],
	# E3 part 3: a deep mine late, in a province rich in iron only (its ore is sold where the
	# rulers trade, RulerExpansion.SURPLUS_GOODS; a conquered one is ready for the player).
	[&"deep_mine", 1],
]
## Plan entries looked at each time (the first ones the province lacks).
const LOOK_AHEAD := 3
## Seconds between two new construction sites in a province, by difficulty (easy, normal,
## hard).
const BUILD_SECONDS: Array[int] = [56, 40, 28]
## Construction sites a province of a ruler has open at most, by difficulty.
const MAX_SITES: Array[int] = [1, 2, 2]
## Gold a ruler starts with, by difficulty; on hard also [constant HARD_STORE] in his storage.
const START_GOLD: Array[int] = [300, 500, 800]
const HARD_STORE: Dictionary[StringName, int] = {&"wood": 40, &"planks": 30, &"stone": 20, &"bread": 20}
## Seconds before a building without room is tried again in that province.
const NO_ROOM_SECONDS := 600
## The planner runs every this many seconds (each ruler's province in its own second).
const EVERY := 5
## Shortages looked at before the plan: below this much in store the province builds more of
## what makes it (woodcutters, stone, food), up to a limit that grows with its people.
const LOW_WOOD := 20
const LOW_STONE := 6
## Below this much stone a province rich in stone with a quarry opens its stone pit (E3).
const PIT_STONE := 20
const LOW_FOOD := 15
## From this many people a province rich in game keeps a second hunter (E3 part 4).
const GAME_PEOPLE := 20
## An input piled up this high means the next link of its chain needs another building.
const PILED_UP := 25
## After the plan the town keeps growing: a new hut whenever every house is full, up to this.
const MAX_HUTS := 40
## A sawmill stops while wood is below this or planks above PLANKS_ENOUGH (it would take all
## the wood the sites need); tar kilns stop with the wood low too.
const SAWMILL_WOOD := 12
const PLANKS_ENOUGH := 40


## The difficulty of the game (normal when the world has no settings).
static func difficulty(sim: Simulation) -> int:
	var s := sim.world.settings
	return s.growth_level() if s != null else GameSettings.NORMAL


## Every ruler holding a province has his state (a new game; a save from before part 3).
static func ensure_rulers(sim: Simulation) -> void:
	var level := difficulty(sim)
	for owner: StringName in Rulers.alive(sim.world):
		if sim.world.rulers.has(owner):
			continue
		var ruler := RulerState.create(owner, START_GOLD[level], sim.clock.tick)
		ruler.next_expedition = sim.clock.tick + SimClock.seconds_to_ticks(
				RulerExpansion.EXPEDITION_MINUTES[level] * 60.0)
		ruler.next_war = sim.clock.tick + RulerWar.first_ticks(level)
		sim.world.rulers[owner] = ruler
		if level == GameSettings.HARD:
			for id: int in Rulers.provinces_of(sim.world, owner):
				_give_store(sim.province_state(id))


static func _give_store(town: ProvinceSim) -> void:
	if town == null:
		return
	for building: BuildingState in town.storage_buildings():
		if building.stock == null:
			continue
		for good: StringName in HARD_STORE:
			building.stock.add(good, HARD_STORE[good])
		return


## Once a second (Simulation._update_world).
static func update(sim: Simulation) -> void:
	var second := sim.clock.tick / SimClock.TICKS_PER_SECOND
	var owners: Array[StringName] = []
	owners.assign(sim.world.rulers.keys())
	owners.sort()
	for owner: StringName in owners:
		if not Rulers.is_raiders(owner):   # (the raiders' towns stand as they are, M8 part 5)
			update_owner(sim, sim.world.rulers[owner], second)


## The planner of the provinces of [param ruler] (the automatic player of the test games uses
## it for the player's provinces too, M8 part 5).
static func update_owner(sim: Simulation, ruler: RulerState, second: int) -> void:
	for id: int in Rulers.provinces_of(sim.world, ruler.owner):
		if (second + id) % EVERY == 0:
			_plan_province(sim, ruler, id)


static func _plan_province(sim: Simulation, ruler: RulerState, id: int) -> void:
	var town := sim.province_state(id)
	if town == null or town.landing != null and town.landing.state != Landing.State.DONE:
		return
	var tick := sim.clock.tick
	if tick < int(ruler.next_build.get(id, 0)):
		return
	steward(town)
	var level := difficulty(sim)
	if town.sites.size() >= MAX_SITES[level]:
		return
	var placed := try_next(sim, ruler, id)
	if placed != null:
		ruler.next_build[id] = tick + SimClock.seconds_to_ticks(BUILD_SECONDS[level])


## Opens a construction site for the next building of the plan province [param id] lacks
## and can have now; returns it, or null.
static func try_next(sim: Simulation, ruler: RulerState, id: int) -> BuildingState:
	var town := sim.province_state(id)
	var counts := counts_of(town)
	var saving := ruler.saving_for == id
	for building_id: StringName in shortages(town, counts, saving):
		var def := sim.data.get_building(building_id)
		if def == null or _no_room(ruler, id, building_id, sim.clock.tick):
			continue
		if _affordable(town, ruler, def):
			var placed := _open(sim, ruler, id, town, def)
			if placed != null:
				return placed
	if saving and town.stored(&"wood") < LOW_WOOD + int(Departure.KIT[&"wood"]):
		return null   # the wood goes to the expedition's kit (with the wood there, the town
		# grows on while it waits for the bread: M8 part 4, it stalled before)
	var looked := 0
	for entry: Array in PLAN:
		var building_id: StringName = entry[0]
		if int(counts.get(building_id, 0)) >= int(entry[1]):
			continue
		if _no_room(ruler, id, building_id, sim.clock.tick):
			continue
		var def := sim.data.get_building(building_id)
		if def == null or not _allowed(town, def):
			continue
		looked += 1
		if _affordable(town, ruler, def):
			var placed := _open(sim, ruler, id, town, def)
			if placed != null:
				return placed
			if building_id == LARGE_BARRACKS:
				# No room for the 5x5 barracks: the small ones (E4 part 4).
				placed = _open_small_barracks(sim, ruler, id, town)
				if placed != null:
					return placed
		if looked >= LOOK_AHEAD:
			break
	return null


static func _open(sim: Simulation, ruler: RulerState, id: int, town: ProvinceSim, def: BuildingDef) -> BuildingState:
	var placed := place(town, def)
	if placed != null:
		sim.events.emit(&"ruler_built", {"owner": ruler.owner, "province": id, "def": def.id})
		return placed
	ruler.no_room[_room_key(id, def.id)] = sim.clock.tick + SimClock.seconds_to_ticks(NO_ROOM_SECONDS)
	return null


## What the province lacks most now, before the plan (buildings to try, most needed first):
## more woodcutters (and foresters) when wood runs low, a quarry for stone, fishermen, farms,
## mills and bakeries for food. Each kind up to a limit that grows with the people.
static func shortages(town: ProvinceSim, counts: Dictionary[StringName, int], saving: bool = false) -> Array[StringName]:
	var result: Array[StringName] = []
	var people := residents(town)
	var cutters := int(counts.get(&"woodcutter", 0))
	var low_wood := LOW_WOOD + (int(Departure.KIT[&"wood"]) if saving else 0)
	if town.stored(&"wood") < low_wood and cutters < mini(2 + people / 15, 8):
		result.append(&"woodcutter")
	if cutters >= 4 and int(counts.get(&"forester", 0)) * 2 < cutters:
		result.append(&"forester")
	# E3 part 3 (owner's survey 2026-11-11): in a province rich in stone the second source of
	# stone is a stone pit, which never runs out (the first quarry is cheaper to start). It is
	# opened while stone runs short, not out: it costs stone itself.
	var quarries := int(counts.get(&"quarry", 0))
	var rich := town.traits.has(ProvinceDef.RICH_STONE)
	if rich and quarries >= 1 and int(counts.get(&"stone_pit", 0)) < 1 \
			and town.stored(&"stone") < PIT_STONE:
		result.append(&"stone_pit")
	elif town.stored(&"stone") < LOW_STONE and quarries < (1 if rich else 2):
		result.append(&"quarry")
	if food(town) < LOW_FOOD and people > 0:
		if int(counts.get(&"fishing_hut", 0)) < 1 + people / 40:
			result.append(&"fishing_hut")
		# (E2 part 4: an orchard needs no water and no mill; a hunter while the herds last.)
		if int(counts.get(&"orchard", 0)) < 1 + people / 60:
			result.append(&"orchard")
		if int(counts.get(&"hunter_lodge", 0)) < 1 and not town.wild.all().is_empty():
			result.append(&"hunter_lodge")
		var mills := int(counts.get(&"mill", 0))
		if int(counts.get(&"farm", 0)) < 2 * maxi(mills, 1):
			result.append(&"farm")
		elif int(counts.get(&"bakery", 0)) < mills:
			result.append(&"bakery")
		elif mills < mini(1 + people / 50, 4):
			result.append(&"mill")
	# E3 part 4 (owner's survey 2026-11-11): a province rich in game keeps a second hunter, a
	# fertile one its second farm as soon as a mill grinds (before the food runs short).
	var hunters := int(counts.get(&"hunter_lodge", 0))
	if town.rich_in_game() and hunters == 1 and people >= GAME_PEOPLE and not town.wild.all().is_empty():
		result.append(&"hunter_lodge")
	var mills_now := int(counts.get(&"mill", 0))
	if town.field_yield() > 1.0 and mills_now >= 1 and int(counts.get(&"farm", 0)) < 2:
		result.append(&"farm")
	# A link of the bread chain that cannot keep up: its input piles up.
	if town.stored(&"grain") > PILED_UP and mills_now < 4 and mills_now > 0:
		result.append(&"mill")
	if town.stored(&"flour") > PILED_UP and int(counts.get(&"bakery", 0)) < mills_now + 1:
		result.append(&"bakery")
	if int(counts.get(&"hut", 0)) < MAX_HUTS and _houses_full(town) \
			and plan_progress(town).x >= PLAN.size():
		result.append(&"hut")
	return result


## Food in the province's stores: every kind people eat (E2 part 3).
static func food(town: ProvinceSim) -> int:
	return town.stored(&"bread") + town.stored(&"fish") + town.stored(&"apples") + town.stored(&"meat")


static func _houses_full(town: ProvinceSim) -> bool:
	for building: BuildingState in town.buildings.all():
		if building.house != null and (not building.is_complete()
				or building.house.residents < building.capacity()):
			return false
	return true


## People living in the province's houses.
static func residents(town: ProvinceSim) -> int:
	var n := 0
	for building: BuildingState in town.buildings.all():
		if building.house != null:
			n += building.house.residents
	return n


## Keeps the wood for the sites: sawmills stop while wood is short or planks plenty, tar kilns
## while wood is short (what a careful player does with the pause button).
static func steward(town: ProvinceSim) -> void:
	var wood := town.stored(&"wood")
	var planks := town.stored(&"planks")
	var cogs := 0
	var port := false
	for ship: ShipUnit in town.ships.values():
		if ship.def.id == &"cog":
			cogs += 1
	for building: BuildingState in town.buildings.all():
		if building.def.is_port() and building.is_complete():
			port = true
	for building: BuildingState in town.buildings.all():
		match building.def.id:
			&"shipyard":
				# One cog for expeditions over the sea and routes, once there is a port.
				if port and cogs == 0 and building.is_complete() and building.ship_orders.is_empty() \
						and Ships.build_at(town, building) == null:
					building.ship_orders.append(&"cog")
			&"sawmill":
				building.paused = wood < SAWMILL_WOOD or planks >= PLANKS_ENOUGH
			&"tar_kiln", &"charcoal_burner":
				building.paused = wood < SAWMILL_WOOD


## How far along the plan province [param id] is: entries it has, of all (the ruler's panel).
static func plan_progress(town: ProvinceSim) -> Vector2i:
	var counts := counts_of(town)
	var done := 0
	for entry: Array in PLAN:
		if int(counts.get(entry[0], 0)) >= int(entry[1]):
			done += 1
	return Vector2i(done, PLAN.size())


## Buildings of the province by kind, construction sites included. Barracks of any kind (the
## old 3x3 ones of older towns, the small ones where the large did not fit) count as large
## barracks too (E4 part 4), so a town has one barracks of the plan.
static func counts_of(town: ProvinceSim) -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	for building: BuildingState in town.buildings.all():
		counts[building.def.id] = counts.get(building.def.id, 0) + 1
		if building.def.soldier_beds > 0 and building.def.id != LARGE_BARRACKS:
			counts[LARGE_BARRACKS] = counts.get(LARGE_BARRACKS, 0) + 1
	return counts


static func _open_small_barracks(sim: Simulation, ruler: RulerState, id: int, town: ProvinceSim) -> BuildingState:
	var small := sim.data.get_building(SMALL_BARRACKS)
	if small == null or _no_room(ruler, id, SMALL_BARRACKS, sim.clock.tick) \
			or not _affordable(town, ruler, small):
		return null
	return _open(sim, ruler, id, town, small)


static func _allowed(town: ProvinceSim, def: BuildingDef) -> bool:
	if def.needs_rare != &"" and town.rare_resource != def.needs_rare:
		return false
	if def.needs_trait != &"" and not town.traits.has(def.needs_trait):
		return false
	return true


static func _affordable(town: ProvinceSim, ruler: RulerState, def: BuildingDef) -> bool:
	if not ruler.treasury.can_pay(def.gold_cost):
		return false
	for good: StringName in def.build_cost:
		if town.stored(good) < int(def.build_cost[good]):
			return false
	return true


static func _room_key(id: int, building_id: StringName) -> String:
	return "%d:%s" % [id, building_id]


static func _no_room(ruler: RulerState, id: int, building_id: StringName, tick: int) -> bool:
	return tick < int(ruler.no_room.get(_room_key(id, building_id), 0))


## The middle of the ruler's town: the town hall, else the pioneer camp, else a storage.
static func centre(town: ProvinceSim) -> Vector2i:
	var hall := town.seat()
	if hall != null:
		return hall.entrance_tile()
	for building: BuildingState in town.buildings.all():
		if building.def.id == &"pioneer_camp":
			return building.entrance_tile()
	for building: BuildingState in town.storage_buildings():
		return building.entrance_tile()
	return town.grid.size / 2


## Opens a construction site for [param def] at a free spot near its work, or returns null.
static func place(town: ProvinceSim, def: BuildingDef) -> BuildingState:
	return NeutralTown.place(town, def, NeutralTown.near_its_work(town, def, centre(town)), false)
