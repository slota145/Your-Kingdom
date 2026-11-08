extends GdUnitTestSuite
## Review fixes, batch 1 (2026-11-07, ROADMAP M4b-2, M4b-3, M5, M6): start protection, more
## stallholders, "Send goods" with the settlement's demand, cancelling ordered cobbles, save v17.


func _warnings(sim: Simulation) -> int:
	var count := 0
	for event: Dictionary in sim.events.drain():
		if event["type"] == &"house_warning" or event["type"] == &"resident_left":
			count += 1
	return count


## While the start protection lasts a house short of food neither loses happiness nor warns;
## afterwards the shortage counts as before.
func test_start_protection_keeps_residents_calm() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var province := sim.province
	var hut := SimFixture.house(sim, Vector2i(10, 10), 4, false)
	hut.house.happiness = 60.0
	province.grace_until = province.tick + SimFixture.ticks(120)
	assert_bool(province.in_grace()).is_true()
	var lowest := 100.0
	var warnings := 0
	for i: int in SimFixture.ticks(110):
		sim.step()
		warnings += _warnings(sim)
		lowest = minf(lowest, hut.house.happiness)
	assert_float(lowest).is_greater_equal(60.0)
	assert_int(warnings).is_equal(0)
	assert_int(hut.house.residents).is_equal(4)
	assert_int(hut.house.unmet_seconds).is_equal(0)
	# Protection over: happiness sinks and the warning comes after WARN_AFTER s.
	for i: int in SimFixture.ticks(10 + Population.WARN_AFTER + 2):
		sim.step()
		warnings += _warnings(sim)
	assert_bool(province.in_grace()).is_false()
	assert_float(hut.house.happiness).is_less(60.0)
	assert_int(warnings).is_greater_equal(1)


## A new game and a newly settled province start protected for 15 minutes; it is saved.
func test_new_game_is_protected_and_the_protection_is_saved() -> void:
	var registry := SimFixture.registry()
	var sim := Simulation.from_map(registry, registry.get_map(&"riverlands"))
	assert_float(sim.province.grace_seconds_left()).is_equal(ProvinceSim.GRACE_SECONDS)
	sim.run_ticks(SimFixture.ticks(30))
	var copy := Simulation.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())), registry)
	assert_int(copy.province.grace_until).is_equal(sim.province.grace_until)
	assert_float(copy.province.grace_seconds_left()).is_equal(ProvinceSim.GRACE_SECONDS - 30.0)
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))


## A v16 game migrates to v17 unchanged (no start protection: it is past its start).
func test_v16_save_migrates_to_v17_unchanged() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v16_crane.json"))
	var state := SaveMigrations.migrate_v16_to_v17((document["state"] as Dictionary).duplicate(true))
	assert_str(SimCodec.canonical(state)).is_equal(SimCodec.canonical(document["state"]))
	var sim := Simulation.from_dict(SaveMigrations.migrate(document["state"], 16), SimFixture.registry())
	assert_bool(sim.province.in_grace()).is_false()


## Four stallholders per market keep the stalls of a big town filled (owner's survey).
func test_market_has_four_stallholders() -> void:
	var def := SimFixture.registry().get_building(&"market")
	assert_int(def.worker_count()).is_equal(4)


## "Send goods" fills the new route with what the settlement still lacks.
func test_send_goods_takes_the_settlement_demand() -> void:
	var registry := SimFixture.registry()
	var sim := Simulation.from_world(registry, registry.get_world(&"kingdom"), 1)
	var pid := sim.world.id_of(&"iron_wold")
	var s := sim.world.settlements[pid] as NeutralSettlement
	var bread := s.missing(&"bread")
	assert_int(bread).is_greater(0)
	s.take(&"bread", 5)
	var lines := TradeRoutes.demand_lines(sim, pid)
	assert_int(lines.size()).is_between(1, TradeRoute.MAX_LINES)
	var found := false
	for entry: Dictionary in lines:
		assert_int(int(entry["amount"])).is_equal(s.missing(entry["good"]))
		if entry["good"] == &"bread":
			found = true
			assert_int(int(entry["amount"])).is_equal(bread - 5)
	assert_bool(found).is_true()
	assert_str(String(CreateTradeRouteCommand.lines_error(sim, lines))).is_empty()
	# A player's province asks for nothing.
	assert_array(TradeRoutes.demand_lines(sim, sim.viewed_id)).is_empty()


## Ordered cobbles can be cancelled tile by tile; the dirt road stays, stone already brought
## lands on the ground when nothing is left to lay.
func test_cancel_ordered_paving() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var province := sim.province
	var tiles: Array[Vector2i] = [Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8)]
	assert_str(String(sim.execute(BuildPavingCommand.new(tiles)))).is_empty()
	var site := province.paving[province.paving_site_at(tiles[0])] as PavingSite
	site.stock.add(&"stone", 1)
	var middle: Array[Vector2i] = [tiles[1]]
	assert_str(String(sim.execute(CancelPavingCommand.new(middle)))).is_empty()
	assert_int(province.paving_site_at(tiles[1])).is_equal(0)
	assert_bool(province.grid.has_road(tiles[1])).is_true()
	assert_bool(province.grid.is_paved(tiles[1])).is_false()
	assert_int(site.tiles.size()).is_equal(2)
	# Nothing ordered there any more.
	assert_str(String(sim.execute(CancelPavingCommand.new(middle)))).is_equal("not_paving")
	var rest: Array[Vector2i] = [tiles[0], tiles[2]]
	assert_str(String(sim.execute(CancelPavingCommand.new(rest)))).is_empty()
	assert_bool(province.paving.is_empty()).is_true()
	var on_ground := 0
	for pile: GroundPile in province.piles.values():
		on_ground += pile.stock.total(&"stone")
	assert_int(on_ground).is_equal(1)
	for tile: Vector2i in tiles:
		assert_bool(province.grid.has_road(tile)).is_true()
	for request: TransportRequest in province.jobs.all():
		assert_int(request.dest_id).is_not_equal(site.id)
