class_name HarbourBot
extends RefCounted
## The harbour of N1 part 2 for the automatic player on Coast (commands only): from minute 45,
## beside the SliceBot's town, it builds a port and a tar kiln on the west shore of the bay, a
## timber pier south of the port with a mooring and a cargo crane on it, a port warehouse on a
## second pier beside it, and a shipyard further south (so the cog's home is the mooring); it
## orders a cog once the mooring and the crane stand and keeps sending it on voyages, so the
## sea merchant and the cog often lie at both berths at once.
##
## Spots are searched near anchors relative to the landing beach (the west shore of the bay
## runs north to south, the sea is at +x); the pier goes on the shore south of the port, and
## the mooring, the crane and the warehouse on it. A placement that does not fit yet (a quay
## still being laid) is tried again later, as is anything the treasury cannot pay for.

## Seconds before trying an action again.
const RETRY := 30

var sim: Simulation
var log: PackedStringArray = PackedStringArray()
## Seconds of game time -> actions still to do, in order (harbour from minute 45).
var _plan: Array[Dictionary] = []
## Statistics of the run (read by the test).
var cog_home: StringName = &""
var both_berths_seconds: int = 0
var crane_lifted: int = 0
var crane_lifts: int = 0
var warehouse_stored: int = 0
var voyages: int = 0
var merchant_at_mooring: int = 0
## The bay shore where the port and its pier go (Coast): the town bot leaves it free.
func port_ground() -> Rect2i:
	var b := sim.province.landing.beach if sim.province.landing != null else Vector2i(70, 74)
	return Rect2i(b + Vector2i(-7, 6), Vector2i(10, 12))


## First tile of the pier (its corner at the shore), once laid out.
var _pier: Vector2i = Agent.NO_TILE


func _init(simulation: Simulation, start: int = 2700) -> void:
	sim = simulation
	var b := sim.province.landing.beach if sim.province.landing != null else Vector2i(70, 74)
	_plan = [
		{"at": start, "build": &"port", "near": b + Vector2i(-1, 10)},
		{"at": start + 60, "build": &"tar_kiln", "near": b + Vector2i(-8, 12)},
		# South of the pier: the cog's home is the nearest berth, the mooring with the crane.
		# W1: on the sea shore east of the bay mouth (the town fills the west side), lower down
		# than the pier, so the mooring is still the nearest berth.
		{"at": start + 120, "build": &"shipyard", "near": b + Vector2i(30, 17)},
		{"at": start + 180, "pier": true},
		{"at": start + 300, "build": &"mooring", "on_pier": Vector2i(2, 0)},
		{"at": start + 300, "build": &"crane", "on_pier": Vector2i(2, 2)},
		{"at": start + 360, "store_quay": true},
		{"at": start + 480, "build": &"port_warehouse", "on_pier": Vector2i(1, 4)},
		{"at": start + 600, "ship": &"cog"},
		# The sea merchant brings tar and cloth for the shipyard and the tailors: unloaded at
		# whichever berth he gets, by the crane at the mooring.
		{"at": start + 600, "buy": {&"tar": 30, &"cloth": 30}},
		# P2 part 1: a dockers' hut inland of the port (after the warehouse has its spot); its dockers help at every berth.
		{"at": start + 1500, "build": &"docker_hut", "near": b + Vector2i(4, 4)},
	]


## Carries out the actions due by [param second] and looks after the cog and the statistics.
func act(second: int) -> void:
	while not _plan.is_empty() and int(_plan[0]["at"]) <= second:
		_do(_plan.pop_front())
	_watch()


## Counts what the crane and the warehouse did (simulation events).
func note(e: Dictionary) -> void:
	if e["type"] != &"good_stored":
		return
	var agent := sim.province.agents.get_agent(int(e["agent"]))
	if agent != null and agent.kind == Cranes.OPERATOR_KIND:
		crane_lifted += int(e["amount"])
		crane_lifts += 1
	var building := sim.province.buildings.get_building(int(e["storage"]))
	if building != null and building.def.id == &"port_warehouse":
		warehouse_stored += int(e["amount"])


func _watch() -> void:
	var province := sim.province
	var moored := 0
	for ship: ShipUnit in province.ships.values():
		if ship.berth_id != 0 and Harbour.port_of(province, ship.id) != null:
			moored += 1
	if moored >= 2:
		both_berths_seconds += 1
	var trader := province.sea_merchant
	if trader.is_trading():
		var port := province.buildings.get_building(trader.port_id)
		if port != null and port.def.served_by_port:
			merchant_at_mooring += 1
	for ship: ShipUnit in province.ships.values():
		if ship.voyage != null and ship.home_id != 0:
			cog_home = province.buildings.get_building(ship.home_id).def.id
		if ship.voyage != null and ship.voyage.state == Voyage.State.IDLE and ship.hold.is_empty():
			# Planks out (the town keeps a surplus), tar and cloth back.
			if ship.voyage.sell.is_empty():
				sim.execute(SetVoyagePlanCommand.new(ship.id, &"planks", 10))
				sim.execute(SetVoyagePlanCommand.new(ship.id, &"tar", 10, true))
				sim.execute(SetVoyagePlanCommand.new(ship.id, &"cloth", 10, true))
			if sim.execute(StartVoyageCommand.new(ship.id)) == &"":
				voyages += 1


func _retry(action: Dictionary) -> void:
	action["at"] = int(action["at"]) + RETRY
	_plan.append(action)
	_plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) < int(b["at"]))


func _do(action: Dictionary) -> void:
	if action.has("pier"):
		_lay_pier()
		return
	if action.has("store_quay"):
		if _pier == Agent.NO_TILE:
			_retry(action)
			return
		# A pier south of the first: the warehouse on its sea side, a walkway on the shore side
		# (timber: the coast town has little stone).
		var tiles := _block(_pier + Vector2i(0, 4), 4, 3)
		var error := sim.execute(BuildQuayCommand.new(tiles, TileGrid.PIER))
		if error != &"":
			log.append("store quay: %s" % error)
		return
	if action.has("buy"):
		var buy: Dictionary = action["buy"]
		for good: StringName in buy:
			var error := sim.execute(SetBuyUpToCommand.new(good, int(buy[good])))
			if error != &"":
				log.append("buy %s: %s" % [good, error])
		return
	if action.has("ship"):
		# Once the harbour stands: the cog's home is then the nearest berth, the mooring.
		var yard := _first(&"shipyard")
		var ready := yard != null and yard.is_complete() and _first(&"mooring") != null \
				and _first(&"mooring").is_complete() and _first(&"crane") != null and _first(&"crane").is_complete()
		var error := sim.execute(OrderShipCommand.new(yard.id, action["ship"])) if ready else &"not_ready"
		if error != &"":
			_retry(action)
		return
	var id: StringName = action["build"]
	var def := sim.data.get_building(id)
	var spot := Agent.NO_TILE
	var turn := 1
	if action.has("on_pier"):
		if _pier == Agent.NO_TILE:
			_retry(action)
			return
		spot = _pier + (action["on_pier"] as Vector2i)
	else:
		var found := _find_spot(def, action["near"])
		spot = found[0]
		turn = found[1]
		if spot == Agent.NO_TILE:
			# Somebody may be standing on the only spot (W1: fewer straight shores); try again.
			if int(action.get("tries", 0)) < 20:
				action["tries"] = int(action.get("tries", 0)) + 1
				_retry(action)
				return
			log.append("no spot for %s near %s" % [id, action["near"]])
			return
	var error := sim.execute(PlaceBuildingCommand.new(id, spot, false, turn))
	if error == &"":
		return
	# Not yet: gold, the quay still being laid, the port not finished.
	if error in [&"not_enough_gold", &"needs_quay", &"no_port_nearby", &"no_berth_nearby",
			&"tile_occupied", &"tile_has_people", &"blocks_access"] and int(action.get("tries", 0)) < 60:
		action["tries"] = int(action.get("tries", 0)) + 1
		_retry(action)
		return
	log.append("%s at %s: %s" % [id, spot, error])


## The spot (and turn) nearest to [param near] where [param def] fits, keeping a free tile
## beside its land part; [Agent.NO_TILE, 0] if none within 14 tiles.
func _find_spot(def: BuildingDef, near: Vector2i) -> Array:
	var province := sim.province
	for r: int in 15:
		for y: int in range(near.y - r, near.y + r + 1):
			for x: int in range(near.x - r, near.x + r + 1):
				if maxi(absi(x - near.x), absi(y - near.y)) != r:
					continue
				for turn: int in def.orientation_count():
					if province.placement_error(def, Vector2i(x, y), turn) == &"":
						return [Vector2i(x, y), turn]
	return [Agent.NO_TILE, 0]


## Lays out the pier: a 4x4 block on the sea from the shore, south of the port (the first that
## the quay rules take whole and whose mooring berth is open water), and orders it.
func _lay_pier() -> void:
	var province := sim.province
	var port := _first(&"port")
	if port == null:
		log.append("pier: no port")
		return
	var from := port.origin + Vector2i(0, port.def.footprint.y + 1)
	for dy: int in 12:
		for dx: int in range(-3, 6):
			var corner := from + Vector2i(dx, dy)
			# The corner is the first sea tile east of the shore.
			if province.sail_depth(corner) == 0 or province.sail_depth(corner + Vector2i(-1, 0)) != 0:
				continue
			var tiles := _block(corner, 4, 4)
			var plan := province.quay_plan(tiles)
			if (plan["tiles"] as Array).size() != tiles.size():
				continue
			var berth := corner + Vector2i(4, 1)
			if province.sail_depth(berth) == 0 or not province.fairway.is_empty() and province.fairway.has(berth):
				continue
			var error := sim.execute(BuildQuayCommand.new(tiles, TileGrid.PIER))
			if error == &"":
				_pier = corner
				return
	log.append("pier: no place south of the port")


## Tiles of a [param w] x [param h] block from [param corner], row by row from the shore.
static func _block(corner: Vector2i, w: int, h: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x: int in w:
		for y: int in h:
			tiles.append(corner + Vector2i(x, y))
	return tiles


func _first(id: StringName) -> BuildingState:
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == id:
			return b
	return null
