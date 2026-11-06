class_name TradeRoute
extends RefCounted
## A trade route between two of the player's provinces (ROADMAP M6 part 3, GDD §4.5): from A
## to B, up to MAX_LINES goods, each with the units taken on a run and a threshold ("bring
## bread while B has less than 20"). One vehicle runs it in circles: the player's cog (by sea)
## or a wagon lent by a stable of A (by land, to a land neighbour only).
##
## WAITING: the vehicle is at home in A; once a second the route looks whether B is short of
##   one of its goods while A has it.
## LOADING: in A the vehicle is loaded: by porters and dockers when A is viewed (Voyage for the
##   cog, RouteWagon for the wagon), at once when not.
## TRAVELLING: on the world map, by the clock (WorldSim.travel_seconds).
## UNLOADING: in B: a wagon drives in and porters unload it when B is viewed; a cog's cargo is
##   put down at B's port for porters; at once into storages when B is not viewed.
## RETURNING: back to A by the clock, empty.
## A one-off route (the port panel's voyage "to my province") is removed when it is back.

enum State { WAITING, LOADING, TRAVELLING, UNLOADING, RETURNING }

const MAX_LINES := 3
## Units a route wagon carries. ROADMAP M6 started from a horse wagon's 6; tuned to 12 while
## building part 3: with 6 a run of about 6 minutes brought too little to buy a settlement by
## land within its 20 minutes.
const WAGON_LOAD := 12
## Default units of a new line and default threshold.
const DEFAULT_AMOUNT := 10
const DEFAULT_BELOW := 20

var id: int = 0
var from: int = 0
var to: int = 0
var by_sea: bool = false
## The cog (an entity of province [member from]) or the stable lending its wagon.
var vehicle: int = 0
## Goods: [{good, amount, below}], at most MAX_LINES.
var lines: Array[Dictionary] = []
var state: State = State.WAITING
var paused: bool = false
## A one-off run (voyage to my province): removed when it is back.
var one_off: bool = false
## The player removed it while it was under way: removed when it is back.
var closing: bool = false
## Goods under way (TRAVELLING).
var cargo: Dictionary[StringName, int] = {}
## Ticks it set out and arrives (TRAVELLING, RETURNING).
var depart_at: int = 0
var arrive_at: int = 0
## Runs done and units brought by them, for the routes window.
var runs: int = 0
var delivered: int = 0


static func line(good: StringName, amount: int, below: int) -> Dictionary:
	return {"good": good, "amount": amount, "below": below}


## How far along the world map it is (0..1) while travelling or returning.
func progress(tick: int) -> float:
	if arrive_at <= depart_at:
		return 1.0
	return clampf(float(tick - depart_at) / float(arrive_at - depart_at), 0.0, 1.0)


func is_on_the_way() -> bool:
	return state == State.TRAVELLING or state == State.RETURNING


func to_dict() -> Dictionary:
	var l: Array = []
	for entry: Dictionary in lines:
		l.append([String(entry["good"]), int(entry["amount"]), int(entry["below"])])
	var d := {"id": id, "from": from, "to": to, "sea": by_sea, "vehicle": vehicle, "lines": l,
			"state": state, "runs": runs, "delivered": delivered}
	if paused:
		d["paused"] = true
	if one_off:
		d["one_off"] = true
	if closing:
		d["closing"] = true
	if not cargo.is_empty():
		d["cargo"] = Expedition.goods_to_dict(cargo)
	if state != State.WAITING:
		d["depart"] = depart_at
		d["arrive"] = arrive_at
	return d


static func from_dict(d: Dictionary) -> TradeRoute:
	var r := TradeRoute.new()
	r.id = int(d["id"])
	r.from = int(d["from"])
	r.to = int(d["to"])
	r.by_sea = bool(d.get("sea", false))
	r.vehicle = int(d.get("vehicle", 0))
	for entry: Variant in d.get("lines", []):
		var a := entry as Array
		r.lines.append(line(StringName(String(a[0])), int(a[1]), int(a[2])))
	r.state = clampi(int(d.get("state", 0)), State.WAITING, State.RETURNING) as State
	r.paused = bool(d.get("paused", false))
	r.one_off = bool(d.get("one_off", false))
	r.closing = bool(d.get("closing", false))
	r.cargo = Expedition.goods_from(d.get("cargo", {}))
	r.depart_at = int(d.get("depart", 0))
	r.arrive_at = int(d.get("arrive", 0))
	r.runs = int(d.get("runs", 0))
	r.delivered = int(d.get("delivered", 0))
	return r
