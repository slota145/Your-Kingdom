extends GdUnitTestSuite
## What a building makes and uses per minute (ROADMAP UI-3 part 1): the full-crew estimate of
## the build menu and the record of what a building really made (the building panel).


func test_the_sawmill_makes_twice_the_planks_of_the_wood_it_uses() -> void:
	var data := SimFixture.registry()
	var def := data.get_building(&"sawmill")
	var rates := ProductionEstimate.full_crew(def, data)
	var made: Dictionary = rates["made"]
	var used: Dictionary = rates["used"]
	assert_array(made.keys()).contains_exactly([&"planks"])
	assert_array(used.keys()).contains_exactly([&"wood"])
	assert_float(float(made[&"planks"])).is_equal_approx(2.0 * float(used[&"wood"]), 0.001)
	# Six seconds of sawing and a walk of 10 tiles to the storage and back for the wood (the
	# planks go on the yard by the door).
	var cycle := 6.0 + 2.0 * ProvinceAbstract.DEFAULT_WALK / Movement.BASE_SPEED
	assert_float(float(made[&"planks"])).is_equal_approx(2.0 * 60.0 / cycle, 0.001)
	# Research that speeds the work up gives more.
	var faster := ProductionEstimate.full_crew(def, data, 2.0)
	assert_float(float((faster["made"] as Dictionary)[&"planks"])).is_greater(float(made[&"planks"]))


func test_makers_of_every_kind_have_a_rate() -> void:
	var data := SimFixture.registry()
	for id: StringName in [&"woodcutter", &"quarry", &"farm", &"orchard", &"fishing_hut", &"hunter_lodge",
			&"bakery", &"apiary", &"sheep_farm", &"deep_mine"]:
		var made: Dictionary = ProductionEstimate.full_crew(data.get_building(id), data)["made"]
		assert_bool(made.is_empty()).override_failure_message("%s makes nothing" % id).is_false()
		for good: StringName in made:
			assert_float(float(made[good])).override_failure_message("%s: %s" % [id, good]).is_greater(0.0)
	# A tavern uses beer up and makes no good; a house and a stockpile neither.
	assert_bool((ProductionEstimate.full_crew(data.get_building(&"tavern"), data)["used"] as Dictionary).is_empty()).is_false()
	for id: StringName in [&"hut", &"stockpile"]:
		var rates := ProductionEstimate.full_crew(data.get_building(id), data)
		assert_bool((rates["made"] as Dictionary).is_empty() and (rates["used"] as Dictionary).is_empty()).is_true()


func test_a_working_sawmill_records_what_it_made_near_the_estimate() -> void:
	var sim := SimFixture.make_sim()
	var store := SimFixture.place(sim, &"stockpile", Vector2i(4, 4))
	store.stock.add(&"wood", 60)
	var mill := SimFixture.place(sim, &"sawmill", Vector2i(12, 6))
	var sawyer := SimFixture.spawn(sim, &"sawyer", mill.entrance_tile())
	assert_str(String(sim.execute(AssignWorkerCommand.new(sawyer.id, mill.id)))).is_equal("")
	sim.run_ticks(SimFixture.ticks(180))
	var ledger := sim.province.ledger
	assert_bool(ledger.has_building(mill.id)).is_true()
	var made := ledger.of_building(mill.id).made_per_minute(&"planks", sim.province.tick)
	var used := ledger.of_building(mill.id).used_per_minute(&"wood", sim.province.tick)
	assert_float(made).is_greater(0.0)
	assert_float(made).is_equal_approx(2.0 * used, 1.0)
	# The estimate (a storage 10 tiles away) is near what it really does (about 8 away).
	var full: float = (ProductionEstimate.full_crew(mill.def, sim.data)["made"] as Dictionary)[&"planks"]
	assert_float(made).is_between(full * 0.6, full * 1.5)
	# Demolished, the building's record goes.
	sim.province.remove_building(mill.id)
	assert_bool(ledger.has_building(mill.id)).is_false()
