extends GdUnitTestSuite
## M8 part 1: a world generated from its number (the same number gives the same world), a
## sandbox game started from settings with AI rulers' towns, its save and load (the world made
## again), victory and defeat.


func _settings(seed_value: int, rulers: int = 2, count: int = 22) -> GameSettings:
	var s := GameSettings.new()
	s.world_seed = seed_value
	s.rulers = rulers
	s.province_count = count
	return s


func test_the_same_number_gives_the_same_world() -> void:
	var data := SimFixture.registry()
	var a := WorldGenerator.generate(data, _settings(7))
	var first: Array = []
	for id: StringName in a.provinces:
		var d := data.get_province(id)
		first.append([d.template, d.owner, d.neighbours, d.outline, d.rare_resource, d.name_parts])
	var b := WorldGenerator.generate(data, _settings(7))
	var second: Array = []
	for id: StringName in b.provinces:
		var d := data.get_province(id)
		second.append([d.template, d.owner, d.neighbours, d.outline, d.rare_resource, d.name_parts])
	assert_str(str(second)).is_equal(str(first))
	var other := WorldGenerator.generate(data, _settings(8))
	assert_str(str(data.get_province(other.provinces[0]).outline)).is_not_equal(str(first[0][3]))


func test_generated_worlds_are_sound() -> void:
	var data := SimFixture.registry()
	for seed_value: int in [1, 2, 3, 42, 1234]:
		for count: int in [16, 22, 30]:
			var world := WorldGenerator.generate(data, _settings(seed_value, 3, count))
			assert_int(world.provinces.size()).is_equal(count)
			var owners: Dictionary[StringName, int] = {}
			for id: StringName in world.provinces:
				var d := data.get_province(id)
				owners[d.owner] = owners.get(d.owner, 0) + 1
				assert_int(d.outline.size()).is_greater_equal(3)
				for n: StringName in d.neighbours:
					assert_bool(data.get_province(n).neighbours.has(id)).override_failure_message(
							"%s-%s not both ways" % [id, n]).is_true()
				if d.island:
					assert_bool(d.coastal).is_true()
			assert_int(owners.get(ProvinceDef.OWNER_PLAYER, 0)).is_equal(1)
			for r: int in range(1, 4):
				assert_int(owners.get(WorldGenerator.ruler_owner(r), 0)).is_equal(1)
			assert_int(owners.get(ProvinceDef.OWNER_NEUTRAL, 0)).is_greater_equal(2)
			var start := data.get_province(world.start_province)
			assert_bool(start.coastal).is_true()
			assert_str(String(start.template)).is_equal("islands" if start.island else "coast")
			var islands := 0
			for id: StringName in world.provinces:
				if data.get_province(id).island:
					islands += 1
			assert_int(islands).is_greater_equal(2)
			# Every province can be reached from the start: by land or, on the coast, by sea.
			assert_int(_reachable(data, world)).is_equal(count)


func _reachable(data: DataRegistry, world: WorldDef) -> int:
	var seen: Dictionary[StringName, bool] = {world.start_province: true}
	var queue: Array[StringName] = [world.start_province]
	while not queue.is_empty():
		var d := data.get_province(queue.pop_back())
		var next: Array[StringName] = []
		next.append_array(d.neighbours)
		if d.coastal:
			for id: StringName in world.provinces:
				if data.get_province(id).coastal:
					next.append(id)
		for n: StringName in next:
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen.size()


func test_a_sandbox_game_starts_with_ruler_towns_and_saves() -> void:
	var data := SimFixture.registry()
	var problems := PackedStringArray()
	var sim := Simulation.from_settings(data, _settings(5, 2, 18), 1, problems)
	assert_object(sim).is_not_null()
	assert_array(Array(problems)).is_empty()
	assert_array(Rulers.alive(sim.world)).has_size(2)
	for owner: StringName in Rulers.alive(sim.world):
		var id: int = Rulers.provinces_of(sim.world, owner)[0]
		var town := sim.province_state(id)
		assert_object(town).is_not_null()
		assert_int(town.buildings.all().size()).is_greater(15)
		assert_object(town.seat()).is_not_null()
	assert_bool(sim.province.landing != null).is_true()
	sim.run_ticks(SimFixture.ticks(5))
	var state := sim.to_dict()
	var copy := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(state))
	assert_int(copy.world.settings.world_seed).is_equal(5)
	assert_int(SaveMigrations.CURRENT_VERSION).is_greater_equal(27)


func test_victory_and_defeat() -> void:
	var data := SimFixture.registry()
	var settings := _settings(9, 1, 16)
	var sim := Simulation.from_settings(data, settings, 1)
	# Conquest: the only ruler loses his province.
	var ruler: int = Rulers.provinces_of(sim.world, WorldGenerator.ruler_owner(1))[0]
	sim.world.get_province(ruler).owner = ProvinceDef.OWNER_NONE
	sim.run_ticks(SimFixture.ticks(1.1))
	assert_str(String(sim.world.result)).is_equal(String(WorldSim.RESULT_WON))
	# Provinces: two needed.
	var sim2 := Simulation.from_settings(data, settings, 1)
	settings.victory = GameSettings.VICTORY_PROVINCES
	settings.victory_target = 2
	sim2.world.settings = settings
	sim2.run_ticks(SimFixture.ticks(1.1))
	assert_str(String(sim2.world.result)).is_equal("")
	sim2.world.get_province(ruler).owner = ProvinceDef.OWNER_PLAYER
	sim2.run_ticks(SimFixture.ticks(1.1))
	assert_str(String(sim2.world.result)).is_equal(String(WorldSim.RESULT_WON))
	# Defeat: the player holds nothing.
	var sim3 := Simulation.from_settings(data, _settings(9, 1, 16), 1)
	sim3.world.settings.victory = GameSettings.VICTORY_FREE
	for id: int in sim3.world.ids():
		if sim3.world.owner_of(id) == ProvinceDef.OWNER_PLAYER:
			sim3.world.get_province(id).owner = ProvinceDef.OWNER_NONE
	sim3.run_ticks(SimFixture.ticks(1.1))
	assert_str(String(sim3.world.result)).is_equal(String(WorldSim.RESULT_LOST))


## The player chooses where to start; the rulers get theirs only then, far from him (owner's
## survey 2026-11-09). 9 to 60 provinces, up to 10 islands, a bigger sheet for a bigger world.
func test_the_player_chooses_his_start_and_worlds_go_from_9_to_60() -> void:
	var data := SimFixture.registry()
	var settings := _settings(11, 3, 30)
	settings.islands = 6
	var world := WorldGenerator.geography(data, settings)
	var choices := WorldGenerator.start_choices(data, world, settings)
	assert_bool(choices.size() > 5).is_true()
	for id: StringName in world.provinces:
		assert_str(String(data.get_province(id).owner)).is_equal("")
	var island: StringName = &""
	for id: StringName in choices:
		if data.get_province(id).island:
			island = id
	assert_str(String(island)).is_not_empty()
	settings.start = String(island)
	world = WorldGenerator.generate(data, settings)
	assert_str(String(world.start_province)).is_equal(String(island))
	var start := data.get_province(island)
	assert_str(String(start.owner)).is_equal(String(ProvinceDef.OWNER_PLAYER))
	assert_str(String(start.template)).is_equal("islands")
	for r: int in range(1, 4):
		for id: StringName in world.provinces:
			var d := data.get_province(id)
			if d.owner == WorldGenerator.ruler_owner(r):
				assert_float(d.world_pos.distance_to(start.world_pos)).is_greater(world.size.x * 0.25)
	for count: int in [9, 60]:
		var s := _settings(3, 3, count)
		s.islands = 10
		var w := WorldGenerator.generate(data, s)
		assert_int(w.provinces.size()).is_equal(count)
	assert_float(WorldGenerator.size_for(60).x).is_greater(WorldGenerator.size_for(22).x)
