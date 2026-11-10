extends SceneTree
## Builds the save fixture of Z1 part 1 (save version 32) from the M4b-2 town (v7): its old
## pigsty migrated with a pen of the 5 freed tiles, a second pigsty with an L-shaped pen of 4
## tiles and a breeding reserve of 3, and some minutes of play (the swineherds in their pens).
## Run: "$GODOT" --headless --path . -s res://tools/build_pens_fixture.gd

const SOURCE := "res://tests/fixtures/saves/v7_town.json"
const PATH := "res://tests/fixtures/saves/v32_pens.json"


func _init() -> void:
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var sim := Simulation.from_dict(SaveMigrations.migrate(doc["state"], 7), registry)
	var province := sim.province
	sim.treasury.gold = maxi(sim.treasury.gold, 200)
	var def := registry.get_building(&"pigsty")
	var sty: BuildingState = null
	for r: int in range(2, 20):
		for y: int in range(-r, r + 1):
			for x: int in range(-r, r + 1):
				var at := province.grid.size / 2 + Vector2i(x, y)
				if sty == null and province.placement_error(def, at) == &"":
					province.add_building(def, at, true)
					sty = province.buildings.get_building(province.grid.occupant(at))
	var placed := Pens.auto_place(province, sty, 4)
	print("second pigsty at ", sty.origin, " pens ", placed)
	sim.execute(SetHerdKeepCommand.new(sty.id, 3))
	sim.run_ticks(SimClock.seconds_to_ticks(180.0))
	sim.events.drain()
	var document := {"header": {"save_version": SaveMigrations.CURRENT_VERSION}, "state": sim.to_dict()}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "", false, true))
	file.close()
	print("written ", PATH)
	quit()
