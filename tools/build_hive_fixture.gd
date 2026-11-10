extends SceneTree
## Builds the save fixture of Z1 part 3 (save version 34) from the flocks fixture (v33): an
## apiary with 5 hives and its beekeeper, and some minutes of play.
## Run: "$GODOT" --headless --path . -s res://tools/build_hive_fixture.gd

const SOURCE := "res://tests/fixtures/saves/v33_flocks.json"
const PATH := "res://tests/fixtures/saves/v34_hives.json"


func _init() -> void:
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var sim := Simulation.from_dict(SaveMigrations.migrate(doc["state"], 33), registry)
	var province := sim.province
	# The old apiaries of the town get their hives on the first second.
	sim.run_ticks(SimClock.seconds_to_ticks(2.0))
	var def := registry.get_building(&"apiary")
	var apiary: BuildingState = null
	for r: int in range(2, 30):
		for y: int in range(-r, r + 1):
			for x: int in range(-r, r + 1):
				var at := province.grid.size / 2 + Vector2i(x, y)
				if apiary == null and province.placement_error(def, at) == &"":
					province.add_building(def, at, true)
					apiary = province.buildings.get_building(province.grid.occupant(at))
	print("apiary at ", apiary.origin, " hives ", Pens.auto_place(province, apiary, 5))
	sim.execute(SpawnAgentCommand.new(&"beekeeper", apiary.entrance_tile()))
	sim.execute(AssignWorkerCommand.new(sim.ids.next_id - 1, apiary.id))
	sim.run_ticks(SimClock.seconds_to_ticks(150.0))
	sim.events.drain()
	var document := {"header": {"save_version": SaveMigrations.CURRENT_VERSION}, "state": sim.to_dict()}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "", false, true))
	file.close()
	print("written ", PATH)
	quit()
