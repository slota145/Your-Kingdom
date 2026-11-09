extends GdUnitTestSuite
## M8 part 2: armies and fleets on the world map (ROADMAP M8, "Część 2"; survey 2026-11-09).
## - ways over the land and the sea of the world map (WorldNav),
## - an army goes to any spot of the land and stands there, also in a foreign province,
## - warships go out as a fleet (all from the world map, one from the ship's panel), with the
##   soldiers aboard; a fleet sails anywhere on the sea, sets its soldiers ashore, goes back
##   into the port,
## - enemy armies that meet fight: the player chooses (at once or on the battlefield), others
##   fight at once; fleets fight a sea battle at once,
## - the battlefield: the map of the province without its town, the survivors come back,
## - armies, fleets and battles survive a save; a v27 save migrates.

static var _world: Simulation


func _sim() -> Simulation:
	if _world == null:
		var problems := PackedStringArray()
		_world = Simulation.from_world(SimFixture.registry(), SimFixture.registry().get_world(&"kingdom"), 1, problems)
		assert_array(Array(problems)).is_empty()
	var sim := Simulation.from_dict(_world.to_dict(), SimFixture.registry())
	sim.treasury.gold = 1000
	return sim


func _run(sim: Simulation, seconds: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i: int in SimFixture.ticks(seconds):
		sim.step()
		events.append_array(sim.events.drain())
	return events


func _until(sim: Simulation, seconds: float, done: Callable, events: Array[Dictionary] = []) -> bool:
	for k: int in int(seconds):
		events.append_array(_run(sim, 1))
		if done.call():
			return true
	return false


func _types(events: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	for event: Dictionary in events:
		result.append(event["type"])
	return result


func _units(d: Dictionary) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for unit: Variant in d:
		result[StringName(String(unit))] = int(d[unit])
	return result


## An army of [param owner] standing at [param pos].
func _army(sim: Simulation, pos: Vector2, units: Dictionary, owner: StringName = ProvinceDef.OWNER_PLAYER) -> Army:
	var army := Army.new()
	army.id = sim.ids.take()
	army.owner = owner
	army.home = sim.world.id_of(&"landing_bay")
	army.state = Army.State.IDLE
	army.units = _units(units)
	army.food = army.food_cap()
	army.pos = pos
	ArmyOrders.place(sim, army)
	sim.world.armies[army.id] = army
	return army


func _town(sim: Simulation, def_id: StringName) -> Vector2:
	return sim.world.def_of(sim.world.id_of(def_id), sim.data).world_pos


func _warship(sim: Simulation, id: StringName = &"warship") -> ShipUnit:
	var ship := ShipUnit.new(sim.ids.take(), sim.data.get_ship(id), Vector2.ZERO, sim.data)
	ship.pos = IsoMath.tile_center(Armies._sea_spot(sim.province, ship))
	ship.prev_pos = ship.pos
	sim.province.ships[ship.id] = ship
	return ship


func _aboard(sim: Simulation, ship: ShipUnit, unit: StringName, count: int) -> void:
	for k: int in count:
		var agent := sim.province.spawn_agent(unit, ship.tile())
		agent.combat = CombatState.new(sim.data.get_unit(unit).combat.hp)
		agent.vehicle = Ships.ABOARD
		agent.pos = ship.pos
		ship.troops.append(agent.id)


func test_ways_over_land_and_sea() -> void:
	var sim := _sim()
	var nav := ArmyOrders.nav(sim)
	var bay := _town(sim, &"landing_bay")
	var iron := _town(sim, &"iron_wold")
	assert_int(nav.province_at(bay)).is_equal(sim.world.id_of(&"landing_bay"))
	var land := nav.find_path(bay, iron, false)
	assert_bool(land.is_empty()).is_false()
	assert_vector(land[land.size() - 1]).is_equal(iron)
	# Every leg stays on the land.
	var from := bay
	for p: Vector2 in land:
		assert_bool(nav.line_open(from, p, false)).is_true()
		from = p
	# The isle cannot be walked to, but sailed round to.
	var isle := _town(sim, &"gull_isle")
	assert_bool(nav.find_path(bay, isle, false).is_empty()).is_true()
	var sea_a := ArmyOrders.offshore(sim, sim.world.id_of(&"landing_bay"))
	var sea_b := ArmyOrders.offshore(sim, sim.world.id_of(&"gull_isle"))
	assert_bool(nav.is_sea(sea_a)).is_true()
	assert_bool(nav.find_path(sea_a, sea_b, true).is_empty()).is_false()
	# A generated world too.
	var settings := GameSettings.new()
	settings.world_seed = 5
	var generated := Simulation.from_settings(sim.data, settings, 1)
	var gnav := ArmyOrders.nav(generated)
	var ids := generated.world.ids()
	var a := generated.world.def_of(ids[0], sim.data)
	var reached := 0
	for id: int in ids:
		var b := generated.world.def_of(id, sim.data)
		if not b.island and not a.island and not gnav.find_path(a.world_pos, b.world_pos, false).is_empty():
			reached += 1
	assert_int(reached).is_greater(ids.size() / 2)


func test_an_army_goes_to_a_spot_and_stands_there_also_in_a_foreign_province() -> void:
	var sim := _sim()
	var army := _army(sim, ArmyOrders.stand_point(sim, sim.world.id_of(&"landing_bay")), {"spearman": 8})
	# A spot in the field of the neutral Iron Wold, away from its town.
	var spot := _town(sim, &"iron_wold") + Vector2(0, 80)
	assert_int(ArmyOrders.nav(sim).province_at(spot)).is_equal(sim.world.id_of(&"iron_wold"))
	assert_str(String(sim.execute(SendArmyCommand.to_spot(army.id, spot)))).is_empty()
	assert_int(army.state).is_equal(Army.State.MOVING)
	var food := army.food
	var there := _until(sim, 1200, func() -> bool: return army.state == Army.State.IDLE)
	assert_bool(there).is_true()
	assert_float(army.pos.distance_to(spot)).is_less(1.0)
	assert_int(army.at).is_equal(sim.world.id_of(&"iron_wold"))
	assert_float(army.food).is_less(food)
	# Not into the sea; a town it is right-clicked on is its goal.
	assert_str(String(ArmyOrders.order_error(sim, army, 0, Vector2(10, 10)))).is_equal("army_not_at_sea")
	assert_str(String(sim.execute(SendArmyCommand.new(army.id, sim.world.id_of(&"iron_wold"))))).is_empty()
	var waits := _until(sim, 600, func() -> bool: return army.state == Army.State.WAITING)
	assert_bool(waits).is_true()
	assert_float(army.pos.distance_to(_town(sim, &"iron_wold"))).is_less(ArmyOrders.TOWN_BORDER + 25.0)


func test_warships_go_out_as_a_fleet_land_soldiers_and_come_back() -> void:
	var sim := _sim()
	var home := sim.world.id_of(&"landing_bay")
	var cog := _warship(sim)
	_aboard(sim, cog, &"spearman", 6)
	var other := _warship(sim)
	assert_str(String(sim.execute(FleetOutCommand.new(home)))).is_empty()
	assert_bool(sim.province.ships.has(cog.id) or sim.province.ships.has(other.id)).is_false()
	var fleet: Army = null
	for army: Army in sim.world.armies.values():
		fleet = army
	assert_bool(fleet.is_fleet()).is_true()
	assert_int(fleet.ships).is_equal(2)
	assert_int(fleet.units[&"spearman"]).is_equal(6)
	assert_bool(sim.province.agents.has_agent(cog.troops[0] if not cog.troops.is_empty() else 0)).is_false()
	assert_str(String(sim.execute(FleetOutCommand.new(home)))).is_equal("no_warships")
	# Out to sea and back; a fleet with soldiers sent to the land sets them ashore.
	var nav := ArmyOrders.nav(sim)
	var sea := nav.nearest(_town(sim, &"gull_isle") + Vector2(-60, 0), true)
	assert_str(String(sim.execute(SendArmyCommand.to_spot(fleet.id, sea)))).is_empty()
	assert_bool(_until(sim, 900, func() -> bool: return fleet.state == Army.State.IDLE)).is_true()
	assert_bool(fleet.by_sea).is_true()
	var isle := sim.world.id_of(&"gull_isle")
	var events: Array[Dictionary] = []
	assert_str(String(sim.execute(SendArmyCommand.to_spot(fleet.id, _town(sim, &"gull_isle") + Vector2(0, 20))))).is_empty()
	assert_bool(_until(sim, 900, func() -> bool: return not fleet.by_sea and fleet.state == Army.State.IDLE, events)).is_true()
	assert_array(_types(events)).contains([&"army_landed"])
	assert_int(fleet.at).is_equal(isle)
	assert_int(fleet.men()).is_equal(6)
	var ships: Army = null
	for army: Army in sim.world.armies.values():
		if army.is_fleet():
			ships = army
	assert_int(ships.ships).is_equal(2)
	# An empty fleet cannot land; sent to its home town it goes into the port.
	assert_str(String(ArmyOrders.order_error(sim, ships, isle, Vector2.INF))).is_equal("fleet_cannot_land")
	assert_str(String(sim.execute(SendArmyCommand.new(ships.id, home)))).is_empty()
	assert_bool(_until(sim, 1500, func() -> bool: return not sim.world.armies.has(ships.id))).is_true()
	assert_int(Fleets.free_warships(sim, home).size()).is_equal(2)


func test_one_warship_sails_out_from_its_panel() -> void:
	var sim := _sim()
	var cog := _warship(sim)
	_aboard(sim, cog, &"archer", 3)
	assert_str(String(sim.execute(SailOutCommand.new(cog.id)))).is_empty()
	var fleet: Army = sim.world.armies.values()[0]
	assert_int(fleet.state).is_equal(Army.State.INSIDE)
	assert_str(String(sim.execute(SailOutCommand.new(cog.id)))).is_equal("ship_busy")
	var out := _until(sim, 600, func() -> bool: return fleet.state == Army.State.IDLE)
	assert_bool(out).is_true()
	assert_bool(sim.province.ships.has(cog.id)).is_false()
	assert_int(fleet.ships).is_equal(1)
	assert_int(fleet.units[&"archer"]).is_equal(3)
	assert_bool(ArmyOrders.nav(sim).is_sea(fleet.pos)).is_true()


func test_meeting_bandits_the_player_chooses_and_the_battle_is_decided() -> void:
	var sim := _sim()
	var spot := _town(sim, &"willow_vale") + Vector2(0, 40)
	var mine := _army(sim, spot + Vector2(-60, 0), {"swordsman": 14, "archer": 6})
	var bandits := _army(sim, spot + Vector2(60, 0), {"spearman": 6, "archer": 2}, Army.BANDITS)
	assert_str(String(sim.execute(SendArmyCommand.to_spot(mine.id, spot + Vector2(80, 0))))).is_empty()
	var events: Array[Dictionary] = []
	var met := _until(sim, 300, func() -> bool: return mine.state == Army.State.ENGAGED, events)
	assert_bool(met).is_true()
	assert_array(_types(events)).contains([&"field_battle_pending"])
	assert_int(bandits.state).is_equal(Army.State.ENGAGED)
	var battle := FieldBattles.of(sim, mine)
	assert_float(FieldBattles.chances(sim, battle)).is_greater(0.5)
	# Standing still while the player chooses.
	var at := mine.pos
	_run(sim, 5)
	assert_vector(mine.pos).is_equal(at)
	assert_str(String(sim.execute(FieldBattleCommand.new(battle.id, FieldBattles.AUTO)))).is_empty()
	assert_bool(sim.world.armies.has(bandits.id)).is_false()
	assert_int(mine.state).is_not_equal(Army.State.ENGAGED)
	assert_int(sim.world.reports.size()).is_equal(1)
	assert_bool(sim.world.battles.is_empty()).is_true()


func test_a_battle_on_the_battlefield_and_back() -> void:
	var sim := _sim()
	var viewed := sim.viewed_id
	var spot := _town(sim, &"willow_vale") + Vector2(0, 40)
	var mine := _army(sim, spot, {"swordsman": 12, "archer": 4})
	var enemy := _army(sim, spot + Vector2(10, 0), {"spearman": 5}, &"ruler_1")
	_run(sim, 1)
	var battle := FieldBattles.of(sim, mine)
	assert_object(battle).is_not_null()
	assert_str(String(sim.execute(FieldBattleCommand.new(battle.id, FieldBattles.LIVE)))).is_empty()
	assert_int(sim.viewed_id).is_equal(Simulation.BATTLEFIELD)
	assert_int(sim.province.buildings.all().size()).is_equal(0)
	var mine_on := 0
	var theirs_on := 0
	for agent: Agent in sim.province.agents.all():
		if agent.combat != null and agent.combat.army == mine.id:
			mine_on += 1
		elif agent.combat != null and agent.combat.army == enemy.id:
			theirs_on += 1
			assert_int(agent.combat.faction).is_equal(CombatState.TOWN)
	assert_int(mine_on).is_equal(16)
	assert_int(theirs_on).is_equal(5)
	assert_str(String(sim.execute(EnterProvinceCommand.new(viewed)))).is_equal("army_in_battle")
	# A save in the middle of the battle comes back the same.
	_run(sim, 3)
	var saved := sim.to_dict()
	var loaded := Simulation.from_dict(saved, SimFixture.registry())
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(saved))
	var events: Array[Dictionary] = []
	var over := _until(sim, 400, func() -> bool: return sim.viewed_id != Simulation.BATTLEFIELD, events)
	assert_bool(over).is_true()
	assert_int(sim.viewed_id).is_equal(viewed)
	assert_array(_types(events)).contains([&"field_battle_over"])
	assert_bool(sim.world.armies.has(enemy.id)).is_false()
	assert_int(mine.men()).is_greater(0)
	assert_int(mine.men()).is_less_equal(16)
	assert_int(mine.state).is_equal(Army.State.IDLE)
	assert_bool(sim.world.reports[sim.world.reports.size() - 1].has("live")).is_true()


func test_the_player_retreats_from_the_battlefield() -> void:
	var sim := _sim()
	var spot := _town(sim, &"willow_vale") + Vector2(0, 40)
	var mine := _army(sim, spot, {"spearman": 4})
	_army(sim, spot + Vector2(10, 0), {"swordsman": 20}, &"ruler_1")
	_run(sim, 1)
	var battle := FieldBattles.of(sim, mine)
	sim.execute(FieldBattleCommand.new(battle.id, FieldBattles.LIVE))
	assert_str(String(sim.execute(FieldBattleCommand.new(battle.id, FieldBattleCommand.RETREAT)))).is_empty()
	var over := _until(sim, 400, func() -> bool: return sim.viewed_id != Simulation.BATTLEFIELD)
	assert_bool(over).is_true()
	if sim.world.armies.has(mine.id):
		# The men who got away go home.
		assert_int(mine.safe_until).is_greater(sim.clock.tick)


func test_rulers_and_bandits_fight_at_once_and_fleets_at_sea() -> void:
	var sim := _sim()
	var spot := _town(sim, &"willow_vale") + Vector2(0, 40)
	var ruler := _army(sim, spot, {"swordsman": 20}, &"ruler_1")
	var bandits := _army(sim, spot + Vector2(10, 0), {"spearman": 4}, Army.BANDITS)
	var events := _run(sim, 1)
	assert_array(_types(events)).contains([&"battle_resolved"])
	assert_bool(sim.world.armies.has(bandits.id)).is_false()
	assert_bool(sim.world.armies.has(ruler.id)).is_true()
	# The player's fleet meets a ruler's fleet at sea: a sea battle at once.
	var nav := ArmyOrders.nav(sim)
	var sea := ArmyOrders.offshore(sim, sim.world.id_of(&"landing_bay"))
	var mine := _army(sim, sea, {"spearman": 30})
	mine.by_sea = true
	mine.ships = 1
	mine.fleet = {&"galleon_war": 1}
	mine.at = 0
	var theirs := _army(sim, nav.nearest(sea + Vector2(-15, 0), true), {"spearman": 10}, &"ruler_1")
	theirs.by_sea = true
	theirs.ships = 2
	theirs.fleet = {&"warship": 2}
	theirs.at = 0
	events = _run(sim, 1)
	assert_array(_types(events)).contains([&"sea_battle"])
	var report: Dictionary = sim.world.reports[sim.world.reports.size() - 1]
	assert_int(int(report["kind"])).is_equal(BattleResolver.Kind.NAVAL)
	assert_bool(report.has("pos")).is_true()
	var men_after := (mine.men() if sim.world.armies.has(mine.id) else 0) \
			+ (theirs.men() if sim.world.armies.has(theirs.id) else 0)
	assert_int(men_after).is_less(40)
	# The beaten one does not fight again at once.
	var beaten := theirs if (report["result"] as Dictionary)["winner"] == 0 else mine
	if sim.world.armies.has(beaten.id):
		assert_int(beaten.safe_until).is_greater(sim.clock.tick)


func test_an_army_goes_after_an_enemy_army() -> void:
	var sim := _sim()
	var spot := _town(sim, &"willow_vale") + Vector2(0, 40)
	var mine := _army(sim, spot + Vector2(-120, 0), {"swordsman": 10})
	var bandits := _army(sim, spot + Vector2(60, 0), {"spearman": 3}, Army.BANDITS)
	assert_str(String(sim.execute(SendArmyCommand.after(mine.id, bandits.id)))).is_empty()
	assert_int(mine.chase).is_equal(bandits.id)
	var met := _until(sim, 400, func() -> bool: return mine.state == Army.State.ENGAGED)
	assert_bool(met).is_true()
	assert_str(String(ArmyOrders.chase_error(sim, mine, mine.id))).is_equal("army_in_battle")


func test_armies_fleets_and_battles_survive_a_save_and_v27_migrates() -> void:
	var sim := _sim()
	var spot := _town(sim, &"willow_vale") + Vector2(0, 40)
	var mine := _army(sim, spot, {"spearman": 5})
	_army(sim, spot + Vector2(10, 0), {"spearman": 5}, Army.BANDITS)
	var walker := _army(sim, ArmyOrders.stand_point(sim, sim.world.id_of(&"landing_bay")), {"archer": 3})
	sim.execute(SendArmyCommand.to_spot(walker.id, _town(sim, &"amber_coast") + Vector2(20, 30)))
	_warship(sim)
	sim.execute(FleetOutCommand.new(sim.world.id_of(&"landing_bay")))
	_run(sim, 2)
	assert_object(FieldBattles.of(sim, mine)).is_not_null()
	var saved := sim.to_dict()
	var loaded := Simulation.from_dict(saved, SimFixture.registry())
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(saved))
	# A v27 army on its way: a route of provinces; it finds its way on.
	var old := {"world": {"armies": [{"id": 5, "owner": "player", "state": Army.State.MOVING, "at": 1,
			"units": {"spearman": 3}, "next": 3, "route": [8], "depart": 0, "arrive": 100}]}}
	var migrated := SaveMigrations.migrate_v27_to_v28(old)
	var a: Dictionary = (migrated["world"]["armies"] as Array)[0]
	assert_int(int(a["target"])).is_equal(8)
	assert_bool(a.has("next") or a.has("route")).is_false()
	var army := Army.from_dict(a)
	assert_vector(army.pos).is_equal(Vector2.INF)
	army.id = sim.ids.take()
	army.home = sim.world.id_of(&"landing_bay")
	army.food = army.food_cap()
	sim.world.armies[army.id] = army
	_run(sim, 2)
	assert_vector(army.pos).is_not_equal(Vector2.INF)
	assert_int(army.state).is_equal(Army.State.MOVING)
	assert_int(army.target).is_equal(8)
