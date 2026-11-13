class_name SliceBot
extends RefCounted
## A scripted player for the DoD scenarios (M3 bread chain, M4a burghers, M4b-1 patricians): on the real start
## map it builds what a sensible player would, using only commands. Spots are searched near
## anchor tiles, so small map edits do not break it. Anchors are relative to the town hall and
## made for Riverlands; on another map (M4b-3: Lakeland) a building whose work needs rocks,
## trees or water nearby moves its anchor to the nearest of them when it has none in reach. A building it cannot afford yet is
## tried again later (taxes bring gold in).

## Seconds before retrying a building the treasury could not pay for.
const GOLD_RETRY := 30
## E2 part 4: the patrician chains (bricks, clothes, mead, the tavern) start this many seconds
## earlier than before (minute 35, not 45), except on the Coast.
const PATRICIANS_EARLIER := 600
## E4 part 5 (owner's survey 2026-11-11): a bot that studies ([member studies]) plays a game
## with research locked, as the player's: a school early (it needs no burghers from E4 part 5),
## then these researches in order (bricks, clothes and mead for the patricians, the pigsty).
const STUDIES: Array[StringName] = [&"brickmaking", &"tailoring", &"beekeeping", &"butchery"]
const SCHOOL_AT := 600
## Times of the patrician block's actions (seconds) after the shift.
const PATRICIAN_TIMES: Array[int] = [2100, 2160, 2220, 2280, 2340, 2400, 2460, 2520, 2580, 2640, 2700, 2760, 3000]

var sim: Simulation
## Plays with research (E4 part 5): builds a school and studies [constant STUDIES]; a building
## still locked is tried again later.
var studies: bool = false
## Seconds of game time -> actions still to do, in order.
var _plan: Array[Dictionary] = []
var log: PackedStringArray = PackedStringArray()
## Ground the town leaves free for another bot (UI-2 part 2: the HarbourBot's port on the Coast
## shore, which a faster growing town built over); empty = none.
var keep_clear: Rect2i = Rect2i()
## Units produced and sold to the merchant so far, by good (from the events).
var produced: Dictionary[StringName, int] = {}
var sold: Dictionary[StringName, int] = {}
## Walking distance (steps) from the town centre to every tile, taken at the start; empty =
## not used. On Coast (M5 part 3) a river runs between the town and the plan's anchors made
## for Riverlands, so a spot is taken only if people need no long detour (a far ford) to it.
var _reach: Dictionary[Vector2i, int] = {}
## Town centre of the plan.
var _town: Vector2i


func _init(simulation: Simulation, with_research: bool = false) -> void:
	sim = simulation
	studies = with_research
	if studies:
		sim.research = ResearchState.new()
		sim.bind_research()
	var start: Array[Dictionary] = []
	var town: Vector2i
	if sim.province.landing != null:
		# M5 part 3, Coast: the game starts from a ship. The town grows inland from the beach;
		# first the pioneer camp by the start kit, then what the other maps have from the
		# start: a storage and three huts.
		var beach := sim.province.landing.beach
		town = beach + Vector2i(-12, -8)
		start = [
			{"at": 0, "build": &"pioneer_camp", "near": beach + Vector2i(-6, -4)},
			# The storage right by the heap on the beach: porters fetch the kit from close by.
			{"at": 0, "build": &"stockpile", "near": beach + Vector2i(-5, 2)},
			{"at": 0, "build": &"hut", "near": town + Vector2i(0, 7)},
			{"at": 0, "build": &"hut", "near": town + Vector2i(3, 7)},
			{"at": 0, "build": &"hut", "near": town + Vector2i(6, 7)},
			# The forest of Coast lies far from the beach: woodcutters at its nearest edge, in
			# the south, with a storage of their own.
			{"at": 0, "build": &"woodcutter", "near": beach + Vector2i(-10, 10)},
			{"at": 60, "build": &"woodcutter", "near": beach + Vector2i(-4, 12)},
			{"at": 120, "build": &"stockpile", "near": beach + Vector2i(-7, 8)},
			# Farmers carry every sheaf to a storage: one by the fields and the mills.
			{"at": 300, "build": &"stockpile", "near": town + Vector2i(-9, 2)},
			# The town starts with 6 settlers instead of 12 residents: two more huts early.
			{"at": 240, "build": &"hut", "near": town + Vector2i(-3, 7)},
			{"at": 240, "build": &"hut", "near": town + Vector2i(-3, 10)},
			# More newcomers come to the coast town early: a third bread chain and more beer.
			{"at": 600, "build": &"farm", "near": town + Vector2i(-16, 8), "fields": 16},
			{"at": 660, "build": &"mill", "near": town + Vector2i(-7, -12)},
			{"at": 660, "build": &"bakery", "near": town + Vector2i(-3, -12)},
			{"at": 1500, "build": &"farm", "near": town + Vector2i(-18, -4), "fields": 16},
			{"at": 1500, "build": &"hut", "near": town + Vector2i(-6, 13)},
			{"at": 1500, "build": &"hut", "near": town + Vector2i(-6, 16)},
			{"at": 1560, "build": &"well", "near": town + Vector2i(-8, 18)},
			{"at": 1200, "build": &"hop_farm", "near": town + Vector2i(-16, 20), "fields": 12},
			{"at": 1260, "build": &"brewery", "near": town + Vector2i(-11, -13)},
		]
		_reach = _walk_steps(town)
	else:
		town = _first(&"town_hall").origin
	_town = town
	_plan = [
		{"at": 0, "build": &"woodcutter", "near": town + Vector2i(-6, -4)},
		{"at": 0, "build": &"well", "near": town + Vector2i(5, 12)},
		{"at": 0, "build": &"woodcutter", "near": town + Vector2i(-8, 2)},
		{"at": 0, "build": &"woodcutter", "near": town + Vector2i(-6, 8)},
		{"at": 30, "build": &"farm", "near": town + Vector2i(14, 2), "fields": 16},
		{"at": 60, "build": &"mill", "near": town + Vector2i(10, -4)},
		{"at": 60, "build": &"bakery", "near": town + Vector2i(13, -4)},
		{"at": 90, "build": &"hut", "near": town + Vector2i(0, 11)},
		{"at": 90, "build": &"hut", "near": town + Vector2i(3, 11)},
		{"at": 120, "build": &"woodcutter", "near": town + Vector2i(-12, -2)},
		{"at": 120, "build": &"sawmill", "near": town + Vector2i(4, -6)},
		{"at": 150, "build": &"hut", "near": town + Vector2i(6, 11)},
		{"at": 150, "build": &"chapel", "near": town + Vector2i(-3, 7)},
		{"at": 180, "build": &"fishing_hut", "near": town + Vector2i(23, 0)},
		{"at": 210, "build": &"quarry", "near": town + Vector2i(11, -13)},
		{"at": 240, "build": &"woodcutter", "near": town + Vector2i(-14, -6)},
		{"at": 240, "build": &"farm", "near": town + Vector2i(14, 12), "fields": 16},
		{"at": 270, "build": &"hut", "near": town + Vector2i(9, 11)},
		{"at": 270, "build": &"hut", "near": town + Vector2i(12, 11)},
		{"at": 200, "build": &"hop_farm", "near": town + Vector2i(16, 21), "fields": 12, "priority": 0},
		{"at": 300, "build": &"brewery", "near": town + Vector2i(6, -10), "priority": 0},
		{"at": 360, "build": &"hut", "near": town + Vector2i(-2, 15)},
		{"at": 360, "build": &"hut", "near": town + Vector2i(1, 15)},
		{"at": 420, "build": &"hut", "near": town + Vector2i(4, 15)},
		{"at": 420, "build": &"well", "near": town + Vector2i(14, 16)},
		{"at": 420, "build": &"bakery", "near": town + Vector2i(14, -8)},
		{"at": 480, "build": &"woodcutter", "near": town + Vector2i(-18, -12)},
		{"at": 540, "build": &"mill", "near": town + Vector2i(10, -8)},
		{"at": 540, "build": &"fishing_hut", "near": town + Vector2i(23, 6)},
		{"at": 600, "build": &"hop_farm", "near": town + Vector2i(6, 22), "fields": 12},
		{"at": 600, "build": &"market", "near": town + Vector2i(8, 17)},
		{"at": 660, "build": &"hut", "near": town + Vector2i(15, 11)},
		{"at": 660, "build": &"brewery", "near": town + Vector2i(2, -11)},
		{"at": 690, "build": &"stockpile", "near": town + Vector2i(18, -6)},
		{"at": 720, "build": &"church", "near": town + Vector2i(-6, 18)},
		{"at": 1200, "build": &"stockpile", "near": town + Vector2i(-4, -12)},
		# M4b-1 (while the burghers settle, from minute 35; E2 part 4: 10 minutes earlier than
		# before, the patricians came late with their 3 kinds of food; on the Coast at the old
		# time, see PATRICIANS_EARLIER): patricians (bricks, clothes, mead,
		# a tavern) and foresters for the woodcutters.
		{"at": 2100, "build": &"forester", "near": town + Vector2i(-10, -6)},
		{"at": 2100, "build": &"forester", "near": town + Vector2i(-10, 6)},
		{"at": 2160, "build": &"clay_pit", "near": town + Vector2i(21, 3)},
		{"at": 2220, "build": &"brickworks", "near": town + Vector2i(16, -2)},
		{"at": 2280, "build": &"sheep_farm", "near": town + Vector2i(-12, 12), "fields": 4},
		{"at": 2280, "build": &"apiary", "near": town + Vector2i(18, 24), "fields": 4},
		{"at": 2340, "build": &"weaver", "near": town + Vector2i(-6, 12)},
		{"at": 2340, "build": &"apiary", "near": town + Vector2i(12, 25), "fields": 4},
		{"at": 2400, "build": &"tailor", "near": town + Vector2i(-3, 12)},
		{"at": 2400, "build": &"sheep_farm", "near": town + Vector2i(-14, 17), "fields": 4},
		{"at": 2460, "build": &"meadery", "near": town + Vector2i(8, -14)},
		{"at": 2520, "build": &"tavern", "near": town + Vector2i(8, 21)},
		{"at": 2580, "build": &"hut", "near": town + Vector2i(-2, 19)},
		{"at": 2580, "build": &"hut", "near": town + Vector2i(1, 19)},
		{"at": 2640, "build": &"hut", "near": town + Vector2i(4, 19)},
		{"at": 2640, "build": &"hut", "near": town + Vector2i(7, 19)},
		{"at": 2700, "build": &"hop_farm", "near": town + Vector2i(-4, 26), "fields": 12},
		{"at": 2760, "build": &"brewery", "near": town + Vector2i(-2, -14)},
		{"at": 3000, "build": &"meadery", "near": town + Vector2i(12, -14)},
		{"at": 3000, "build": &"apiary", "near": town + Vector2i(22, 24), "fields": 4},
		# E1: a third farm for the long game (after the patrician tests' 90 minutes): the bread
		# of two farms ran short at about 2 hours already before E1 (6 supplied houses, the limit).
		{"at": 5460, "build": &"farm", "near": town + Vector2i(18, 12), "fields": 16},
		# E2 part 3: patricians eat 3 kinds of food; meat comes late (pigs), so apples are the
		# third kind (and the burghers' second next to bread and fish).
		# Keep some wood from the sawmill for the sites (the orchard and the pigsty waited
		# 40 minutes for their few logs while the planks piled up).
		{"at": 900, "keep": {&"wood": 15}},
		{"at": 900, "build": &"orchard", "near": town + Vector2i(20, 16), "fields": 12},
		{"at": 1680, "build": &"orchard", "near": town + Vector2i(-16, -16), "fields": 12},
		# E2 part 4: a hunter by the herds nearest the town: meat (a kind of food) long before
		# the pigs.
		{"at": 600, "build": &"hunter_lodge", "near": town + Vector2i(-10, 10)},
		# M4b-2: meat (pigs bought from the travelling merchant) and selling surplus to him.
		{"at": 1500, "build": &"pigsty", "near": town + Vector2i(-14, 22), "fields": 6},
		{"at": 1560, "build": &"slaughterhouse", "near": town + Vector2i(-9, 23)},
		{"at": 1560, "buy_pigs": 3},
		{"at": 1560, "sell": {&"hides": 0, &"planks": 60, &"stone": 60}},
	]
	if studies:
		# Built first (its site gets the porters and builders) and a second one: the study goes
		# twice as fast (what a player in a hurry for the patricians does).
		_plan.append({"at": SCHOOL_AT, "build": &"school", "near": town + Vector2i(-8, 15), "priority": 0})
		_plan.append({"at": SCHOOL_AT + 30, "build": &"school", "near": town + Vector2i(-12, 15), "priority": 0})
		_plan.append({"at": SCHOOL_AT, "study": STUDIES.duplicate()})
	if not start.is_empty():
		# The Coast keeps the patrician chains at their old time (from minute 45): earlier, the
		# apiaries, the tavern and the huts took the shore where the harbour bot puts the port.
		for action: Dictionary in _plan:
			if int(action["at"]) in PATRICIAN_TIMES:
				action["at"] = int(action["at"]) + PATRICIANS_EARLIER
		# Coast: the bread chain, the anglers, the breweries and the bricks stay on the town's
		# side of the river (the anchors made for
		# Riverlands would put the mill and the bakery across it, far from the fields).
		var coast_spots := {&"farm": [Vector2i(-10, 4), Vector2i(-12, 14)],
				&"mill": [Vector2i(-4, -4), Vector2i(-4, -8)], &"bakery": [Vector2i(-1, -4), Vector2i(-1, -8)],
				&"fishing_hut": [Vector2i(5, -3), Vector2i(4, -9)], &"brewery": [Vector2i(-8, -4), Vector2i(-8, -9)],
				&"hop_farm": [Vector2i(-14, 16), Vector2i(-4, 20)],
				&"stockpile": [Vector2i(-6, -10), Vector2i(-16, 0)],
				&"clay_pit": [Vector2i(6, -1)], &"brickworks": [Vector2i(2, -14)]}
		var used := {}
		for action: Dictionary in _plan:
			var id: StringName = action.get("build", &"")
			if coast_spots.has(id) and int(used.get(id, 0)) < (coast_spots[id] as Array).size():
				action["near"] = town + (coast_spots[id] as Array)[int(used.get(id, 0))]
				used[id] = int(used.get(id, 0)) + 1
	_plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) < int(b["at"]))
	# The start actions come first, in their order (the camp before anything else).
	var later: Array[Dictionary] = []
	for action: Dictionary in start:
		if int(action["at"]) > 0:
			later.append(action)
	for action: Dictionary in later:
		start.erase(action)
	_plan = start + _plan
	for action: Dictionary in later:
		var i := 0
		while i < _plan.size() and int(_plan[i]["at"]) <= int(action["at"]):
			i += 1
		_plan.insert(i, action)


## Runs [param seconds] of game time, carrying out the plan.
func run(seconds: int, on_minute: Callable = Callable()) -> void:
	for second: int in seconds:
		act(second)
		for i: int in SimClock.TICKS_PER_SECOND:
			sim.step()
			for e: Dictionary in sim.events.drain():
				note(e)
		if second % 60 == 59 and on_minute.is_valid():
			on_minute.call(second / 60 + 1)


## Carries out the plan's actions due by [param second] (in the viewed province; the world
## bot of M6 part 3 calls it only while this bot's province is viewed).
func act(second: int) -> void:
	while not _plan.is_empty() and int(_plan[0]["at"]) <= second:
		_do(_plan.pop_front())


## Adds an action to the plan (the world bot: a town hall and a stable on the Coast).
func add(action: Dictionary) -> void:
	_plan.append(action)
	_plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) < int(b["at"]))


## Counts a simulation event (produced and sold goods).
func note(e: Dictionary) -> void:
	if e["type"] == &"good_produced":
		produced[e["good"]] = produced.get(e["good"], 0) + int(e["amount"])
	elif e["type"] == &"goods_sold":
		sold[e["good"]] = sold.get(e["good"], 0) + int(e["amount"])
	elif e["type"] == &"research_finished":
		log.append("min %d studied %s" % [sim.clock.tick / SimClock.seconds_to_ticks(60.0), e["research"]])


## Houses of [param level] or above whose basic needs are all met right now.
func supplied_houses(level: int) -> int:
	var n := 0
	for b: BuildingState in sim.province.buildings.all():
		if b.house == null or b.house.level < level or b.house.residents == 0:
			continue
		var ok := true
		for need: NeedDef in b.level_def().needs:
			if need.is_basic and not b.house.satisfied.get(need.id, false):
				ok = false
		if ok:
			n += 1
	return n


func houses_at_level(level: int) -> int:
	var n := 0
	for b: BuildingState in sim.province.buildings.all():
		if b.house != null and b.house.level >= level:
			n += 1
	return n


## Does the action later (not enough gold, the merchant not there yet).
func _retry(action: Dictionary) -> void:
	action["at"] = int(action["at"]) + GOLD_RETRY
	_plan.append(action)
	_plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) < int(b["at"]))


func _do(action: Dictionary) -> void:
	if action.has("sell"):
		var sell: Dictionary = action["sell"]
		for good: StringName in sell:
			sim.execute(SetSellAboveCommand.new(good, int(sell[good])))
		return
	if action.has("keep"):
		var keep: Dictionary = action["keep"]
		for good: StringName in keep:
			sim.execute(SetKeepForBuildingCommand.new(good, int(keep[good])))
		return
	if action.has("study"):
		# Each research in turn: started or queued; tried again without a school or gold.
		var left: Array = action["study"]
		while not left.is_empty():
			var error := sim.execute(StartResearchCommand.new(left[0]))
			if error != &"" and error != &"research_planned" and error != &"research_done":
				break
			left.pop_front()
		if not left.is_empty():
			_retry(action)
		return
	if action.has("buy_pigs"):
		var left := int(action["buy_pigs"])
		while left > 0 and sim.execute(BuyPigCommand.new()) == &"":
			left -= 1
		if left > 0:
			action["buy_pigs"] = left
			_retry(action)
		return
	var def := sim.data.get_building(action["build"])
	var spot := find_spot(def, _near_its_work(def, action["near"]))
	if spot == Agent.NO_TILE and studies:
		# (E4 part 5: a building that waited for its research may find its spot taken.)
		spot = find_spot(def, _town)
	if spot == Agent.NO_TILE:
		log.append("no spot for %s near %s" % [def.id, action["near"]])
		return
	var error := sim.execute(PlaceBuildingCommand.new(def.id, spot))
	if error == &"not_enough_gold" or studies and error in [&"needs_research", &"needs_burghers"]:
		_retry(action)
		return
	if error != &"":
		log.append("%s at %s: %s" % [def.id, spot, error])
		return
	var building := sim.province.buildings.get_building(sim.province.grid.occupant(spot))
	if action.has("priority"):
		sim.execute(SetPriorityCommand.new(building.id, int(action["priority"])))
	var fields := int(action.get("fields", 0))
	if def.has_tiles():
		# A pen or the hives in one piece beside the building (Z1).
		Pens.auto_place(sim.province, building, fields)
		fields = 0
	for r: int in range(1, def.work_radius + 1):
		for y: int in range(spot.y - r, spot.y + def.footprint.y + r):
			for x: int in range(spot.x - r, spot.x + def.footprint.x + r):
				if fields > 0 and sim.execute(PlaceFieldCommand.new(building.id, Vector2i(x, y))) == &"":
					fields -= 1


## [param near], or the nearest tile with what [param def] works on (rocks, trees, water) when
## there is none within its reach of [param near].
func _near_its_work(def: BuildingDef, near: Vector2i) -> Vector2i:
	var node := &""
	if def.recipe != null:
		for step: StepDef in def.recipe.steps:
			if step is GoToStepDef and (step as GoToStepDef).target == &"resource":
				node = (step as GoToStepDef).resource
	var reach := def.work_radius
	if def.id == &"hunter_lodge":
		return NeutralTown.hunting_ground(sim.province, near)
	if node == &"" and def.needs_terrain_near == &"":
		return near
	var best := near
	var best_d := 1 << 30
	var size := sim.province.grid.size
	for y: int in size.y:
		for x: int in size.x:
			var t := Vector2i(x, y)
			var hit := false
			if node != &"":
				hit = sim.province.resources.has_node(t, node) and not sim.province.resources.is_depleted(t)
			else:
				var terrain := sim.province.terrain_at(t)
				hit = terrain != null and terrain.is_kind(def.needs_terrain_near)
			if not hit:
				continue
			var d := (t - near).length_squared()
			if d <= reach * reach:
				return near
			if d < best_d:
				best_d = d
				best = t
	return best


## The free spot nearest to [param near] that keeps one free tile around the building.
func find_spot(def: BuildingDef, near: Vector2i) -> Vector2i:
	for r: int in 20:
		for y: int in range(near.y - r, near.y + r + 1):
			for x: int in range(near.x - r, near.x + r + 1):
				if maxi(absi(x - near.x), absi(y - near.y)) != r:
					continue
				var origin := Vector2i(x, y)
				if _fits_with_margin(def, origin):
					return origin
	return Agent.NO_TILE


func _fits_with_margin(def: BuildingDef, origin: Vector2i) -> bool:
	if sim.province.placement_error(def, origin) != &"":
		return false
	if keep_clear.intersects(Rect2i(origin, def.footprint)):
		return false
	if not _reach.is_empty():
		var steps := int(_reach.get(origin, 1 << 20))
		var straight := maxi(absi(origin.x - _town.x), absi(origin.y - _town.y))
		if steps > straight * 3 / 2 + 8:
			return false
	for y: int in range(origin.y - 1, origin.y + def.footprint.y + 1):
		for x: int in range(origin.x - 1, origin.x + def.footprint.x + 1):
			var t := Vector2i(x, y)
			if sim.province.grid.occupant(t) != 0 or not sim.province.nav.is_walkable(t):
				return false
	return true


## Steps (8 neighbours, walkable tiles at the start) from [param from] to every tile reached.
func _walk_steps(from: Vector2i) -> Dictionary[Vector2i, int]:
	var steps: Dictionary[Vector2i, int] = {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	var nav := sim.province.nav
	while head < queue.size():
		var tile := queue[head]
		head += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var next := tile + d
			if not steps.has(next) and nav.is_walkable(next):
				steps[next] = steps[tile] + 1
				queue.append(next)
	return steps


func _first(id: StringName) -> BuildingState:
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == id:
			return b
	return null


## The town centre the plan's anchors are relative to.
func town() -> Vector2i:
	return _town
