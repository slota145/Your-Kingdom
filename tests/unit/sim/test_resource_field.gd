extends GdUnitTestSuite


func _field() -> ResourceField:
	var field := ResourceField.new(Vector2i(16, 16))
	return field


func test_tree_gives_logs_then_becomes_stump() -> void:
	var field := _field()
	var tree := SimFixture.registry().get_resource_node(&"tree")
	field.place(Vector2i(3, 3), tree)
	# Trees are walkable since M4b-2 (a dense forest only slows people down).
	assert_bool(field.blocks_movement(Vector2i(3, 3))).is_false()
	for i: int in tree.amount:
		assert_int(field.take(Vector2i(3, 3))).is_equal(tree.per_gather)
	assert_int(field.take(Vector2i(3, 3))).is_equal(0)
	assert_bool(field.is_depleted(Vector2i(3, 3))).is_true()
	assert_bool(field.blocks_movement(Vector2i(3, 3))).is_false()


func test_nearest_skips_claimed_nodes() -> void:
	var field := _field()
	var tree := SimFixture.registry().get_resource_node(&"tree")
	field.place(Vector2i(5, 5), tree)
	field.place(Vector2i(8, 5), tree)
	assert_vector(field.find_nearest(&"tree", Vector2i(4, 5), 10)).is_equal(Vector2i(5, 5))
	assert_bool(field.claim(Vector2i(5, 5), 7)).is_true()
	assert_bool(field.claim(Vector2i(5, 5), 8)).is_false()
	assert_vector(field.find_nearest(&"tree", Vector2i(4, 5), 10)).is_equal(Vector2i(8, 5))
	assert_vector(field.find_nearest(&"tree", Vector2i(4, 5), 2)).is_equal(Vector2i(-1, -1))


func test_round_trip() -> void:
	var field := _field()
	var tree := SimFixture.registry().get_resource_node(&"tree")
	field.place(Vector2i(1, 2), tree)
	field.place(Vector2i(4, 2), tree)
	field.take(Vector2i(4, 2))
	field.claim(Vector2i(1, 2), 33)
	var text := JSON.stringify(field.to_dict())
	var back := ResourceField.from_dict(JSON.parse_string(text), Vector2i(16, 16), SimFixture.registry())
	assert_str(JSON.stringify(back.to_dict())).is_equal(text)
	assert_int(back.amount(Vector2i(4, 2))).is_equal(tree.amount - 1)
	assert_int(back.claimant(Vector2i(1, 2))).is_equal(33)


func test_rock_blocks_movement_until_quarried() -> void:
	var field := _field()
	var rock := SimFixture.registry().get_resource_node(&"rock")
	field.place(Vector2i(4, 4), rock)
	assert_bool(field.blocks_movement(Vector2i(4, 4))).is_true()
