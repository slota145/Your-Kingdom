extends SceneTree
## Builds the save fixture of M6 part 3 (save version 14): the Riverlands town playing Landing
## Bay in the world runs a wagon route with bread and planks to Willow Vale (settled, not
## viewed); porters are loading the wagon in front of the stable. A second, made-up route is on
## its way back from the vale.
## Run: "$GODOT" --headless --path . -s res://tools/build_routes_fixture.gd

const PATH := "res://tests/fixtures/saves/v14_routes.json"


func _init() -> void:
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var sim := Simulation.from_map(registry, registry.get_map(&"riverlands"))
	sim.world = WorldSim.from_def(registry.get_world(&"kingdom"), registry)
	sim.world.get_province(WorldSim.FIRST_ID).owner = ProvinceDef.OWNER_PLAYER
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == &"stockpile":
			b.stock.add(&"bread", 40)
			b.stock.add(&"planks", 20)
	var vale := sim.world.id_of(&"willow_vale")
	sim.open_province(vale, registry.get_map(&"riverlands"))
	var stable := _place_stable(sim)
	for i: int in 2:
		var carter := sim.province.spawn_agent(Carriers.CARTER_KIND, stable.entrance_tile())
		sim.execute(AssignWorkerCommand.new(carter.id, stable.id))
	for i: int in 4:
		sim.province.spawn_agent(JobBoard.PORTER_KIND, sim.province.seat().entrance_tile())
	var lines: Array[Dictionary] = [TradeRoute.line(&"bread", 4, 500), TradeRoute.line(&"planks", 2, 500)]
	var error := sim.execute(CreateTradeRouteCommand.new(WorldSim.FIRST_ID, vale, false, stable.id, lines))
	var ticks := 0
	var route: TradeRoute = sim.world.routes.values()[0] if not sim.world.routes.is_empty() else null
	while route != null and ticks < 3000:
		sim.step()
		ticks += 1
		var wagon := sim.province.route_wagons.get(route.id) as RouteWagon
		if wagon != null and wagon.store.total_amount() >= 2:
			break
	var back := TradeRoute.new()
	back.id = sim.ids.take()
	back.from = vale
	back.to = WorldSim.FIRST_ID
	back.vehicle = 0
	back.lines.append(TradeRoute.line(&"wood", 6, 30))
	back.state = TradeRoute.State.RETURNING
	back.depart_at = sim.clock.tick - 300
	back.arrive_at = sim.clock.tick + 900
	back.runs = 1
	back.delivered = 6
	sim.world.routes[back.id] = back
	var document := {"header": {"save_version": SaveMigrations.CURRENT_VERSION}, "state": sim.to_dict()}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "", false, true))
	file.close()
	print("saved %s (%s): routes %d, wagons %d, ticks %d" % [PATH, error, sim.world.routes.size(),
			sim.province.route_wagons.size(), ticks])
	quit()


## A finished stable on the first free spot by the town hall.
func _place_stable(sim: Simulation) -> BuildingState:
	var def := sim.data.get_building(&"stable")
	var hall := sim.province.seat().origin
	for r: int in range(4, 30):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				var origin := hall + Vector2i(dx, dy)
				if sim.province.placement_error(def, origin, 0) == &"":
					sim.execute(PlaceBuildingCommand.new(&"stable", origin, true))
					return sim.province.buildings.get_building(sim.ids.next_id - 1)
	return null
