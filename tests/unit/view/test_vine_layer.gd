extends GdUnitTestSuite
## Review fix 2026-11-07: vineyard fields show trellis rows whose vines follow the field.


func test_vine_state_follows_the_field() -> void:
	var fields := FieldStore.new()
	var tile := Vector2i(3, 4)
	fields.add(tile, 7)
	assert_str(VineLayer.state_of(fields, tile, 0)).is_equal("pruned")
	fields.set_stage(tile, FieldStore.Stage.PLOWED)
	assert_str(VineLayer.state_of(fields, tile, 0)).is_equal("pruned")
	fields.sow(tile, 0, 300)
	# E1 part 2: a sown tile waits for the rest of the vineyard, still pruned.
	assert_str(VineLayer.state_of(fields, tile, 10)).is_equal("pruned")
	assert_int(fields.start_if_ready(7, 0).size()).is_equal(1)
	assert_str(VineLayer.state_of(fields, tile, 10)).is_equal("bud")
	assert_str(VineLayer.state_of(fields, tile, 150)).is_equal("leaf")
	assert_str(VineLayer.state_of(fields, tile, 250)).is_equal("full")
	assert_str(VineLayer.state_of(fields, tile, 300)).is_equal("ripe")


func test_only_grape_fields_get_vines() -> void:
	var data := DataRegistry.new()
	data.load_from("res://data")
	assert_bool(VineLayer.is_vineyard(data.get_building(&"vineyard"))).is_true()
	assert_bool(VineLayer.is_vineyard(data.get_building(&"farm"))).is_false()
	assert_bool(VineLayer.is_vineyard(data.get_building(&"hop_farm"))).is_false()
