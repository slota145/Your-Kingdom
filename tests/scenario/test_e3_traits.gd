extends GdUnitTestSuite
## E3 part 1: province traits and the stone pit. A province rich in stone (Amber Coast in the
## Kingdom) lets a stone pit be built by rocks; its three stonecutters break stone in the pit and
## never use the rocks up. Part 2: the deep mine in a province rich in iron (iron ore as its rare
## resource), three miners, no vein used up. Traits are data: a loaded game takes them from its
## province's def.


func _registry() -> DataRegistry:
	return SimFixture.registry()


func test_traits_come_from_the_province_defs() -> void:
	var amber := _registry().get_province(&"amber_coast")
	assert_array(Array(amber.all_traits())).contains_exactly([ProvinceDef.RICH_STONE])
	# Iron ore as the rare resource makes a province rich in iron.
	assert_array(Array(_registry().get_province(&"iron_wold").all_traits())).contains_exactly([ProvinceDef.RICH_IRON])
	assert_array(Array(_registry().get_province(&"landing_bay").all_traits())).is_empty()
	var sim := SimFixture.make_sim(Vector2i(16, 16))
	sim.world = WorldSim.from_def(_registry().get_world(&"kingdom"), _registry())
	var coast := sim.world.id_of(&"amber_coast")
	sim.open_province(coast, _registry().get_map(&"coast"))
	assert_array(Array(sim.province_state(coast).traits)).contains_exactly([ProvinceDef.RICH_STONE])


## A world game saved and loaded keeps its traits (they are not in the save: the defs give them).
func test_a_loaded_game_takes_traits_from_the_defs() -> void:
	var sim := Simulation.from_world(_registry(), _registry().get_world(&"kingdom"))
	var coast := sim.world.id_of(&"amber_coast")
	sim.open_province(coast, _registry().get_map(&"coast"))
	var saved := sim.to_dict()
	assert_str(JSON.stringify(saved)).not_contains("rich_stone")
	var loaded := Simulation.from_dict(saved, _registry())
	assert_array(Array(loaded.province_state(coast).traits)).contains_exactly([ProvinceDef.RICH_STONE])
	assert_array(Array(loaded.province.traits)).is_empty()


func _scene(rich: bool) -> Dictionary:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	if rich:
		sim.province.traits = [ProvinceDef.RICH_STONE]
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(4, 4))
	SimFixture.place_nodes(sim, Rect2i(24, 14, 3, 2), &"rock")
	return {"sim": sim, "stock": stock}


func test_the_stone_pit_stands_only_where_stone_is_rich_and_by_rocks() -> void:
	var sim: Simulation = _scene(false)["sim"]
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"stone_pit", Vector2i(20, 14), true)))).is_equal("needs_rich_stone")
	sim.province.traits = [ProvinceDef.RICH_STONE]
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"stone_pit", Vector2i(10, 28), true)))).is_equal("no_rock_nearby")
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"stone_pit", Vector2i(20, 14), true)))).is_empty()


## Three stonecutters in the pit break stone, take turns at the crane and carry it to the
## stockpile; the rocks around stay whole.
func test_the_stone_pit_never_uses_rocks_up() -> void:
	var scene := _scene(true)
	var sim: Simulation = scene["sim"]
	var stock: BuildingState = scene["stock"]
	var pit := SimFixture.place(sim, &"stone_pit", Vector2i(20, 14))
	var workers: Array[Agent] = []
	for i: int in 3:
		var w := SimFixture.spawn(sim, &"stonecutter", pit.entrance_tile())
		assert_str(String(sim.execute(AssignWorkerCommand.new(w.id, pit.id)))).is_empty()
		workers.append(w)
	var rocks := _rock_amount(sim)
	var seen: Dictionary[StringName, bool] = {}
	for i: int in SimFixture.ticks(180):
		sim.step()
		sim.events.drain()
		for w: Agent in workers:
			seen[w.activity] = true
	var stone := stock.stock.total(&"stone") + (pit.yard.total(&"stone") if pit.yard != null else 0)
	print("stone pit, 3 workers, 3 min: ", stone, " stone")
	assert_bool(seen.has(&"hew") and seen.has(&"shape") and seen.has(&"hoist")) \
			.override_failure_message("activities seen: %s" % [seen.keys()]).is_true()
	assert_int(stone).is_greater_equal(9)
	assert_int(_rock_amount(sim)).is_equal(rocks)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


## The pit's stonecutter makes about as much as a quarry's (owner's survey 2026-11-11: more
## workers and a dearer build, not more stone per man).
func test_a_pit_worker_makes_about_what_a_quarry_worker_makes() -> void:
	var quarry_scene := _scene(false)
	var qsim: Simulation = quarry_scene["sim"]
	SimFixture.place_nodes(qsim, Rect2i(24, 18, 4, 4), &"rock")
	var quarry := SimFixture.place(qsim, &"quarry", Vector2i(20, 14))
	var cutter := SimFixture.spawn(qsim, &"stonecutter", quarry.entrance_tile())
	qsim.execute(AssignWorkerCommand.new(cutter.id, quarry.id))
	var pit_scene := _scene(true)
	var psim: Simulation = pit_scene["sim"]
	var pit := SimFixture.place(psim, &"stone_pit", Vector2i(20, 14))
	var w := SimFixture.spawn(psim, &"stonecutter", pit.entrance_tile())
	psim.execute(AssignWorkerCommand.new(w.id, pit.id))
	qsim.run_ticks(SimFixture.ticks(600))
	psim.run_ticks(SimFixture.ticks(600))
	var by_quarry := (quarry_scene["stock"] as BuildingState).stock.total(&"stone")
	var by_pit := (pit_scene["stock"] as BuildingState).stock.total(&"stone")
	print("10 min, one stonecutter: quarry ", by_quarry, ", stone pit ", by_pit)
	assert_float(by_pit / float(by_quarry)).is_between(0.75, 1.35)


## The simplified mode makes stone in the pit too, without rocks to use up.
func test_the_simplified_mode_works_the_pit() -> void:
	var scene := _scene(true)
	var sim: Simulation = scene["sim"]
	var pit := SimFixture.place(sim, &"stone_pit", Vector2i(20, 14))
	for i: int in 3:
		var w := SimFixture.spawn(sim, &"stonecutter", pit.entrance_tile())
		sim.execute(AssignWorkerCommand.new(w.id, pit.id))
	sim.run_ticks(2)
	var rocks := _rock_amount(sim)
	var abstract := ProvinceAbstract.freeze(sim.province, sim.clock.tick)
	for t: int in range(0, SimFixture.ticks(300), ProvinceAbstract.STEP_TICKS):
		abstract.step(sim.clock.tick / ProvinceAbstract.STEP_TICKS * ProvinceAbstract.STEP_TICKS + t)
	assert_int(int(abstract.detail.ledger.made_total.get(&"stone", 0))).is_greater_equal(20)
	assert_int(_rock_amount(abstract.detail)).is_equal(rocks)


func _rock_amount(source: Variant) -> int:
	var province: ProvinceSim = source.province if source is Simulation else source
	var total := 0
	for tile: Vector2i in province.resources.tiles_with_nodes():
		var def := province.resources.def_at(tile)
		if def != null and def.id == &"rock":
			total += province.resources.amount(tile)
	return total


# --- E3 part 2: the deep mine in a province rich in iron ---

func _mine_scene(rich: bool) -> Dictionary:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	if rich:
		sim.province.traits = [ProvinceDef.RICH_IRON]
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(4, 4))
	SimFixture.place_nodes(sim, Rect2i(24, 14, 3, 2), &"ore_vein")
	return {"sim": sim, "stock": stock}


func test_the_deep_mine_stands_only_where_iron_is_rich_and_by_a_vein() -> void:
	var sim: Simulation = _mine_scene(false)["sim"]
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"deep_mine", Vector2i(20, 14), true)))).is_equal("needs_rich_iron")
	sim.province.traits = [ProvinceDef.RICH_IRON]
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"deep_mine", Vector2i(10, 28), true)))).is_equal("no_ore_vein_nearby")
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"deep_mine", Vector2i(20, 14), true)))).is_empty()


## Iron ore as the rare resource is enough: such a province lets a deep mine be built.
func test_iron_ore_as_the_rare_resource_lets_a_deep_mine_stand() -> void:
	var sim := SimFixture.make_sim(Vector2i(16, 16))
	sim.world = WorldSim.from_def(_registry().get_world(&"kingdom"), _registry())
	var wold := sim.world.id_of(&"iron_wold")
	sim.open_province(wold, _registry().get_map(_registry().get_province(&"iron_wold").template))
	assert_bool(sim.province_state(wold).traits.has(ProvinceDef.RICH_IRON)).is_true()


## Three miners go down the shaft, wind the ore up and carry it to the stockpile; the vein
## beside the mine stays whole.
func test_the_deep_mine_never_uses_a_vein_up() -> void:
	var scene := _mine_scene(true)
	var sim: Simulation = scene["sim"]
	var stock: BuildingState = scene["stock"]
	var mine := SimFixture.place(sim, &"deep_mine", Vector2i(20, 14))
	var workers: Array[Agent] = []
	for i: int in 3:
		var w := SimFixture.spawn(sim, &"miner", mine.entrance_tile())
		assert_str(String(sim.execute(AssignWorkerCommand.new(w.id, mine.id)))).is_empty()
		workers.append(w)
	var veins := _node_amount(sim, &"ore_vein")
	var seen: Dictionary[StringName, bool] = {}
	for i: int in SimFixture.ticks(180):
		sim.step()
		sim.events.drain()
		for w: Agent in workers:
			seen[w.activity] = true
	var ore := stock.stock.total(&"iron_ore") + (mine.yard.total(&"iron_ore") if mine.yard != null else 0)
	print("deep mine, 3 miners, 3 min: ", ore, " iron ore")
	assert_bool(seen.has(&"descend") and seen.has(&"dig_ore") and seen.has(&"wind") and seen.has(&"shape")) \
			.override_failure_message("activities seen: %s" % [seen.keys()]).is_true()
	assert_int(ore).is_greater_equal(9)
	assert_int(_node_amount(sim, &"ore_vein")).is_equal(veins)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


## A deep mine's miner makes about as much as an ordinary mine's (owner's survey 2026-11-11:
## more workers and a dearer build, not more ore per man).
func test_a_deep_miner_makes_about_what_a_mine_worker_makes() -> void:
	var plain := _mine_scene(false)
	var msim: Simulation = plain["sim"]
	SimFixture.place_nodes(msim, Rect2i(24, 18, 4, 4), &"ore_vein")
	var mine := SimFixture.place(msim, &"mine", Vector2i(21, 15))
	var miner := SimFixture.spawn(msim, &"miner", mine.entrance_tile())
	msim.execute(AssignWorkerCommand.new(miner.id, mine.id))
	var deep_scene := _mine_scene(true)
	var dsim: Simulation = deep_scene["sim"]
	var deep := SimFixture.place(dsim, &"deep_mine", Vector2i(20, 14))
	var w := SimFixture.spawn(dsim, &"miner", deep.entrance_tile())
	dsim.execute(AssignWorkerCommand.new(w.id, deep.id))
	msim.run_ticks(SimFixture.ticks(600))
	dsim.run_ticks(SimFixture.ticks(600))
	var by_mine := (plain["stock"] as BuildingState).stock.total(&"iron_ore")
	var by_deep := (deep_scene["stock"] as BuildingState).stock.total(&"iron_ore")
	print("10 min, one miner: mine ", by_mine, ", deep mine ", by_deep)
	assert_int(by_mine).is_greater(0)
	assert_float(by_deep / float(by_mine)).is_between(0.75, 1.35)


## The simplified mode digs ore in the deep mine too, without veins to use up.
func test_the_simplified_mode_works_the_deep_mine() -> void:
	var scene := _mine_scene(true)
	var sim: Simulation = scene["sim"]
	var mine := SimFixture.place(sim, &"deep_mine", Vector2i(20, 14))
	for i: int in 3:
		var w := SimFixture.spawn(sim, &"miner", mine.entrance_tile())
		sim.execute(AssignWorkerCommand.new(w.id, mine.id))
	sim.run_ticks(2)
	var veins := _node_amount(sim, &"ore_vein")
	var abstract := ProvinceAbstract.freeze(sim.province, sim.clock.tick)
	for t: int in range(0, SimFixture.ticks(300), ProvinceAbstract.STEP_TICKS):
		abstract.step(sim.clock.tick / ProvinceAbstract.STEP_TICKS * ProvinceAbstract.STEP_TICKS + t)
	# About what the live mine makes (3 a minute with the stockpile far away), not one cycle at a time.
	assert_int(int(abstract.detail.ledger.made_total.get(&"iron_ore", 0))).is_greater_equal(12)
	assert_int(_node_amount(abstract.detail, &"ore_vein")).is_equal(veins)


func _node_amount(source: Variant, node: StringName) -> int:
	var province: ProvinceSim = source.province if source is Simulation else source
	var total := 0
	for tile: Vector2i in province.resources.tiles_with_nodes():
		var def := province.resources.def_at(tile)
		if def != null and def.id == node:
			total += province.resources.amount(tile)
	return total


# --- E3 part 3: the rest of the world keeps up ---

func _world_settings(seed_value: int, count: int, rulers: int = 2) -> GameSettings:
	var s := GameSettings.new()
	s.world_seed = seed_value
	s.rulers = rulers
	s.province_count = count
	return s


## A random world gives "rich in stone" to about one province in ten, never the player's start,
## one of them his neighbour (or a neighbour's neighbour); the same number gives the same.
## A neutral town there quarries in a stone pit.
func test_random_worlds_give_out_rich_stone() -> void:
	for seed_value: int in [3, 7, 21]:
		for count: int in [9, 22, 40]:
			var data := _registry()
			var world := WorldGenerator.generate(data, _world_settings(seed_value, count))
			var rich: Array[StringName] = []
			for id: StringName in world.provinces:
				var def := data.get_province(id)
				if def.traits.has(ProvinceDef.RICH_STONE):
					rich.append(id)
					if def.owner == ProvinceDef.OWNER_NEUTRAL:
						assert_bool(def.town_buildings.has(&"stone_pit")).is_true()
						assert_bool(def.town_buildings.has(&"quarry")).is_false()
			var label := "seed %d, %d provinces" % [seed_value, count]
			assert_int(rich.size()).override_failure_message(label).is_equal(
					maxi(1, roundi(world.provinces.size() / float(WorldGenerator.STONE_EVERY))))
			var start := data.get_province(world.start_province)
			assert_bool(rich.has(start.id)).override_failure_message(label).is_false()
			var near := false
			for id: StringName in rich:
				var def := data.get_province(id)
				if start.neighbours.has(id):
					near = true
				for n: StringName in def.neighbours:
					if start.neighbours.has(n):
						near = true
			if not start.neighbours.is_empty():
				assert_bool(near).override_failure_message(label).is_true()
			# The same number again: the same provinces.
			var again_data := _registry()
			var again := WorldGenerator.generate(again_data, _world_settings(seed_value, count))
			for id: StringName in again.provinces:
				assert_bool(again_data.get_province(id).traits.has(ProvinceDef.RICH_STONE)) \
						.override_failure_message(label).is_equal(rich.has(id))


## A save of a random world (traits are never in it, so a save from before part 3 is alike)
## loads with the traits of its seed in every town.
func test_a_random_world_save_loads_with_its_traits() -> void:
	var problems := PackedStringArray()
	var sim := Simulation.from_settings(_registry(), _world_settings(5, 18), 1, problems)
	assert_array(Array(problems)).is_empty()
	sim.run_ticks(SimFixture.ticks(5))
	var saved := sim.to_dict()
	assert_str(JSON.stringify(saved)).not_contains("rich_stone")
	var data := _registry()
	var loaded := Simulation.from_dict(saved, data)
	var rich := 0
	for id: int in loaded.runtime_ids():
		var def := loaded.world.def_of(id, data)
		var town := loaded.province_state(id)
		assert_array(Array(town.traits)).is_equal(Array(def.all_traits()))
	for id: int in loaded.world.ids():
		if loaded.world.def_of(id, data).traits.has(ProvinceDef.RICH_STONE):
			rich += 1
	assert_int(rich).is_greater_equal(1)
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(saved))


## A ruler (and the automatic player) short of stone in a province rich in stone builds a stone
## pit instead of the second quarry (owner's survey 2026-11-11); elsewhere two quarries.
func test_rulers_build_a_stone_pit_instead_of_a_second_quarry() -> void:
	var town := SimFixture.make_sim(Vector2i(16, 16)).province
	var none: Dictionary[StringName, int] = {}
	var one: Dictionary[StringName, int] = {&"quarry": 1}
	var with_pit: Dictionary[StringName, int] = {&"quarry": 1, &"stone_pit": 1}
	assert_array(Array(RulerPlanner.shortages(town, none))).contains([&"quarry"])
	assert_array(Array(RulerPlanner.shortages(town, one))).contains([&"quarry"])
	assert_array(Array(RulerPlanner.shortages(town, one))).not_contains([&"stone_pit"])
	town.traits = [ProvinceDef.RICH_STONE]
	assert_array(Array(RulerPlanner.shortages(town, none))).contains([&"quarry"])
	assert_array(Array(RulerPlanner.shortages(town, one))).contains([&"stone_pit"])
	assert_array(Array(RulerPlanner.shortages(town, one))).not_contains([&"quarry"])
	assert_array(Array(RulerPlanner.shortages(town, with_pit))).not_contains([&"quarry", &"stone_pit"])


## The planner finds a spot by the rocks for a stone pit and by a vein for a deep mine, though
## neither works on them (their place is chosen like a quarry's or a mine's).
func test_the_planner_places_a_pit_and_a_deep_mine_by_their_work() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	sim.province.traits = [ProvinceDef.RICH_STONE, ProvinceDef.RICH_IRON]
	SimFixture.place(sim, &"stockpile", Vector2i(4, 4))
	SimFixture.place_nodes(sim, Rect2i(36, 36, 3, 2), &"rock")
	SimFixture.place_nodes(sim, Rect2i(36, 8, 3, 2), &"ore_vein")
	for id: StringName in [&"stone_pit", &"deep_mine"]:
		var placed := RulerPlanner.place(sim.province, _registry().get_building(id))
		assert_object(placed).override_failure_message(String(id)).is_not_null()
		assert_bool(sim.province.has_node_near(placed.def, placed.origin)).override_failure_message(String(id)).is_true()


## The deep mine is the last entry of the plan and only in a province rich in iron; its ore is
## sold where the rulers trade.
func test_the_deep_mine_comes_late_and_only_where_iron_is_rich() -> void:
	var last: Array = RulerPlanner.PLAN[RulerPlanner.PLAN.size() - 1]
	assert_str(String(last[0])).is_equal("deep_mine")
	var town := SimFixture.make_sim(Vector2i(16, 16)).province
	var def := _registry().get_building(&"deep_mine")
	assert_bool(RulerPlanner._allowed(town, def)).is_false()
	town.traits = [ProvinceDef.RICH_IRON]
	assert_bool(RulerPlanner._allowed(town, def)).is_true()
	assert_bool(RulerExpansion.SURPLUS_GOODS.has(&"iron_ore")).is_true()


## Iron Wold (the Kingdom's neutral settlement rich in iron, and a layout of the random worlds'
## settlements) stands with a deep mine for whoever takes it.
func test_iron_wold_has_a_deep_mine() -> void:
	var problems := PackedStringArray()
	var sim := Simulation.from_world(_registry(), _registry().get_world(&"kingdom"), 1, problems)
	assert_array(Array(problems)).is_empty()
	var wold := sim.province_state(sim.world.id_of(&"iron_wold"))
	assert_object(wold).is_not_null()
	var mines := 0
	for building: BuildingState in wold.buildings.all():
		if building.def.id == &"deep_mine":
			mines += 1
			assert_bool(building.is_complete()).is_true()
	assert_int(mines).is_equal(1)


# --- E3 part 4: fertile land and rich in game ---

## In the Kingdom Willow Vale is fertile and Mirror Lakes are rich in game (owner's survey
## 2026-11-11); a town there has the trait.
func test_the_kingdom_has_fertile_land_and_game() -> void:
	assert_array(Array(_registry().get_province(&"willow_vale").all_traits())).contains_exactly([ProvinceDef.FERTILE])
	assert_array(Array(_registry().get_province(&"mirror_lakes").all_traits())).contains_exactly([ProvinceDef.RICH_GAME])
	var sim := Simulation.from_world(_registry(), _registry().get_world(&"kingdom"))
	var vale := sim.world.id_of(&"willow_vale")
	sim.open_province(vale, _registry().get_map(&"riverlands"))
	assert_float(sim.province_state(vale).field_yield()).is_equal_approx(ProvinceDef.FERTILE_YIELD, 0.0001)
	assert_bool(sim.province_state(vale).rich_in_game()).is_false()


## A field tile on fertile land yields half as much again, the extra yield included: ten
## harvests of 1 + 0.2 give 18 instead of 12; the simplified mode adds the same half.
func test_fertile_land_yields_half_again() -> void:
	var data := _registry()
	var farm := BuildingState.new(1, data.get_building(&"farm"), Vector2i.ZERO)
	var step := farm.def.recipe.steps[0] as FieldStepDef
	var total := 0
	for i: int in 10:
		total += farm.take_field_yield(step, ProvinceDef.FERTILE_YIELD)
	assert_int(total).is_equal(18)
	assert_float(farm.field_yield_carry).is_equal_approx(0.0, 0.0001)
	var extra := 0
	for i: int in 10:
		extra += farm.fertile_extra(1, ProvinceDef.FERTILE_YIELD)
	assert_int(extra).is_equal(5)
	assert_int(farm.fertile_extra(1, 1.0)).is_equal(0)


func _farm(fertile: bool) -> Dictionary:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	if fertile:
		sim.province.traits = [ProvinceDef.FERTILE]
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	var farm := SimFixture.place(sim, &"farm", Vector2i(12, 12))
	for tile: Vector2i in [Vector2i(14, 12), Vector2i(15, 12), Vector2i(14, 13), Vector2i(15, 13),
			Vector2i(14, 14), Vector2i(15, 14), Vector2i(16, 12), Vector2i(16, 13)]:
		assert_str(String(sim.execute(PlaceFieldCommand.new(farm.id, tile)))).is_empty()
	var farmer := SimFixture.spawn(sim, &"farmer", farm.entrance_tile())
	sim.execute(AssignWorkerCommand.new(farmer.id, farm.id))
	return {"sim": sim, "stock": stock, "farm": farm}


func _grain(sim: Simulation) -> int:
	return int(sim.province.ledger.made_total.get(&"grain", 0))


## A farmer on fertile land works as fast and brings in about half as much again.
func test_a_farmer_on_fertile_land_brings_in_more() -> void:
	var plain: Simulation = _farm(false)["sim"]
	var rich: Simulation = _farm(true)["sim"]
	plain.run_ticks(SimFixture.ticks(480))
	rich.run_ticks(SimFixture.ticks(480))
	var a := _grain(plain)
	var b := _grain(rich)
	assert_int(a).is_greater(0)
	assert_float(float(b) / a).override_failure_message("plain %d, fertile %d" % [a, b]).is_between(1.3, 1.7)


## The simplified mode harvests half as much again on fertile land too.
func test_the_simplified_mode_harvests_more_on_fertile_land() -> void:
	var made: Array[int] = []
	for fertile: bool in [false, true]:
		var sim: Simulation = _farm(fertile)["sim"]
		sim.run_ticks(2)
		var abstract := ProvinceAbstract.freeze(sim.province, sim.clock.tick)
		var start := sim.clock.tick / ProvinceAbstract.STEP_TICKS * ProvinceAbstract.STEP_TICKS
		for t: int in range(0, SimFixture.ticks(1200), ProvinceAbstract.STEP_TICKS):
			abstract.step(start + t)
		made.append(int(abstract.detail.ledger.made_total.get(&"grain", 0)))
	assert_int(made[0]).is_greater(0)
	assert_float(float(made[1]) / made[0]).override_failure_message("plain %d, fertile %d" % made) \
			.is_between(1.3, 1.7)


func _woods(rich: bool) -> Simulation:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	if rich:
		sim.province.traits = [ProvinceDef.RICH_GAME]
	var forest := _registry().get_terrain(&"forest")
	for y: int in range(20, 46):
		for x: int in range(20, 46):
			sim.province.grid.set_terrain(Vector2i(x, y), forest.index)
	return sim


## Woods rich in game feed half as many herds again, and a herd grows back twice as fast.
func test_woods_rich_in_game_keep_more_herds_breeding_faster() -> void:
	var plain := _woods(false)
	var rich := _woods(true)
	plain.run_ticks(SimFixture.ticks(2))
	rich.run_ticks(SimFixture.ticks(2))
	var base := plain.province.wild.herds.size()
	assert_int(base).is_greater_equal(WildHerds.MIN_HERDS)
	assert_int(rich.province.wild.herds.size()).is_equal(roundi(base * ProvinceDef.GAME_HERDS))
	assert_int(rich.province.wild.herds.size()).is_greater(base)
	# One breeding time of the plain woods: a herd rich in game has had two young.
	var herd: WildHerds.Herd = rich.province.wild.all()[0]
	var start := herd.count
	rich.run_ticks(SimFixture.ticks(WildHerds.BREED_SECONDS + 1))
	assert_int(herd.count).is_equal(mini(start + 2, WildHerds.size_of(herd.kind)))


## Random worlds give out fertile land and game like stone: about one province in ten each,
## never the start, fertile land once near the player; the same number gives the same, and
## rich in stone falls where it fell before part 4 (a die of its own each).
func test_random_worlds_give_out_fertile_land_and_game() -> void:
	for seed_value: int in [3, 7, 21]:
		for count: int in [9, 22, 40]:
			var data := _registry()
			var world := WorldGenerator.generate(data, _world_settings(seed_value, count))
			var label := "seed %d, %d provinces" % [seed_value, count]
			var start := data.get_province(world.start_province)
			var expected := maxi(1, roundi(world.provinces.size() / float(WorldGenerator.STONE_EVERY)))
			for t: StringName in [ProvinceDef.FERTILE, ProvinceDef.RICH_GAME]:
				var with_trait: Array[StringName] = []
				for id: StringName in world.provinces:
					if data.get_province(id).traits.has(t):
						with_trait.append(id)
				assert_int(with_trait.size()).override_failure_message(label + " " + t).is_equal(expected)
				assert_bool(with_trait.has(start.id)).override_failure_message(label + " " + t).is_false()
				if t == ProvinceDef.FERTILE and not start.neighbours.is_empty():
					var near := false
					for id: StringName in with_trait:
						near = near or start.neighbours.has(id)
						for n: StringName in data.get_province(id).neighbours:
							near = near or start.neighbours.has(n)
					assert_bool(near).override_failure_message(label).is_true()
			var again_data := _registry()
			var again := WorldGenerator.generate(again_data, _world_settings(seed_value, count))
			for id: StringName in again.provinces:
				assert_array(Array(again_data.get_province(id).traits)) \
						.override_failure_message(label).is_equal(Array(data.get_province(id).traits))


## A ruler in a province rich in game keeps a second hunter once the town has people; in a
## fertile one the second farm comes as soon as a mill grinds, before food runs short.
func test_rulers_use_fertile_land_and_game() -> void:
	var sim := Simulation.from_settings(_registry(), _world_settings(5, 18), 1, PackedStringArray())
	sim.run_ticks(SimClock.TICKS_PER_SECOND * 2)
	var town := sim.province_state(Rulers.provinces_of(sim.world, Rulers.alive(sim.world)[0])[0])
	assert_int(RulerPlanner.residents(town)).is_greater_equal(RulerPlanner.GAME_PEOPLE)
	assert_bool(town.wild.all().is_empty()).is_false()
	var one_hunter: Dictionary[StringName, int] = {&"hunter_lodge": 1}
	var two_hunters: Dictionary[StringName, int] = {&"hunter_lodge": 2}
	var one_farm: Dictionary[StringName, int] = {&"mill": 1, &"farm": 1, &"hunter_lodge": 2}
	var two_farms: Dictionary[StringName, int] = {&"mill": 1, &"farm": 2, &"hunter_lodge": 2}
	town.traits = []
	assert_array(Array(RulerPlanner.shortages(town, one_hunter))).not_contains([&"hunter_lodge"])
	town.traits = [ProvinceDef.RICH_GAME]
	assert_array(Array(RulerPlanner.shortages(town, one_hunter))).contains([&"hunter_lodge"])
	assert_array(Array(RulerPlanner.shortages(town, two_hunters))).not_contains([&"hunter_lodge"])
	town.traits = [ProvinceDef.FERTILE]
	assert_array(Array(RulerPlanner.shortages(town, one_farm))).contains([&"farm"])
	assert_array(Array(RulerPlanner.shortages(town, two_farms))).not_contains([&"farm"])
