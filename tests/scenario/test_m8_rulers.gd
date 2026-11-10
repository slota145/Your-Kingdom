extends GdUnitTestSuite
## M8 part 3: the AI rulers build, settle and trade. Their towns live in the simplified mode,
## the planner opens construction sites from the plan of growth, each ruler pays from his own
## treasury, sends expeditions of settlers, buys neutral settlements and runs routes between
## his provinces (owner's survey 2026-11-10).


func _settings(seed_value: int, rulers: int = 2, count: int = 18, level: int = GameSettings.NORMAL) -> GameSettings:
	var s := GameSettings.new()
	s.world_seed = seed_value
	s.rulers = rulers
	s.province_count = count
	s.difficulty = level
	return s


func _game(level: int = GameSettings.NORMAL, rulers: int = 2) -> Simulation:
	var problems := PackedStringArray()
	var sim := Simulation.from_settings(SimFixture.registry(), _settings(5, rulers, 18, level), 1, problems)
	assert_array(Array(problems)).is_empty()
	return sim


func _home(sim: Simulation, owner: StringName) -> int:
	return Rulers.provinces_of(sim.world, owner)[0]


func test_rulers_get_treasuries_and_pay_from_them() -> void:
	var sim := _game()
	var owner: StringName = Rulers.alive(sim.world)[0]
	var ruler := sim.world.rulers[owner]
	assert_int(ruler.treasury.gold).is_equal(RulerPlanner.START_GOLD[GameSettings.NORMAL])
	var town := sim.province_state(_home(sim, owner))
	assert_object(town.treasury).is_same(ruler.treasury)
	assert_object(sim.province.treasury).is_same(sim.treasury)
	var player_gold := sim.treasury.gold
	var market := sim.data.get_building(&"market")
	town.stored(&"planks")
	var before := ruler.treasury.gold
	assert_object(RulerPlanner.place(town, market)).is_not_null()
	assert_int(ruler.treasury.gold).is_equal(before - market.gold_cost)
	assert_int(sim.treasury.gold).is_equal(player_gold)


func test_ruler_towns_grow_by_the_plan() -> void:
	var sim := _game()
	var counts: Dictionary[StringName, int] = {}
	for owner: StringName in Rulers.alive(sim.world):
		counts[owner] = sim.province_state(_home(sim, owner)).buildings.all().size()
	var built: Array[Dictionary] = []
	for second: int in 600:
		sim.run_ticks(SimClock.TICKS_PER_SECOND)
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"ruler_built":
				built.append(e)
	assert_int(built.size()).is_greater_equal(6)
	for owner: StringName in Rulers.alive(sim.world):
		var town := sim.province_state(_home(sim, owner))
		assert_int(town.buildings.all().size()).override_failure_message(
				"%s did not grow" % owner).is_greater(counts[owner] + 2)
		# Sites get finished in the simplified mode.
		var done := 0
		for building: BuildingState in town.buildings.all():
			if building.is_complete():
				done += 1
		assert_int(done).is_greater(counts[owner])


func test_hard_rulers_grow_faster_than_easy_ones() -> void:
	var grown: Array[int] = []
	for level: int in [GameSettings.EASY, GameSettings.HARD]:
		var sim := _game(level, 1)
		var owner: StringName = Rulers.alive(sim.world)[0]
		var before := sim.province_state(_home(sim, owner)).buildings.all().size()
		sim.run_ticks(SimFixture.ticks(480))
		grown.append(sim.province_state(_home(sim, owner)).buildings.all().size() - before)
	assert_int(grown[1]).is_greater(grown[0])


## A ruler with a full store and a town hall sends settlers to an empty province: they land
## at once (the simplified mode), with a pioneer camp and a storage, and the province is his.
func test_a_ruler_sends_settlers_and_takes_an_empty_province() -> void:
	var sim := _game()
	var owner: StringName = Rulers.alive(sim.world)[0]
	var home := _home(sim, owner)
	var town := sim.province_state(home)
	_stock(town, {&"wood": 120, &"bread": 40})
	sim.world.rulers[owner].next_expedition = sim.clock.tick
	var settled := 0
	for second: int in 400:
		sim.run_ticks(SimClock.TICKS_PER_SECOND)
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"province_settled" and e["owner"] == owner:
				settled = int(e["province"])
		if settled != 0:
			break
	assert_int(settled).is_not_equal(0)
	assert_str(String(sim.world.owner_of(settled))).is_equal(String(owner))
	var colony := sim.province_state(settled)
	assert_object(colony).is_not_null()
	assert_bool(sim.is_detailed(settled)).is_false()
	var kinds: Array[StringName] = []
	for b: BuildingState in colony.buildings.all():
		kinds.append(b.def.id)
	assert_array(kinds).contains([&"pioneer_camp", &"stockpile"])
	assert_object(colony.treasury).is_same(sim.world.rulers[owner].treasury)
	# It grows by the plan too.
	sim.run_ticks(SimFixture.ticks(300))
	assert_int(colony.buildings.all().size()).is_greater(kinds.size())


## Whoever comes first takes the province (owner's survey 2026-11-10): the player's expedition
## waiting at the border keeps it, the ruler's turns back and brings settlers and kit home;
## the other way round the ruler settles and the player's turns back.
func test_whoever_comes_first_takes_the_province() -> void:
	var sim := _game()
	var owner: StringName = Rulers.alive(sim.world)[0]
	var home := _home(sim, owner)
	var target := RulerExpansion.best_target(sim, owner, home, false)
	assert_int(target).is_not_equal(0)
	var player := _expedition(sim, ProvinceDef.OWNER_PLAYER, sim.viewed_id, target, 0)
	player.state = Expedition.State.WAITING
	var ruler := _expedition(sim, owner, home, target, 2)
	var wood := sim.province_state(home).stored(&"wood")
	sim.run_ticks(SimFixture.ticks(4))
	assert_bool(ruler.bounced).is_true()
	assert_int(ruler.state).is_equal(Expedition.State.RETURNING)
	assert_str(String(sim.world.owner_of(target))).is_equal(String(ProvinceDef.OWNER_NONE))
	sim.run_ticks(SimFixture.ticks(5))
	assert_bool(sim.world.expeditions.has(ruler.id)).is_false()
	assert_int(sim.province_state(home).stored(&"wood")).is_greater_equal(wood + 60)
	# The ruler first: he settles, the player's expedition on its way turns back.
	sim.world.expeditions.erase(player.id)
	var second := _expedition(sim, owner, home, target, 3)
	var late := _expedition(sim, ProvinceDef.OWNER_PLAYER, sim.viewed_id, target, 15)
	sim.run_ticks(SimFixture.ticks(6))
	assert_str(String(sim.world.owner_of(target))).is_equal(String(owner))
	assert_int(second.state).is_not_equal(Expedition.State.TRAVELLING)
	sim.run_ticks(SimFixture.ticks(15))
	assert_bool(late.bounced).is_true()
	assert_str(String(SendExpeditionCommand.error_for(sim, sim.viewed_id, target))).is_not_empty()


func _expedition(sim: Simulation, owner: StringName, from: int, to: int, seconds: int) -> Expedition:
	var e := Expedition.new()
	e.id = sim.ids.take()
	e.owner = owner
	e.from = from
	e.to = to
	e.settlers = Departure.SETTLERS.duplicate()
	e.kit = {&"wood": 90, &"bread": 20}
	e.depart_at = sim.clock.tick
	e.arrive_at = sim.clock.tick + SimFixture.ticks(seconds)
	sim.world.expeditions[e.id] = e
	return e


func _stock(town: ProvinceSim, goods: Dictionary) -> void:
	for good: StringName in goods:
		Departure.give_back(town, good, int(goods[good]), RulerPlanner.centre(town), true)


## A ruler next to a neutral settlement pays its gold and sends the goods by a one-off route
## with his merchant wagon; the settlement becomes his, and what the player gave is lost.
func test_a_ruler_buys_a_neutral_settlement_first() -> void:
	var data := SimFixture.registry()
	var sim := Simulation.from_world(data, data.get_world(&"kingdom"), 1)
	var wold := sim.world.id_of(&"iron_wold")
	var neighbour := 0
	for id: int in sim.world.ids():
		if id != wold and not sim.runtimes.has(id) and sim.world.are_neighbours(id, wold, data) \
				and sim.world.owner_of(id) == ProvinceDef.OWNER_NONE:
			neighbour = id
			break
	assert_int(neighbour).is_not_equal(0)
	var owner := &"ruler_1"
	sim.open_province(neighbour, data.get_map(sim.world.get_province(neighbour).map_id), owner)
	RulerPlanner.ensure_rulers(sim)
	sim.bind_treasuries()
	var ruler := sim.world.rulers[owner]
	ruler.treasury.gold = 1000
	ruler.next_expedition = 1 << 40
	var town := sim.province_state(neighbour)
	var post := NeutralTown.place(town, data.get_building(&"trading_post"), RulerPlanner.centre(town))
	assert_object(post).is_not_null()
	if town.storage_buildings().is_empty():
		NeutralTown.place(town, data.get_building(&"stockpile"), RulerPlanner.centre(town))
	_stock(town, {&"bread": 60, &"planks": 30, &"wood": 30})
	var s := sim.world.settlements[wold] as NeutralSettlement
	s.pay(100)   # the player gave something already
	var joined := &""
	for second: int in 900:
		sim.run_ticks(SimClock.TICKS_PER_SECOND)
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"settlement_joined":
				joined = e["owner"]
		if joined != &"":
			break
	assert_str(String(joined)).is_equal(String(owner))
	assert_str(String(sim.world.owner_of(wold))).is_equal(String(owner))
	assert_bool(sim.world.settlements.has(wold)).is_false()
	assert_object(sim.province_state(wold).treasury).is_same(ruler.treasury)
	assert_int(ruler.treasury.gold).is_less(1000)


## Rival bids are kept apart and saved.
func test_rival_bids_are_kept_apart_and_saved() -> void:
	var s := NeutralSettlement.new()
	s.gold = 300
	s.goods = {&"bread": 40}
	s.pay(300, &"ruler_2")
	assert_int(s.take(&"bread", 50, &"ruler_2")).is_equal(10)
	s.pay(100)
	assert_int(s.gold_missing()).is_equal(200)
	assert_int(s.missing(&"bread")).is_equal(40)
	assert_str(String(s.winner())).is_equal("ruler_2")
	var copy := NeutralSettlement.from_dict(s.to_dict())
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(s.to_dict()))
	assert_str(String(copy.winner())).is_equal("ruler_2")


## The rulers' treasuries, plans, expeditions and bids are saved; a v28 save gets them.
func test_rulers_survive_a_save_and_v28_migrates() -> void:
	var sim := _game()
	var owner: StringName = Rulers.alive(sim.world)[0]
	sim.world.rulers[owner].saving_for = _home(sim, owner)
	var e := _expedition(sim, owner, _home(sim, owner), RulerExpansion.best_target(sim, owner, _home(sim, owner), false), 100)
	e.bounced = false
	sim.run_ticks(SimFixture.ticks(90))
	var state := sim.to_dict()
	assert_int((state["world"]["rulers"] as Array).size()).is_equal(2)
	var copy := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(state))
	assert_object(copy.province_state(_home(copy, owner)).treasury).is_same(copy.world.rulers[owner].treasury)
	assert_str(String(copy.world.expeditions[e.id].owner)).is_equal(String(owner))
	# A save from before part 3: no rulers' states, expeditions without owners.
	var old := sim.to_dict().duplicate(true)
	(old["world"] as Dictionary).erase("rulers")
	for ed: Variant in old["world"].get("expeditions", []):
		(ed as Dictionary).erase("owner")
	var migrated := SaveMigrations.migrate(old, 28)
	var loaded := Simulation.from_dict(migrated, SimFixture.registry())
	assert_int(loaded.world.rulers.size()).is_equal(2)
	assert_int(loaded.world.rulers[owner].treasury.gold).is_equal(RulerPlanner.START_GOLD[GameSettings.NORMAL])
	assert_object(loaded.province_state(_home(loaded, owner)).treasury).is_same(loaded.world.rulers[owner].treasury)
	loaded.run_ticks(SimFixture.ticks(60))
	assert_int(SaveMigrations.CURRENT_VERSION).is_equal(29)
