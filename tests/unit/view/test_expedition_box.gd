extends GdUnitTestSuite
## M6 part 2 (owner's decision 2026-11-06): the expedition box (town hall and world map)
## prepares an expedition by its kind only and shows how it goes; on the world map a right
## click on a province with the ready expedition selected sends it there.


func _town() -> Simulation:
	var registry := SimFixture.registry()
	var sim := Simulation.from_map(registry, registry.get_map(&"riverlands"))
	sim.world = WorldSim.from_def(registry.get_world(&"kingdom"), registry)
	sim.world.get_province(WorldSim.FIRST_ID).owner = ProvinceDef.OWNER_PLAYER
	return sim


func test_box_prepares_by_kind_and_shows_the_gathering() -> void:
	var sim := _town()
	var box: ExpeditionBox = auto_free(ExpeditionBox.new())
	add_child(box)
	box.show_for(sim, WorldSim.FIRST_ID)
	assert_bool(box.visible).is_true()
	assert_bool(box._land.disabled).is_true()   # no kit in store yet
	assert_bool(box._sea.disabled).is_true()
	assert_str(box._why.text).is_not_empty()
	sim.treasury.gold = 500
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == &"stockpile":
			b.stock.add(&"wood", 100)
			b.stock.add(&"bread", 30)
	box.show_for(sim, WorldSim.FIRST_ID)
	assert_bool(box._land.disabled).is_false()
	assert_bool(box._sea.disabled).is_true()   # no cog
	var sent: Array[Command] = []
	box.command_requested.connect(func(command: Command) -> void: sent.append(command))
	box._land.pressed.emit()
	assert_int(sent.size()).is_equal(1)
	assert_str(String(sim.execute(sent[0]))).is_empty()
	box.show_for(sim, WorldSim.FIRST_ID)
	assert_bool(box._buttons.visible).is_false()
	assert_bool(box._disband.visible).is_true()
	assert_str(box._status.text).is_not_empty()
	# An empty province has no box; a single-province game neither.
	box.show_for(sim, sim.world.id_of(&"willow_vale"))
	assert_bool(box.visible).is_false()


func test_right_click_sends_the_selected_expedition() -> void:
	var sim := _town()
	sim.treasury.gold = 500
	var departure := Departure.new()
	departure.id = 77
	departure.state = Departure.State.READY
	sim.province.departure = departure
	var screen: WorldMapScreen = auto_free(WorldMapScreen.new())
	add_child(screen)
	screen.open(sim)
	var sent: Array[Command] = []
	screen.command_requested.connect(func(command: Command) -> void:
		sent.append(command)
		sim.execute(command))
	screen._canvas.expedition_from = WorldSim.FIRST_ID
	screen._expedition_clicked(WorldSim.FIRST_ID)
	# Not to an island by land: the panel says why, nothing is sent.
	screen._send(WorldSim.FIRST_ID, sim.world.id_of(&"salt_isle"))
	assert_int(sent.size()).is_equal(0)
	assert_str(screen._hint.text).contains(tr("ui.command_error.not_a_neighbour"))
	screen._send(WorldSim.FIRST_ID, sim.world.id_of(&"willow_vale"))
	assert_int(sent.size()).is_equal(1)
	assert_int(departure.target).is_equal(sim.world.id_of(&"willow_vale"))
	assert_int(screen._canvas.expedition_from).is_equal(0)
