extends GdUnitTestSuite
## M6 part 3 DoD: a trade route by wagon and by cog carries goods by its threshold, with the
## loading visible in the viewed province (porters fill the wagon in front of the trading post,
## dockers load the cog) and done at once in one nobody looks at; a wagon is unloaded by
## porters in B when B is viewed. The port's voyage "to my province" carries the plan there.
## No goods are lost on the way, and a save taken mid-run plays on.


func _registry() -> DataRegistry:
	return SimFixture.registry()


## 48x48 town playing Landing Bay: town hall, stockpile with bread and planks, a trading post
## with its carter, porters without a house; Willow Vale (a land neighbour) settled on Riverlands
## and left alone.
func _land_world() -> Dictionary:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	sim.world = WorldSim.from_def(_registry().get_world(&"kingdom"), _registry())
	sim.world.get_province(WorldSim.FIRST_ID).owner = ProvinceDef.OWNER_PLAYER
	var village := SimFixture.village(sim, 40, 60)
	var stock: BuildingState = village["stock"]
	stock.stock.add(&"planks", 30)
	var stable := SimFixture.place(sim, &"trading_post", Vector2i(20, 10))
	var carter := SimFixture.spawn(sim, Carriers.CARTER_KIND, stable.entrance_tile())
	assert_str(String(sim.execute(AssignWorkerCommand.new(carter.id, stable.id)))).is_empty()
	for i: int in 4:
		SimFixture.spawn(sim, JobBoard.PORTER_KIND, Vector2i(12, 6))
	sim.province.entry_tile = Vector2i(47, 20)
	var vale := sim.world.id_of(&"willow_vale")
	sim.open_province(vale, _registry().get_map(&"riverlands"))
	return {"sim": sim, "stable": stable, "stock": stock, "vale": vale}


func _bread_lines(below: int = 50) -> Array[Dictionary]:
	var lines: Array[Dictionary] = [TradeRoute.line(&"bread", 6, below)]
	return lines


## Goods of the whole kingdom: every province of the player plus what is under way.
func _kingdom(sim: Simulation, good: StringName) -> int:
	var sum := int(TradeRoutes.goods_under_way(sim).get(good, 0))
	for id: int in sim.runtime_ids():
		if sim.world.owner_of(id) == ProvinceDef.OWNER_PLAYER:
			sum += int(KingdomGoods.of(sim.province_state(id)).get(good, 0))
	return sum


func test_wagon_route_loads_visibly_and_delivers_by_threshold() -> void:
	var scene := _land_world()
	var sim: Simulation = scene["sim"]
	var stable: BuildingState = scene["stable"]
	var vale: int = scene["vale"]
	var home := WorldSim.FIRST_ID
	var b := sim.province_state(vale)
	var bread_b := b.stored(&"bread")
	var total := _kingdom(sim, &"bread")
	var eaten_from := 0
	# No route to an island by land, none without a free wagon, none with a live animal.
	assert_str(String(CreateTradeRouteCommand.route_error(sim, home, sim.world.id_of(&"gull_isle"), false))).is_equal("not_your_province")
	var pigs: Array[Dictionary] = [TradeRoute.line(&"pig", 2, 5)]
	assert_str(String(sim.execute(CreateTradeRouteCommand.new(home, vale, false, stable.id, pigs)))).is_equal("no_goods")
	assert_array(CreateTradeRouteCommand.free_vehicles(sim, home, false)).is_equal([stable.id])
	assert_str(String(sim.execute(CreateTradeRouteCommand.new(home, vale, false, stable.id,
			_bread_lines(bread_b + 10))))).is_empty()
	assert_int(stable.lent).is_equal(1)
	var route: TradeRoute = sim.world.routes.values()[0]
	# The wagon stands in front of the trading post, porters fill it, the carter drives off.
	sim.run_ticks(SimFixture.ticks(2))
	assert_int(route.state).is_equal(TradeRoute.State.LOADING)
	var wagon := sim.province.route_wagons.get(route.id) as RouteWagon
	assert_object(wagon).is_not_null()
	assert_object(sim.province.agents.get_agent(wagon.agent_id)).is_not_null()
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return route.state == TradeRoute.State.TRAVELLING, 300)).is_true()
	assert_int(int(route.cargo.get(&"bread", 0))).is_equal(6)
	assert_bool(sim.province.route_wagons.has(route.id)).is_false()
	assert_int(_kingdom(sim, &"bread")).is_equal(total)
	assert_array(Array(sim.province.dangling_holds())).is_empty()
	# About three minutes on the way; Willow Vale (not viewed) gets the bread at once.
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.clock.tick + SimClock.TICKS_PER_SECOND >= route.arrive_at, 300)).is_true()
	eaten_from = b.stored(&"bread")
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return route.state == TradeRoute.State.RETURNING, 30)).is_true()
	# The vale's houses eat its bread meanwhile: compared with just before it came.
	assert_int(b.stored(&"bread")).is_greater_equal(eaten_from + 6 - 1)
	assert_int(route.runs).is_equal(1)
	assert_int(route.delivered).is_equal(6)
	# Back home it runs again while the vale is still short of bread.
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return route.state == TradeRoute.State.LOADING, 400)).is_true()
	# Above the threshold it waits: the wagon stays at the trading post.
	assert_str(String(sim.execute(SetTradeRouteCommand.new(route.id, _bread_lines(0))))).is_empty()
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return route.state == TradeRoute.State.WAITING, 900)).is_true()
	sim.run_ticks(SimFixture.ticks(30))
	assert_int(route.state).is_equal(TradeRoute.State.WAITING)
	assert_int(route.runs).is_equal(2)
	# Removed: the wagon goes back to its trading post.
	assert_str(String(sim.execute(RemoveTradeRouteCommand.new(route.id)))).is_empty()
	assert_bool(sim.world.routes.is_empty()).is_true()
	assert_int(stable.lent).is_equal(0)


## B viewed: the route's wagon drives in, porters unload it into the storages, it drives off.
func test_wagon_is_unloaded_by_porters_in_the_viewed_province() -> void:
	var scene := _land_world()
	var sim: Simulation = scene["sim"]
	var stable: BuildingState = scene["stable"]
	var vale: int = scene["vale"]
	var lines: Array[Dictionary] = [TradeRoute.line(&"planks", 6, 1000)]
	assert_str(String(sim.execute(CreateTradeRouteCommand.new(WorldSim.FIRST_ID, vale, false,
			stable.id, lines)))).is_empty()
	var route: TradeRoute = sim.world.routes.values()[0]
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return route.state == TradeRoute.State.TRAVELLING, 300)).is_true()
	assert_str(String(sim.execute(EnterProvinceCommand.new(vale)))).is_empty()
	var b := sim.province
	var planks := b.kingdom_stock(&"planks")
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return route.state == TradeRoute.State.UNLOADING, 300)).is_true()
	var wagon := b.route_wagons.get(route.id) as RouteWagon
	assert_object(wagon).is_not_null()
	assert_int(wagon.store.total(&"planks")).is_equal(6)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return route.state == TradeRoute.State.RETURNING, 300)).is_true()
	assert_int(b.kingdom_stock(&"planks")).is_greater_equal(planks + 6 - 1)
	assert_bool(b.route_wagons.has(route.id)).is_false()
	assert_array(Array(b.dangling_holds())).is_empty()
	# The save mid-way home plays on alike.
	var state := sim.to_dict()
	var loaded := Simulation.from_dict(JSON.parse_string(JSON.stringify(state, "", false, true)), _registry())
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(state))


## Leaving the province while porters load the wagon: what is missing comes at once, nothing
## is lost; a save taken while it loads plays on alike.
func test_wagon_loading_finishes_when_the_player_leaves() -> void:
	var scene := _land_world()
	var sim: Simulation = scene["sim"]
	var stable: BuildingState = scene["stable"]
	var vale: int = scene["vale"]
	var total := _kingdom(sim, &"bread")
	assert_str(String(sim.execute(CreateTradeRouteCommand.new(WorldSim.FIRST_ID, vale, false,
			stable.id, _bread_lines(1000))))).is_empty()
	var route: TradeRoute = sim.world.routes.values()[0]
	sim.run_ticks(SimFixture.ticks(6))
	assert_int(route.state).is_equal(TradeRoute.State.LOADING)
	var state := sim.to_dict()
	var loaded := Simulation.from_dict(JSON.parse_string(JSON.stringify(state, "", false, true)), _registry())
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(state))
	assert_str(String(sim.execute(EnterProvinceCommand.new(vale)))).is_empty()
	sim.run_ticks(SimFixture.ticks(2))
	assert_int(route.state).is_equal(TradeRoute.State.TRAVELLING)
	assert_int(int(route.cargo.get(&"bread", 0))).is_equal(6)
	assert_int(_kingdom(sim, &"bread")).is_equal(total)


## 48x48 coast town as Landing Bay with a port and the player's cog at anchor (as in
## test_m6_expedition); Amber Coast settled on the Coast map and left alone.
func _sea_world() -> Dictionary:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	sim.world = WorldSim.from_def(_registry().get_world(&"kingdom"), _registry())
	sim.world.get_province(WorldSim.FIRST_ID).owner = ProvinceDef.OWNER_PLAYER
	SimFixture.coast(sim, 30, 33)
	var village := SimFixture.village(sim, 40, 20)
	(village["stock"] as BuildingState).stock.add(&"planks", 60)
	(village["stock"] as BuildingState).stock.add(&"cloth", 40)
	var port := SimFixture.place(sim, &"port", Vector2i(20, 28))
	var shipyard := SimFixture.place(sim, &"shipyard", Vector2i(30, 28))
	for kind: StringName in [Harbour.DOCKER_KIND, Harbour.DOCKER_KIND]:
		var docker := SimFixture.spawn(sim, kind, port.entrance_tile())
		assert_str(String(sim.execute(AssignWorkerCommand.new(docker.id, port.id)))).is_empty()
	for i: int in 6:
		SimFixture.spawn(sim, JobBoard.PORTER_KIND, Vector2i(16, 20))
	sim.province.sea_merchant.next_visit = 1 << 30
	var cog := Ships.launch(sim.province, sim.data.get_ship(&"cog"), shipyard)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return cog.home_id != 0 and cog.tile() == cog.voyage.anchor \
				and cog.path_state != ShipUnit.PathState.MOVING, 120)).is_true()
	var coast := sim.world.id_of(&"amber_coast")
	sim.open_province(coast, _registry().get_map(&"coast"))
	return {"sim": sim, "cog": cog, "port": port, "coast": coast}


func test_cog_route_loads_at_the_quay_and_sails_to_the_other_coast() -> void:
	var scene := _sea_world()
	var sim: Simulation = scene["sim"]
	var cog: ShipUnit = scene["cog"]
	var coast: int = scene["coast"]
	var b := sim.province_state(coast)
	var cloth_b := b.kingdom_stock(&"cloth")
	var total := _kingdom(sim, &"cloth")
	assert_array(CreateTradeRouteCommand.free_vehicles(sim, WorldSim.FIRST_ID, true)).is_equal([cog.id])
	var lines: Array[Dictionary] = [TradeRoute.line(&"cloth", 20, cloth_b + 15),
			TradeRoute.line(&"bread", 10, 0)]
	assert_str(String(sim.execute(CreateTradeRouteCommand.new(WorldSim.FIRST_ID, coast, true,
			cog.id, lines)))).is_empty()
	var route: TradeRoute = sim.world.routes.values()[0]
	assert_int(cog.voyage.route).is_equal(route.id)
	# The player cannot send it on a voyage of his own meanwhile.
	assert_str(String(sim.execute(StartVoyageCommand.new(cog.id)))).is_equal("ship_busy")
	# It moors, the dockers load the cloth (not the bread: the coast has more than 0).
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return cog.voyage.state == Voyage.State.LOADING, 200)).is_true()
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return route.state == TradeRoute.State.TRAVELLING, 600)).is_true()
	assert_dict(route.cargo).is_equal({&"cloth": 20})
	assert_bool(cog.is_away()).is_true()
	assert_int(_kingdom(sim, &"cloth")).is_equal(total)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return route.state == TradeRoute.State.RETURNING, 600)).is_true()
	assert_int(b.kingdom_stock(&"cloth")).is_equal(cloth_b + 20)
	# Back over the horizon it sails home to its anchorage.
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return route.state == TradeRoute.State.WAITING, 600)).is_true()
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return cog.voyage.state == Voyage.State.IDLE, 600)).is_true()
	assert_int(_kingdom(sim, &"cloth")).is_equal(total)
	# Removed: the cog is free for voyages again.
	assert_str(String(sim.execute(RemoveTradeRouteCommand.new(route.id)))).is_empty()
	assert_int(cog.voyage.route).is_equal(0)


## The port's voyage "to my province": the plan goes to Amber Coast, the cog comes home and
## the one-off route is gone; nothing sold, no gold.
func test_voyage_to_my_province() -> void:
	var scene := _sea_world()
	var sim: Simulation = scene["sim"]
	var cog: ShipUnit = scene["cog"]
	var coast: int = scene["coast"]
	var b := sim.province_state(coast)
	var cloth_b := b.kingdom_stock(&"cloth")
	var gold := sim.treasury.gold
	assert_str(String(sim.execute(StartVoyageCommand.new(cog.id, false, coast)))).is_equal("no_goods")
	cog.voyage.sell = {&"cloth": 10}
	assert_str(String(sim.execute(StartVoyageCommand.new(cog.id, false, sim.world.id_of(&"willow_vale"))))).is_equal("not_your_province")
	assert_str(String(sim.execute(StartVoyageCommand.new(cog.id, false, coast)))).is_empty()
	assert_int(sim.world.routes.size()).is_equal(1)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.world.routes.is_empty(), 1500)).is_true()
	assert_int(b.kingdom_stock(&"cloth")).is_equal(cloth_b + 10)
	assert_int(sim.treasury.gold).is_less(gold + 10)   # taxes only, nothing sold
	assert_int(cog.voyage.route).is_equal(0)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return cog.voyage.state == Voyage.State.IDLE, 600)).is_true()


## A route in a province nobody looks at: the cog loads at once and sails by the clock.
func test_cog_route_from_a_province_nobody_looks_at() -> void:
	var scene := _sea_world()
	var sim: Simulation = scene["sim"]
	var cog: ShipUnit = scene["cog"]
	var coast: int = scene["coast"]
	var lines: Array[Dictionary] = [TradeRoute.line(&"cloth", 10, 10000)]
	assert_str(String(sim.execute(CreateTradeRouteCommand.new(WorldSim.FIRST_ID, coast, true,
			cog.id, lines)))).is_empty()
	assert_str(String(sim.execute(EnterProvinceCommand.new(coast)))).is_empty()
	var route: TradeRoute = sim.world.routes.values()[0]
	var cloth := sim.province.kingdom_stock(&"cloth")
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return route.state == TradeRoute.State.TRAVELLING, 60)).is_true()
	# Coast is viewed: the cargo is put down in front of its town hall (no port) for porters.
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return route.state == TradeRoute.State.RETURNING, 600)).is_true()
	assert_int(sim.province.kingdom_stock(&"cloth")).is_equal(cloth + 10)
	var state := sim.to_dict()
	var loaded := Simulation.from_dict(JSON.parse_string(JSON.stringify(state, "", false, true)), _registry())
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(state))
