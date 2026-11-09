extends Node
## M6 prototype: starts a new game in the world, optionally settles Willow Vale (simplified
## mode), opens the world map with a province selected and saves a screenshot.
## Run (cloud): xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 \
##   res://src/prototype/m6/world_shot.tscn -- --out=/tmp/world.png [--select=<province id>] [--settle]
##   [--expeditions] (a cog on its way to Gull Isle, a wagon to Willow Vale, one waiting at
##   Amber Coast, all made up for the picture) [--ready] (a ready land expedition by the start
##   town, selected, the mouse over Willow Vale) [--routes] (Willow Vale and Amber Coast settled,
##   a wagon route and a cog route on their way, made up for the picture; with --window the
##   routes window is open over the map) [--armies] (M7 part 3: the bandits' camp, a bandit raid
##   and an army of the player on their way, the player's army waiting at Iron Wold, selected,
##   with the report of a battle; made up for the picture)

const GAME_SCENE := "res://src/main/game_scene.tscn"
const SETTLE_FRAMES := 10
const SHOT_FRAMES := 30

var _game: Node2D
var _frames: int = 0
var _out: String = ""
var _select: StringName = &""
var _settle: bool = false
var _expeditions: bool = false
var _ready_one: bool = false
var _routes: bool = false
var _window: bool = false
var _armies: bool = false


var _seed: int = 0
var _provinces: int = 22
var _rulers: int = 3
## --result=won|lost (M8 part 1): the end-of-game window over the province view.
var _result: String = ""


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--select="):
			_select = StringName(arg.trim_prefix("--select="))
		elif arg == "--settle":
			_settle = true
		elif arg == "--expeditions":
			_expeditions = true
		elif arg == "--ready":
			_ready_one = true
		elif arg == "--routes":
			_routes = true
		elif arg == "--window":
			_window = true
		elif arg == "--armies":
			_armies = true
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--provinces="):
			_provinces = int(arg.trim_prefix("--provinces="))
		elif arg.begins_with("--result="):
			_result = arg.trim_prefix("--result=")
		elif arg.begins_with("--rulers="):
			_rulers = int(arg.trim_prefix("--rulers="))
	Game.start_request = {"world": "kingdom"}
	# M8 part 1: a generated world (--seed=<n> [--provinces=<16..30>] [--rulers=<1..3>]).
	if _seed > 0:
		var settings := GameSettings.new()
		settings.world_seed = _seed
		settings.province_count = _provinces
		settings.rulers = _rulers
		Game.start_request = {"settings": settings.to_dict()}
	_game = (load(GAME_SCENE) as PackedScene).instantiate() as Node2D
	add_child(_game)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == SETTLE_FRAMES:
		var sim: Simulation = _game.get("sim")
		if _result != "":
			(_game.get("_result") as ResultWindow).show_result(_result == "won", GameSettings.VICTORY_CONQUEST)
		if _settle:
			sim.open_province(sim.world.id_of(&"willow_vale"), sim.data.get_map(&"riverlands"))
		if _expeditions:
			var plan := [[&"gull_isle", true, Expedition.State.TRAVELLING, 0.55],
					[&"willow_vale", false, Expedition.State.TRAVELLING, 0.4],
					[&"amber_coast", true, Expedition.State.WAITING, 1.0]]
			for i: int in plan.size():
				var e := Expedition.new()
				e.id = 900 + i
				e.from = sim.viewed_id
				e.to = sim.world.id_of(plan[i][0])
				e.by_sea = plan[i][1]
				e.state = plan[i][2]
				e.depart_at = sim.clock.tick - roundi(1000 * plan[i][3])
				e.arrive_at = e.depart_at + 1000
				sim.world.expeditions[e.id] = e
		if _ready_one:
			var departure := Departure.new()
			departure.id = 990
			departure.state = Departure.State.READY
			departure.stand = sim.province.entry_tile
			sim.province.departure = departure
		if _routes:
			_make_routes(sim)
		if _armies:
			_make_armies(sim)
		_game.call("_toggle_world_map")
		if _window:
			(_game.get("_world_map") as WorldMapScreen).routes_requested.emit(sim.viewed_id)
		if _ready_one:
			var screen := _game.get("_world_map") as WorldMapScreen
			screen._canvas.expedition_from = sim.viewed_id
			screen._expedition_clicked(sim.viewed_id)
			screen._canvas._hover = sim.world.id_of(&"willow_vale")
		if _select != &"":
			(_game.get("_world_map") as WorldMapScreen).select(sim.world.id_of(_select))
		if _armies:
			var screen := _game.get("_world_map") as WorldMapScreen
			screen._canvas.army_selected = 960
			screen._army_clicked(960)
	elif _frames == SHOT_FRAMES and not _out.is_empty():
		get_viewport().get_texture().get_image().save_png(_out)
		get_tree().quit()


func _make_routes(sim: Simulation) -> void:
	var vale := sim.world.id_of(&"willow_vale")
	var coast := sim.world.id_of(&"amber_coast")
	sim.open_province(vale, sim.data.get_map(&"riverlands"))
	sim.open_province(coast, sim.data.get_map(&"coast"))
	var plan := [[vale, false, TradeRoute.State.TRAVELLING, 0.45, &"bread"],
			[coast, true, TradeRoute.State.RETURNING, 0.3, &"planks"]]
	for i: int in plan.size():
		var r := TradeRoute.new()
		r.id = 950 + i
		r.from = sim.viewed_id
		r.to = plan[i][0]
		r.by_sea = plan[i][1]
		r.state = plan[i][2]
		r.lines.append(TradeRoute.line(plan[i][4], 6 if not r.by_sea else 20, 30))
		r.lines.append(TradeRoute.line(&"wood", 6 if not r.by_sea else 10, 40))
		if r.state == TradeRoute.State.TRAVELLING:
			r.cargo = {plan[i][4]: 6}
		r.depart_at = sim.clock.tick - roundi(1000 * plan[i][3])
		r.arrive_at = r.depart_at + 1000
		r.runs = 3
		r.delivered = 18
		sim.world.routes[r.id] = r


func _make_armies(sim: Simulation) -> void:
	var home := sim.viewed_id
	sim.raids_enabled = true
	Armies.update(sim)
	var iron := sim.world.id_of(&"iron_wold")
	var make := func(id: int, owner: StringName, at: int, units: Dictionary) -> Army:
		var army := Army.new()
		army.id = id
		army.owner = owner
		army.at = at
		army.home = home
		army.state = Army.State.IDLE
		for unit: Variant in units:
			army.units[StringName(unit)] = int(units[unit])
		army.food = army.food_cap() * 0.7
		sim.world.armies[id] = army
		return army
	var waiting: Army = make.call(960, ProvinceDef.OWNER_PLAYER, iron,
			{"swordsman": 18, "archer": 10, "ram": 1, "ladderman": 2})
	waiting.state = Army.State.WAITING
	waiting.home = sim.world.id_of(&"willow_vale")
	var marching: Army = make.call(961, ProvinceDef.OWNER_PLAYER, home, {"spearman": 12, "archer": 4})
	Armies.send(sim, marching, sim.world.id_of(&"horse_haven"))
	marching.depart_at -= 900
	marching.arrive_at -= 900
	var camp := sim.world.camp
	var bandits: Army = make.call(962, Army.BANDITS, camp.province, {"spearman": 5, "archer": 2})
	Armies.send_bandits(sim, bandits, home)
	bandits.depart_at -= 1200
	bandits.arrive_at -= 1200
	# A battle fought earlier at Iron Wold, for its report.
	var scouts: Army = make.call(963, ProvinceDef.OWNER_PLAYER, iron, {"spearman": 10, "archer": 4})
	Armies.battle(sim, scouts, BattleSide.new(sim.world.settlements[iron].guards), BattleResolver.Kind.SIEGE,
			Armies.fort_of(sim.province_state(iron)), iron, ProvinceDef.OWNER_NEUTRAL)
	sim.world.armies.erase(963)
	sim.events.drain()
