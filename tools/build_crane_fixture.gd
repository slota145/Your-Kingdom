extends SceneTree
## Builds the save fixture of N1 part 2 (save version 16) from the quay fixture (v15): a
## cargo crane on a pier by the mooring lifts wood onto a cog moored there (the save is taken
## in the middle of a lift), and a port warehouse on a pier block west of it holds goods.
## Run: "$GODOT" --headless --path . -s res://tools/build_crane_fixture.gd

const SOURCE := "res://tests/fixtures/saves/v15_quays.json"
const PATH := "res://tests/fixtures/saves/v16_crane.json"


func _init() -> void:
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var sim := Simulation.from_dict(SaveMigrations.migrate(doc["state"], 15), registry)
	var province := sim.province
	# Let the pier of the v15 fixture be finished first.
	var ticks := 0
	while ticks < 6000 and not province.paving.is_empty():
		sim.step()
		ticks += 1
	_lay(province, [Vector2i(18, 30), Vector2i(19, 30), Vector2i(18, 31), Vector2i(19, 31)])
	var block: Array[Vector2i] = []
	for y: int in range(30, 33):
		for x: int in range(5, 8):
			block.append(Vector2i(x, y))
	_lay(province, block)
	var errors: Array[StringName] = []
	errors.append(sim.execute(PlaceBuildingCommand.new(&"crane", Vector2i(18, 30), true)))
	var crane := province.buildings.get_building(sim.ids.next_id - 1)
	errors.append(sim.execute(PlaceBuildingCommand.new(&"port_warehouse", Vector2i(5, 30), true)))
	var warehouse := province.buildings.get_building(sim.ids.next_id - 1)
	warehouse.stock.add(&"planks", 10)
	warehouse.stock.add(&"tar", 4)
	errors.append(sim.execute(SpawnAgentCommand.new(Cranes.OPERATOR_KIND, crane.entrance_tile())))
	errors.append(sim.execute(AssignWorkerCommand.new(sim.ids.next_id - 1, crane.id)))
	var operator := province.agents.get_agent(sim.ids.next_id - 1)
	var mooring: BuildingState = null
	for b: BuildingState in province.buildings.all():
		if b.def.id == &"mooring":
			mooring = b
	var ship := ShipUnit.new(province.ids.take(), registry.get_ship(&"foreign_cog"),
			IsoMath.tile_center(mooring.berth_tile()), registry)
	province.ships[ship.id] = ship
	Harbour.moor(ship, mooring)
	mooring.stock.add(&"wood", 12)
	province.jobs.add(&"wood", 12, mooring.id, ship.id)
	# Into the first lift, the hook swinging over with its load (porters may take the rest of
	# the wood to storages: no merchant keeps it on the quay).
	while ticks < 12000:
		sim.step()
		sim.events.drain()
		ticks += 1
		var t := Cranes.lift_progress(operator)
		if t > 0.3 and t < 0.5:
			break
	var document := {"header": {"save_version": SaveMigrations.CURRENT_VERSION}, "state": sim.to_dict()}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "", false, true))
	file.close()
	print("saved %s (%s): wood aboard %d, lift %.2f, ticks %d" % [PATH, errors, ship.hold.total(&"wood"),
			Cranes.lift_progress(operator), ticks])
	quit()


func _lay(province: ProvinceSim, tiles: Array[Vector2i]) -> void:
	for tile: Vector2i in tiles:
		province.grid.set_quay(tile, TileGrid.PIER)
		province.refresh_tile(tile)
	province.refresh_fairways()
