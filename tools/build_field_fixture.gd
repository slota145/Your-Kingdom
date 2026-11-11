extends SceneTree
## Builds the save fixture of E1 part 2 (save version 35) from the hives fixture (v34): a farm
## with 12 fields and its farmer, saved while part of the field is sown and waits for the rest
## and the farm keeps a fraction of its extra yield.
## Run: "$GODOT" --headless --path . -s res://tools/build_field_fixture.gd

const SOURCE := "res://tests/fixtures/saves/v34_hives.json"
const PATH := "res://tests/fixtures/saves/v35_fields.json"


func _init() -> void:
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var sim := Simulation.from_dict(SaveMigrations.migrate(doc["state"], 34), registry)
	var province := sim.province
	var def := registry.get_building(&"farm")
	var farm: BuildingState = null
	for r: int in range(2, 40):
		for y: int in range(-r, r + 1):
			for x: int in range(-r, r + 1):
				var at := province.grid.size / 2 + Vector2i(x, y)
				if farm == null and province.placement_error(def, at) == &"":
					province.add_building(def, at, true)
					farm = province.buildings.get_building(province.grid.occupant(at))
	for r: int in range(1, 5):
		for y: int in range(-r, r + 2):
			for x: int in range(-r, r + 2):
				if province.fields.tiles_of(farm.id).size() < 12:
					sim.execute(PlaceFieldCommand.new(farm.id, farm.origin + Vector2i(x, y)))
	sim.execute(SpawnAgentCommand.new(&"farmer", farm.entrance_tile()))
	sim.execute(AssignWorkerCommand.new(sim.ids.next_id - 1, farm.id))
	farm.field_yield_carry = 0.6
	var waiting := 0
	for i: int in SimClock.seconds_to_ticks(240.0):
		sim.step()
		sim.events.drain()
		waiting = 0
		for tile: Vector2i in province.fields.tiles_of(farm.id):
			if province.fields.is_waiting(tile):
				waiting += 1
		if waiting >= 5:
			break
	print("farm at ", farm.origin, ", ", province.fields.tiles_of(farm.id).size(), " fields, ",
			waiting, " waiting at ", sim.clock.tick)
	var document := {"header": {"save_version": SaveMigrations.CURRENT_VERSION}, "state": sim.to_dict()}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "", false, true))
	file.close()
	print("written ", PATH)
	quit()
