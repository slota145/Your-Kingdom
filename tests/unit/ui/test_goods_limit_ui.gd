extends GdUnitTestSuite
## E5: the "Limit" column of the "Kingdom stocks" window and the limit rows of a workshop's
## panel send the player's limit as a command and show what the province holds.


func _sent(node: Node, sim: Simulation) -> Array[Command]:
	var commands: Array[Command] = []
	node.command_requested.connect(func(command: Command) -> void:
		commands.append(command)
		sim.execute(command))
	return commands


func test_the_stocks_window_sets_and_shows_a_limit() -> void:
	var sim := SimFixture.make_sim()
	var window: KingdomStockWindow = auto_free(KingdomStockWindow.new())
	add_child(window)
	window.open(sim.province)
	var commands := _sent(window, sim)
	var row: Dictionary = window._rows[&"planks"]
	(row["limit_amount"] as SpinBox).value = 40
	(row["limit_tick"] as CheckBox).button_pressed = true
	assert_int(sim.province.goods_limits.get(&"planks", -1)).is_equal(40)
	assert_object(commands[commands.size() - 1]).is_instanceof(SetGoodsLimitCommand)
	(row["limit_tick"] as CheckBox).button_pressed = false
	assert_bool(sim.province.goods_limits.has(&"planks")).is_false()
	# Set elsewhere (the panel), the window shows it on its next refresh.
	sim.province.goods_limits[&"bread"] = 25
	window._refresh()
	var bread: Dictionary = window._rows[&"bread"]
	assert_bool((bread["limit_tick"] as CheckBox).button_pressed).is_true()
	assert_int(int((bread["limit_amount"] as SpinBox).value)).is_equal(25)
	window.queue_free()


func test_a_workshop_panel_offers_the_limit_of_its_goods() -> void:
	var sim := SimFixture.make_sim()
	var mill := SimFixture.place(sim, &"sawmill", Vector2i(12, 6))
	var panel: BuildingPanel = auto_free(BuildingPanel.new())
	add_child(panel)
	panel.show_building(sim.province, mill.id)
	_sent(panel, sim)
	assert_bool(panel._limit_box.visible).is_true()
	assert_array(Array(panel._limit_goods)).is_equal([&"planks"])
	var row: Dictionary = panel._limit_rows[&"planks"]
	(row["amount"] as SpinBox).value = 0
	(row["tick"] as CheckBox).button_pressed = true
	assert_int(sim.province.goods_limits.get(&"planks", -1)).is_equal(0)
	panel._refresh()
	assert_bool(panel._limit_status.visible).is_true()
	# A farm has none: its fields go on growing.
	var farm := SimFixture.place(sim, &"farm", Vector2i(20, 16))
	panel.show_building(sim.province, farm.id)
	assert_bool(panel._limit_box.visible).is_false()
	panel.queue_free()
