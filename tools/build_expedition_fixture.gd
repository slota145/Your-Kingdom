extends SceneTree
## Builds the save fixture of M6 part 2 (save version 13): the Riverlands town playing Landing
## Bay in the world has sent one expedition by land to Willow Vale (on its way) and is
## gathering a second one for Amber Coast (settlers walking, the wagon half loaded).
## Run: "$GODOT" --headless --path . -s res://tools/build_expedition_fixture.gd

const PATH := "res://tests/fixtures/saves/v13_expedition.json"


func _init() -> void:
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var sim := Simulation.from_map(registry, registry.get_map(&"riverlands"))
	sim.world = WorldSim.from_def(registry.get_world(&"kingdom"), registry)
	sim.world.get_province(WorldSim.FIRST_ID).owner = ProvinceDef.OWNER_PLAYER
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == &"stockpile":
			b.stock.add(&"wood", 160)
			b.stock.add(&"bread", 40)
		if b.house != null:
			b.house.residents = b.capacity()
	for i: int in 4:
		sim.province.spawn_agent(JobBoard.PORTER_KIND, sim.province.seat().entrance_tile())
	sim.treasury.gold = 500
	var error := sim.execute(PrepareExpeditionCommand.new(WorldSim.FIRST_ID, false))
	var ticks := 0
	while not sim.province.departure.is_ready() and ticks < 9000:
		sim.step()
		ticks += 1
	error = sim.execute(SendExpeditionCommand.new(WorldSim.FIRST_ID, sim.world.id_of(&"willow_vale")))
	while sim.province.departure != null and ticks < 9000:
		sim.step()
		ticks += 1
	for b: BuildingState in sim.province.buildings.all():
		if b.house != null:
			b.house.residents = b.capacity()
	# The second one is only prepared (since 2026-11-06 it goes nowhere until it is ready and
	# sent); the fixture in the repository was made before that, with a target already.
	var second := sim.execute(PrepareExpeditionCommand.new(WorldSim.FIRST_ID, false))
	sim.run_ticks(500)
	var document := {"header": {"save_version": SaveMigrations.CURRENT_VERSION}, "state": sim.to_dict()}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "", false, true))
	file.close()
	print("saved %s (%s, %s): expeditions %d, departure %s" % [PATH, error, second,
			sim.world.expeditions.size(), sim.province.departure.to_dict() if sim.province.departure != null else "none"])
	quit()
