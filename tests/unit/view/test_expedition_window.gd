extends GdUnitTestSuite
## M6 part 2: the town hall's expedition window lists the empty provinces with a button by sea
## and by land where there is such a way, and shows the expedition getting ready.


func test_window_lists_empty_provinces_and_the_departure() -> void:
	var registry := SimFixture.registry()
	var sim := Simulation.from_map(registry, registry.get_map(&"riverlands"))
	sim.world = WorldSim.from_def(registry.get_world(&"kingdom"), registry)
	sim.world.get_province(WorldSim.FIRST_ID).owner = ProvinceDef.OWNER_PLAYER
	var window: ExpeditionWindow = auto_free(ExpeditionWindow.new())
	add_child(window)
	window.open(sim)
	var buttons := _buttons(window)
	# Willow Vale and Amber Coast by land, the coastal ones and the islands by sea.
	assert_int(buttons.size()).is_greater_equal(6)
	for button: Button in buttons:
		if button.text.contains("(") and not button.text.is_empty():
			assert_bool(button.disabled).is_true()   # no kit in store, no cog: nothing yet
	sim.treasury.gold = 500
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == &"stockpile":
			b.stock.add(&"wood", 100)
			b.stock.add(&"bread", 30)
	assert_str(String(sim.execute(SendExpeditionCommand.new(sim.world.id_of(&"willow_vale"), false)))).is_empty()
	window._refresh()
	assert_str(window._status.text).is_not_empty()


func _buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in node.get_children():
		if child is Button and not child.is_queued_for_deletion():
			result.append(child as Button)
		result.append_array(_buttons(child))
	return result
