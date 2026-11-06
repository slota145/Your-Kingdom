extends GdUnitTestSuite
## M5 part 2 DoD: a port with its quay yard and dockers; the sea merchant's cog comes in from
## the sea edge only to a port, reserves and takes the berth, buys the player's surplus above
## the "sell above" settings and sells his goods while the kingdom has less than "buy up to";
## dockers carry every unit over the gangway, and the hold the ship panel lists matches the
## simulation after each unit. Saves taken mid-loading play on alike.


## 48x48: land above row 30, shallow sea rows 30-32, deep sea from row 33. A village with a
## second storage near the port at (20, 28) (quay on rows 30-31, berth (22, 32)).
func _port_sim(seed_value: int = 1, with_port: bool = true) -> Dictionary:
	var sim := SimFixture.make_sim(Vector2i(48, 48), seed_value)
	SimFixture.coast(sim, 30, 33)
	SimFixture.village(sim, 10, 40)
	for i: int in 3:
		SimFixture.house(sim, Vector2i(2 + 3 * i, 12))
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(14, 22))
	stock.stock.add(&"wood", 60)
	stock.stock.add(&"tar", 2)
	sim.treasury.gold = 500
	var scene := {"sim": sim, "stock": stock}
	if with_port:
		scene["port"] = _port(sim)
	return scene


func _port(sim: Simulation) -> BuildingState:
	var port := SimFixture.place(sim, &"port", Vector2i(20, 28))
	for i: int in 2:
		var docker := SimFixture.spawn(sim, Harbour.DOCKER_KIND, port.entrance_tile())
		assert_str(String(sim.execute(AssignWorkerCommand.new(docker.id, port.id)))).is_empty()
	return port


func _until(sim: Simulation, state: SeaMerchant.State, seconds: float) -> bool:
	return SimFixture.run_until(sim, func() -> bool: return sim.province.sea_merchant.state == state, seconds)


func _trader_ship(sim: Simulation) -> ShipUnit:
	return sim.province.ships.get(sim.province.sea_merchant.ship_id) as ShipUnit


func test_port_needs_the_sea_and_a_way_to_deep_water() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	SimFixture.coast(sim, 30, 33)
	var def := sim.data.get_building(&"port")
	assert_str(String(sim.province.placement_error(def, Vector2i(20, 20)))).is_equal("needs_sea")
	assert_str(String(sim.province.placement_error(def, Vector2i(20, 28)))).is_empty()
	var port := SimFixture.place(sim, &"port", Vector2i(20, 28))
	assert_int(port.stock.slot_count()).is_equal(6)
	assert_vector(port.berth_tile()).is_equal(Vector2i(22, 32))
	assert_vector(port.gangway_tile()).is_equal(Vector2i(22, 31))
	# The berth joins deep water by a fairway, so a cog can moor there.
	assert_bool(sim.province.cog_nav.is_walkable(port.berth_tile())).is_true()
	# The quay yard is private: nobody stores goods there on his own.
	assert_int(sim.province.nearest_sink(&"wood", 1, port.entrance_tile())).is_equal(0)


func test_sea_merchant_comes_only_to_a_port_and_leaves_over_the_edge() -> void:
	var scene := _port_sim(1, false)
	var sim: Simulation = scene["sim"]
	var trader := sim.province.sea_merchant
	trader.next_visit = 10
	assert_bool(_until(sim, SeaMerchant.State.COMING, 30)).is_false()
	assert_int(sim.province.ships.size()).is_equal(0)
	var port := _port(sim)
	trader.next_visit = sim.province.tick + 10
	assert_bool(_until(sim, SeaMerchant.State.COMING, 30)).is_true()
	var ship := _trader_ship(sim)
	assert_str(String(ship.def.id)).is_equal("foreign_cog")
	# He comes in over the map edge and has the berth reserved on the way.
	var at := ship.tile()
	assert_bool(at.x == 0 or at.y == 0 or at.x == 47 or at.y == 47).is_true()
	assert_object(Harbour.berth_holder(sim.province, port)).is_same(ship)
	assert_dict(ship.hold.totals()).is_equal({&"cloth": 10, &"planks": 20, &"tar": 10})
	assert_bool(_until(sim, SeaMerchant.State.TRADING, 120)).is_true()
	assert_vector(ship.tile()).is_equal(port.berth_tile())
	assert_bool(ship.is_moored()).is_true()
	assert_bool(_until(sim, SeaMerchant.State.AWAY, SeaMerchant.STAY + SeaMerchant.FINISH_WAIT + 120)).is_true()
	assert_bool(sim.province.ships.has(ship.id)).is_false()
	assert_object(Harbour.berth_holder(sim.province, port)).is_null()
	assert_int(trader.next_visit).is_greater(sim.province.tick)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_berth_takes_one_ship_at_a_time() -> void:
	var scene := _port_sim()
	var sim: Simulation = scene["sim"]
	var port: BuildingState = scene["port"]
	var cog := sim.data.get_ship(&"foreign_cog")
	var first := ShipUnit.new(sim.province.ids.take(), cog, Vector2(10.5, 40.5), sim.data)
	var second := ShipUnit.new(sim.province.ids.take(), cog, Vector2(30.5, 40.5), sim.data)
	sim.province.ships[first.id] = first
	sim.province.ships[second.id] = second
	assert_bool(Harbour.claim_berth(sim.province, first, port)).is_true()
	assert_bool(Harbour.claim_berth(sim.province, second, port)).is_false()
	assert_object(Harbour.free_port(sim.province, Vector2i.ZERO)).is_null()
	# No free berth: the sea merchant does not come.
	sim.province.sea_merchant.next_visit = sim.province.tick + 1
	sim.run_ticks(SimFixture.ticks(2))
	assert_int(sim.province.sea_merchant.state).is_equal(SeaMerchant.State.AWAY)
	first.berth_id = 0
	assert_bool(Harbour.claim_berth(sim.province, second, port)).is_true()


## Watches dockers and the hold during a visit: every unit goes over the gangway, and the
## ship panel lists exactly the hold after each unit.
func _watch_visit(sim: Simulation, port: BuildingState, seconds: float) -> Dictionary:
	var seen := {"gangway": false, "at_ship": true, "units_in": 0, "units_out": 0, "panel_ok": true,
			"visited": false}
	var quay: Array[Vector2i] = port.def.water_tiles_at(port.origin, port.orientation)
	var panel := ShipPanel.new()
	for i: int in SimFixture.ticks(seconds):
		sim.step()
		var trader := sim.province.sea_merchant
		var ship := _trader_ship(sim)
		for e: Dictionary in sim.events.drain():
			if ship == null:
				continue
			if e["type"] == &"good_stored" and int(e["storage"]) == ship.id:
				seen["units_in"] = int(seen["units_in"]) + int(e["amount"])
			if e["type"] == &"good_taken" and int(e["storage"]) == ship.id:
				seen["units_out"] = int(seen["units_out"]) + int(e["amount"])
			if e["type"] in [&"good_stored", &"good_taken"] and int(e["storage"]) == ship.id:
				# The agent hands the unit over standing at the ship, at the top of the gangway.
				var agent := sim.province.agents.get_agent(int(e["agent"]))
				if agent.tile() != port.berth_tile():
					seen["at_ship"] = false
				panel.show_ship(sim.province, ship.id)
				if panel.listed() != ship.hold.totals():
					seen["panel_ok"] = false
		if trader.is_trading():
			seen["visited"] = true
		for agent: Agent in sim.province.agents.all():
			if agent.kind == Harbour.DOCKER_KIND and quay.has(agent.tile()) and agent.activity == &"walk":
				seen["gangway"] = true
		if seen["visited"] and trader.state == SeaMerchant.State.AWAY:
			break
	panel.free()
	return seen


func test_sea_merchant_buys_surplus_carried_aboard_by_dockers() -> void:
	var scene := _port_sim()
	var sim: Simulation = scene["sim"]
	var port: BuildingState = scene["port"]
	var stock: BuildingState = scene["stock"]
	assert_str(String(sim.execute(SetSellAboveCommand.new(&"wood", 30)))).is_empty()
	# Planks are in his own offer: he does not buy them.
	assert_str(String(sim.execute(SetSellAboveCommand.new(&"planks", 0)))).is_empty()
	stock.stock.add(&"planks", 10)
	var wood := sim.province.goods_total(&"wood")
	var gold := sim.treasury.gold
	sim.province.sea_merchant.next_visit = sim.province.tick + 10
	var seen := _watch_visit(sim, port, SeaMerchant.STAY + 400)
	var trader := sim.province.sea_merchant
	print("sea merchant bought: ", trader.bought, " for ", trader.earned, "; seen ", seen)
	assert_bool(seen["visited"]).is_true()
	assert_bool(seen["gangway"]).is_true()
	assert_bool(seen["at_ship"]).is_true()
	assert_bool(seen["panel_ok"]).is_true()
	assert_int(trader.bought).is_greater_equal(10)
	assert_int(trader.bought).is_less_equal(SeaMerchant.MAX_BUY)
	assert_int(int(seen["units_in"])).is_equal(trader.bought)
	assert_int(trader.earned).is_equal(trader.bought * sim.data.get_good(&"wood").base_price)
	assert_int(sim.treasury.gold).is_greater_equal(gold + trader.earned)
	# The setting is kept: the kingdom still has 30 wood, nothing is lost on the way.
	assert_int(sim.province.goods_total(&"wood")).is_equal(wood - trader.bought)
	assert_int(sim.province.kingdom_stock(&"wood")).is_greater_equal(30)
	assert_int(sim.province.goods_total(&"planks")).is_equal(10)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_sea_merchant_sells_up_to_the_players_setting() -> void:
	var scene := _port_sim()
	var sim: Simulation = scene["sim"]
	var port: BuildingState = scene["port"]
	assert_str(String(sim.execute(SetBuyUpToCommand.new(&"tar", 8)))).is_empty()
	assert_str(String(sim.execute(SetBuyUpToCommand.new(&"wood", 8)))).is_equal("not_offered")
	var gold := sim.treasury.gold
	var tar := sim.province.goods_total(&"tar")
	sim.province.sea_merchant.next_visit = sim.province.tick + 10
	var seen := _watch_visit(sim, port, SeaMerchant.STAY + 400)
	var trader := sim.province.sea_merchant
	print("sea merchant sold: ", seen["units_out"], " for ", trader.spent)
	assert_bool(seen["visited"]).is_true()
	assert_bool(seen["panel_ok"]).is_true()
	assert_int(tar).is_equal(2)
	assert_int(int(seen["units_out"])).is_equal(6)
	assert_int(trader.spent).is_equal(6 * SeaMerchant.sell_price(sim.province, &"tar"))
	assert_int(sim.treasury.gold).is_less_equal(gold - trader.spent + 60)
	assert_int(sim.province.goods_total(&"tar")).is_equal(8)
	# Porters took the bought tar from the quay to a storage.
	assert_int(port.stock.total(&"tar")).is_equal(0)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func _reload(sim: Simulation) -> Simulation:
	var state := sim.to_dict()
	return Simulation.from_dict(JSON.parse_string(JSON.stringify(state, "", true, true)), SimFixture.registry())


func test_save_mid_loading_continues_alike() -> void:
	var scene := _port_sim(5)
	var sim: Simulation = scene["sim"]
	assert_str(String(sim.execute(SetSellAboveCommand.new(&"wood", 30)))).is_empty()
	assert_str(String(sim.execute(SetBuyUpToCommand.new(&"tar", 8)))).is_empty()
	sim.province.sea_merchant.next_visit = sim.province.tick + 10
	var province := sim.province
	# Until a docker is out on the gangway.
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		for agent: Agent in province.agents.all():
			if agent.task != null and agent.task.bb.has("_gw"):
				return true
		return false, 300.0)).is_true()
	var copy := _reload(sim)
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))
	for i: int in SimFixture.ticks(120):
		sim.step()
		copy.step()
		sim.events.drain()
		copy.events.drain()
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))
	assert_array(Array(copy.province.dangling_holds())).is_empty()
