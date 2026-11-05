extends Node2D
## M2 PROTOTYPE: the real simulation on screen. A woodcutter fells trees and carries logs to
## the stockpile; porters move goods between three stockpiles on random requests.
## Debug texts here are English and hardcoded on purpose (prototype-only, see CLAUDE.md).
##
## Controls: WASD/arrows/middle-drag pan, wheel or 1-4 zoom, +/- game speed, Space pause,
## F grid, Esc back to menu.
## Run with "-- --bench" for the M2 DoD check: 200 porters at 4x for 60 s, prints and quits.

const MAP_SIZE := Vector2i(64, 64)
const STOCKPILES: Array[Vector2i] = [Vector2i(20, 24), Vector2i(40, 22), Vector2i(28, 42)]
const WOODCUTTER_HUT := Vector2i(12, 18)
const FOREST := Rect2i(2, 4, 12, 10)
const RANDOM_GOODS: Array[StringName] = [&"bread", &"grain", &"flour"]
## Art for buildings until data/visuals arrives (M3).
const BUILDING_ART: Dictionary[StringName, String] = {&"woodcutter": "hut_box", &"bakery": "workshop_box"}
const BENCH_SECONDS := 60.0

@export var porter_count: int = 30
@export var benchmark: bool = false

var sim: Simulation
var camera: GameCamera
var terrain: TerrainLayer
var world: Node2D
var agents_view: AgentViewPool
var nature: NatureLayer
var piles_view: PileLayer
var stockpile_views: Array[StockpileView] = []

var _hud: Label
var _time: float = 0.0
var _request_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _bench_time: float = 0.0
var _bench_frames: int = 0
var _bench_worst_frame: float = 0.0
var _bench_ticks: int = 0


func _ready() -> void:
	InputSetup.ensure_defaults()
	if "--bench" in OS.get_cmdline_user_args():
		benchmark = true
	if benchmark:
		porter_count = 200
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--porters="):
			porter_count = int(arg.trim_prefix("--porters="))
	_request_rng.seed = 7
	_build_simulation()
	_build_view()
	Game.start(sim)
	if benchmark:
		Game.set_speed_index(Game.SPEEDS.size() - 1)
	EventBus.sim_event_emitted.connect(nature.on_sim_event)


func _exit_tree() -> void:
	Game.stop()


func _build_simulation() -> void:
	sim = Simulation.new(Data.registry, MAP_SIZE, 1)
	var map_rng := RandomNumberGenerator.new()
	map_rng.seed = 3
	var tree := Data.registry.get_resource_node(&"tree")
	for y: int in range(FOREST.position.y, FOREST.end.y):
		for x: int in range(FOREST.position.x, FOREST.end.x):
			if map_rng.randf() < 0.6:
				sim.province.resources.place(Vector2i(x, y), tree)
	for i: int in 40:
		var t := Vector2i(map_rng.randi_range(0, MAP_SIZE.x - 1), map_rng.randi_range(0, MAP_SIZE.y - 1))
		sim.province.resources.place(t, tree)
	sim.province.rebuild_nav()
	for origin: Vector2i in STOCKPILES:
		_execute(PlaceBuildingCommand.new(&"stockpile", origin, true))
	_execute(PlaceBuildingCommand.new(&"woodcutter", WOODCUTTER_HUT, true))
	var hut := _last_building()
	_execute(SpawnAgentCommand.new(&"woodcutter", hut.entrance_tile()))
	_execute(AssignWorkerCommand.new(sim.ids.next_id - 1, hut.id))
	for building: BuildingState in sim.province.buildings.all():
		if building.stock != null:
			for good: StringName in RANDOM_GOODS:
				building.stock.add(good, 40)
	var placed := 0
	while placed < porter_count:
		var t := Vector2i(map_rng.randi_range(16, 48), map_rng.randi_range(16, 48))
		if sim.province.nav.is_walkable(t):
			_execute(SpawnAgentCommand.new(&"porter", t))
			placed += 1
	sim.events.drain()


func _execute(command: Command) -> void:
	var error := sim.execute(command)
	if error != &"":
		push_warning("M2 sandbox: %s rejected (%s)" % [command.get_name(), error])


func _last_building() -> BuildingState:
	var all := sim.province.buildings.all()
	return all.back()


func _build_view() -> void:
	terrain = TerrainLayer.new()
	add_child(terrain)
	terrain.setup(MAP_SIZE)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	nature = NatureLayer.new()
	world.add_child(nature)
	nature.setup(sim.province.resources)
	for building: BuildingState in sim.province.buildings.all():
		if building.stock != null:
			var view := StockpileView.new()
			world.add_child(view)
			view.setup(building)
			stockpile_views.append(view)
		elif BUILDING_ART.has(building.def.id):
			var b := BuildingView.new()
			world.add_child(b)
			b.setup("buildings/%s/base" % BUILDING_ART[building.def.id], building.origin)
	piles_view = PileLayer.new()
	world.add_child(piles_view)
	agents_view = AgentViewPool.new()
	world.add_child(agents_view)

	camera = GameCamera.new()
	add_child(camera)
	camera.bounds = Rect2(IsoMath.grid_to_screen(Vector2(0, MAP_SIZE.y)).x, 0,
			MAP_SIZE.x * IsoMath.HALF_W * 2.0, MAP_SIZE.y * IsoMath.HALF_H * 2.0)
	camera.position = IsoMath.grid_to_screen(Vector2(22, 22))
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(8, 8)
	_hud.add_theme_font_size_override(&"font_size", 16)
	_hud.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override(&"outline_size", 4)
	layer.add_child(_hud)
	var panel := StockpilePanel.new()
	panel.stock = sim.province.buildings.get_building(1).stock
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -220.0
	panel.offset_top = 8.0
	panel.offset_right = -8.0
	layer.add_child(panel)


func _process(delta: float) -> void:
	_time += delta
	_issue_random_requests()
	var rect := camera.visible_world_rect()
	agents_view.update_view(sim.province.agents, Game.alpha(), rect, _time)
	piles_view.update_view(sim.province.piles)
	for view: StockpileView in stockpile_views:
		view.update_view()
	_update_hud()
	if benchmark:
		_bench_step(delta)


## Keeps about one open request per two porters, between random stockpiles.
func _issue_random_requests() -> void:
	if sim.province.jobs.count() * 2 >= porter_count:
		return
	var a := sim.province.buildings.get_building(1 + _request_rng.randi_range(0, STOCKPILES.size() - 1))
	var b := sim.province.buildings.get_building(1 + _request_rng.randi_range(0, STOCKPILES.size() - 1))
	var good := RANDOM_GOODS[_request_rng.randi_range(0, RANDOM_GOODS.size() - 1)]
	if a == null or b == null or a == b or a.stock.available(good) < 4:
		return
	sim.submit(RequestTransportCommand.new(good, _request_rng.randi_range(1, 4), a.id, b.id))


func _update_hud() -> void:
	var busy := 0
	for agent: Agent in sim.province.agents.all():
		if agent.task != null:
			busy += 1
	_hud.text = "FPS %d | tick %.3f ms | view %.2f ms | speed %.0fx%s | game time %d s\n" % [
		Engine.get_frames_per_second(), Game.tick_usec_avg / 1000.0,
		agents_view.last_update_usec / 1000.0, Game.SPEEDS[Game.speed_index],
		" PAUSED" if Game.paused else "", int(sim.clock.seconds())]
	_hud.text += "people %d (busy %d, visible %d) | requests %d | piles %d | wood stored %d\n" % [
		sim.province.agents.count(), busy, agents_view.visible_count, sim.province.jobs.count(),
		sim.province.piles.size(), sim.province.buildings.get_building(1).stock.total(&"wood")]
	if not benchmark:
		_hud.text += "+/- speed | Space pause | F grid | 1-4 zoom | Esc menu"


func _bench_step(delta: float) -> void:
	_bench_time += delta
	if _bench_time < 2.0:
		return  # warm-up
	_bench_frames += 1
	_bench_worst_frame = maxf(_bench_worst_frame, delta)
	if _bench_time >= BENCH_SECONDS + 2.0:
		print("M2 bench: %d porters, speed %.0fx, %.0f s: avg FPS %.1f, worst frame %.1f ms, tick %.3f ms, game time %d s" % [
			porter_count, Game.get_speed(), BENCH_SECONDS, _bench_frames / BENCH_SECONDS,
			_bench_worst_frame * 1000.0, Game.tick_usec_avg / 1000.0, int(sim.clock.seconds())])
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_tree().change_scene_to_file("res://src/main/main.tscn")
	elif event.is_action_pressed(&"toggle_pause"):
		Game.toggle_pause()
	elif event.is_action_pressed(&"game_speed_up"):
		Game.set_speed_index(Game.speed_index + 1)
	elif event.is_action_pressed(&"game_speed_down"):
		Game.set_speed_index(Game.speed_index - 1)
	elif event.is_action_pressed(&"toggle_grid"):
		terrain.show_grid = not terrain.show_grid
