extends GdUnitTestSuite
## Z1 part 1 (animal pens): pen tiles placed like fields, pens of touching tiles with a gate,
## room for 2 animals a tile, the starting pair, the breeding reserve slider, the keeper in
## the pen, surplus after removing tiles, saves and the migration of old pigsties.


func _village(sim: Simulation) -> BuildingState:
	var village := SimFixture.village(sim, 30, 20)
	SimFixture.place(sim, &"well", Vector2i(9, 9))
	SimFixture.house(sim, Vector2i(2, 12))
	SimFixture.house(sim, Vector2i(5, 12))
	return village["stock"]


func _place_pens(sim: Simulation, sty: BuildingState, tiles: Array[Vector2i]) -> void:
	for tile: Vector2i in tiles:
		assert_str(String(sim.execute(PlaceFieldCommand.new(sty.id, tile)))).is_equal("")


func test_pen_tiles_are_placed_like_fields_within_reach_up_to_twelve() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var sty := SimFixture.place(sim, &"pigsty", Vector2i(16, 16))
	assert_int(sty.def.footprint.x).is_equal(2)
	# Not on the building, not out of reach.
	assert_str(String(sim.execute(PlaceFieldCommand.new(sty.id, Vector2i(16, 16))))).is_equal("tile_occupied")
	assert_str(String(sim.execute(PlaceFieldCommand.new(sty.id, Vector2i(30, 30))))).is_equal("out_of_range")
	var placed := 0
	for y: int in range(12, 22):
		for x: int in range(12, 15):
			if sim.execute(PlaceFieldCommand.new(sty.id, Vector2i(x, y))) == &"":
				placed += 1
	assert_int(placed).is_equal(12)
	assert_int(sty.pens).is_equal(12)
	assert_int(sty.herd_room()).is_equal(24)
	assert_str(String(sim.province.field_error(sty.id, Vector2i(15, 12)))).is_equal("too_many_pens")
	# A pen tile blocks building like a field, and people go round it.
	assert_bool(sim.province.is_pen(Vector2i(12, 12))).is_true()
	assert_float(sim.province.nav.get_cost(Vector2i(12, 12))).is_equal(ProvinceSim.PEN_COST)


func test_touching_tiles_make_one_pen_with_a_gate_towards_the_door() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var sty := SimFixture.place(sim, &"pigsty", Vector2i(16, 16))
	var other := SimFixture.place(sim, &"pigsty", Vector2i(22, 16))
	# An L of 3 tiles and a lone tile apart from it.
	_place_pens(sim, sty, [Vector2i(14, 16), Vector2i(14, 17), Vector2i(15, 18)] as Array[Vector2i])
	_place_pens(sim, sty, [Vector2i(14, 18)] as Array[Vector2i])
	_place_pens(sim, sty, [Vector2i(19, 14)] as Array[Vector2i])
	# The other pigsty's tile beside it is not part of the first pigsty's pen.
	_place_pens(sim, other, [Vector2i(20, 14)] as Array[Vector2i])
	var groups := Pens.groups(sim.province, sty.id)
	assert_int(groups.size()).is_equal(2)
	var sizes: Array[int] = []
	for group: Array in groups:
		sizes.append(group.size())
	sizes.sort()
	assert_array(sizes).is_equal([1, 4])
	assert_int(Pens.groups(sim.province, other.id).size()).is_equal(1)
	# The gate: on a tile of the pen, on a side facing out of it.
	for group: Array in groups:
		var gate := Pens.gate(sty, group)
		assert_bool(group.has(gate[0])).is_true()
		assert_bool(group.has(gate[0] + gate[1])).is_false()


func test_the_first_pen_brings_a_pair_once_and_the_herd_breeds_to_its_room() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village(sim)
	var sty := SimFixture.place(sim, &"pigsty", Vector2i(16, 4))
	assert_int(sty.yard.total(&"pig")).is_equal(0)
	# Without a pen the swineherd has nothing to do and nobody brings pigs there.
	assert_int(sim.province.nearest_sink(&"pig", 1, Vector2i(16, 8))).is_equal(0)
	_place_pens(sim, sty, [Vector2i(14, 4)] as Array[Vector2i])
	assert_int(sty.yard.total(&"pig")).is_equal(2)
	_place_pens(sim, sty, [Vector2i(14, 5)] as Array[Vector2i])
	assert_int(sty.yard.total(&"pig")).is_equal(2)
	assert_int(sty.herd_room()).is_equal(4)
	sim.run_ticks(SimFixture.ticks(600))
	assert_int(sty.yard.total(&"pig")).is_equal(4)


func test_the_swineherd_works_in_the_pen() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village(sim)
	var sty := SimFixture.place(sim, &"pigsty", Vector2i(16, 4))
	assert_int(Pens.auto_place(sim.province, sty, 4)).is_equal(4)
	var pens := sim.province.fields.tiles_of(sty.id)
	var inside := false
	for i: int in SimFixture.ticks(120):
		sim.step()
		for id: int in sty.workers:
			var agent := sim.province.agents.get_agent(id)
			if agent != null and pens.has(agent.tile()) and agent.activity in [&"feed", &"muck"]:
				inside = true
	assert_bool(inside).is_true()


func test_removed_pens_keep_the_animals_and_the_surplus_goes_first() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village(sim)
	var sty := SimFixture.place(sim, &"pigsty", Vector2i(16, 4))
	assert_int(Pens.auto_place(sim.province, sty, 4)).is_equal(4)
	sty.yard.add(&"pig", 6)
	assert_int(sty.yard.total(&"pig")).is_equal(8)
	for tile: Vector2i in sim.province.fields.tiles_of(sty.id).slice(0, 3):
		assert_str(String(sim.execute(RemoveFieldCommand.new(tile)))).is_equal("")
	# Room for 2, 8 pigs: nobody vanishes, the herd does not grow.
	assert_int(sty.herd_room()).is_equal(2)
	assert_int(sty.yard.total(&"pig")).is_equal(8)
	assert_int(sty.herd_spare()).is_equal(6)
	sty.breed_ticks = 0
	sim.run_ticks(SimFixture.ticks(300))
	assert_int(sty.yard.total(&"pig")).is_equal(8)
	# The butcher takes the surplus down to the breeding pair.
	SimFixture.place(sim, &"slaughterhouse", Vector2i(16, 10))
	sim.run_ticks(SimFixture.ticks(900))
	assert_int(sty.yard.total(&"pig")).is_equal(2)


func test_the_breeding_reserve_slider_keeps_pigs_from_the_butcher() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village(sim)
	var sty := SimFixture.place(sim, &"pigsty", Vector2i(16, 4))
	assert_int(Pens.auto_place(sim.province, sty, 4)).is_equal(4)
	sty.yard.add(&"pig", 4)
	# From 2 to the herd's room.
	sim.execute(SetHerdKeepCommand.new(sty.id, 1))
	assert_int(sty.herd_keep).is_equal(2)
	sim.execute(SetHerdKeepCommand.new(sty.id, 99))
	assert_int(sty.herd_keep).is_equal(8)
	assert_str(String(sim.execute(SetHerdKeepCommand.new(sty.id, 5)))).is_equal("")
	assert_int(sty.herd_keep).is_equal(5)
	sty.paused = true
	SimFixture.place(sim, &"slaughterhouse", Vector2i(16, 10))
	sim.run_ticks(SimFixture.ticks(600))
	assert_int(sty.yard.total(&"pig")).is_equal(5)
	assert_str(String(sim.execute(SetHerdKeepCommand.new(sim.province.storage_buildings()[0].id, 3)))).is_equal("no_herd")


func test_pens_and_the_reserve_survive_a_save() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village(sim)
	var sty := SimFixture.place(sim, &"pigsty", Vector2i(16, 4))
	assert_int(Pens.auto_place(sim.province, sty, 3)).is_equal(3)
	sim.execute(SetHerdKeepCommand.new(sty.id, 4))
	sim.run_ticks(SimFixture.ticks(30))
	var loaded := Simulation.from_dict(sim.to_dict(), SimFixture.registry())
	var again := loaded.province.buildings.get_building(sty.id)
	assert_int(again.pens).is_equal(3)
	assert_int(again.herd_room()).is_equal(6)
	assert_int(again.herd_keep).is_equal(4)
	assert_bool(again.herd_given).is_true()
	assert_int(again.yard.stack_limit).is_equal(6)
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))
	for i: int in 300:
		sim.step()
		loaded.step()
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))


## v31 → v32: the old 3×3 pigsty shrinks to 2×2 and the 5 tiles it frees become its pen;
## every pig stays.
func test_old_pigsties_get_their_freed_ground_as_a_pen() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v7_town.json"))
	var before := 0
	var origins: Dictionary[int, Vector2i] = {}
	for b: Variant in (document["state"]["province"] as Dictionary)["buildings"]:
		var building := b as Dictionary
		if building["def"] == "pigsty":
			origins[int(building["id"])] = SimCodec.to_vec2i(building["origin"])
			if building.has("yard"):
				for slot: Variant in (building["yard"] as Dictionary)["slots"]:
					before += int((slot as Array)[1])
	assert_int(origins.size()).is_greater(0)
	var state := SaveMigrations.migrate(document["state"], 7)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	var after := 0
	for id: int in origins:
		var sty := sim.province.buildings.get_building(id)
		assert_int(sty.pens).is_equal(5)
		assert_int(Pens.groups(sim.province, id).size()).is_equal(1)
		assert_bool(sim.province.is_pen(origins[id] + Vector2i(2, 2))).is_true()
		assert_bool(sim.province.is_pen(origins[id] + Vector2i(1, 1))).is_false()
		after += sty.yard.total(&"pig")
	assert_int(after).is_equal(before)
	sim.run_ticks(SimFixture.ticks(60))
	assert_array(Array(sim.province.dangling_holds())).is_empty()


## The v32 fixture (tools/build_pens_fixture.gd): two pigsties with pens and a reserve of 3
## load unchanged and keep playing.
func test_v32_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v32_pens.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(32)
	var state := SaveMigrations.migrate(document["state"], 32)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	var pens: Array[int] = []
	var keeps: Array[int] = []
	for b: BuildingState in sim.province.buildings.all():
		if b.def.has_pens():
			pens.append(b.pens)
			keeps.append(b.herd_keep)
	pens.sort()
	keeps.sort()
	assert_array(pens).is_equal([4, 5])
	assert_array(keeps).is_equal([2, 3])
	sim.run_ticks(SimFixture.ticks(120))
	assert_array(Array(sim.province.dangling_holds())).is_empty()


# --- Part 2: sheep and horses ----------------------------------------------------------------

func _wool_in(seconds: float, sheep: int) -> int:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village(sim)
	var farm := SimFixture.place(sim, &"sheep_farm", Vector2i(16, 4))
	farm.herd_given = sheep != 2
	# A full pen: no lambs, the flock stays the same size for the comparison.
	assert_int(Pens.auto_place(sim.province, farm, sheep / 2)).is_equal(sheep / 2)
	farm.yard.add(&"sheep", sheep - farm.yard.total(&"sheep"))
	var wool := 0
	for i: int in SimFixture.ticks(seconds):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"good_produced" and e["good"] == &"wool":
				wool += int(e["amount"])
	return wool


func test_a_bigger_flock_gives_wool_faster() -> void:
	var small := _wool_in(300, 2)
	var big := _wool_in(300, 24)
	print("wool in 5 min: 2 sheep ", small, ", 24 sheep ", big)
	assert_int(small).is_greater(0)
	assert_int(big).is_greater_equal(small * 3 / 2)


func test_no_sheep_no_wool() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village(sim)
	var farm := SimFixture.place(sim, &"sheep_farm", Vector2i(16, 4))
	farm.herd_given = true
	assert_int(Pens.auto_place(sim.province, farm, 2)).is_equal(2)
	assert_int(farm.yard.total(&"sheep")).is_equal(0)
	sim.run_ticks(SimFixture.ticks(180))
	assert_int(sim.province.goods_total(&"wool")).is_equal(0)


func test_sheep_and_stud_farms_get_their_pair_with_the_first_pen() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	sim.province.rare_resource = &"horses"
	var farm := SimFixture.place(sim, &"sheep_farm", Vector2i(16, 4))
	var stud := SimFixture.place(sim, &"stud_farm", Vector2i(16, 16))
	assert_int(stud.def.footprint.x).is_equal(2)
	assert_int(Pens.auto_place(sim.province, farm, 1)).is_equal(1)
	assert_int(Pens.auto_place(sim.province, stud, 10)).is_equal(10)
	assert_int(farm.yard.total(&"sheep")).is_equal(2)
	assert_int(stud.yard.total(&"horse")).is_equal(2)
	assert_str(String(sim.province.field_error(stud.id, Vector2i(20, 20)))).is_equal("too_many_pens")
	# One horse a tile (owner's decision 2026-11-10).
	assert_int(stud.herd_room()).is_equal(10)


func test_the_merchant_sells_sheep_and_horses_where_they_have_a_pen() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	_village(sim)
	sim.province.entry_tile = Vector2i(39, 20)
	SimFixture.place(sim, &"market", Vector2i(20, 20))
	sim.province.treasury.gold = 500
	sim.province.merchant.next_visit = sim.province.tick + 10
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.province.merchant.is_trading(), 120)).is_true()
	# No sheep farm, no stud farm: nowhere to lead them.
	assert_str(String(sim.execute(BuyAnimalCommand.new(&"sheep")))).is_equal("no_room_for_animals")
	assert_str(String(sim.execute(BuyAnimalCommand.new(&"horse")))).is_equal("no_room_for_animals")
	assert_str(String(sim.execute(BuyAnimalCommand.new(&"wool")))).is_equal("not_for_sale")
	var farm := SimFixture.place(sim, &"sheep_farm", Vector2i(16, 4))
	assert_int(Pens.auto_place(sim.province, farm, 3)).is_equal(3)
	var gold := sim.province.treasury.gold
	assert_str(String(sim.execute(BuyAnimalCommand.new(&"sheep")))).is_equal("")
	assert_int(gold - sim.province.treasury.gold).is_equal(Merchant.animal_price(&"sheep"))
	assert_int(sim.province.merchant.left(&"sheep")).is_equal(3)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return farm.yard.total(&"sheep") >= 3, 120)).is_true()


## v32 → v33: an old stud farm shrinks to 2×2 with a pen of its freed ground, an old sheep farm
## gets a pen and a pair of sheep on its first second.
func test_v32_saves_get_pens_for_stud_and_sheep_farms() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	sim.province.rare_resource = &"horses"
	var farm := SimFixture.place(sim, &"sheep_farm", Vector2i(16, 4))
	var stud := SimFixture.place(sim, &"stud_farm", Vector2i(16, 16))
	var state: Dictionary = sim.to_dict()
	# As a v32 save had them: a 3×3 stud farm with 4 horses and no pens, no sheep.
	for entry: Variant in state["provinces"]:
		var province: Dictionary = (entry as Dictionary)["state"]
		province["fields"] = []
		for b: Variant in province["buildings"]:
			var d := b as Dictionary
			if d["def"] == "stud_farm":
				d["yard"] = {"slots": [["horse", 4]], "reservations": [], "next": 1, "limit": 6}
				d.erase("herd_given")
	var migrated := SaveMigrations.migrate(state, 32)
	var loaded := Simulation.from_dict(migrated, SimFixture.registry())
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(migrated))
	var stud2 := loaded.province.buildings.get_building(stud.id)
	assert_int(stud2.pens).is_equal(5)
	assert_int(stud2.yard.total(&"horse")).is_equal(4)
	assert_int(stud2.herd_room()).is_equal(5)
	var farm2 := loaded.province.buildings.get_building(farm.id)
	assert_int(farm2.pens_due).is_equal(SaveMigrations.AUTO_SHEEP_PENS)
	loaded.run_ticks(SimFixture.ticks(2))
	assert_int(farm2.pens).is_equal(SaveMigrations.AUTO_SHEEP_PENS)
	assert_int(farm2.pens_due).is_equal(0)
	assert_int(farm2.yard.total(&"sheep")).is_equal(2)


## The v33 fixture (tools/build_flock_fixture.gd): a sheep farm and a stud farm with pens load
## unchanged and keep playing; wool keeps coming.
func test_v33_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v33_flocks.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(33)
	var state := SaveMigrations.migrate(document["state"], 33)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	var farm: BuildingState = null
	var stud: BuildingState = null
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == &"sheep_farm":
			farm = b
		elif b.def.id == &"stud_farm":
			stud = b
	assert_int(farm.pens).is_equal(4)
	assert_int(farm.herd_keep).is_equal(4)
	assert_int(farm.yard.total(&"sheep")).is_greater_equal(6)
	assert_int(stud.pens).is_equal(3)
	assert_int(stud.yard.total(&"horse")).is_greater_equal(2)
	var wool := 0
	for i: int in SimFixture.ticks(180):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"good_produced" and e["good"] == &"wool":
				wool += int(e["amount"])
	assert_int(wool).is_greater(0)
	assert_array(Array(sim.province.dangling_holds())).is_empty()
