extends GdUnitTestSuite
## M4b-2 DoD: the meat chain runs on its own and every unit comes from its visible steps
## (event counters): pigs breed in the pigsty, the butcher leads one to the slaughterhouse and
## makes meat and hides, and the last 2 pigs always stay.


## Runs [param seconds] and counts produced goods and born animals by id.
func _run_counting(sim: Simulation, seconds: float) -> Dictionary:
	var counts := {}
	for i: int in SimFixture.ticks(seconds):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"good_produced":
				var key := "produced:%s" % e["good"]
				counts[key] = int(counts.get(key, 0)) + int(e["amount"])
			elif e["type"] == &"animal_born":
				counts["born"] = int(counts.get("born", 0)) + 1
	return counts


## A village with an extra hut (workers for the pigsty and the slaughterhouse) and a well.
func _village(sim: Simulation) -> BuildingState:
	var village := SimFixture.village(sim, 30, 20)
	SimFixture.place(sim, &"well", Vector2i(9, 9))
	SimFixture.house(sim, Vector2i(2, 12))
	SimFixture.house(sim, Vector2i(5, 12))
	return village["stock"]


func test_pigs_breed_faster_in_a_bigger_herd_up_to_the_pigsty_size() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village(sim)
	var sty := SimFixture.place(sim, &"pigsty", Vector2i(16, 4))
	sty.yard.add(&"pig", 2)
	var counts := _run_counting(sim, 150)
	# One young pig after about 2 minutes with 2 pigs (and a walk to work first).
	print("pigsty in 2.5 min: ", counts)
	assert_int(int(counts.get("born", 0))).is_between(1, 2)
	counts = _run_counting(sim, 600)
	assert_int(sty.yard.total(&"pig")).is_equal(sty.def.herd_capacity)
	assert_int(sim.province.goods_total(&"pig")).is_equal(sty.def.herd_capacity)


func test_one_pig_does_not_breed() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village(sim)
	var sty := SimFixture.place(sim, &"pigsty", Vector2i(16, 4))
	sty.yard.add(&"pig", 1)
	var counts := _run_counting(sim, 300)
	assert_int(int(counts.get("born", 0))).is_equal(0)


func test_butcher_leads_a_pig_and_makes_meat_and_hides() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var stock := _village(sim)
	var sty := SimFixture.place(sim, &"pigsty", Vector2i(16, 4))
	sty.yard.add(&"pig", 8)
	SimFixture.place(sim, &"slaughterhouse", Vector2i(16, 10))
	# Village pantries start full, some meat included.
	var meat_before := sim.province.goods_total(&"meat")
	var led := false
	var counts := {}
	for i: int in SimFixture.ticks(240):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"good_produced":
				var key := "produced:%s" % e["good"]
				counts[key] = int(counts.get(key, 0)) + int(e["amount"])
		for agent: Agent in sim.province.agents.all():
			if agent.kind == &"butcher" and agent.carry_good == &"pig" and agent.activity == &"walk":
				led = true
	print("butcher in 4 min: ", counts)
	var meat := int(counts.get("produced:meat", 0))
	var hides := int(counts.get("produced:hides", 0))
	assert_bool(led).is_true()
	assert_int(meat).is_greater_equal(4)
	assert_int(meat % 2).is_equal(0)
	assert_int(hides).is_between(meat / 2 - 1, meat / 2)
	assert_int(sim.province.goods_total(&"meat")).is_equal(meat_before + meat)
	assert_int(sim.province.goods_total(&"hides")).is_equal(hides)
	assert_int(stock.stock.total(&"meat")).is_greater(0)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_the_last_two_pigs_stay() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village(sim)
	var sty := SimFixture.place(sim, &"pigsty", Vector2i(16, 4))
	sty.yard.add(&"pig", 3)
	SimFixture.place(sim, &"slaughterhouse", Vector2i(16, 10))
	# Paused: no young pigs, so only the butcher changes the herd.
	sty.paused = true
	var counts := _run_counting(sim, 300)
	assert_int(int(counts.get("produced:meat", 0))).is_equal(2)
	assert_int(sty.yard.total(&"pig")).is_equal(2)
	assert_int(sim.province.goods_total(&"pig")).is_equal(2)


func test_burghers_eat_meat_instead_of_fish() -> void:
	var need := SimFixture.registry().get_def(&"need", &"fish_or_meat") as NeedDef
	assert_array(need.goods).contains([&"meat"])
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var hut := SimFixture.house(sim, Vector2i(10, 10), 4, false)
	assert_bool(hut.house_goods().has(&"meat")).is_true()


# --- Travelling merchant -------------------------------------------------------------------

## Runs until the merchant reaches [param state] (at most [param seconds]).
func _until_merchant(sim: Simulation, state: Merchant.State, seconds: float) -> bool:
	return SimFixture.run_until(sim, func() -> bool: return sim.province.merchant.state == state, seconds)


func test_merchant_comes_only_when_there_is_a_market() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village(sim)
	sim.province.entry_tile = Vector2i(39, 20)
	sim.province.merchant.next_visit = 10
	assert_bool(_until_merchant(sim, Merchant.State.COMING, 30)).is_false()
	SimFixture.place(sim, &"market", Vector2i(20, 20))
	sim.province.merchant.next_visit = sim.province.tick + 10
	assert_bool(_until_merchant(sim, Merchant.State.TRADING, 120)).is_true()
	var merchant := sim.province.agents.get_agent(sim.province.merchant.agent_id)
	assert_str(String(merchant.kind)).is_equal("merchant")
	# He trades about 3 minutes, then walks off the map.
	assert_bool(_until_merchant(sim, Merchant.State.AWAY, Merchant.STAY + 120)).is_true()
	assert_object(sim.province.agents.get_agent(merchant.id)).is_null()
	assert_int(sim.province.merchant.next_visit).is_greater(sim.province.tick)


func test_merchant_buys_only_above_the_players_setting() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var stock := _village(sim)
	stock.stock.add(&"planks", 30)
	sim.province.entry_tile = Vector2i(39, 20)
	SimFixture.place(sim, &"market", Vector2i(20, 20))
	assert_str(String(sim.execute(SetSellAboveCommand.new(&"planks", 18)))).is_equal("")
	assert_str(String(sim.execute(SetSellAboveCommand.new(&"pig", 0)))).is_equal("not_for_sale")
	sim.province.merchant.next_visit = sim.province.tick + 10
	var sold := {}
	var gold := 0
	for i: int in SimFixture.ticks(Merchant.STAY + 200):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"goods_sold":
				sold[e["good"]] = int(sold.get(e["good"], 0)) + int(e["amount"])
				gold += int(e["gold"])
	print("merchant bought: ", sold, " for ", gold)
	assert_dict(sold).is_equal({&"planks": 12})
	assert_int(gold).is_equal(12 * SimFixture.registry().get_good(&"planks").base_price)
	assert_int(stock.stock.total(&"planks")).is_equal(18)
	assert_int(sim.province.merchant.state).is_equal(Merchant.State.AWAY)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_pigs_bought_from_the_merchant_are_led_to_the_pigsty() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village(sim)
	sim.province.entry_tile = Vector2i(39, 20)
	SimFixture.place(sim, &"market", Vector2i(20, 20))
	var sty := SimFixture.place(sim, &"pigsty", Vector2i(16, 4))
	sim.province.treasury.gold = 200
	assert_str(String(sim.execute(BuyPigCommand.new()))).is_equal("merchant_away")
	sim.province.merchant.next_visit = sim.province.tick + 10
	assert_bool(_until_merchant(sim, Merchant.State.TRADING, 120)).is_true()
	var gold := sim.province.treasury.gold
	assert_str(String(sim.execute(BuyPigCommand.new()))).is_equal("")
	assert_str(String(sim.execute(BuyPigCommand.new()))).is_equal("")
	assert_int(sim.province.treasury.gold).is_less_equal(gold - 2 * Merchant.PIG_PRICE + 1)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sty.yard.total(&"pig") >= 2, 120)).is_true()
	assert_int(sim.province.goods_total(&"pig")).is_greater_equal(2)
	sim.province.treasury.gold = 0
	assert_str(String(sim.execute(BuyPigCommand.new()))).is_equal("not_enough_gold")


# --- Market stalls -------------------------------------------------------------------------

func test_market_serves_only_with_goods_on_its_stalls() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	SimFixture.village(sim, 30, 0)
	var market := SimFixture.place(sim, &"market", Vector2i(20, 20))
	assert_object(market.supply).is_not_null()
	sim.run_ticks(SimFixture.ticks(2))
	assert_bool(market.provides_service(sim.province.tick)).is_false()
	market.supply.add(&"bread", 2)
	sim.run_ticks(SimFixture.ticks(2))
	assert_bool(market.provides_service(sim.province.tick)).is_true()


func test_stallholders_stock_the_stalls_and_householders_buy_there() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var stock := _village(sim)
	stock.stock.add(&"fish", 10)
	var market := SimFixture.place(sim, &"market", Vector2i(10, 16))
	sim.run_ticks(SimFixture.ticks(150))
	assert_int(market.supply.total(&"fish")).is_between(1, BuildingState.STALL_UNITS)
	# Hungry houses: their householders now buy at the stocked market.
	for b: BuildingState in sim.province.buildings.all():
		if b.house != null:
			for good: StringName in b.house_goods():
				b.supply.remove(good, 99)
	var bought := 0
	for i: int in SimFixture.ticks(120):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"good_taken" and e["storage"] == market.id:
				var agent := sim.province.agents.get_agent(int(e["agent"]))
				if agent != null and agent.kind == Population.HOUSEHOLDER_KIND:
					bought += int(e["amount"])
	print("market stalls after 5 min: ", market.supply.totals(), ", householders bought ", bought)
	assert_int(market.supply.total_amount()).is_greater(0)
	assert_int(bought).is_greater(0)
	assert_array(Array(sim.province.dangling_holds())).is_empty()
