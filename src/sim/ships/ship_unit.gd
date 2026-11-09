class_name ShipUnit
extends RefCounted
## A ship on the water of a province (ARCHITECTURE §10, M5): a fishing boat or a cog. A plain
## object like Agent, moving along a path on the water NavGrid of its kind. No combat yet;
## the hold is a Stockpile so loading works like any store (part 2).

enum PathState { NONE, MOVING, ARRIVED, FAILED }

var id: int
var def: ShipDef
## Position in grid space (tile units, float).
var pos: Vector2
## Position at the start of the last tick (view interpolation). Not saved.
var prev_pos: Vector2
var facing: int = IsoMath.Dir.SE
## The building this ship works for (a fishing wharf); 0 = none yet.
var home_id: int = 0
## The building at whose berth it is moored (a shipyard after launching, its wharf); 0 = at sea.
var dock_id: int = 0
## The port whose berth this ship reserved, on its way in or moored there (M5 part 2); 0 = none.
var berth_id: int = 0
## Agent id of whoever sails it (a fisherman aboard); 0 = nobody.
var crew: int = 0
## What it is doing, for the view: &"idle", &"sail", or the crew's work (&"cast_net"...).
var activity: StringName = &"idle"
var hold: Stockpile
## Voyages of a trading ship (the player's cog, M5 part 3); null for other ships.
var voyage: Voyage = null
## Soldiers aboard (agent ids, P2 part 2, TroopTransport).
var troops: Array[int] = []
## Soldiers ordered aboard, on their way to the dock.
var boarding: Array[int] = []
## Soldiers set ashore at the dock while the rest are still landing.
var landed: Array[int] = []
## TroopTransport.BOARD, LAND or &"" (none).
var troop_order: StringName = &""
## The dock the soldiers going aboard were sent to (0 = not yet).
var troops_called: int = 0
## A warship sailing to the edge of the map to join this fleet on the world map (M8 part 2);
## 0 = none.
var sail_out: int = 0

var path_state: PathState = PathState.NONE
var path_goal: Vector2i = Agent.NO_TILE
var path: Array[Vector2i] = []
var path_index: int = 0


func _init(entity_id: int, ship_def: ShipDef, at: Vector2, data: DataRegistry) -> void:
	id = entity_id
	def = ship_def
	pos = at
	prev_pos = at
	hold = Stockpile.new(ship_def.hold_slots, data)
	hold.stack_limit = ship_def.hold_stack
	if ship_def.trades:
		voyage = Voyage.new()


func tile() -> Vector2i:
	return Vector2i(floori(pos.x), floori(pos.y))


## Over the horizon on a trade voyage: not on the map (M5 part 3).
func is_away() -> bool:
	return voyage != null and voyage.is_away()


func is_moored() -> bool:
	return dock_id != 0 and path_state != PathState.MOVING


func clear_path() -> void:
	path_state = PathState.NONE
	path_goal = Agent.NO_TILE
	path = []
	path_index = 0


func to_dict() -> Dictionary:
	var d := {
		"id": id, "def": String(def.id), "pos": SimCodec.vec2(pos), "facing": facing,
		"home": home_id, "dock": dock_id, "crew": crew, "activity": String(activity),
		"path": [path_state, SimCodec.vec2i(path_goal), SimCodec.tiles(path), path_index],
	}
	if berth_id != 0:
		d["berth"] = berth_id
	if not hold.is_empty() or hold.reservation_count() > 0:
		d["hold"] = hold.to_dict()
	if voyage != null:
		d["voyage"] = voyage.to_dict()
	if not troops.is_empty() or not boarding.is_empty() or not landed.is_empty() or troop_order != &"":
		d["troops"] = {"aboard": troops.duplicate(), "boarding": boarding.duplicate(),
				"landed": landed.duplicate(), "order": String(troop_order), "called": troops_called}
	if sail_out != 0:
		d["sail_out"] = sail_out
	return d


static func from_dict(d: Dictionary, data: DataRegistry) -> ShipUnit:
	var ship := ShipUnit.new(int(d["id"]), data.get_ship(StringName(String(d["def"]))),
			SimCodec.to_vec2(d["pos"]), data)
	ship.facing = int(d.get("facing", IsoMath.Dir.SE))
	ship.home_id = int(d.get("home", 0))
	ship.dock_id = int(d.get("dock", 0))
	ship.crew = int(d.get("crew", 0))
	ship.berth_id = int(d.get("berth", 0))
	ship.activity = StringName(String(d.get("activity", "idle")))
	var p: Array = d.get("path", [0, [-1, -1], [], 0])
	ship.path_state = int(p[0]) as PathState
	ship.path_goal = SimCodec.to_vec2i(p[1])
	ship.path = SimCodec.to_tiles(p[2])
	ship.path_index = int(p[3])
	if d.has("hold"):
		ship.hold = Stockpile.from_dict(d["hold"], data)
		ship.hold.stack_limit = ship.def.hold_stack
	if ship.def.trades:
		ship.voyage = Voyage.from_dict(d.get("voyage", {}))
	if d.has("troops"):
		var t: Dictionary = d["troops"]
		for key: String in ["aboard", "boarding", "landed"]:
			var list: Array[int] = ship.troops if key == "aboard" else (ship.boarding if key == "boarding" else ship.landed)
			for id: Variant in t.get(key, []):
				list.append(int(id))
		ship.troop_order = StringName(String(t.get("order", "")))
		ship.troops_called = int(t.get("called", 0))
	ship.sail_out = int(d.get("sail_out", 0))
	return ship
