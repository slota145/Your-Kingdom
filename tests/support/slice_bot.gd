class_name SliceBot
extends RefCounted
## A scripted player for the M3 DoD scenario: on the real start map it builds what a sensible
## player would (well, woodcutter, farm with fields, mill, bakery, more huts) using only
## commands. Spots are searched near anchor tiles, so small map edits do not break it.

var sim: Simulation
## Seconds of game time -> actions still to do, in order.
var _plan: Array[Dictionary] = []
var log: PackedStringArray = PackedStringArray()


func _init(simulation: Simulation) -> void:
	sim = simulation
	var town := _first(&"town_hall").origin
	_plan = [
		{"at": 0, "build": &"woodcutter", "near": town + Vector2i(-6, -4)},
		{"at": 0, "build": &"well", "near": town + Vector2i(5, 12)},
		{"at": 0, "build": &"woodcutter", "near": town + Vector2i(-8, 2)},
		{"at": 30, "build": &"farm", "near": town + Vector2i(14, 2), "fields": 16},
		{"at": 60, "build": &"mill", "near": town + Vector2i(10, -4)},
		{"at": 60, "build": &"bakery", "near": town + Vector2i(13, -4)},
		{"at": 120, "build": &"hut", "near": town + Vector2i(0, 11)},
		{"at": 120, "build": &"hut", "near": town + Vector2i(3, 11)},
		{"at": 120, "build": &"hut", "near": town + Vector2i(6, 11)},
		{"at": 300, "build": &"farm", "near": town + Vector2i(14, 12), "fields": 16},
		{"at": 300, "build": &"woodcutter", "near": town + Vector2i(-6, 8)},
		{"at": 420, "build": &"hut", "near": town + Vector2i(9, 11)},
		{"at": 420, "build": &"hut", "near": town + Vector2i(12, 11)},
		{"at": 480, "build": &"mill", "near": town + Vector2i(10, -8)},
		{"at": 480, "build": &"bakery", "near": town + Vector2i(14, -8)},
	]


## Runs [param seconds] of game time, carrying out the plan.
func run(seconds: int, on_minute: Callable = Callable()) -> void:
	for second: int in seconds:
		while not _plan.is_empty() and int(_plan[0]["at"]) <= second:
			_do(_plan.pop_front())
		sim.run_ticks(SimClock.TICKS_PER_SECOND)
		sim.events.drain()
		if second % 60 == 59 and on_minute.is_valid():
			on_minute.call(second / 60 + 1)


func houses_at_level(level: int) -> int:
	var n := 0
	for b: BuildingState in sim.province.buildings.all():
		if b.house != null and b.house.level >= level:
			n += 1
	return n


func _do(action: Dictionary) -> void:
	var def := sim.data.get_building(action["build"])
	var spot := find_spot(def, action["near"])
	if spot == Agent.NO_TILE:
		log.append("no spot for %s near %s" % [def.id, action["near"]])
		return
	var error := sim.execute(PlaceBuildingCommand.new(def.id, spot))
	if error != &"":
		log.append("%s at %s: %s" % [def.id, spot, error])
		return
	var building := sim.province.buildings.get_building(sim.province.grid.occupant(spot))
	var fields := int(action.get("fields", 0))
	for r: int in range(1, def.work_radius + 1):
		for y: int in range(spot.y - r, spot.y + def.footprint.y + r):
			for x: int in range(spot.x - r, spot.x + def.footprint.x + r):
				if fields > 0 and sim.execute(PlaceFieldCommand.new(building.id, Vector2i(x, y))) == &"":
					fields -= 1


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
