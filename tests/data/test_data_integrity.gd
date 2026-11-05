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
		assert_int(building.workers).is_greater(0)
		for step: StepDef in building.recipe.steps:
			if step is GoToStepDef and (step as GoToStepDef).target == &"resource":
				assert_int(building.work_radius).override_failure_message(
						"%s gathers but has no work_radius" % building.id).is_greater(0)
