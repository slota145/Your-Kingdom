extends SceneTree
## E1 part 2 probe (prototype): goods one farm, hop farm and vineyard harvest in 30 minutes
## with all their fields, a farmer and a stockpile close by. Run before and after a change:
## "$GODOT" --headless --path . -s res://src/prototype/e1/farm_yield_probe.gd [-- --minutes=30]

func _init() -> void:
	var minutes := 30
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			minutes = int(arg.trim_prefix("--minutes="))
	for id: StringName in [&"farm", &"hop_farm", &"vineyard"]:
		var sim := SimFixture.make_sim(Vector2i(40, 40))
		sim.province.rare_resource = &"vines"
		var stock := SimFixture.place(sim, &"stockpile", Vector2i(4, 18))
		var farm := SimFixture.place(sim, id, Vector2i(18, 18))
		var worker := SimFixture.spawn(sim, farm.def.worker_kinds[0], farm.entrance_tile())
		sim.execute(AssignWorkerCommand.new(worker.id, farm.id))
		for r: int in range(1, 6):
			for y: int in range(18 - r, 20 + r):
				for x: int in range(18 - r, 20 + r):
					if sim.province.fields.tiles_of(farm.id).size() < farm.def.max_fields:
						sim.execute(PlaceFieldCommand.new(farm.id, Vector2i(x, y)))
		var good := (farm.def.recipe.steps[0] as FieldStepDef).harvest_good
		var made := 0
		var first := -1
		for t: int in SimFixture.ticks(minutes * 60):
			sim.step()
			for event: Dictionary in sim.events.drain():
				if event["type"] == &"good_harvested":
					made += int(event["amount"])
					if first < 0:
						first = sim.clock.tick
		print("%s: %d fields, %s harvested %d in %d min (first at %.0f s), stored %d" % [id,
				sim.province.fields.tiles_of(farm.id).size(), good, made, minutes,
				first / float(SimClock.TICKS_PER_SECOND), stock.stock.total(good)])
	quit()
