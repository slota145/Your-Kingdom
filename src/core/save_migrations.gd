class_name SaveMigrations
extends RefCounted
## Upgrades saved simulation states to the current format (ARCHITECTURE §8). Each step
## migrate_vN_to_vN+1 changes only what that version changed; tests keep one fixture per version.

const CURRENT_VERSION := 26


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
	if version < 7:
		result = migrate_v6_to_v7(result)
		version = 7
	if version < 8:
		result = migrate_v7_to_v8(result)
		version = 8
	if version < 9:
		result = migrate_v8_to_v9(result)
		version = 9
	if version < 10:
		result = migrate_v9_to_v10(result)
		version = 10
	if version < 11:
		result = migrate_v10_to_v11(result)
		version = 11
	if version < 12:
		result = migrate_v11_to_v12(result)
		version = 12
	if version < 13:
		result = migrate_v12_to_v13(result)
		version = 13
	if version < 14:
		result = migrate_v13_to_v14(result)
		version = 14
	if version < 15:
		result = migrate_v14_to_v15(result)
		version = 15
	if version < 16:
		result = migrate_v15_to_v16(result)
		version = 16
	if version < 17:
		result = migrate_v16_to_v17(result)
		version = 17
	if version < 18:
		result = migrate_v17_to_v18(result)
		version = 18
	if version < 19:
		result = migrate_v18_to_v19(result)
		version = 19
	if version < 20:
		result = migrate_v19_to_v20(result)
		version = 20
	if version < 21:
		result = migrate_v20_to_v21(result)
		version = 21
	if version < 22:
		result = migrate_v21_to_v22(result)
		version = 22
	if version < 23:
		result = migrate_v22_to_v23(result)
		version = 23
	if version < 24:
		result = migrate_v23_to_v24(result)
		version = 24
	if version < 25:
		result = migrate_v24_to_v25(result)
		version = 25
	if version < 26:
		result = migrate_v25_to_v26(result)
		version = 26
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


## M4b-2: hut pantries get a slot for meat (burghers and patricians eat meat or fish), and
## the travelling merchant is away, due for his first visit 10 minutes into the game (at once
## in an older town) with nothing to sell. Production yards, herds and breeding start empty
## and are not written while empty.
static func migrate_v6_to_v7(state: Dictionary) -> Dictionary:
	var province: Dictionary = state["province"]
	province["merchant"] = {"state": 0, "next": 6000}
	for building: Variant in province.get("buildings", []):
		var b := building as Dictionary
		if b["def"] == "hut" and b.has("supply"):
			var slots: Array = (b["supply"] as Dictionary)["slots"]
			while slots.size() < 7:
				slots.append(["", 0])
	return state


## M4b-3: paving sites (none in an older town). Roads keep their value 1 (dirt road).
static func migrate_v7_to_v8(state: Dictionary) -> Dictionary:
	var province: Dictionary = state["province"]
	province["paving"] = []
	return state


## M5: ships and ship builds (none in an older town; shipyard queues start empty). The map
## and every other part stay as they were.
static func migrate_v8_to_v9(state: Dictionary) -> Dictionary:
	var province: Dictionary = state["province"]
	province["ships"] = []
	province["ship_builds"] = []
	return state


## M5 part 2: ports and the sea merchant. A v9 game has no port, so no ship reserved a berth;
## the sea merchant is away and comes as soon as there is a port (like the travelling
## merchant after v7).
static func migrate_v9_to_v10(state: Dictionary) -> Dictionary:
	var province: Dictionary = state["province"]
	province["sea_merchant"] = {"state": 0, "next": 0}
	return state


## v11 (M5 part 3): the player's cog keeps its voyage (plan, anchorage, state) under
## "voyage", a start from a ship its landing under "landing" and the building to place first
## under "first_building". Older saves have no player's cog and no landing: nothing to add.
static func migrate_v10_to_v11(state: Dictionary) -> Dictionary:
	return state


## v12 (M6 part 1): the world. An older save is a world with one province (id 1, the
## player's, viewed in detail); its map is not known any more, which only the world map needs.
static func migrate_v11_to_v12(state: Dictionary) -> Dictionary:
	var first := WorldSim.FIRST_ID
	state["world"] = {"world": "", "provinces": [{"id": first, "map": "", "owner": "player"}]}
	state["viewed"] = first
	state["provinces"] = [{"id": first, "mode": "detail", "state": state["province"]}]
	state.erase("province")
	return state


## v13 (M6 part 2): expeditions of settlers. The world keeps those on their way under
## "expeditions", a province one getting ready under "departure", a landing whether it came by
## land ("by_land", the wagon) and from which expedition, the player's cog the expedition it
## carries. A v12 game has none of them: nothing to add.
static func migrate_v12_to_v13(state: Dictionary) -> Dictionary:
	return state


## v14 (M6 part 3): trade routes, neutral settlements and wine. The world keeps routes under
## "routes" and the demands of neutral settlements under "settlements", a province the wagons
## of routes being loaded or unloaded there ("route_wagons"), a stable the wagons it lent
## ("lent"), the player's cog the route it runs ("route", "route_run", "shipped"). A v13 game
## has none of them (its neutral provinces get their towns on the first seconds). Wine is a
## new good of patrician houses: every hut's pantry gets a slot more for it (8).
static func migrate_v13_to_v14(state: Dictionary) -> Dictionary:
	for entry: Variant in state.get("provinces", []):
		var province: Dictionary = (entry as Dictionary)["state"]
		if province.has("province"):
			province = province["province"]   # the simplified mode keeps its detail inside
		for building: Variant in province.get("buildings", []):
			var b := building as Dictionary
			if b["def"] == "hut" and b.has("supply"):
				var slots: Array = (b["supply"] as Dictionary)["slots"]
				while slots.size() < 8:
					slots.append(["", 0])
	return state


## v15 (N1 part 1): quays on the sea. Each province grid keeps them under "quays" (one byte a
## tile: 0 none, 1 timber pier, 2 stone quay); paving sites that lay quay say so ("kind"). A
## v14 game has no quays: an empty layer. Moorings are a new building (nothing to change).
static func migrate_v14_to_v15(state: Dictionary) -> Dictionary:
	for entry: Variant in state.get("provinces", []):
		var province: Dictionary = (entry as Dictionary)["state"]
		if province.has("province"):
			province = province["province"]   # the simplified mode keeps its detail inside
		var grid: Dictionary = province["grid"]
		if grid.has("quays"):
			continue
		var size := SimCodec.to_vec2i(grid["size"])
		var empty := PackedByteArray()
		empty.resize(size.x * size.y)
		grid["quays"] = Marshalls.raw_to_base64(empty)
	return state


## v16 (N1 part 2): cargo cranes and port warehouses. Both are new buildings, and a crane
## operator's lift lives in his task blackboard (Cranes), so older saves need no change; the
## version guards a game with cranes from an older build that does not know them.
static func migrate_v15_to_v16(state: Dictionary) -> Dictionary:
	return state


## v17 (review fixes 2026-11-07): a province may keep the tick its start protection ends
## ("grace_until"). An older game is past its start: no protection, nothing to change.
static func migrate_v16_to_v17(state: Dictionary) -> Dictionary:
	return state


## v18 (M7 part 1): metals, weapons, barracks and soldiers. Buildings keep a blacksmith's
## choice ("recipe_mode", "next_choice"), a barracks' soldiers, recruits, meals and garrison;
## agents a soldier's "combat"; tasks the kinds "enlist" and "soldier". A v17 game has none
## of them. Ore veins are new on every map: the rocks chosen by ProvinceSim.choose_ore_veins
## (the same as in a new game) become veins, but not those a stonecutter is working on.
static func migrate_v17_to_v18(state: Dictionary) -> Dictionary:
	var vein_amount := 40
	var vein_def := load("res://data/resource_nodes/ore_vein.tres") as ResourceNodeDef
	if vein_def != null:
		vein_amount = vein_def.amount
	for entry: Variant in state.get("provinces", []):
		var province: Dictionary = (entry as Dictionary)["state"]
		if province.has("province"):
			province = province["province"]   # the simplified mode keeps its detail inside
		_lay_ore_veins(province, vein_amount)
	return state


## M7 part 2: walls, gatehouses, towers and stairs, fighters under orders, arrows, ladders and
## bandit raids. Everything new is optional with a default: no walls, whole buildings, nobody
## under orders, the first raid 40 minutes after the game is next played. Nothing to change.
static func migrate_v18_to_v19(state: Dictionary) -> Dictionary:
	return state


## M7 part 3: armies, the bandits' camp and battle reports in the world, soldiers' armies,
## guards and walls of neutral settlements. All optional: no armies; the camp comes up and the
## settlements get their walls and guards on the first second of play (Simulation).
static func migrate_v19_to_v20(state: Dictionary) -> Dictionary:
	return state


## v21 (B1 part 1): bridges over rivers, fords and lakes, a new layer of the grid
## ("bridges"), and paving sites of the kinds 6 and 7 (timber and stone bridge). Older games
## have no bridges: an empty layer.
static func migrate_v20_to_v21(state: Dictionary) -> Dictionary:
	for entry: Variant in state.get("provinces", []):
		var province: Dictionary = (entry as Dictionary)["state"]
		if province.has("province"):
			province = province["province"]   # the simplified mode keeps its detail inside
		var grid: Dictionary = province["grid"]
		if grid.has("bridges"):
			continue
		var size := SimCodec.to_vec2i(grid["size"])
		var empty := PackedByteArray()
		empty.resize(size.x * size.y)
		grid["bridges"] = Marshalls.raw_to_base64(empty)
	return state


## v22 (J1 part 2): ballistas (a new siege engine, saved like a ram) and their bolts in
## flight (arrows with "b": 1, and "w": the wall tile a bolt was shot at). All optional: an
## older game has none. The version guards a game with ballistas from a build that does not
## know them.
static func migrate_v21_to_v22(state: Dictionary) -> Dictionary:
	return state


## v23 (J1 part 3): an army at sea keeps its warships by kind ("fleet": ship id -> number;
## caravels, carracks and galleons besides the war cog). An older army's "ships" were all war
## cogs: Army.from_dict reads them as such, nothing to change here.
static func migrate_v22_to_v23(state: Dictionary) -> Dictionary:
	return state


## v24 (P2 part 1): bollards, smaller port warehouses and houses of dockers (new buildings);
## port warehouses have no porters any more: an older game's go home on the first second
## (Population lets a workplace keep no more workers than it needs). Nothing to change here;
## the version guards a game with the new buildings from a build that does not know them.
static func migrate_v23_to_v24(state: Dictionary) -> Dictionary:
	return state


## v25 (P2 part 2): a ship keeps the soldiers aboard and the soldiers on their way aboard
## ("troops": aboard, boarding, landed, order, called). Optional: an older ship has none.
static func migrate_v24_to_v25(state: Dictionary) -> Dictionary:
	return state


## v26 (P2 part 3): five tax rates (none, low, normal, high, very high) instead of three: the
## old low, normal and high move up by one.
static func migrate_v25_to_v26(state: Dictionary) -> Dictionary:
	var treasury: Dictionary = state.get("treasury", {})
	if treasury.has("rate"):
		treasury["rate"] = int(treasury["rate"]) + 1
	return state


static func _lay_ore_veins(province: Dictionary, vein_amount: int) -> void:
	var res: Dictionary = province.get("resources", {})
	var kinds: Array = res.get("kinds", [])
	var rock := kinds.find("rock") + 1
	if rock == 0 or kinds.has("ore_vein"):
		return
	var size := SimCodec.to_vec2i((province["grid"] as Dictionary)["size"])
	var kind := Marshalls.base64_to_raw(String(res.get("kind", "")))
	var amount := Marshalls.base64_to_raw(String(res.get("amount", "")))
	var claimed: Dictionary[int, bool] = {}
	var claims: Array = res.get("claims", [])
	for i: int in range(0, claims.size() - 1, 2):
		claimed[int(claims[i])] = true
	var rocks: Array[Vector2i] = []
	for i: int in kind.size():
		if kind[i] == rock and not claimed.has(i):
			rocks.append(Vector2i(i % size.x, i / size.x))
	var veins := ProvinceSim.choose_ore_veins(rocks, String(province.get("rare", "")) == "iron_ore")
	if veins.is_empty():
		return
	kinds.append("ore_vein")
	res["kinds"] = kinds
	for tile: Vector2i in veins:
		var i := tile.y * size.x + tile.x
		kind[i] = kinds.size()
		amount[i] = vein_amount
	res["kind"] = Marshalls.raw_to_base64(kind)
	res["amount"] = Marshalls.raw_to_base64(amount)
