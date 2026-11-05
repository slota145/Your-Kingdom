extends GdUnitTestSuite


func test_same_seed_same_numbers() -> void:
	var a := SimRng.new(42)
	var b := SimRng.new(42)
	for i: int in 10:
		assert_int(a.stream(&"jobs").randi()).is_equal(b.stream(&"jobs").randi())


func test_streams_are_independent() -> void:
	var a := SimRng.new(7)
	var b := SimRng.new(7)
	b.stream(&"other").randi()
	b.stream(&"other").randi()
	assert_int(a.stream(&"jobs").randi()).is_equal(b.stream(&"jobs").randi())


func test_state_survives_json_round_trip() -> void:
	var rng := SimRng.new(123456789)
	for i: int in 5:
		rng.stream(&"jobs").randi()
	var text := JSON.stringify(rng.to_dict())
	var restored := SimRng.from_dict(JSON.parse_string(text))
	for i: int in 10:
		assert_int(restored.stream(&"jobs").randi()).is_equal(rng.stream(&"jobs").randi())
