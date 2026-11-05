class_name SaveMigrations
extends RefCounted
## Upgrades saved simulation states to the current format (ARCHITECTURE §8). Each step
## migrate_vN_to_vN+1 changes only what that version changed; tests keep one fixture per version.

const CURRENT_VERSION := 6


## Returns [param state] (saved by [param from_version]) in the current format.
static func migrate(state: Dictionary, from_version: int) -> Dictionary:
	var result := state.duplicate(true)
	var version := from_version
	if version < 2:
		result = migrate_v1_to_v2(result)
		version = 2
	if version < 3:
		result = migrate_v2_to_v3(result)
		version = 3
	if version < 4:
		result = migrate_v3_to_v4(result)
		version = 4
	if version < 5:
		result = migrate_v4_to_v5(result)
		version = 5
	if version < 6:
		result = migrate_v5_to_v6(result)
		version = 6
	return result


## M3: terrain and roads in the grid, construction sites, fields, map entry, agents' homes.
## A v1 map is all default terrain (grass) without roads; every building in it is finished.
static func migrate_v1_to_v2(state: Dictionary) -> Dictionary:
	var province: Dictionary = state["province"]
	var grid: Dictionary = province["grid"]
	var blocked := Marshalls.base64_to_raw(String(grid.get("blocked", "")))
	var empty := PackedByteArray()
	empty.resize(blocked.size())
	grid["terrain"] = Marshalls.raw_to_base64(empty)
	grid["roads"] = Marshalls.raw_to_base64(empty)
	province["sites"] = []
	province["fields"] = []
	province["entry"] = [0, 0]
	for agent: Variant in province.get("agents", []):
		(agent as Dictionary)["home"] = 0
	return state


## M4a: the treasury (an M3 town starts with the gold of a new game), the wood reserve of
## stockpiles, and hut pantries with a slot for every good of the new needs (bread, beer,
## fish, wood). Work priorities default to normal and are not written.
static func migrate_v2_to_v3(state: Dictionary) -> Dictionary:
	state["treasury"] = {"gold": 100, "rate": 1, "fraction": 0.0}
	var province: Dictionary = state["province"]
	for building: Variant in province.get("buildings", []):
		var b := building as Dictionary
		if b["def"] == "stockpile" and b.has("stock"):
			b["reserves"] = {"wood": 5}
		if b["def"] == "hut" and b.has("supply"):
			var slots: Array = (b["supply"] as Dictionary)["slots"]
			while slots.size() < 4:
				slots.append(["", 0])
	return state


## Goods the workshops leave for building (keep_for_building): none in an older town.
static func migrate_v3_to_v4(state: Dictionary) -> Dictionary:
	(state["province"] as Dictionary)["keep_for_building"] = {}
	return state


## M4b-1: hut pantries get slots for the patricians' goods (clothes, mead) and stockpiles 15
## slots instead of 12 (every yard tile but the entrance holds a stack). Production is not
## paused, taverns have not served yet and no saplings grow; those defaults are not written.
static func migrate_v4_to_v5(state: Dictionary) -> Dictionary:
	var province: Dictionary = state["province"]
	for building: Variant in province.get("buildings", []):
		var b := building as Dictionary
		if b["def"] == "hut" and b.has("supply"):
			var slots: Array = (b["supply"] as Dictionary)["slots"]
			while slots.size() < 6:
				slots.append(["", 0])
		if b["def"] == "stockpile" and b.has("stock"):
			var stock_slots: Array = (b["stock"] as Dictionary)["slots"]
			while stock_slots.size() < 15:
				stock_slots.append(["", 0])
	return state


## M4b-1.5: every building saves which way it is turned. Older buildings keep the entrance
## they always had (orientation 0), so nothing moves.
static func migrate_v5_to_v6(state: Dictionary) -> Dictionary:
	var province: Dictionary = state["province"]
	for building: Variant in province.get("buildings", []):
		(building as Dictionary)["orient"] = 0
	return state
