extends GdUnitTestSuite
## Every definition in res://data loads, has a valid unique id and only references existing ids.

var _registry: DataRegistry


func before() -> void:
	_registry = DataRegistry.new()
	_registry.load_from("res://data")


func test_data_loads_without_errors() -> void:
	assert_array(Array(_registry.errors)).is_empty()


func test_slice_goods_exist() -> void:
	for id: StringName in [&"wood", &"grain", &"flour", &"bread"]:
		assert_bool(_registry.has_def(&"good", id)).override_failure_message(
				"missing good '%s'" % id).is_true()


func test_file_name_matches_id() -> void:
	for kind: StringName in _registry.kinds():
		for def: GameDef in _registry.all_of(kind):
			assert_str(def.resource_path.get_file().get_basename()).is_equal(String(def.id))


func test_building_costs_reference_existing_goods() -> void:
	for building: BuildingDef in _registry.buildings():
		for good_id: StringName in building.build_cost:
			assert_bool(_registry.has_def(&"good", good_id)).override_failure_message(
					"%s: unknown good '%s' in build_cost" % [building.id, good_id]).is_true()
			assert_int(building.build_cost[good_id]).is_greater(0)


func test_building_entrance_on_footprint_edge() -> void:
	for building: BuildingDef in _registry.buildings():
		assert_bool(building.is_entrance_on_edge()).override_failure_message(
				"%s: entrance %s not on edge of %s" % [building.id, building.entrance, building.footprint]
		).is_true()


func test_registry_rejects_duplicates_and_bad_ids() -> void:
	var registry := DataRegistry.new()
	var a := GoodDef.new()
	a.id = &"bread"
	var b := GoodDef.new()
	b.id = &"bread"
	var bad := GoodDef.new()
	bad.id = &"Bad-Id"
	registry._register(a, "a")
	registry._register(b, "b")
	registry._register(bad, "c")
	assert_int(registry.errors.size()).is_equal(2)
	assert_int(registry.goods().size()).is_equal(1)


func test_recipes_reference_existing_goods_and_nodes() -> void:
	for def: GameDef in _registry.all_of(&"recipe"):
		var recipe := def as RecipeDef
		assert_array(recipe.steps).override_failure_message("%s: no steps" % recipe.id).is_not_empty()
		for step: StepDef in recipe.steps:
			assert_str(String(step.get_step_kind())).override_failure_message(
					"%s: step without kind" % recipe.id).is_not_empty()
			var goods: Array[StringName] = []
			if step is FetchStepDef:
				goods.append((step as FetchStepDef).good)
			elif step is ProduceStepDef:
				goods.append((step as ProduceStepDef).output)
			elif step is GoToStepDef and (step as GoToStepDef).target == &"resource":
				var node := (step as GoToStepDef).resource
				assert_bool(_registry.has_def(&"resource_node", node)).override_failure_message(
						"%s: unknown resource node '%s'" % [recipe.id, node]).is_true()
			for good: StringName in goods:
				assert_bool(_registry.has_def(&"good", good)).override_failure_message(
						"%s: unknown good '%s'" % [recipe.id, good]).is_true()


func test_resource_nodes_give_existing_goods() -> void:
	for def: GameDef in _registry.all_of(&"resource_node"):
		var node := def as ResourceNodeDef
		assert_bool(_registry.has_def(&"good", node.good)).override_failure_message(
				"%s: unknown good '%s'" % [node.id, node.good]).is_true()


func test_gathering_buildings_have_work_radius_and_workers() -> void:
	for building: BuildingDef in _registry.buildings():
		if building.recipe == null:
			continue
		assert_int(building.worker_count()).is_greater(0)
		for step: StepDef in building.recipe.steps:
			if step is GoToStepDef and (step as GoToStepDef).target == &"resource":
				assert_int(building.work_radius).override_failure_message(
						"%s gathers but has no work_radius" % building.id).is_greater(0)


func test_house_levels_are_consistent() -> void:
	for building: BuildingDef in _registry.buildings():
		for i: int in building.house_levels.size():
			var level := building.house_levels[i]
			assert_int(level.level).is_equal(i + 1)
			var weights := 0
			for need: NeedDef in level.needs:
				weights += level.weight_of(need)
				for good: StringName in need.goods:
					assert_bool(_registry.has_def(&"good", good)).is_true()
				if need.is_service():
					var service := _registry.get_building(need.service)
					assert_object(service).is_not_null()
					assert_int(service.service_radius).is_greater(0)
			assert_int(weights).override_failure_message("%s: weights must sum to 100" % level.id) \
					.is_equal(100)
			for good: StringName in level.upgrade_cost:
				assert_bool(_registry.has_def(&"good", good)).is_true()
			if i > 0:
				assert_dict(level.upgrade_cost).is_not_empty()
			for need_id: StringName in level.need_weights:
				assert_bool(level.needs.any(func(n: NeedDef) -> bool: return n.id == need_id)) \
						.override_failure_message("%s: weight for unused need %s" % [level.id, need_id]).is_true()


func test_workshop_inputs_and_terrain_needs_exist() -> void:
	for building: BuildingDef in _registry.buildings():
		for good: StringName in building.input_goods:
			assert_bool(_registry.has_def(&"good", good)).is_true()
		for good: StringName in building.default_reserves:
			assert_bool(_registry.has_def(&"good", good)).is_true()
			assert_int(building.storage_slots).is_greater(0)
		if building.needs_terrain_near != &"":
			assert_bool(_registry.has_def(&"terrain", building.needs_terrain_near)).is_true()
			assert_int(building.work_radius).is_greater(0)
		if building.recipe != null:
			for step: StepDef in building.recipe.steps:
				if step is ProduceStepDef:
					for good: StringName in (step as ProduceStepDef).consume:
						assert_bool(building.input_goods.has(good)).override_failure_message(
								"%s consumes %s without an input store" % [building.id, good]).is_true()
				if step is GoToStepDef and (step as GoToStepDef).target == &"shore":
					assert_str(String(building.needs_terrain_near)).is_not_empty()


func test_terrain_indices_are_unique_and_dense() -> void:
	var by_index := _registry.terrains_by_index()
	assert_int(by_index.size()).is_equal(_registry.all_of(&"terrain").size())
	for terrain: TerrainDef in by_index:
		assert_object(terrain).is_not_null()
		if terrain.resource_node != &"":
			assert_bool(_registry.has_def(&"resource_node", terrain.resource_node)).is_true()


func test_slice_buildings_exist() -> void:
	for id: StringName in [&"town_hall", &"stockpile", &"hut", &"well", &"woodcutter", &"farm",
			&"mill", &"bakery"]:
		assert_bool(_registry.has_def(&"building", id)).override_failure_message(
				"missing building '%s'" % id).is_true()


func test_farms_can_have_fields() -> void:
	for building: BuildingDef in _registry.buildings():
		if building.max_fields > 0:
			assert_int(building.work_radius).is_greater(0)
			assert_float(building.field_grow_time).is_greater(0.0)


## Every building has a visual definition whose art exists for every state it can be in:
## construction phases, finished (or yard), house levels with row variants, scaffolding.
func test_every_building_has_visuals_and_art() -> void:
	for building: BuildingDef in _registry.buildings():
		var visual := BuildingVisualDef.for_building(building.id)
		assert_object(visual).override_failure_message("%s: no data/visuals entry" % building.id).is_not_null()
		if visual == null:
			continue
		var names: Array[String] = ["construction_1", "construction_2"]
		if not visual.yard:
			names.append("base")
			for v: int in range(2, visual.base_variants + 1):
				names.append("base_%d" % v)
		for i: int in visual.level_art.size():
			var art := visual.level_art[i]
			if visual.row_from_level > 0 and i + 1 >= visual.row_from_level:
				for variant: String in ["single", "end_a", "middle", "end_b"]:
					for axis: String in ["x", "y"]:
						names.append("%s_%s_%s" % [art, variant, axis])
			else:
				names.append(art)
		if building.house_levels.size() > 1:
			names.append("upgrade_scaffold")
		for name: String in names:
			for ext: String in [".png", ".json"]:
				var path := ArtPaths.resolve("buildings/%s/%s%s" % [visual.art_id, name, ext])
				assert_bool(FileAccess.file_exists(path) or ResourceLoader.exists(path)) \
						.override_failure_message("missing art " + path).is_true()


func test_every_profession_has_a_visual() -> void:
	var kinds: Array[StringName] = [Population.HOUSEHOLDER_KIND, Population.SETTLER_KIND]
	for building: BuildingDef in _registry.buildings():
		for kind: StringName in building.worker_kinds:
			if not kinds.has(kind):
				kinds.append(kind)
	for kind: StringName in kinds:
		assert_object(AgentVisualDef.for_kind(kind)).override_failure_message(
				"no data/visuals/agents/%s.tres" % kind).is_not_null()


## Every building can be built from some tab of the build menu.
func test_every_building_is_in_the_build_menu() -> void:
	var listed: Array[StringName] = []
	for tab: Dictionary in BuildMenu.TABS:
		for id: StringName in tab["buildings"]:
			listed.append(id)
	for building: BuildingDef in _registry.buildings():
		assert_bool(listed.has(building.id)).override_failure_message(
				"%s is in no build menu tab" % building.id).is_true()
