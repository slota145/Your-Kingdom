extends GdUnitTestSuite
## M2 DoD: save -> load -> save is identical, and a loaded game continues exactly like the
## original one would have.

const SaveServiceScript := preload("res://src/core/save_service.gd")
const TEST_PATH := "user://test_saves/sim_round_trip.sav"


func after_test() -> void:
	DirAccess.remove_absolute(TEST_PATH)


## Woodcutter, two stockpiles, porters with transport requests, goods on the ground.
func _busy_sim(seed_value: int) -> Simulation:
	var sim := SimFixture.make_sim(Vector2i(40, 40), seed_value)
	var scene := SimFixture.woodcutter_scene(sim)
	var a: BuildingState = scene["stock"]
	var b := SimFixture.place(sim, &"stockpile", Vector2i(24, 24))
	a.stock.add(&"bread", 40)
	b.stock.add(&"grain", 15)
	for i: int in 8:
		SimFixture.spawn(sim, &"porter", Vector2i(10 + i, 14))
	sim.execute(RequestTransportCommand.new(&"bread", 25, a.id, b.id))
	sim.execute(RequestTransportCommand.new(&"grain", 10, b.id, a.id))
	sim.province.drop_goods(Vector2i(30, 10), &"flour", 4)
	return sim


func _reload(sim: Simulation) -> Simulation:
	var text := JSON.stringify(sim.to_dict(), "", false, true)
	return Simulation.from_dict(JSON.parse_string(text), SimFixture.registry())


func test_save_load_save_is_identical_mid_work() -> void:
	var sim := _busy_sim(3)
	for ticks: int in [1, 37, 400, 1200]:
		sim.run_ticks(ticks)
		var first := SimCodec.canonical(sim.to_dict())
		var second := SimCodec.canonical(_reload(sim).to_dict())
		assert_str(second).is_equal(first)


func test_loaded_game_continues_deterministically() -> void:
	var original := _busy_sim(11)
	original.run_ticks(733)
	var loaded := _reload(original)
	for chunk: int in 6:
		original.run_ticks(250)
		loaded.run_ticks(250)
		assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(original.to_dict()))
	assert_int(original.province.agents.count()).is_equal(9)


func test_two_runs_from_same_start_are_identical() -> void:
	var a := _busy_sim(5)
	var b := _busy_sim(5)
	a.run_ticks(1500)
	b.run_ticks(1500)
	assert_str(SimCodec.canonical(a.to_dict())).is_equal(SimCodec.canonical(b.to_dict()))


func test_save_file_round_trip_through_save_service() -> void:
	var service: Node = auto_free(SaveServiceScript.new())
	var sim := _busy_sim(2)
	sim.run_ticks(500)
	assert_int(service.save_simulation(TEST_PATH, sim)).is_equal(OK)
	var loaded: Simulation = service.load_simulation(TEST_PATH, SimFixture.registry())
	assert_object(loaded).is_not_null()
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))
	sim.run_ticks(300)
	loaded.run_ticks(300)
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))


## A save written by save_version 1 still loads and keeps playing. When the format changes,
## add a migration so this fixture keeps passing (ARCHITECTURE §8).
func test_v1_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v1_woodcutter.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(1)
	var state := SaveMigrations.migrate(document["state"], 1)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	var wood_before := sim.province.goods_total(&"wood")
	sim.run_ticks(SimFixture.ticks(120))
	assert_int(sim.province.goods_total(&"wood")).is_greater(wood_before)
	assert_int(sim.province.goods_total(&"bread")).is_equal(12)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


## M3: a village mid-work: construction site, farm with fields, households, roads.
func _village_sim(seed_value: int) -> Simulation:
	var sim := SimFixture.make_sim(Vector2i(40, 40), seed_value)
	SimFixture.village(sim, 60, 10)
	SimFixture.house(sim, Vector2i(8, 8), 4, false)
	SimFixture.place(sim, &"well", Vector2i(9, 12))
	var farm := SimFixture.place(sim, &"farm", Vector2i(18, 14))
	for x: int in range(20, 24):
		sim.execute(PlaceFieldCommand.new(farm.id, Vector2i(x, 13)))
	SimFixture.place(sim, &"mill", Vector2i(14, 4))
	var road: Array[Vector2i] = []
	for x: int in range(2, 20):
		road.append(Vector2i(x, 11))
	sim.execute(BuildRoadCommand.new(road))
	sim.execute(PlaceBuildingCommand.new(&"bakery", Vector2i(18, 4)))
	sim.province.entry_tile = Vector2i(0, 30)
	return sim


func test_village_save_load_save_is_identical() -> void:
	var sim := _village_sim(4)
	var carried := false
	for ticks: int in [1, 233, 600, 1500]:
		sim.run_ticks(ticks)
		for agent: Agent in sim.province.agents.all():
			carried = carried or agent.is_carrying()
		assert_str(SimCodec.canonical(_reload(sim).to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))
	assert_bool(carried).is_true()


func test_village_continues_deterministically_after_load() -> void:
	var original := _village_sim(8)
	original.run_ticks(1111)
	var goods_before := {}
	for good: StringName in [&"wood", &"bread", &"grain"]:
		goods_before[good] = original.province.goods_total(good)
	var loaded := _reload(original)
	for chunk: int in 8:
		original.run_ticks(300)
		loaded.run_ticks(300)
		assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(original.to_dict()))
	assert_array(Array(loaded.province.dangling_holds())).is_empty()


## A save written by save_version 2 keeps loading unchanged.
func test_v2_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v2_village.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(2)
	var state := SaveMigrations.migrate(document["state"], 2)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	var people := 0
	for b: BuildingState in sim.province.buildings.all():
		if b.house != null:
			people += b.house.residents
	sim.run_ticks(SimFixture.ticks(120))
	assert_int(sim.province.agents.count()).is_greater(0)
	assert_int(people).is_greater(0)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


## M4a: a v2 town gets the treasury, the stockpile's wood reserve and bigger hut pantries.
func test_v2_migration_adds_m4a_state() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v2_village.json"))
	var sim := Simulation.from_dict(SaveMigrations.migrate(document["state"], 2), SimFixture.registry())
	assert_int(sim.treasury.gold).is_equal(100)
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == &"stockpile":
			assert_int(int(b.reserves.get(&"wood", 0))).is_equal(5)
		if b.house != null:
			assert_int(b.supply.slot_count()).is_equal(b.house_goods().size())


## A save written by save_version 3 (M4a: treasury, reserves, priorities, a brewery's input
## store, an angler) loads unchanged and keeps playing.
func test_v3_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v3_town.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(3)
	var state := SaveMigrations.migrate(document["state"], 3)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	assert_int(sim.treasury.tax_rate).is_equal(Treasury.TaxRate.HIGH)
	var brewery: BuildingState = null
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == &"brewery":
			brewery = b
		if b.def.id == &"stockpile":
			assert_int(int(b.reserves[&"wood"])).is_equal(8)
	assert_int(brewery.priority).is_equal(BuildingState.Priority.HIGH)
	assert_int(brewery.supply.total(&"grain")).is_equal(1)
	sim.run_ticks(SimFixture.ticks(120))
	assert_int(sim.province.goods_total(&"fish")).is_greater(0)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


## v3 -> v4: an older town keeps nothing back for building.
func test_v3_migration_keeps_nothing_for_building() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v3_town.json"))
	var sim := Simulation.from_dict(SaveMigrations.migrate(document["state"], 3), SimFixture.registry())
	assert_bool(sim.province.keep_for_building.is_empty()).is_true()


## A save written by save_version 4 (wood kept for building) loads unchanged and keeps playing.
func test_v4_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v4_town.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(4)
	var state := SaveMigrations.migrate(document["state"], 4)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	assert_int(sim.province.keep_for_building[&"wood"]).is_equal(10)
	sim.run_ticks(SimFixture.ticks(60))
	assert_array(Array(sim.province.dangling_holds())).is_empty()


## v4 -> v5: hut pantries get slots for clothes and mead; nothing is paused, no tavern has
## served and no saplings grow.
func test_v4_migration_adds_patrician_pantry_slots() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v4_town.json"))
	var sim := Simulation.from_dict(SaveMigrations.migrate(document["state"], 4), SimFixture.registry())
	assert_int(sim.province.resources.growing_count()).is_equal(0)
	for b: BuildingState in sim.province.buildings.all():
		assert_bool(b.paused).is_false()
		assert_int(b.serving_until).is_equal(0)
		if b.house != null:
			assert_int(b.supply.slot_count()).is_equal(b.house_goods().size())
		if b.def.id == &"stockpile":
			assert_int(b.stock.slot_count()).is_equal(15)


## A save written by save_version 5 (M4b-1: saplings growing, a paused tailor, a tavern that
## has served, a patrician house) loads unchanged and keeps playing.
func test_v5_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v5_town.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(5)
	var state := SaveMigrations.migrate(document["state"], 5)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	assert_int(sim.province.resources.growing_count()).is_greater(0)
	var levels: Array[int] = []
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == &"tailor":
			assert_bool(b.paused).is_true()
		if b.def.id == &"tavern":
			assert_int(b.serving_until).is_greater(0)
		if b.house != null:
			levels.append(b.house.level)
	assert_array(levels).contains([3])
	sim.run_ticks(SimFixture.ticks(60))
	assert_array(Array(sim.province.dangling_holds())).is_empty()


## v5 -> v6: every building keeps the entrance it had (orientation 0), so no door moves.
func test_v5_migration_keeps_every_entrance() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v5_town.json"))
	var old_entrances: Dictionary[int, Vector2i] = {}
	for b: Variant in document["state"]["province"]["buildings"]:
		var d := b as Dictionary
		var def := SimFixture.registry().get_building(StringName(String(d["def"])))
		old_entrances[int(d["id"])] = SimCodec.to_vec2i(d["origin"]) + def.entrance
	var sim := Simulation.from_dict(SaveMigrations.migrate(document["state"], 5), SimFixture.registry())
	assert_int(sim.province.buildings.all().size()).is_equal(old_entrances.size())
	for b: BuildingState in sim.province.buildings.all():
		assert_int(b.orientation).is_equal(0)
		assert_vector(b.entrance_tile()).is_equal(old_entrances[b.id])
	sim.run_ticks(SimFixture.ticks(60))
	assert_array(Array(sim.province.dangling_holds())).is_empty()


## A save written by save_version 6 (M4b-1.5: houses turned four ways, two rows back to
## back, a mirrored bakery, a turned construction site) loads unchanged and keeps playing.
func test_v6_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v6_town.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(6)
	var state := SaveMigrations.migrate(document["state"], 6)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	var turned: Dictionary[int, bool] = {}
	for b: BuildingState in sim.province.buildings.all():
		turned[b.orientation] = true
	assert_array(turned.keys()).contains_exactly_in_any_order([0, 1, 2, 3])
	sim.run_ticks(SimFixture.ticks(60))
	assert_array(Array(sim.province.dangling_holds())).is_empty()


## A save written by save_version 7 (M4b-2: a woodcutter's yard with wood, a pigsty herd,
## market stalls, the merchant trading with a pig bought and planks for sale) loads
## unchanged and keeps playing.
func test_v7_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v7_town.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(7)
	var state := SaveMigrations.migrate(document["state"], 7)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	assert_bool(sim.province.merchant.is_trading()).is_true()
	assert_dict(sim.province.merchant.sell_above).is_equal({&"planks": 20})
	var herds := 0
	for b: BuildingState in sim.province.buildings.all():
		if b.def.herd_good == &"pig":
			herds += b.yard.total(&"pig")
	assert_int(herds).is_greater_equal(5)
	sim.run_ticks(SimFixture.ticks(60))
	assert_array(Array(sim.province.dangling_holds())).is_empty()


## M4b-1.5 town (v6): after the migration huts have a pantry slot for meat and the merchant
## is away, due for a visit.
func test_v6_save_gets_meat_slot_and_merchant() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v6_town.json"))
	var sim := Simulation.from_dict(SaveMigrations.migrate(document["state"], 6), SimFixture.registry())
	assert_int(sim.province.merchant.state).is_equal(Merchant.State.AWAY)
	for b: BuildingState in sim.province.buildings.all():
		if b.house != null:
			assert_bool(b.supply.slot_count() >= b.house_goods().size()).is_true()


## A save written by save_version 8 (M4b-3: paving half laid, a storage with a handcart in
## use, a carter driving a wagon) loads unchanged and keeps playing.
func test_v8_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v8_town.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(8)
	var state := SaveMigrations.migrate(document["state"], 8)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	assert_int(sim.province.grid.paved_count()).is_equal(5)
	assert_int(sim.province.paving.size()).is_equal(1)
	var vehicles := {}
	for agent: Agent in sim.province.agents.all():
		vehicles[agent.vehicle] = true
	assert_bool(vehicles.has(Carriers.WAGON)).is_true()
	var province := sim.province
	assert_bool(SimFixture.run_until(sim, func() -> bool: return province.grid.paved_count() == 10,
			180.0)).is_true()
	assert_array(Array(sim.province.dangling_holds())).is_empty()


## M4b-2 town (v7): after the migration there are no paving sites and nothing changes.
func test_v7_save_gets_empty_paving() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v7_town.json"))
	var sim := Simulation.from_dict(SaveMigrations.migrate(document["state"], 7), SimFixture.registry())
	assert_int(sim.province.paving.size()).is_equal(0)
	assert_int(sim.province.grid.paved_count()).is_equal(0)


## A save written by save_version 9 (M5 part 1: a fisherman out at sea in his boat, the
## second boat on the slipway with its first stage under way) loads unchanged, keeps playing
## and launches the boat.
func test_v9_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v9_harbour.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(9)
	var state := SaveMigrations.migrate(document["state"], 9)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	var province := sim.province
	assert_int(province.ships.size()).is_equal(1)
	assert_int(province.ship_builds.size()).is_equal(1)
	var aboard := 0
	for agent: Agent in province.agents.all():
		if agent.vehicle == Ships.ABOARD:
			aboard += 1
	assert_int(aboard).is_equal(1)
	assert_bool(SimFixture.run_until(sim, func() -> bool: return province.ships.size() == 2, 300.0)).is_true()
	assert_array(Array(province.dangling_holds())).is_empty()


## M4b-3 town (v8): after the migration there are no ships and no ship builds.
func test_v8_save_gets_no_ships() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v8_town.json"))
	var sim := Simulation.from_dict(SaveMigrations.migrate(document["state"], 8), SimFixture.registry())
	assert_int(sim.province.ships.size()).is_equal(0)
	assert_int(sim.province.ship_builds.size()).is_equal(0)
	assert_int(sim.province.fairway.size()).is_equal(0)


## A save written by save_version 10 (M5 part 2: the sea merchant's cog moored at a port,
## a docker on the gangway with a unit of wood, settings to sell wood and buy tar) loads
## unchanged, keeps playing and the merchant finishes his visit without losing goods.
func test_v10_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v10_port.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(10)
	var state := SaveMigrations.migrate(document["state"], 10)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	var province := sim.province
	var trader := province.sea_merchant
	assert_bool(trader.is_trading()).is_true()
	assert_dict(trader.buy_up_to).is_equal({&"tar": 8})
	var on_gangway := 0
	for agent: Agent in province.agents.all():
		if agent.task != null and agent.task.bb.has("_gw"):
			on_gangway += 1
	assert_int(on_gangway).is_greater_equal(1)
	var wood := province.goods_total(&"wood")
	var bought := trader.bought
	assert_bool(SimFixture.run_until(sim, func() -> bool: return trader.state == SeaMerchant.State.AWAY,
			SeaMerchant.STAY + 300.0)).is_true()
	assert_int(province.goods_total(&"wood")).is_equal(wood - (trader.bought - bought) - _wood_aboard(state))
	assert_int(province.goods_total(&"tar")).is_equal(8)
	assert_array(Array(province.dangling_holds())).is_empty()


## Wood already in the cog's hold in [param state] (it sails away with him).
func _wood_aboard(state: Dictionary) -> int:
	var sum := 0
	for ship: Variant in state["provinces"][0]["state"]["ships"]:
		var hold: Dictionary = (ship as Dictionary).get("hold", {})
		if hold.is_empty():
			continue
		var stock := Stockpile.from_dict(hold, SimFixture.registry())
		sum += stock.total(&"wood")
	return sum


## M5 part 1 harbour (v9): after the migration the sea merchant is away, due as soon as there
## is a port, with no settings; ships hold no berth.
func test_v9_save_gets_sea_merchant() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v9_harbour.json"))
	var sim := Simulation.from_dict(SaveMigrations.migrate(document["state"], 9), SimFixture.registry())
	var trader := sim.province.sea_merchant
	assert_int(trader.state).is_equal(SeaMerchant.State.AWAY)
	assert_int(trader.next_visit).is_equal(0)
	assert_dict(trader.buy_up_to).is_empty()
	for ship: ShipUnit in sim.province.ships.values():
		assert_int(ship.berth_id).is_equal(0)
	# No port: he does not come.
	sim.run_ticks(SimFixture.ticks(5))
	assert_int(trader.state).is_equal(SeaMerchant.State.AWAY)


## A save written by save_version 11 (M5 part 3: the player's cog away over the horizon with
## a sale of wood and an order of planks, a second cog on the slipway in its planking stage)
## loads unchanged; the cog comes back with the planks and the gold, the second cog is
## launched, and no goods are lost.
func test_v11_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v11_voyage.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(11)
	var state := SaveMigrations.migrate(document["state"], 11)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	var province := sim.province
	var cog: ShipUnit = null
	for ship: ShipUnit in province.ships.values():
		if ship.voyage != null:
			cog = ship
	assert_object(cog).is_not_null()
	assert_bool(cog.is_away()).is_true()
	assert_int(province.ship_builds.size()).is_equal(1)
	var planks := province.goods_total(&"planks") + cog.hold.total(&"planks")
	var gold := sim.treasury.gold
	var earned := cog.voyage.earned
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return cog.voyage.state == Voyage.State.IDLE and province.ship_builds.is_empty(),
		Voyage.AWAY_TIME + 600.0)).is_true()
	assert_int(cog.voyage.last_bought).is_equal(5)
	assert_int(sim.treasury.gold).is_greater_equal(gold + earned - 60)
	# The planks came home; the slipway used some for the second cog.
	assert_int(province.goods_total(&"planks")).is_greater_equal(planks - 20)
	assert_int(province.ships.size()).is_equal(2)
	assert_array(Array(province.dangling_holds())).is_empty()


## M5 part 2 port (v10): after the migration (nothing to add) the save plays on unchanged.
func test_v10_save_migrates_to_v11() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v10_port.json"))
	var state := SaveMigrations.migrate(document["state"], 10)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_object(sim.province.landing).is_null()
	assert_str(String(sim.province.first_building)).is_empty()
	for ship: ShipUnit in sim.province.ships.values():
		assert_object(ship.voyage).is_null()
