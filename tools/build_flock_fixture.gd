extends SceneTree
## Builds the save fixture of Z1 part 2 (save version 33) from the pens fixture (v32): a sheep
## farm with a pen of 4 tiles and 6 sheep, a stud farm (the province gets horse pastures) with
## a pen of 3 tiles, a breeding reserve of 4 at the sheep farm, a shepherd and a groom, and some
## minutes of play.
## Run: "$GODOT" --headless --path . -s res://tools/build_flock_fixture.gd

const SOURCE := "res://tests/fixtures/saves/v32_pens.json"
const PATH := "res://tests/fixtures/saves/v33_flocks.json"


func _init() -> void:
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var sim := Simulation.from_dict(SaveMigrations.migrate(doc["state"], 32), registry)
	var province := sim.province
	province.rare_resource = &"horses"
	var farm := _place(province, registry.get_building(&"sheep_farm"))
	var stud := _place(province, registry.get_building(&"stud_farm"))
	print("sheep farm at ", farm.origin, " pens ", Pens.auto_place(province, farm, 4))
	print("stud farm at ", stud.origin, " pens ", Pens.auto_place(province, stud, 3))
	farm.yard.add(&"sheep", 4)
	# Their keepers (the town has no free people): a shepherd and a groom.
	for building: BuildingState in [farm, stud]:
		sim.execute(SpawnAgentCommand.new(building.def.worker_kinds[0], building.entrance_tile()))
		sim.execute(AssignWorkerCommand.new(sim.ids.next_id - 1, building.id))
	sim.execute(SetHerdKeepCommand.new(farm.id, 4))
	sim.run_ticks(SimClock.seconds_to_ticks(180.0))
	sim.events.drain()
	var document := {"header": {"save_version": SaveMigrations.CURRENT_VERSION}, "state": sim.to_dict()}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "", false, true))
	file.close()
	print("written ", PATH)
	quit()


func _place(province: ProvinceSim, def: BuildingDef) -> BuildingState:
	for r: int in range(2, 30):
		for y: int in range(-r, r + 1):
			for x: int in range(-r, r + 1):
				var at := province.grid.size / 2 + Vector2i(x, y)
				if province.placement_error(def, at) == &"" and _room(province, at):
					province.add_building(def, at, true)
					return province.buildings.get_building(province.grid.occupant(at))
	return null


## Free ground around a 2×2 plot, for its pen.
func _room(province: ProvinceSim, at: Vector2i) -> bool:
	for y: int in range(at.y - 2, at.y + 4):
		for x: int in range(at.x - 2, at.x + 4):
			if province.grid.occupant(Vector2i(x, y)) != 0 or province.fields.has_field(Vector2i(x, y)):
				return false
	return true
