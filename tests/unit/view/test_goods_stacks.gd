extends GdUnitTestSuite
## G2: stacks of goods drawn by PixelLab grow one piece at a time, so each sheet has one
## frame per piece a slot holds (stack_size), StackSprite.FRAME_W wide.

const SHEETS_PER_PIECE: Array[StringName] = [&"wood", &"planks", &"stone", &"bricks", &"clay",
		&"flour", &"grain", &"bread", &"fish", &"grapes", &"meat", &"hides", &"wool", &"cloth",
		&"clothes", &"hops", &"beer", &"wine", &"mead", &"honey", &"tar"]


func test_every_good_has_one_frame_per_piece() -> void:
	var data := DataRegistry.new()
	data.load_from("res://data")
	for good: StringName in SHEETS_PER_PIECE:
		var def := data.get_def(&"good", good) as GoodDef
		assert_object(def).override_failure_message(String(good)).is_not_null()
		var tex := load("res://assets/goods/stacks/%s.png" % good) as Texture2D
		assert_object(tex).override_failure_message(String(good)).is_not_null()
		assert_int(tex.get_width()).override_failure_message(
				"%s: %d px for %d pieces" % [good, tex.get_width(), def.stack_size]).is_equal(
				def.stack_size * StackSprite.FRAME_W)


func test_stack_sprite_shows_the_frame_of_each_piece() -> void:
	var sprite := StackSprite.new()
	sprite.show_stack(&"wood", 7, 20)
	assert_bool(sprite.visible).is_true()
	assert_float(sprite.region_rect.position.x).is_equal(6.0 * StackSprite.FRAME_W)
	sprite.show_stack(&"wood", 0, 20)
	assert_bool(sprite.visible).is_false()
	sprite.free()
