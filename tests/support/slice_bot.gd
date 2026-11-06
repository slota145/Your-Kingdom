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

var sim: Simulation
## Seconds of game time -> actions still to do, in order.
var _plan: Array[Dictionary] = []
var log: PackedStringArray = PackedStringArray()
## Units produced and sold to the merchant so far, by good (from the events).
var produced: Dictionary[StringName, int] = {}
var sold: Dictionary[StringName, int] = {}


func _init(simulation: Simulation) -> void:
	sim = simulation
	var town := _first(&"town_hall").origin
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
		# M4b-1 (after the burghers are settled, minute 45): patricians (bricks, clothes, mead,
		# a tavern) and foresters for the woodcutters.
		{"at": 2700, "build": &"forester", "near": town + Vector2i(-10, -6)},
		{"at": 2700, "build": &"forester", "near": town + Vector2i(-10, 6)},
		{"at": 2760, "build": &"clay_pit", "near": town + Vector2i(21, 3)},
		{"at": 2820, "build": &"brickworks", "near": town + Vector2i(16, -2)},
		{"at": 2880, "build": &"sheep_farm", "near": town + Vector2i(-12, 12)},
		{"at": 2880, "build": &"apiary", "near": town + Vector2i(18, 24)},
		{"at": 2940, "build": &"weaver", "near": town + Vector2i(-6, 12)},
		{"at": 2940, "build": &"apiary", "near": town + Vector2i(12, 25)},
		{"at": 3000, "build": &"tailor", "near": town + Vector2i(-3, 12)},
		{"at": 3000, "build": &"sheep_farm", "near": town + Vector2i(-14, 17)},
		{"at": 3060, "build": &"meadery", "near": town + Vector2i(8, -14)},
		{"at": 3120, "build": &"tavern", "near": town + Vector2i(8, 21)},
		{"at": 3180, "build": &"hut", "near": town + Vector2i(-2, 19)},
		{"at": 3180, "build": &"hut", "near": town + Vector2i(1, 19)},
		{"at": 3240, "build": &"hut", "near": town + Vector2i(4, 19)},
		{"at": 3240, "build": &"hut", "near": town + Vector2i(7, 19)},
		{"at": 3300, "build": &"hop_farm", "near": town + Vector2i(-4, 26), "fields": 12},
		{"at": 3360, "build": &"brewery", "near": town + Vector2i(-2, -14)},
		{"at": 3600, "build": &"meadery", "near": town + Vector2i(12, -14)},
		{"at": 3600, "build": &"apiary", "near": town + Vector2i(22, 24)},
		# M4b-2: meat (pigs bought from the travelling merchant) and selling surplus to him.
		{"at": 1500, "build": &"pigsty", "near": town + Vector2i(-14, 22)},
		{"at": 1560, "build": &"slaughterhouse", "near": town + Vector2i(-9, 23)},
		{"at": 1560, "buy_pigs": 3},
		{"at": 1560, "sell": {&"hides": 0, &"planks": 60, &"stone": 60}},
	]
	_plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) < int(b["at"]))


## Runs [param seconds] of game time, carrying out the plan.
func run(seconds: int, on_minute: Callable = Callable()) -> void:
	for second: int in seconds:
		while not _plan.is_empty() and int(_plan[0]["at"]) <= second:
			_do(_plan.pop_front())
		for i: int in SimClock.TICKS_PER_SECOND:
			sim.step()
			for e: Dictionary in sim.events.drain():
				if e["type"] == &"good_produced":
					produced[e["good"]] = produced.get(e["good"], 0) + int(e["amount"])
				elif e["type"] == &"goods_sold":
					sold[e["good"]] = sold.get(e["good"], 0) + int(e["amount"])
		if second % 60 == 59 and on_minute.is_valid():
			on_minute.call(second / 60 + 1)


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
	if spot == Agent.NO_TILE:
		log.append("no spot for %s near %s" % [def.id, action["near"]])
		return
	var error := sim.execute(PlaceBuildingCommand.new(def.id, spot))
	if error == &"not_enough_gold":
		_retry(action)
		return
	if error != &"":
		log.append("%s at %s: %s" % [def.id, spot, error])
		return
	var building := sim.province.buildings.get_building(sim.province.grid.occupant(spot))
	if action.has("priority"):
		sim.execute(SetPriorityCommand.new(building.id, int(action["priority"])))
	var fields := int(action.get("fields", 0))
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
	for y: int in range(origin.y - 1, origin.y + def.footprint.y + 1):
		for x: int in range(origin.x - 1, origin.x + def.footprint.x + 1):
			var t := Vector2i(x, y)
			if sim.province.grid.occupant(t) != 0 or not sim.province.nav.is_walkable(t):
				return false
	return true


func _first(id: StringName) -> BuildingState:
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == id:
			return b
	return null
