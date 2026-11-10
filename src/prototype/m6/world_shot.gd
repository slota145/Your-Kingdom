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
##   [--m8=armies|choice|field|report] (M8 part 2, made up for the picture: armies and fleets
##   anywhere on the map, a battle in the field and a sea battle; the window asking how to fight;
##   the live battle on the battlefield after --field_seconds=<s>; the report of a sea battle)
##   [--m8=war --advance=<minutes>] (M8 part 4: the rulers' armies on their way, a ruler's panel)
##   [--m8=rulers|visit --advance=<minutes>] (M8 part 3: a generated world (--seed) run for that
##   many minutes; the world map with the first ruler's home selected, or his town entered and
##   looked at, with --building=<id> the panel of his first such building open)

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
var _m8: String = ""
var _field_seconds: float = 6.0


var _seed: int = 0
var _advance: int = 0
var _building: StringName = &""
var _provinces: int = 22
var _rulers: int = 3
## --zoom=<1..4> (M8 part 1): the world map zoomed in on the player's province.
var _zoom: float = 1.0
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
		elif arg.begins_with("--m8="):
			_m8 = arg.trim_prefix("--m8=")
		elif arg.begins_with("--field_seconds="):
			_field_seconds = float(arg.trim_prefix("--field_seconds="))
		elif arg.begins_with("--advance="):
			_advance = int(arg.trim_prefix("--advance="))
		elif arg.begins_with("--building="):
			_building = StringName(arg.trim_prefix("--building="))
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--provinces="):
			_provinces = int(arg.trim_prefix("--provinces="))
		elif arg.begins_with("--zoom="):
			_zoom = float(arg.trim_prefix("--zoom="))
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
		if _zoom > 1.0:
			var canvas := _game.find_children("*", "WorldMapCanvas", true, false)
			if not canvas.is_empty():
				var c := canvas[0] as WorldMapCanvas
				c.zoom_at(c.size / 2.0, _zoom)
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
		if _m8 == "war":
			_war_shot(sim)
			return
		if _m8 == "rulers" or _m8 == "visit":
			if _rulers_shot(sim):
				return
		elif _m8 != "":
			_make_m8(sim)
			if _m8 == "field":
				return
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
		if _m8 == "armies":
			var screen := _game.get("_world_map") as WorldMapScreen
			screen._canvas.army_selected = 970
			screen._army_clicked(970)
			screen._canvas._mouse = sim.world.def_of(sim.world.id_of(&"vine_hills"), sim.data).world_pos + Vector2(40, 40)
			screen.show_sea_fight(sim.world.armies[975].pos.lerp(sim.world.armies[976].pos, 0.5) + Vector2(0, 30))
		elif _m8 == "report":
			var screen := _game.get("_world_map") as WorldMapScreen
			screen.show_sea_fight(sim.world.armies[975].pos)
			(_game.get("_report_window") as BattleReportWindow).show_last(sim)
	elif _frames > SETTLE_FRAMES and (_m8 == "armies" or _m8 == "report"):
		# The sea battle stays half-way through until the picture is taken.
		var fights := (_game.get("_world_map") as WorldMapScreen)._canvas._sea_fights
		if not fights.is_empty():
			fights[0]["start"] = Time.get_ticks_msec() - 2500
	if _frames == SHOT_FRAMES and not _out.is_empty():
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
		army.pos = ArmyOrders.stand_point(sim, at)
		sim.world.armies[id] = army
		return army
	var waiting: Army = make.call(960, ProvinceDef.OWNER_PLAYER, iron,
			{"swordsman": 18, "archer": 10, "ram": 1, "ladderman": 2})
	waiting.state = Army.State.WAITING
	waiting.home = sim.world.id_of(&"willow_vale")
	waiting.pos = sim.world.def_of(iron, sim.data).world_pos + Vector2(-60, 0)
	var marching: Army = make.call(961, ProvinceDef.OWNER_PLAYER, home, {"spearman": 12, "archer": 4})
	Armies.send(sim, marching, sim.world.id_of(&"horse_haven"))
	ArmyOrders.step(sim, marching, 120.0)
	var camp := sim.world.camp
	var bandits: Army = make.call(962, Army.BANDITS, camp.province, {"spearman": 5, "archer": 2})
	bandits.pos = sim.world.def_of(camp.province, sim.data).world_pos
	Armies.send_bandits(sim, bandits, home)
	ArmyOrders.step(sim, bandits, 200.0)
	# A battle fought earlier at Iron Wold, for its report.
	var scouts: Army = make.call(963, ProvinceDef.OWNER_PLAYER, iron, {"spearman": 10, "archer": 4})
	Armies.battle(sim, scouts, BattleSide.new(sim.world.settlements[iron].guards), BattleResolver.Kind.SIEGE,
			Armies.fort_of(sim.province_state(iron)), iron, ProvinceDef.OWNER_NEUTRAL)
	sim.world.armies.erase(963)
	sim.events.drain()


## M8 part 4 (--m8=war --advance=<minutes>): the rulers grow and arm for that long; then the
## world map with the first ruler holding an army on its way selected (his army selected too).
func _war_shot(sim: Simulation) -> void:
	var marching := 0
	for minute: int in _advance + 30:
		sim.run_ticks(60 * SimClock.TICKS_PER_SECOND)
		sim.events.drain()
		if minute + 1 < _advance:
			continue
		for army: Army in sim.world.armies.values():
			if Rulers.is_ruler(army.owner) and army.state == Army.State.MOVING:
				marching = army.id
		if marching != 0:
			break
	_game.call("_toggle_world_map")
	var screen := _game.get("_world_map") as WorldMapScreen
	var army := sim.world.armies.get(marching) as Army
	if army == null:
		print("war: no ruler army on its way")
		return
	print("war: army %d of %s to %d" % [army.id, army.owner, army.target])
	screen.select(army.home)
	screen._canvas.army_selected = army.id


## M8 part 3: the rulers grow for --advance minutes; "visit" enters the first ruler's town
## (returns true: no world map), "rulers" selects it on the world map.
func _rulers_shot(sim: Simulation) -> bool:
	sim.run_ticks(_advance * 60 * SimClock.TICKS_PER_SECOND)
	sim.events.drain()
	var owner: StringName = Rulers.alive(sim.world)[0]
	var home: int = Rulers.provinces_of(sim.world, owner)[0]
	if _m8 == "rulers":
		_select = &""
		_game.call("_toggle_world_map")
		(_game.get("_world_map") as WorldMapScreen).select(home)
		return true
	_game.call("_enter_province", home)
	var camera := _game.get("camera") as Camera2D
	var town := sim.province
	var at := RulerPlanner.centre(town)
	for b: BuildingState in town.buildings.all():
		if _building != &"" and b.def.id == _building:
			(_game.get("_building_panel") as BuildingPanel).show_building(town, b.id)
			at = b.origin
			break
	camera.position = IsoMath.grid_to_screen(Vector2(at))
	camera.zoom = Vector2.ONE * maxf(_zoom, 1.0)
	return true


## M8 part 2: armies and fleets anywhere, a battle in the field, a sea battle.
func _make_m8(sim: Simulation) -> void:
	var nav := ArmyOrders.nav(sim)
	var home := sim.viewed_id
	var town := func(def_id: StringName) -> Vector2:
		return sim.world.def_of(sim.world.id_of(def_id), sim.data).world_pos
	var make := func(id: int, owner: StringName, pos: Vector2, units: Dictionary) -> Army:
		var army := Army.new()
		army.id = id
		army.owner = owner
		army.home = home
		army.state = Army.State.IDLE
		for unit: Variant in units:
			army.units[StringName(unit)] = int(units[unit])
		army.food = army.food_cap() * 0.8
		army.pos = pos
		ArmyOrders.place(sim, army)
		sim.world.armies[id] = army
		return army
	var fleet_of := func(army: Army, ships: Dictionary) -> void:
		army.by_sea = true
		army.at = 0
		army.fleet_home = home
		for ship: Variant in ships:
			army.fleet[StringName(ship)] = int(ships[ship])
			army.ships += int(ships[ship])
	# The player's army standing in the field of Willow Vale, selected (the way to the mouse).
	make.call(970, ProvinceDef.OWNER_PLAYER, town.call(&"willow_vale") + Vector2(-20, 70),
			{"swordsman": 16, "archer": 8, "crossbowman": 4})
	# A ruler's army in Mirror Lakes, the player's army marching to Amber Coast's fields.
	make.call(971, &"ruler_1", town.call(&"mirror_lakes") + Vector2(40, 60), {"spearman": 20, "archer": 6})
	var marching: Army = make.call(972, ProvinceDef.OWNER_PLAYER, ArmyOrders.stand_point(sim, home),
			{"spearman": 10, "archer": 4})
	ArmyOrders.order(sim, marching, 0, town.call(&"amber_coast") + Vector2(60, 40))
	ArmyOrders.step(sim, marching, 60.0)
	# A battle in the field: the player's army and bandits by Vine Hills.
	var spot: Vector2 = town.call(&"vine_hills") + Vector2(-70, -30)
	var mine: Army = make.call(973, ProvinceDef.OWNER_PLAYER, spot, {"swordsman": 12, "archer": 6, "spearman": 6})
	var bandits: Army = make.call(974, Army.BANDITS, spot + Vector2(14, 0), {"spearman": 7, "archer": 3})
	FieldBattles.begin(sim, mine, bandits)
	# Fleets: the player's fleet with soldiers sailing to Gull Isle, a ruler's fleet west of it.
	var sea := ArmyOrders.offshore(sim, home)
	var fleet: Army = make.call(975, ProvinceDef.OWNER_PLAYER, sea, {"spearman": 20})
	fleet_of.call(fleet, {"caravel_war": 1, "warship": 1})
	var theirs: Army = make.call(976, &"ruler_1", nav.nearest(town.call(&"gull_isle") + Vector2(-20, 110), true),
			{"spearman": 14})
	fleet_of.call(theirs, {"warship": 2})
	var sailing: Army = make.call(977, ProvinceDef.OWNER_PLAYER, nav.nearest(sea + Vector2(-40, 120), true),
			{"archer": 10})
	fleet_of.call(sailing, {"carrack_war": 1})
	ArmyOrders.order(sim, sailing, sim.world.id_of(&"salt_isle"), Vector2.INF)
	ArmyOrders.step(sim, sailing, 20.0)
	sim.events.drain()
	match _m8:
		"choice":
			(_game.get("_battle_window") as FieldBattleWindow).show_battle(sim, mine.battle)
			Game.paused = true
		"report":
			Fleets.sea_battle(sim, fleet, theirs)
			sim.events.drain()
		"field":
			sim.world.armies.erase(974)
			var enemy: Army = make.call(978, &"ruler_1", spot + Vector2(14, 0),
					{"spearman": 10, "archer": 4, "swordsman": 4})
			sim.world.battles.clear()
			mine.state = Army.State.IDLE
			mine.battle = 0
			var battle := FieldBattles.begin(sim, mine, enemy)
			_game.call("_execute", FieldBattleCommand.new(battle.id, FieldBattles.LIVE))
			sim.run_ticks(SimClock.seconds_to_ticks(_field_seconds))
			_game.call("_show_province")
			var camera := _game.get("camera") as GameCamera
			camera.set_zoom_index(2)
			# The camera on the middle of the fight.
			var middle := Vector2.ZERO
			var count := 0
			for agent: Agent in sim.province.agents.all():
				if agent.combat != null and agent.combat.hp > 0:
					middle += agent.pos
					count += 1
			if count > 0:
				camera.position = IsoMath.grid_to_screen(middle / count)
