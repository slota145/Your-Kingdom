extends GdUnitTestSuite
## M7 part 3: armies on the world map (ROADMAP M7, "Część 3, plan i decyzje"; GDD §6.3, §7, §8).
## - soldiers march out of the viewed province and stand by the town as an army,
## - an army walks through neighbours to a neutral settlement and waits at its border,
## - the settlement falls to an automatic siege with engines, holds against bare men,
## - in the province's view the army breaks in and takes the town hall,
## - the bandits' camp raids the player's provinces and can be broken,
## - armies, the camp and the settlements' guards survive a save.

static var _world: Simulation


func _sim() -> Simulation:
	# The world (two neutral towns) is built once; each test plays a copy of it.
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


## An army of the player standing in province [param at].
func _army(sim: Simulation, at: int, units: Dictionary) -> Army:
	var army := Army.new()
	army.id = sim.ids.take()
	army.at = at
	army.home = sim.world.id_of(&"landing_bay")
	army.state = Army.State.IDLE
	army.units = _units(units)
	army.food = army.food_cap()
	sim.world.armies[army.id] = army
	return army


func _soldier(sim: Simulation, unit: StringName, tile: Vector2i) -> Agent:
	var agent := sim.province.spawn_agent(unit, tile)
	agent.combat = CombatState.new(sim.data.get_unit(unit).combat.hp)
	return agent


func _place_near(sim: Simulation, id: StringName, at: Vector2i) -> BuildingState:
	var def := sim.data.get_building(id)
	for r: int in 20:
		for y: int in range(at.y - r, at.y + r + 1):
			for x: int in range(at.x - r, at.x + r + 1):
				if sim.province.placement_error(def, Vector2i(x, y)) == &"":
					return sim.province.add_building(def, Vector2i(x, y), true)
	return null


func _until(sim: Simulation, seconds: float, done: Callable) -> bool:
	for k: int in int(seconds):
		_run(sim, 1)
		if done.call():
			return true
	return false


func test_neutral_towns_have_walls_and_guards() -> void:
	var sim := _sim()
	for def_id: StringName in [&"iron_wold", &"horse_haven"]:
		var id := sim.world.id_of(def_id)
		var town := sim.province_state(id)
		var settlement: NeutralSettlement = sim.world.settlements[id]
		assert_bool(settlement.fortified).is_true()
		assert_int(town.home_faction).is_equal(CombatState.TOWN)
		assert_int(town.walls.count()).is_greater(40)
		var gates := town.buildings.all().filter(func(b: BuildingState) -> bool: return b.def.is_gatehouse())
		assert_int(gates.size()).is_equal(1)
		# The ring is closed: an enemy at the edge cannot walk to the town hall without breaking in.
		var door := town.door_tile(town.seat())
		assert_bool(town.mil.siege_nav.find_path(Vector2i(2, 2), door).is_empty()).is_false()
		assert_vector(Armies.exit_tile(town, door, CombatState.PLAYER)).is_equal(Agent.NO_TILE)
	var iron: NeutralSettlement = sim.world.settlements[sim.world.id_of(&"iron_wold")]
	assert_int(iron.guards[&"spearman"] + iron.guards[&"archer"]).is_equal(14)
	assert_int(Armies.fort_of(sim.province_state(sim.world.id_of(&"iron_wold"))).wall).is_equal(Walls.STONE)
	assert_int(Armies.fort_of(sim.province_state(sim.world.id_of(&"horse_haven"))).wall).is_equal(Walls.PALISADE)


func test_soldiers_march_out_and_form_an_army() -> void:
	var sim := _sim()
	var beach := sim.province.landing.beach
	var ids: Array[int] = []
	for k: int in 6:
		ids.append(_soldier(sim, &"spearman" if k < 4 else &"archer", beach).id)
	assert_str(String(sim.execute(MarchOutCommand.new(ids)))).is_empty()
	assert_int(sim.world.armies.size()).is_equal(1)
	var army: Army = sim.world.armies.values()[0]
	assert_int(army.state).is_equal(Army.State.INSIDE)
	var out := _until(sim, 240, func() -> bool: return army.state == Army.State.IDLE)
	assert_bool(out).is_true()
	assert_int(army.units[&"spearman"]).is_equal(4)
	assert_int(army.units[&"archer"]).is_equal(2)
	for id: int in ids:
		assert_bool(sim.province.agents.has_agent(id)).is_false()


func test_army_walks_through_neighbours_to_a_settlement_and_waits() -> void:
	var sim := _sim()
	var home := sim.world.id_of(&"landing_bay")
	var iron := sim.world.id_of(&"iron_wold")
	var army := _army(sim, home, {"spearman": 10})
	var food := army.food
	assert_str(String(sim.execute(SendArmyCommand.new(army.id, iron)))).is_empty()
	assert_int(army.state).is_equal(Army.State.MOVING)
	assert_int(army.next).is_equal(sim.world.id_of(&"willow_vale"))
	assert_array(army.route).is_equal([iron])
	var events: Array[Dictionary] = []
	for k: int in 900:
		events.append_array(_run(sim, 1))
		if army.state == Army.State.WAITING:
			break
	assert_int(army.state).is_equal(Army.State.WAITING)
	assert_int(army.at).is_equal(iron)
	assert_array(_types(events)).contains([&"army_at_settlement"])
	assert_float(army.food).is_less(food)
	# Sent on while standing is fine; the expedition rules keep it out of the camp province.
	assert_str(String(Armies.send_error(sim, army, home))).is_empty()


func test_automatic_siege_with_engines_takes_the_town() -> void:
	var sim := _sim()
	var iron := sim.world.id_of(&"iron_wold")
	var army := _army(sim, iron, {"swordsman": 24, "archer": 10, "ram": 1, "ladderman": 2})
	army.state = Army.State.WAITING
	assert_float(Armies.siege_chances(sim, army, iron)).is_greater(0.8)
	assert_str(String(sim.execute(ArmySiegeCommand.new(army.id, ArmySiegeCommand.AUTO)))).is_empty()
	assert_str(String(sim.world.owner_of(iron))).is_equal("player")
	assert_bool(sim.world.settlements.has(iron)).is_false()
	assert_int(army.state).is_equal(Army.State.IDLE)
	assert_int(sim.province_state(iron).home_faction).is_equal(CombatState.PLAYER)
	assert_int(sim.province_state(iron).raids.mood_until).is_greater(sim.clock.tick)
	assert_int(sim.world.reports.size()).is_equal(1)


func test_automatic_siege_without_engines_fails_at_a_stone_wall() -> void:
	var sim := _sim()
	var iron := sim.world.id_of(&"iron_wold")
	var army := _army(sim, iron, {"spearman": 12})
	army.state = Army.State.WAITING
	sim.execute(ArmySiegeCommand.new(army.id, ArmySiegeCommand.AUTO))
	assert_str(String(sim.world.owner_of(iron))).is_equal("neutral")
	assert_int(army.men()).is_less(12)


func test_army_takes_a_settlement_in_its_view() -> void:
	var sim := _sim()
	var haven := sim.world.id_of(&"horse_haven")
	var army := _army(sim, haven, {"swordsman": 20, "archer": 6})
	army.state = Army.State.WAITING
	assert_str(String(sim.execute(ArmySiegeCommand.new(army.id, ArmySiegeCommand.ENTER)))).is_empty()
	assert_int(sim.viewed_id).is_equal(haven)
	var province := sim.province
	var mine: Array[int] = []
	var guards := 0
	for agent: Agent in province.agents.all():
		if agent.combat != null and agent.combat.army == army.id:
			mine.append(agent.id)
		elif agent.combat != null and agent.combat.faction == CombatState.TOWN:
			guards += 1
	assert_int(mine.size()).is_equal(26)
	assert_int(guards).is_equal(8)
	assert_int(army.state).is_equal(Army.State.INSIDE)
	var door := province.seat().entrance_tile()
	var taken := false
	for k: int in 60:
		# The player sends whoever stands idle at the town hall's door again and again.
		var idle: Array[int] = []
		for id: int in mine:
			var agent := province.agents.get_agent(id)
			if agent != null and agent.combat.order != CombatState.Order.STRUCTURE and agent.combat.target_id == 0:
				idle.append(id)
		if not idle.is_empty() and Troops.structure_standing(province, door):
			sim.execute(OrderTroopsCommand.new(idle, OrderTroopsCommand.BREAK, door))
		elif not idle.is_empty():
			# The door is down: at the guards still standing by it.
			for agent: Agent in province.agents.all():
				if agent.combat != null and agent.combat.faction == CombatState.TOWN and agent.level == MilitaryNav.GROUND:
					sim.execute(OrderTroopsCommand.new(idle, OrderTroopsCommand.ATTACK, Vector2i(-1, -1), 0, agent.id))
					break
		_run(sim, 10)
		if sim.world.owner_of(haven) == ProvinceDef.OWNER_PLAYER:
			taken = true
			break
	assert_bool(taken).is_true()
	for agent: Agent in province.agents.all():
		assert_bool(agent.combat != null and agent.combat.faction == CombatState.TOWN).is_false()
	# Leaving the province: the men left count as the army again, standing in its new province.
	var left := 0
	for id: int in mine:
		if province.agents.has_agent(id):
			left += 1
	sim.view_province(sim.world.id_of(&"landing_bay"))
	assert_int(army.state).is_equal(Army.State.IDLE)
	assert_int(army.men()).is_equal(left)


func test_bandits_raid_the_viewed_province_from_their_camp() -> void:
	var sim := _sim()
	sim.raids_enabled = true
	sim.province.landing.finish_at_once(sim.province)
	sim.province.first_building = &""
	assert_object(_place_near(sim, &"town_hall", sim.province.landing.beach + Vector2i(0, -8))).is_not_null()
	sim.province.grace_until = 0
	_run(sim, 1)
	var camp := sim.world.camp
	assert_object(camp).is_not_null()
	assert_int(camp.province).is_equal(sim.world.id_of(&"mirror_lakes"))
	camp.next_raid = sim.clock.tick + 1
	var events := _run(sim, 2)
	assert_array(_types(events)).contains([&"bandits_set_out"])
	var bandits: Army = null
	for army: Army in sim.world.armies.values():
		if army.owner == Army.BANDITS:
			bandits = army
	assert_int(bandits.goal()).is_equal(sim.viewed_id)
	var size := bandits.men()
	var started := _until(sim, 900, func() -> bool: return sim.province.raids.is_active())
	assert_bool(started).is_true()
	assert_int(sim.province.raids.army).is_equal(bandits.id)
	assert_int(sim.province.raids.members.size()).is_equal(size)
	# The town's soldiers beat them: the army is gone.
	for id: int in sim.province.raids.members.duplicate():
		Troops.kill(sim.province, sim.province.agents.get_agent(id))
	_run(sim, 3)
	assert_bool(sim.world.armies.has(bandits.id)).is_false()


func test_bandits_loot_an_unviewed_province_and_take_the_gold_home() -> void:
	var sim := _sim()
	sim.raids_enabled = true
	var iron := sim.world.id_of(&"iron_wold")
	Armies.capture(sim, iron)
	sim.province_state(iron).walls = Walls.new(sim.province_state(iron).grid.size)
	_run(sim, 1)
	var camp := sim.world.camp
	camp.next_raid = sim.clock.tick + 1
	_run(sim, 2)
	var bandits: Army = null
	for army: Army in sim.world.armies.values():
		if army.owner == Army.BANDITS:
			bandits = army
	assert_int(bandits.goal()).is_equal(iron)
	var gold := sim.treasury.gold
	var looted := _until(sim, 900, func() -> bool: return sim.treasury.gold < gold)
	assert_bool(looted).is_true()
	var home := _until(sim, 900, func() -> bool: return not sim.world.armies.has(bandits.id))
	assert_bool(home).is_true()
	assert_int(camp.gold).is_greater(0)


func test_army_breaks_the_camp_and_takes_its_hoard() -> void:
	var sim := _sim()
	sim.raids_enabled = true
	_run(sim, 1)
	var camp := sim.world.camp
	camp.gold = 120
	var gold := sim.treasury.gold
	var army := _army(sim, sim.world.id_of(&"willow_vale"), {"swordsman": 16, "archer": 6})
	sim.execute(SendArmyCommand.new(army.id, camp.province))
	var broken := _until(sim, 900, func() -> bool: return not camp.is_up())
	assert_bool(broken).is_true()
	assert_int(sim.treasury.gold).is_equal(gold + 120)
	assert_int(army.state).is_equal(Army.State.IDLE)
	assert_str(String(SendExpeditionCommand.error_for(sim, sim.viewed_id, sim.world.id_of(&"mirror_lakes")))).is_not_equal("bandit_camp")


func test_armies_and_the_camp_survive_a_save() -> void:
	var sim := _sim()
	sim.raids_enabled = true
	_run(sim, 1)
	var army := _army(sim, sim.world.id_of(&"landing_bay"), {"spearman": 5})
	sim.execute(SendArmyCommand.new(army.id, sim.world.id_of(&"iron_wold")))
	_run(sim, 5)
	var saved := sim.to_dict()
	var loaded := Simulation.from_dict(saved, SimFixture.registry())
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(saved))
	assert_int((loaded.world.armies[army.id] as Army).state).is_equal(Army.State.MOVING)
	assert_object(loaded.world.camp).is_not_null()
