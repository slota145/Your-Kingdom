class_name SaveMigrations
extends RefCounted
## Upgrades saved simulation states to the current format (ARCHITECTURE §8). Each step
## migrate_vN_to_vN+1 changes only what that version changed; tests keep one fixture per version.

const CURRENT_VERSION := 2


## Returns [param state] (saved by [param from_version]) in the current format.
static func migrate(state: Dictionary, from_version: int) -> Dictionary:
	var result := state.duplicate(true)
	var version := from_version
	if version < 2:
		result = migrate_v1_to_v2(result)
		version = 2
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
