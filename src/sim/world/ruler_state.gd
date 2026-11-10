class_name RulerState
extends RefCounted
## What an AI ruler keeps besides his provinces (ROADMAP M8 part 3, owner's survey 2026-11-10):
## his own treasury (his people's taxes fill it, as the player's do), and the clocks of his
## plans: when each of his provinces may open its next construction site, when he may send his
## next expedition of settlers, and when he looks at trade (buying neutral settlements, routes
## between his provinces). Where his plan of growth stands is not kept: it is read from what
## his provinces have (RulerPlanner), so a save from before part 3 starts the plan where the
## town already is.

var owner: StringName = &""
var treasury: Treasury = Treasury.new()
## Province id -> tick before which no new construction site is opened there.
var next_build: Dictionary[int, int] = {}
## Tick before which no new expedition gets ready.
var next_expedition: int = 0
## Tick of the next look at trade (settlements to buy, routes to set up).
var next_trade: int = 0
## The province saving up the start kit of the next expedition (it opens no new sites but
## those of its shortages until the kit is there); 0 = none.
var saving_for: int = 0
## War (M8 part 4, RulerWar): no attack is started before this tick (the time of grace at
## the start, then the gap between two campaigns).
var next_war: int = 0
## The army now on a campaign (0 = none) and the province it goes for.
var campaign: int = 0
var war_target: int = 0
## He lost his last province (the player was told).
var defeated: bool = false
## "province:building" -> tick before which a building that found no room is not tried
## there again. Not saved (after loading it is simply tried once more).
var no_room: Dictionary[String, int] = {}


static func create(id: StringName, gold: int, now: int) -> RulerState:
	var r := RulerState.new()
	r.owner = id
	r.treasury.gold = gold
	r.next_expedition = now
	r.next_trade = now
	return r


func to_dict() -> Dictionary:
	var builds := {}
	var keys: Array[int] = []
	keys.assign(next_build.keys())
	keys.sort()
	for id: int in keys:
		builds[str(id)] = next_build[id]
	return {"owner": String(owner), "treasury": treasury.to_dict(), "next_build": builds,
			"next_expedition": next_expedition, "next_trade": next_trade, "saving_for": saving_for,
			"next_war": next_war, "campaign": campaign, "war_target": war_target, "defeated": defeated}


static func from_dict(d: Dictionary) -> RulerState:
	var r := RulerState.new()
	r.owner = StringName(String(d.get("owner", "")))
	r.treasury = Treasury.from_dict(d.get("treasury", {}))
	var builds: Dictionary = d.get("next_build", {})
	for key: Variant in builds:
		r.next_build[int(String(key))] = int(builds[key])
	r.next_expedition = int(d.get("next_expedition", 0))
	r.next_trade = int(d.get("next_trade", 0))
	r.saving_for = int(d.get("saving_for", 0))
	r.next_war = int(d.get("next_war", 0))
	r.campaign = int(d.get("campaign", 0))
	r.war_target = int(d.get("war_target", 0))
	r.defeated = bool(d.get("defeated", false))
	return r
