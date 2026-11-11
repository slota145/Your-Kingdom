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
