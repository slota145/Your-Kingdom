extends GdUnitTestSuite
## M8 part 4: the AI rulers at war (owner's survey 2026-11-10). They recruit for gold, weigh
## their targets and march only on what they are likely to take, storm the player's viewed town
## live and take any other town at once; the player takes their towns like a settlement; a
## ruler without provinces is out; on the peaceful level they leave the player alone.


## The hand-made kingdom with a ruler's town next to the iron settlement (as in part 3).
func _kingdom() -> Dictionary:
	var data := SimFixture.registry()
	var sim := Simulation.from_world(data, data.get_world(&"kingdom"), 1)
	var wold := sim.world.id_of(&"iron_wold")
	var near := 0
	for id: int in sim.world.ids():
		if id != wold and not sim.runtimes.has(id) and sim.world.are_neighbours(id, wold, data) \
				and sim.world.owner_of(id) == ProvinceDef.OWNER_NONE:
			near = id
			break
	assert_int(near).is_not_equal(0)
	var owner := &"ruler_1"
	sim.open_province(near, data.get_map(sim.world.get_province(near).map_id), owner)
	RulerPlanner.ensure_rulers(sim)
	sim.bind_treasuries()
	var ruler := sim.world.rulers[owner]
	ruler.next_expedition = 1 << 40
	ruler.next_trade = 1 << 40
	var town := sim.province_state(near)
	_build(town, &"town_hall")
	var barracks := _build(town, &"barracks")
	return {"sim": sim, "owner": owner, "ruler": ruler, "id": near, "town": town, "barracks": barracks, "wold": wold}


func _build(town: ProvinceSim, id: StringName) -> BuildingState:
	for b: BuildingState in town.buildings.all():
		if b.def.id == id:
			return b
	var def := SimFixture.registry().get_building(id)
	var b := NeutralTown.place(town, def, RulerPlanner.centre(town))
	var size := town.grid.size
	for y: int in range(8, size.y - 8, 12):
		for x: int in range(8, size.x - 8, 12):
			if b == null and town.nav.is_walkable(Vector2i(x, y)):
				b = NeutralTown.place(town, def, Vector2i(x, y))
	assert_object(b).override_failure_message("no room for %s" % id).is_not_null()
	return b


func _army(sim: Simulation, owner: StringName, at: int, units: Dictionary[StringName, int]) -> Army:
	var army := Army.new()
	army.id = sim.ids.take()
	army.owner = owner
	army.at = at
	army.home = at
	army.state = Army.State.IDLE
	army.pos = ArmyOrders.stand_point(sim, at)
	army.units = units
	army.food = army.food_cap()
	sim.world.armies[army.id] = army
	return army


func _events(sim: Simulation, seconds: int, type: StringName) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for k: int in seconds:
		sim.run_ticks(SimClock.TICKS_PER_SECOND)
		for e: Dictionary in sim.events.drain():
			if e["type"] == type:
				found.append(e)
		if not found.is_empty():
			break
	return found


func test_a_ruler_recruits_soldiers_for_gold_and_residents() -> void:
	var k := _kingdom()
	var sim: Simulation = k["sim"]
	var ruler: RulerState = k["ruler"]
	var town: ProvinceSim = k["town"]
	ruler.treasury.gold = 3000
	var people := RulerPlanner.residents(town)
	var units: Array[StringName] = []
	for i: int in 6:
		var gold := ruler.treasury.gold
		var unit := RulerWar.recruit(sim, ruler, k["id"])
		if unit == &"":
			break
		units.append(unit)
		assert_int(ruler.treasury.gold).is_equal(gold - sim.data.get_unit(unit).gold_cost * RulerWar.COST_FACTOR)
	assert_int(units.size()).is_greater_equal(3)
	assert_int((k["barracks"] as BuildingState).garrison.size()).is_equal(units.size())
	assert_int(RulerPlanner.residents(town)).is_equal(people - units.size())
	assert_int(RulerWar.strength(sim, k["owner"])).is_equal(units.size())
	# A poor ruler keeps his reserve.
	ruler.treasury.gold = RulerWar.RESERVE_GOLD
	assert_str(String(RulerWar.recruit(sim, ruler, k["id"]))).is_empty()


## He marches only when he is likely to win, takes a settlement at once and moves into it.
func test_a_ruler_weighs_his_odds_and_takes_a_settlement() -> void:
	var k := _kingdom()
	var sim: Simulation = k["sim"]
	var ruler: RulerState = k["ruler"]
	var barracks: BuildingState = k["barracks"]
	sim.province.grace_until = 1 << 40   # (the player is not a target here)
	for i: int in 6:
		barracks.garrison.append(&"spearman")
	assert_object(RulerWar.attack(sim, ruler)).is_null()   # too few
	barracks.garrison.clear()
	for i: int in 24:
		barracks.garrison.append(&"knight")
	var army := RulerWar.attack(sim, ruler)
	assert_object(army).is_not_null()
	assert_int(ruler.campaign).is_equal(army.id)
	assert_int(army.state).is_equal(Army.State.MOVING)
	var target := ruler.war_target
	assert_str(String(sim.world.owner_of(target))).is_equal(String(ProvinceDef.OWNER_NEUTRAL))
	# Some stay home.
	assert_int(barracks.garrison.size()).is_greater_equal(roundi(24 * RulerWar.KEEP_HOME[GameSettings.NORMAL]) - 1)
	var taken := _events(sim, 900, &"province_taken")
	assert_int(taken.size()).is_equal(1)
	assert_int(int(taken[0]["province"])).is_equal(target)
	assert_str(String(sim.world.owner_of(target))).is_equal(String(k["owner"]))
	assert_bool(sim.world.settlements.has(target)).is_false()
	assert_object(sim.province_state(target).treasury).is_same(ruler.treasury)
	assert_int(sim.province_state(target).home_faction).is_equal(CombatState.TOWN)
	sim.run_ticks(SimFixture.ticks(RulerWar.EVERY + 1))
	assert_int(ruler.campaign).is_equal(0)


## Unseen, the player's town falls to the ruler by BattleResolver: its soldiers lay down their
## arms, the town is his.
func test_a_ruler_takes_an_unseen_province_of_the_player() -> void:
	var k := _kingdom()
	var sim: Simulation = k["sim"]
	var mine := sim.viewed_id
	var town := sim.province
	sim.treasury.gold = 5000
	_build(town, &"pioneer_camp")
	_build(town, &"town_hall")
	var barracks := _build(town, &"barracks")
	sim.view_province(k["id"])   # (the player looks elsewhere)
	assert_bool(sim.is_detailed(mine)).is_false()
	barracks.garrison.append(&"spearman")
	var army := _army(sim, k["owner"], mine, {&"knight": 20})
	RulerWar.assault(sim, army)
	assert_str(String(sim.world.owner_of(mine))).is_equal(String(k["owner"]))
	assert_bool(barracks.garrison.has(&"spearman")).is_false()
	assert_object(town.treasury).is_same((k["ruler"] as RulerState).treasury)
	var lost := sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == &"province_taken")
	assert_str(String(lost[0]["from"])).is_equal(String(ProvinceDef.OWNER_PLAYER))
	# The army moved into the town's barracks.
	assert_int(barracks.garrison.size()).is_greater(0)


## In the viewed town the ruler's men come in at the edge, break the hall's door and hold it:
## the town becomes his (and is only looked at from then on).
func test_a_ruler_storms_the_viewed_town_live() -> void:
	var k := _kingdom()
	var sim: Simulation = k["sim"]
	var home := sim.viewed_id
	sim.treasury.gold = 5000
	_build(sim.province, &"pioneer_camp")
	var hall := _build(sim.province, &"town_hall")
	assert_bool(sim.province.has_seat()).is_true()
	var army := _army(sim, k["owner"], home, {&"knight": 8, &"spearman": 8})
	RulerWar.assault(sim, army)
	assert_int(army.state).is_equal(Army.State.INSIDE)
	assert_bool(sim.province.raids.conquest).is_true()
	var attackers := sim.province.agents.all().filter(func(a: Agent) -> bool:
		return a.combat != null and a.combat.army == army.id)
	assert_int(attackers.size()).is_equal(16)
	assert_str(String((attackers[0] as Agent).kind)).is_not_equal("bandit")
	var taken := _events(sim, 600, &"province_taken")
	assert_int(taken.size()).override_failure_message("door hp %d" % hall.hp).is_equal(1)
	assert_str(String(sim.world.owner_of(home))).is_equal(String(k["owner"]))
	assert_int(sim.province.home_faction).is_equal(CombatState.TOWN)
	assert_bool(sim.province.raids.is_active()).is_false()
	assert_int(hall.hp).is_equal(hall.def.max_hp)


## The player's army at a ruler's town waits for his choice; the barracks soldiers defend it;
## taken, the ruler without provinces is out of the game.
func test_the_player_takes_a_ruler_town_and_the_ruler_is_out() -> void:
	var k := _kingdom()
	var sim: Simulation = k["sim"]
	var id: int = k["id"]
	var barracks: BuildingState = k["barracks"]
	for i: int in 4:
		barracks.garrison.append(&"spearman")
	var army := _army(sim, ProvinceDef.OWNER_PLAYER, id, {&"knight": 30})
	army.pos = ArmyOrders.town_point(sim, army, id)
	army.state = Army.State.MOVING
	army.target = id
	army.path.clear()
	Armies.arrive_on_land(sim, army)
	assert_int(army.state).is_equal(Army.State.WAITING)
	assert_str(String(Armies.siege_error(sim, army))).is_empty()
	assert_float(Armies.siege_chances(sim, army, id)).is_greater(0.5)
	var result := Armies.resolve_siege(sim, army)
	assert_bool(result.a_won()).is_true()
	assert_str(String(sim.world.owner_of(id))).is_equal(String(ProvinceDef.OWNER_PLAYER))
	assert_int(barracks.garrison.size()).is_equal(0)
	assert_int(sim.province_state(id).home_faction).is_equal(CombatState.PLAYER)
	var out := _events(sim, RulerWar.EVERY + 2, &"ruler_defeated")
	assert_int(out.size()).is_equal(1)
	assert_bool(Rulers.alive(sim.world).has(k["owner"])).is_false()


## Live: the ruler's barracks soldiers come out as the town's guards.
func test_a_ruler_town_is_defended_by_its_barracks_live() -> void:
	var k := _kingdom()
	var sim: Simulation = k["sim"]
	var id: int = k["id"]
	var barracks: BuildingState = k["barracks"]
	for i: int in 5:
		barracks.garrison.append(&"spearman")
	var home := sim.viewed_id
	var army := _army(sim, ProvinceDef.OWNER_PLAYER, id, {&"knight": 10})
	army.state = Army.State.WAITING
	Armies.enter_fight(sim, army)
	assert_int(sim.viewed_id).is_equal(id)
	var guards := sim.province.agents.all().filter(func(a: Agent) -> bool:
		return a.combat != null and a.combat.faction == CombatState.TOWN and a.combat.commanded)
	assert_int(guards.size()).is_equal(5)
	assert_int(barracks.soldiers.size() + barracks.garrison.size()).is_equal(0)
	# Called off and left, the guards go back into the barracks.
	sim.view_province(home)
	assert_int(sim.viewed_id).is_equal(home)
	assert_int(Barracks.strength(barracks)).is_equal(5)
	assert_int(army.men()).is_equal(10)


func test_peaceful_rulers_leave_the_player_alone() -> void:
	var s := GameSettings.new()
	s.world_seed = 5
	s.rulers = 2
	s.province_count = 18
	s.difficulty = GameSettings.PEACEFUL
	var sim := Simulation.from_settings(SimFixture.registry(), s, 1)
	assert_int(RulerPlanner.difficulty(sim)).is_equal(GameSettings.EASY)
	sim.province.grace_until = 0
	var owner: StringName = Rulers.alive(sim.world)[0]
	assert_bool(RulerWar.target_ok(sim, owner, sim.viewed_id)).is_false()
	var other: StringName = Rulers.alive(sim.world)[1]
	assert_bool(RulerWar.target_ok(sim, owner, Rulers.provinces_of(sim.world, other)[0])).is_true()
	# Their armies pass the player's by.
	var a := _army(sim, owner, Rulers.provinces_of(sim.world, owner)[0], {&"spearman": 5})
	var b := _army(sim, ProvinceDef.OWNER_PLAYER, sim.viewed_id, {&"spearman": 5})
	assert_bool(ArmyMeetings._at_peace(sim, a, b)).is_true()
	b.chase = a.id
	assert_bool(ArmyMeetings._at_peace(sim, a, b)).is_false()
	var copy := GameSettings.from_dict(s.to_dict())
	assert_int(copy.difficulty).is_equal(GameSettings.PEACEFUL)


## A campaign and a storming are saved; a v29 save gets each ruler's time of grace.
func test_war_survives_a_save_and_v29_migrates() -> void:
	var k := _kingdom()
	var sim: Simulation = k["sim"]
	var ruler: RulerState = k["ruler"]
	var barracks: BuildingState = k["barracks"]
	for i: int in 24:
		barracks.garrison.append(&"knight")
	sim.province.grace_until = 1 << 40
	var army := RulerWar.attack(sim, ruler)
	assert_object(army).is_not_null()
	sim.run_ticks(SimFixture.ticks(5))
	var state := sim.to_dict()
	var copy := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(state))
	assert_int(copy.world.rulers[k["owner"]].campaign).is_equal(army.id)
	var old := state.duplicate(true)
	for r: Variant in old["world"]["rulers"]:
		for key: String in ["next_war", "campaign", "war_target", "defeated"]:
			(r as Dictionary).erase(key)
	var migrated := SaveMigrations.migrate(old, 29)
	var loaded := Simulation.from_dict(migrated, SimFixture.registry())
	assert_int(loaded.world.rulers[k["owner"]].next_war).is_equal(
			loaded.clock.tick + RulerWar.first_ticks(GameSettings.NORMAL))
	loaded.run_ticks(SimFixture.ticks(30))
	assert_int(SaveMigrations.CURRENT_VERSION).is_equal(30)
