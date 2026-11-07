extends SceneTree
## Builds the save fixture of N1 part 1 (save version 15) from the M5 harbour fixture (v11):
## a stone quay joins the port and the shipyard into one harbour, a timber pier carries a
## mooring west of the port, and a second pier is being laid (ordered, partly built).
## Run: "$GODOT" --headless --path . -s res://tools/build_quay_fixture.gd

const SOURCE := "res://tests/fixtures/saves/v11_voyage.json"
const PATH := "res://tests/fixtures/saves/v15_quays.json"


func _init() -> void:
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var sim := Simulation.from_dict(SaveMigrations.migrate(doc["state"], 11), registry)
	var province := sim.province
	var stone: Array[Vector2i] = []
	for y: int in range(30, 32):
		for x: int in range(24, 30):
			stone.append(Vector2i(x, y))
	_lay(province, stone, TileGrid.STONE_QUAY)
	_lay(province, [Vector2i(16, 30), Vector2i(17, 30), Vector2i(16, 31), Vector2i(17, 31)], TileGrid.PIER)
	var errors: Array[StringName] = []
	errors.append(sim.execute(PlaceBuildingCommand.new(&"mooring", Vector2i(16, 30), true)))
	var stock := 0
	for b: BuildingState in province.buildings.all():
		if b.def.id == &"stockpile" and stock == 0:
			b.stock.add(&"planks", 20)
			stock = b.id
	var pier: Array[Vector2i] = [Vector2i(12, 30), Vector2i(12, 31), Vector2i(12, 32)]
	errors.append(sim.execute(BuildQuayCommand.new(pier, TileGrid.PIER)))
	var ticks := 0
	while ticks < 6000 and province.grid.quay_count() < 17:
		sim.step()
		ticks += 1
	var document := {"header": {"save_version": SaveMigrations.CURRENT_VERSION}, "state": sim.to_dict()}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "", false, true))
	file.close()
	print("saved %s (%s): quay tiles %d, quay sites %d, ticks %d" % [PATH, errors, province.grid.quay_count(),
			province.paving.size(), ticks])
	quit()


func _lay(province: ProvinceSim, tiles: Array[Vector2i], quay: int) -> void:
	for tile: Vector2i in tiles:
		province.grid.set_quay(tile, quay)
		province.refresh_tile(tile)
	province.refresh_fairways()
