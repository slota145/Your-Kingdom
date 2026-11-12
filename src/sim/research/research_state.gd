class_name ResearchState
extends RefCounted
## What a kingdom has studied (ROADMAP E4 part 2, owner's surveys 2026-11-11): researches done,
## the one being studied with its progress, and the queue of the next ones. One state for all
## the player's provinces (a research works in the whole kingdom).
##
## [member open]: every building and ship may be built without research, and only researches
## in [member done] improve work. Games made without "New game" (tests, tools) and the raiders
## of the Invasion play so. The player's new game starts locked; an old save has everything
## done (migration). Each AI ruler has his own (RulerState.research, E4 part 5), a neutral
## settlement what it has ([method of_towns]).

var open: bool = false
var done: Dictionary[StringName, bool] = {}
## The research being studied (&"" = none) and its seconds of study so far.
var current: StringName = &""
var progress: float = 0.0
## Researches to start next, in order (gold is paid when each starts).
var queue: Array[StringName] = []
## Changes whenever [member done] changes (the bonuses are cached against it).
var version: int = 0

var _cache_version: int = -1
## Building id -> [extra fields, extra radius, work speed].
var _bonus: Dictionary[StringName, Array] = {}
var _porter_load: int = 1
var _cart_extra: int = 0
## Building or ship id -> the research that unlocks it.
var _unlocks: Dictionary[StringName, StringName] = {}


## Every building and ship allowed, nothing improved (the AI, tests, tools).
static func opened() -> ResearchState:
	var state := ResearchState.new()
	state.open = true
	return state


## What [param towns] already have, studied (E4 part 5, owner's survey 2026-11-11: the AI
## rulers' towns and the neutral settlements start with the research of the buildings, ships
## and soldiers they have), with the researches those need.
static func of_towns(data: DataRegistry, towns: Array[ProvinceSim]) -> ResearchState:
	var state := ResearchState.new()
	state._refresh(data)
	for town: ProvinceSim in towns:
		for building: BuildingState in town.buildings.all():
			state._grant(data, state._unlocks.get(building.def.id, &""))
			for unit: StringName in building.garrison:
				state._grant(data, state._unlocks.get(StringName("unit:" + String(unit)), &""))
		for ship: ShipUnit in town.ships.values():
			state._grant(data, state._unlocks.get(StringName("ship:" + String(ship.def.id)), &""))
	state.version += 1
	return state


## Marks [param id] done with every research it needs.
func _grant(data: DataRegistry, id: StringName) -> void:
	if id == &"" or done.has(id):
		return
	done[id] = true
	var def := data.get_research(id)
	if def != null:
		for need: StringName in def.requires:
			_grant(data, need)


func is_done(id: StringName) -> bool:
	return done.has(id)


## Done, studied now or waiting in the queue.
func is_planned(id: StringName) -> bool:
	return done.has(id) or current == id or queue.has(id)


## The research that must be done before [param building] may be built, or &"".
func needed_for_building(data: DataRegistry, building: StringName) -> StringName:
	if open:
		return &""
	_refresh(data)
	var research: StringName = _unlocks.get(building, &"")
	return &"" if research == &"" or done.has(research) else research


func allows_building(data: DataRegistry, building: StringName) -> bool:
	return needed_for_building(data, building) == &""


## As [method needed_for_building], for a ship ("ship:" keys keep them apart from buildings).
func needed_for_ship(data: DataRegistry, ship: StringName) -> StringName:
	return _needed(data, "ship:", ship)


## As [method needed_for_building], for a unit recruited in barracks (E4 part 3).
func needed_for_unit(data: DataRegistry, unit: StringName) -> StringName:
	return _needed(data, "unit:", unit)


func allows_unit(data: DataRegistry, unit: StringName) -> bool:
	return needed_for_unit(data, unit) == &""


## As [method needed_for_building], for a building tool (E4 part 3: &"stone_wall").
func needed_for_tool(data: DataRegistry, tool: StringName) -> StringName:
	return _needed(data, "tool:", tool)


func allows_tool(data: DataRegistry, tool: StringName) -> bool:
	return needed_for_tool(data, tool) == &""


func _needed(data: DataRegistry, prefix: String, id: StringName) -> StringName:
	if open:
		return &""
	_refresh(data)
	var research: StringName = _unlocks.get(StringName(prefix + String(id)), &"")
	return &"" if research == &"" or done.has(research) else research


func allows_ship(data: DataRegistry, ship: StringName) -> bool:
	return needed_for_ship(data, ship) == &""


## Field, pen or hive tiles [param building] gets more.
func extra_fields(data: DataRegistry, building: StringName) -> int:
	_refresh(data)
	var bonus: Array = _bonus.get(building, [])
	return int(bonus[0]) if not bonus.is_empty() else 0


func extra_radius(data: DataRegistry, building: StringName) -> int:
	_refresh(data)
	var bonus: Array = _bonus.get(building, [])
	return int(bonus[1]) if not bonus.is_empty() else 0


## How much faster the workers of [param building] work (1 = as before).
func work_speed(data: DataRegistry, building: StringName) -> float:
	_refresh(data)
	var bonus: Array = _bonus.get(building, [])
	return float(bonus[2]) if not bonus.is_empty() else 1.0


## Units a handcart carries more than its own load (E4 part 3: "Carts").
func cart_extra(data: DataRegistry) -> int:
	_refresh(data)
	return _cart_extra


## Whether farms and herds may take a charter (E4 part 3, "Nadanie").
func allows_charter(data: DataRegistry) -> bool:
	for def: ResearchDef in data.researches():
		if def.charter and done.has(def.id):
			return true
	return false


## Units a porter carries at once (1, 2 with "Better carrying").
func porter_load(data: DataRegistry) -> int:
	_refresh(data)
	return _porter_load


## Why [param id] cannot be started or queued now, or &"" (the needs of a school and of gold
## are checked by StartResearchCommand).
func plan_error(data: DataRegistry, id: StringName) -> StringName:
	var def := data.get_research(id)
	if def == null:
		return &"unknown_research"
	if done.has(id):
		return &"research_done"
	if current == id or queue.has(id):
		return &"research_planned"
	for need: StringName in def.requires:
		if not is_planned(need):
			return &"needs_research"
	return &""


func complete(id: StringName) -> void:
	if done.has(id):
		return
	done[id] = true
	queue.erase(id)
	if current == id:
		current = &""
		progress = 0.0
	version += 1


## Everything done at once (the developer mode, old saves).
func complete_all(data: DataRegistry) -> void:
	for def: ResearchDef in data.researches():
		done[def.id] = true
	current = &""
	progress = 0.0
	queue.clear()
	version += 1


## Removes [param id] from the queue with every queued research that needs it.
func unqueue(data: DataRegistry, id: StringName) -> void:
	queue.erase(id)
	var changed := true
	while changed:
		changed = false
		for queued: StringName in queue.duplicate():
			var def := data.get_research(queued)
			for need: StringName in def.requires:
				if not is_planned(need):
					queue.erase(queued)
					changed = true
					break


func _refresh(data: DataRegistry) -> void:
	if _cache_version == version:
		return
	_cache_version = version
	_bonus.clear()
	_unlocks.clear()
	_porter_load = 1
	_cart_extra = 0
	for def: ResearchDef in data.researches():
		for building: StringName in def.buildings:
			_unlocks[building] = def.id
		for ship: StringName in def.ships:
			_unlocks[StringName("ship:" + String(ship))] = def.id
		for unit: StringName in def.units:
			_unlocks[StringName("unit:" + String(unit))] = def.id
		for tool: StringName in def.tools:
			_unlocks[StringName("tool:" + String(tool))] = def.id
		if not done.has(def.id):
			continue
		_porter_load += def.porter_load
		_cart_extra += def.cart_load
		for building: StringName in def.affects:
			var bonus: Array = _bonus.get(building, [0, 0, 1.0])
			bonus[0] = int(bonus[0]) + def.extra_fields
			bonus[1] = int(bonus[1]) + def.extra_radius
			bonus[2] = float(bonus[2]) * def.work_speed
			_bonus[building] = bonus


func to_dict() -> Dictionary:
	var list: Array = []
	for id: StringName in done:
		list.append(String(id))
	list.sort()
	var queued: Array = []
	for id: StringName in queue:
		queued.append(String(id))
	return {"open": open, "done": list, "current": String(current), "progress": progress,
			"queue": queued}


static func from_dict(d: Dictionary) -> ResearchState:
	var state := ResearchState.new()
	state.open = bool(d.get("open", false))
	for id: Variant in d.get("done", []):
		state.done[StringName(String(id))] = true
	state.current = StringName(String(d.get("current", "")))
	state.progress = float(d.get("progress", 0.0))
	for id: Variant in d.get("queue", []):
		state.queue.append(StringName(String(id)))
	return state
