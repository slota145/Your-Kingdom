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


## Owner 2026-11-11: wheat and hops stand on their fields like the vines.
func test_wheat_and_hops_stand_on_their_fields() -> void:
	var data := DataRegistry.new()
	data.load_from("res://data")
	assert_str(String(VineLayer.crop_of(data.get_building(&"farm")))).is_equal("grain")
	assert_str(String(VineLayer.crop_of(data.get_building(&"hop_farm")))).is_equal("hops")
	assert_str(String(VineLayer.crop_of(data.get_building(&"vineyard")))).is_equal("grapes")
	assert_str(String(VineLayer.crop_of(data.get_building(&"pigsty")))).is_empty()
	var fields := FieldStore.new()
	var tile := Vector2i(3, 4)
	fields.add(tile, 7)
	assert_str(VineLayer.state_of(fields, tile, 0, &"grain")).is_empty()
	assert_str(VineLayer.state_of(fields, tile, 0, &"hops")).is_equal("poles")
	fields.sow(tile, 0, 300, true)
	assert_str(VineLayer.state_of(fields, tile, 10, &"grain")).is_equal("sprout")
	assert_str(VineLayer.state_of(fields, tile, 250, &"hops")).is_equal("full")
	assert_str(VineLayer.state_of(fields, tile, 300, &"grain")).is_equal("ripe")
	for crop: StringName in VineLayer.CROPS:
		var spec: Array = VineLayer.CROPS[crop]
		var names: Array = [spec[1], spec[3]] + (spec[2] as Array)
		for state: Variant in names:
			if String(state) != "":
				assert_object(load("res://assets/%s/%s.png" % [spec[0], state])).override_failure_message(
						"%s/%s" % [spec[0], state]).is_not_null()
