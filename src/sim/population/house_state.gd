class_name HouseState
extends RefCounted
## Who lives in a house and how they are doing (GDD §3): level, residents, happiness and
## the timers behind upgrades and decline. The pantry is the building's supply stockpile.

const START_HAPPINESS := 50.0

var level: int = 1
var residents: int = 0
## Newcomers walking to this house (their places are taken).
var incoming: int = 0
## 0..100, moves smoothly towards the sum of satisfied need weights.
var happiness: float = START_HAPPINESS
## Need id -> units eaten but not yet taken from the pantry (fractional consumption).
var hunger: Dictionary[StringName, float] = {}
## Need id -> whether it was satisfied at the last population update.
var satisfied: Dictionary[StringName, bool] = {}
## Seconds all basic needs have been met in a row / unmet in a row.
var met_seconds: int = 0
## Points of the needs met this second, 0..100 before the tax rate's mood (E2 part 3), and
## the different kinds of food in the pantry; derived every second, not saved.
var points: float = 0.0
var diet_kinds: int = 0
var unmet_seconds: int = 0
## Good -> householder agent id out to fetch it.
var errands: Dictionary[StringName, int] = {}


func free_places(capacity: int) -> int:
	return capacity - residents - incoming


## Residents able to work (GDD §3.4: about half).
func workforce() -> int:
	return residents / 2


func to_dict() -> Dictionary:
	var h := {}
	for need: StringName in hunger:
		h[String(need)] = hunger[need]
	var s := {}
	for need: StringName in satisfied:
		s[String(need)] = satisfied[need]
	var e := {}
	for good: StringName in errands:
		e[String(good)] = errands[good]
	return {"level": level, "residents": residents, "incoming": incoming,
			"happiness": happiness, "hunger": h, "satisfied": s, "met": met_seconds,
			"unmet": unmet_seconds, "errands": e}


static func from_dict(d: Dictionary) -> HouseState:
	var house := HouseState.new()
	house.level = int(d["level"])
	house.residents = int(d["residents"])
	house.incoming = int(d.get("incoming", 0))
	house.happiness = float(d.get("happiness", START_HAPPINESS))
	var h: Dictionary = d.get("hunger", {})
	for need: Variant in h:
		house.hunger[StringName(String(need))] = float(h[need])
	var s: Dictionary = d.get("satisfied", {})
	for need: Variant in s:
		house.satisfied[StringName(String(need))] = bool(s[need])
	house.met_seconds = int(d.get("met", 0))
	house.unmet_seconds = int(d.get("unmet", 0))
	var e: Dictionary = d.get("errands", {})
	for good: Variant in e:
		house.errands[StringName(String(good))] = int(e[good])
	return house
