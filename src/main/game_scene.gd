extends Node2D
## The game: a world of provinces (M6) or a single map (or a loaded save), the viewed
## province's view, the world map and the UI. The player changes the simulation only through
## commands.
##
## Mouse: left = select / use the tool (drag for roads and fields), right or Esc = cancel the
## tool. Keys: WASD/arrows pan, wheel or 1-4 zoom, Space pause, +/- speed, F grid,
## R turns the building being placed, B shows or hides the build bar, T changes its look, M world map, F5 quick save, F9 quick load, F11 pseudolocalization
## (UI text-fit check).
## Soldiers (M7 part 2, as in Stronghold): left click or drag a box selects them, right click
## sends them (onto a wall when clicked on its crown) or attacks the enemy under the cursor,
## Ctrl+1..9 remembers the selection as a group, 1..9 selects the group again. F7 sends a
## bandit raid now.

const START_MAP := &"riverlands"

## Map of a new single-province game (main menu, M4b-3).
## Settings of a sandbox game from the "New game" screen (M8 part 1), or null.
var _settings: GameSettings = null
var _map_id: StringName = START_MAP
## World of a new game (main menu, M6); empty = a single-province game on [member _map_id].
var _world_id: StringName = &""
const QUICK_SLOT := "quick"
## Screen pixels around a person's feet that count as clicking them.
## A person is picked only when clicked close to the body, so clicks near people still
## reach the building behind them (owner feedback 2026-11-05).
const PICK_RADIUS := 9.0
## Seconds between two refreshes of the placement preview caused by the simulation (a
## sped-up town sends events every frame; flooding a service range each time cost frames).
const PREVIEW_REFRESH := 0.25
## How far (world px) from a ship's hull a click still picks it, and how high its sail reaches.
const SHIP_PICK_RADIUS := 40.0
const SHIP_PICK_HEIGHT := 90.0

var sim: Simulation
var view: ProvinceView
var camera: GameCamera

var _ui: CanvasLayer
var _top: TopBar
var _build: BuildMenu
## Shows the build bar again while it is hidden (owner's request 2026-11-07).
var _build_show: Button
var _building_panel: BuildingPanel
var _agent_panel: AgentPanel
var _ship_panel: ShipPanel
var _result: ResultWindow
var _stocks: KingdomStockWindow
var _routes: RoutesWindow
var _world_map: WorldMapScreen
var _notes: Notifications
var _tool: Dictionary = {}
var _hover: Vector2i = Vector2i(-999, -999)
var _drag_tiles: Array[Vector2i] = []
var _dragging: bool = false
var _follow_id: int = 0
var _time: float = 0.0
var _preview_dirty: bool = false
## Something in the simulation changed since the preview was drawn (refreshed with a delay).
var _preview_stale: bool = false
## The service and coverage version the range layer shows (_show_range).
var _range_service: StringName = &""
## Dragging over ordered cobbles to cancel them (review fix 2026-11-07): with the paving tool
## and the right mouse button, or with the demolish tool started on an ordered tile.
var _cancelling: bool = false
var _range_version: int = -1
var _preview_time: float = 0.0
var _turn: PlacementTurn = PlacementTurn.new()
var _army_panel: ArmyPanel
## Selected soldiers (M7 part 2) and the groups under the digit keys.
var _selected: Array[int] = []
var _groups: Dictionary[int, Array] = {}
## Where a left drag started (world space); a drag farther than BOX_MIN selects by box.
var _box_from: Vector2 = Vector2.INF
const BOX_MIN := 6.0


func _ready() -> void:
	InputSetup.ensure_defaults()
	var load_path := String(Game.start_request.get("load", ""))
	_map_id = StringName(String(Game.start_request.get("map", START_MAP)))
	_world_id = StringName(String(Game.start_request.get("world", "")))
	_settings = GameSettings.from_dict(Game.start_request["settings"]) if Game.start_request.has("settings") else null
	var early_raid := bool(Game.start_request.get("early_raid", false))
	Game.start_request = {}
	var loaded: Simulation = null
	if load_path != "":
		loaded = SaveService.load_simulation(load_path, Data.registry)
	_build_ui()
	_start(loaded if loaded != null else _new_game())
	if early_raid:
		_execute(StartRaidCommand.new(120.0))
	EventBus.sim_event_emitted.connect(_on_sim_event)


func _exit_tree() -> void:
	Game.stop()


func _new_game() -> Simulation:
	var problems := PackedStringArray()
	if _settings != null:
		var sandbox := Simulation.from_settings(Data.registry, _settings, 1, problems)
		for problem: String in problems:
			push_warning("Sandbox: " + problem)
		if sandbox != null:
			return sandbox
	var world := Data.registry.get_world(_world_id) if _world_id != &"" else null
	if world != null:
		var in_world := Simulation.from_world(Data.registry, world, 1, problems)
		for problem: String in problems:
			push_warning("World: " + problem)
		if in_world != null:
			return in_world
	var map := Data.registry.get_map(_map_id)
	if map == null:
		map = Data.registry.get_map(START_MAP)
	var game := Simulation.from_map(Data.registry, map, 1, problems)
	for problem: String in problems:
		push_warning("Map: " + problem)
	return game


func _start(simulation: Simulation) -> void:
	sim = simulation
	sim.raids_enabled = true   # bandits come in a game the player plays (M7 part 2)
	_show_province()
	_world_map.visible = false
	_top.clock = sim.clock
	_top.treasury = sim.treasury
	_building_panel.treasury = sim.treasury
	_building_panel.sim = sim
	Game.start(sim)


## Builds the view of the viewed province (a new game, a loaded one, or another province
## entered from the world map).
func _show_province() -> void:
	if view != null:
		view.queue_free()
	if camera != null:
		camera.queue_free()
	view = ProvinceView.new()
	add_child(view)
	move_child(view, 0)
	view.setup(sim.province)
	camera = GameCamera.new()
	add_child(camera)
	var size := sim.province.grid.size
	camera.bounds = Rect2(IsoMath.grid_to_screen(Vector2(0, size.y)).x, 0,
			size.x * IsoMath.HALF_W * 2.0, size.y * IsoMath.HALF_H * 2.0)
	camera.position = IsoMath.grid_to_screen(Vector2(_start_tile()))
	camera.make_current()
	_top.province = sim.province
	_notes.province = sim.province
	_stocks.visible = false
	_routes.visible = false
	_close_panels()
	_set_tool({})


func _start_tile() -> Vector2i:
	if sim.province.landing != null:
		return sim.province.landing.beach   # a start from a ship (M5 part 3)
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == &"town_hall":
			return b.origin + b.def.footprint
	return sim.province.grid.size / 2


# --- UI --------------------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	_ui.add_child(root)
	_top = TopBar.new()
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.save_requested.connect(_quick_save)
	_top.load_requested.connect(_quick_load)
	_top.menu_requested.connect(_back_to_menu)
	_top.stocks_requested.connect(_toggle_stocks)
	_top.world_requested.connect(_toggle_world_map)
	_top.routes_requested.connect(_toggle_routes)
	root.add_child(_top)
	_build = BuildMenu.new()
	_build.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_build.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_build.setup(Data.registry)
	_build.tool_selected.connect(_set_tool)
	_build.hide_requested.connect(_show_build_menu.bind(false))
	root.add_child(_build)
	_build_show = UiKit.button("ui.build.show", _show_build_menu.bind(true))
	_build_show.tooltip_text = "ui.build.show_tip"
	_build_show.theme = UiKit.board_theme()
	_build_show.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_build_show.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	_build_show.visible = false
	root.add_child(_build_show)
	_building_panel = BuildingPanel.new()
	_building_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_building_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_building_panel.position.y = 64
	_building_panel.closed.connect(_close_panels)
	_building_panel.command_requested.connect(func(command: Command) -> void: _execute(command))
	_building_panel.demolish_requested.connect(func(id: int) -> void:
		_execute(DemolishCommand.new(id))
		_close_panels())
	_building_panel.add_fields_requested.connect(func(id: int) -> void:
		_set_tool({"kind": &"field", "farm": id}))
	_building_panel.plant_area_requested.connect(func(id: int) -> void:
		_set_tool({"kind": &"plant", "building": id}))
	_building_panel.stocks_requested.connect(_toggle_stocks)
	root.add_child(_building_panel)
	_stocks = KingdomStockWindow.new()
	_stocks.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_stocks.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stocks.position.y = 64
	_stocks.visible = false
	_stocks.closed.connect(func() -> void: _stocks.visible = false)
	_stocks.command_requested.connect(func(command: Command) -> void: _execute(command))
	root.add_child(_stocks)
	_routes = RoutesWindow.new()
	_routes.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_routes.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_routes.position.y = 64
	_routes.visible = false
	_routes.closed.connect(func() -> void: _routes.visible = false)
	_routes.command_requested.connect(func(command: Command) -> void: _execute(command))
	_agent_panel = AgentPanel.new()
	_agent_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_agent_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_agent_panel.position.y = 64
	_agent_panel.closed.connect(_close_panels)
	_agent_panel.follow_toggled.connect(func(on: bool) -> void:
		_follow_id = _agent_panel.agent_id if on else 0)
	root.add_child(_agent_panel)
	_army_panel = ArmyPanel.new()
	_army_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_army_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_army_panel.position.y = 64
	_army_panel.visible = false
	_army_panel.closed.connect(func() -> void: _select_soldiers([]))
	_army_panel.stance_requested.connect(func(stance: int) -> void:
		_execute(SetStanceCommand.new(_selected.duplicate(), stance)))
	_army_panel.return_requested.connect(func() -> void:
		_execute(OrderTroopsCommand.new(_selected.duplicate(), OrderTroopsCommand.RETURN))
		_select_soldiers([]))
	_army_panel.march_requested.connect(func() -> void:
		if _execute(MarchOutCommand.new(_selected.duplicate())) == &"":
			_notes.push(tr("ui.note.army_marching"))
			_select_soldiers([]))
	root.add_child(_army_panel)
	_ship_panel = ShipPanel.new()
	_ship_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_ship_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ship_panel.position.y = 64
	_ship_panel.visible = false
	_ship_panel.closed.connect(_close_panels)
	_ship_panel.command_requested.connect(func(command: Command) -> void: _execute(command))
	_result = ResultWindow.new()
	_result.set_anchors_preset(Control.PRESET_CENTER)
	_result.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result.grow_vertical = Control.GROW_DIRECTION_BOTH
	_result.visible = false
	_result.continue_requested.connect(func() -> void:
		_result.visible = false
		Game.paused = false)
	_result.menu_requested.connect(_back_to_menu)
	root.add_child(_result)
	root.add_child(_ship_panel)
	_world_map = WorldMapScreen.new()
	_world_map.visible = false
	_world_map.closed.connect(_toggle_world_map)
	_world_map.enter_requested.connect(_enter_province)
	_world_map.command_requested.connect(func(command: Command) -> void: _execute(command))
	_world_map.army_enter_requested.connect(func(army: int) -> void:
		if _execute(ArmySiegeCommand.new(army, ArmySiegeCommand.ENTER)) == &"":
			_world_map.visible = false
			_show_province()
			_notes.push(tr("ui.note.army_entered")))
	_world_map.routes_requested.connect(func(from: int) -> void:
		_routes.open(sim, from)
		_routes.move_to_front())
	_world_map.goods_requested.connect(func(to: int) -> void:
		_routes.open(sim, sim.viewed_id, to)
		_routes.move_to_front())
	root.add_child(_world_map)
	# Over the world map too (opened from its panel).
	root.add_child(_routes)
	_notes = Notifications.new()
	_notes.position = Vector2(12, 64)
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_notes)


## Notes about expeditions and neutral settlements on the world map (M6 parts 2 and 3).
func _note_world_event(event: Dictionary) -> void:
	var type: StringName = event["type"]
	if type == &"expedition_ready":
		_notes.push(tr("ui.note.expedition_ready"))
		return
	if type == &"battle_resolved":
		var name_b := _province_name(int(event["province"]))
		var mine := StringName(event["attacker"]) == ProvinceDef.OWNER_PLAYER
		var won := bool(event["won"]) == mine
		_notes.push(tr("ui.note.battle_won" if won else "ui.note.battle_lost") % name_b)
		return
	if type == &"bandits_set_out":
		_notes.push(tr("ui.note.bandits_set_out") % [_province_name(int(event["province"])),
				maxi(ceili(float(event["seconds"]) / 60.0), 1)])
		return
	if type == &"province_raided":
		_notes.push(tr("ui.note.province_raided") % [_province_name(int(event["province"])), int(event["gold"])])
		return
	if type == &"bandit_camp_broken":
		_notes.push(tr("ui.note.bandit_camp_broken") % int(event["gold"]))
		return
	if type in [&"army_at_settlement", &"army_home", &"army_lost", &"raid_beaten_off", &"province_captured",
			&"bandit_camp_raised"]:
		_notes.push(tr("ui.note.%s" % type) % _province_name(int(event["province"])))
		return
	if type != &"expedition_departed" and type != &"expedition_arrived" \
			and type != &"settlement_joined" and type != &"settlement_refused" \
			and type != &"settlement_asks":
		return
	var def := sim.world.def_of(int(event["province"]), sim.data)
	var name := tr(def.name_key()) if def != null else ""
	_notes.push(tr("ui.note.%s" % type) % name)


func _province_name(id: int) -> String:
	var def := sim.world.def_of(id, sim.data)
	return tr(def.name_key()) if def != null else ""


## Opens or closes the world map (M6). A single-province game has none.
func _toggle_world_map() -> void:
	if _world_map.visible:
		_world_map.visible = false
		return
	if sim.world.is_single():
		_notes.push(tr("ui.note.single_province"))
		return
	_set_tool({})
	_close_panels()
	_world_map.open(sim)


## Enters province [param id] from the world map: it comes in detail, the one viewed so far
## goes to the simplified mode (ARCHITECTURE §7.2).
func _enter_province(id: int) -> void:
	_world_map.visible = false
	if id == sim.viewed_id:
		return
	if _execute(EnterProvinceCommand.new(id)) != &"":
		return
	_show_province()
	var def := sim.world.def_of(id, sim.data)
	_notes.push(tr("ui.note.entered") % (tr(def.name_key()) if def != null else ""))


## Shows or hides the build bar (button, B); hiding it drops the tool in hand.
func _show_build_menu(on: bool) -> void:
	_build.visible = on
	_build_show.visible = not on
	if not on:
		_set_tool({})


## Opens or closes the trade routes window (M6 part 3). A single-province game has none.
func _toggle_routes() -> void:
	if _routes.visible:
		_routes.visible = false
	elif sim.world.is_single():
		_notes.push(tr("ui.note.single_province"))
	else:
		_routes.open(sim)


func _toggle_stocks() -> void:
	if _stocks.visible:
		_stocks.visible = false
	else:
		_stocks.open(sim.province)


func _close_panels() -> void:
	_building_panel.visible = false
	_agent_panel.visible = false
	_ship_panel.visible = false
	_army_panel.visible = false
	_selected.clear()
	if view != null:
		view.troops.selected = _selected
	_agent_panel.set_following(false)
	_follow_id = 0
	_preview_dirty = true


# --- Frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if sim == null:
		return
	_time += delta
	_build.lock_to(sim.province.first_building)
	view.update_view(Game.alpha(), camera.visible_world_rect(), _time, delta)
	if _follow_id != 0:
		var agent := sim.province.agents.get_agent(_follow_id)
		if agent == null:
			_close_panels()
		else:
			camera.position = IsoMath.grid_to_screen(agent.prev_pos.lerp(agent.pos, Game.alpha()))
	var tile := ProvinceView.tile_at(get_global_mouse_position())
	if tile != _hover or _preview_dirty \
			or (_preview_stale and _time - _preview_time >= PREVIEW_REFRESH):
		_hover = tile
		_preview_dirty = false
		_preview_stale = false
		_preview_time = _time
		_update_preview()


func _on_sim_event(event: Dictionary) -> void:
	# The end of a sandbox game (M8 part 1).
	if event["type"] == &"game_won" or event["type"] == &"game_lost":
		Game.paused = true
		_result.show_result(event["type"] == &"game_won", StringName(String(event.get("victory", ""))))
	_note_world_event(event)
	view.on_sim_event(event)
	_notes.on_sim_event(event)
	if not _tool.is_empty() or _building_panel.visible:
		_preview_stale = true


# --- Tools ---------------------------------------------------------------------------------

func _set_tool(tool: Dictionary) -> void:
	_tool = tool
	_drag_tiles.clear()
	_dragging = false
	_cancelling = false
	_turn.begin()
	_build.show_rotate_hint(tool.get("kind", &"") == &"building")
	if not tool.is_empty():
		_close_panels()
	_update_preview()


func _update_preview() -> void:
	if view == null:
		return
	var tiles: Dictionary[Vector2i, String] = {}
	var kind: StringName = _tool.get("kind", &"")
	var ghost := ""
	## The service whose standing reach is shown below (none: &"").
	var range_service := &""
	var ghost_origin := Vector2i.ZERO
	var ghost_ok := false
	match kind:
		&"building":
			var def := sim.data.get_building(_tool["def"])
			var origin := _building_origin(def)
			var turn := _turn.update(sim.province, def, origin)
			if def.service_radius > 0:
				range_service = def.id
				var width := sim.province.grid.size.x
				for i: int in ServiceCoverage.reach_of(sim.province, origin + def.entrance_at(turn),
						def.service_radius):
					tiles[Vector2i(i % width, i / width)] = "range"
			var ok := sim.province.placement_error(def, origin, turn) == &""
			for t: Vector2i in def.footprint_tiles(origin):
				tiles[t] = "ok" if ok else "bad"
			# The tiles in front of the doors: where people will come and go.
			for k: int in def.door_orientations(turn):
				tiles[def.door_front(origin, k)] = "range"
			ghost = BuildingLayer.base_art(def, origin, turn, _turn.look)
			ghost_origin = origin
			ghost_ok = ok
		&"road":
			for t: Vector2i in _drag_tiles + ([_hover] as Array[Vector2i]):
				tiles[t] = "ok" if sim.province.road_error(t) == &"" else "bad"
			_preview_crossings(tiles)
		&"paving":
			for t: Vector2i in _drag_tiles + ([_hover] as Array[Vector2i]):
				if _cancelling:
					if sim.province.cancel_paving_error(t) == &"":
						tiles[t] = "bad"
				else:
					tiles[t] = "ok" if sim.province.paving_error(t) == &"" else "bad"
			if not _cancelling:
				_preview_crossings(tiles)
		&"palisade", &"stone_wall", &"stairs":
			# Walls (M7 part 2): the whole line is checked together (wedges, access).
			var line: Array[Vector2i] = _drag_tiles.duplicate() if _dragging else [_hover] as Array[Vector2i]
			var plan := sim.province.wall_plan(line, _wall_kind(kind))
			for t: Vector2i in line:
				tiles[t] = "bad"
			for t: Vector2i in plan["tiles"]:
				tiles[t] = "ok"
		&"bridge", &"stone_bridge":
			# A bridge (B1) is checked whole, from bank to bank: all of it or nothing.
			if _dragging:
				var plan := sim.province.bridge_plan(_drag_tiles[0], _hover)
				var ok: bool = plan["error"] == &""
				for t: Vector2i in plan["line"]:
					tiles[t] = "ok" if ok else "bad"
			else:
				tiles[_hover] = "ok"
		&"pier", &"quay":
			# The whole line is checked together: reach from the shore, way to the open sea (N1).
			var line: Array[Vector2i] = _drag_tiles.duplicate() if _dragging else [_hover] as Array[Vector2i]
			var plan := sim.province.quay_plan(line)
			for t: Vector2i in line:
				tiles[t] = "bad"
			for t: Vector2i in plan["tiles"]:
				tiles[t] = "ok"
		&"field":
			var farm := sim.province.buildings.get_building(int(_tool["farm"]))
			if farm != null:
				var area := Rect2i(farm.origin, farm.def.footprint).grow(farm.def.work_radius)
				for y: int in range(area.position.y, area.end.y):
					for x: int in range(area.position.x, area.end.x):
						if sim.province.field_error(farm.id, Vector2i(x, y)) == &"":
							tiles[Vector2i(x, y)] = "range"
				for t: Vector2i in _drag_tiles + ([_hover] as Array[Vector2i]):
					tiles[t] = "ok" if sim.province.field_error(farm.id, t) == &"" else "bad"
		&"plant":
			var forester := sim.province.buildings.get_building(int(_tool["building"]))
			if forester != null:
				var work := Rect2i(forester.origin, forester.def.footprint).grow(forester.def.work_radius)
				for y: int in range(work.position.y, work.end.y):
					for x: int in range(work.position.x, work.end.x):
						tiles[Vector2i(x, y)] = "range"
				for t: Vector2i in forester.plant_area:
					tiles[t] = "ok"
				for t: Vector2i in _drag_tiles + ([_hover] as Array[Vector2i]):
					tiles[t] = "ok" if work.has_point(t) else "bad"
		&"demolish":
			if _cancelling:
				for t: Vector2i in _drag_tiles:
					if sim.province.cancel_paving_error(t) == &"":
						tiles[t] = "bad"
			elif _demolish_target(_hover) != null:
				tiles[_hover] = "bad"
		_:
			if _building_panel.visible:
				var b := sim.province.buildings.get_building(_building_panel.building_id)
				if b != null and b.def.service_radius > 0:
					range_service = b.def.id
				if b != null:
					for t: Vector2i in b.plant_area:
						tiles[t] = "ok"
	_show_range(range_service)
	view.overlay.show_tiles(tiles)
	view.buildings.show_ghost(ghost, ghost_origin, ghost_ok)


## The reach of the standing [param service] buildings, on its own layer: built again only
## when the coverage changed (moving the cursor does not rebuild thousands of tiles; review
## fix 2026-11-07).
func _show_range(service: StringName) -> void:
	if service == &"":
		if _range_service != &"":
			_range_service = &""
			view.range_overlay.clear()
		return
	sim.province.coverage.update(sim.province)
	var version := sim.province.coverage.version
	if service == _range_service and version == _range_version:
		return
	_range_service = service
	_range_version = version
	var tiles: Dictionary[Vector2i, String] = {}
	var flags := sim.province.coverage.map_of(service)
	var width := sim.province.grid.size.x
	for i: int in flags.size():
		if flags[i] == 1:
			tiles[Vector2i(i % width, i / width)] = "range"
	view.range_overlay.show_tiles(tiles)


## The building's origin so that the cursor tile is its front (entrance) corner.
func _building_origin(def: BuildingDef) -> Vector2i:
	return _hover - def.footprint + Vector2i.ONE


func _demolish_target(tile: Vector2i) -> Command:
	var owner := sim.province.grid.occupant(tile)
	if owner != 0 and sim.province.buildings.has_building(owner):
		return DemolishCommand.new(owner)
	# Ordered cobbles: the order goes, the dirt road stays (review fix 2026-11-07).
	if sim.province.cancel_paving_error(tile) == &"":
		var planned: Array[Vector2i] = [tile]
		return CancelPavingCommand.new(planned)
	if sim.province.fields.has_field(tile):
		return RemoveFieldCommand.new(tile)
	if sim.province.grid.has_road(tile):
		var road: Array[Vector2i] = [tile]
		return RemoveRoadCommand.new(road)
	# A wall tile or stairs (M7 part 2).
	if sim.province.walls.kind(tile) != Walls.NONE:
		return RemoveWallCommand.new(tile)
	# A bridge, laid or only ordered (B1): the whole bridge goes.
	if sim.province.grid.has_bridge(tile) or sim.province.bridge_site_at(tile) != 0:
		return RemoveBridgeCommand.new(tile)
	# A quay tile, laid or only ordered (N1).
	if sim.province.grid.has_quay(tile) or (not sim.province.paving.is_empty() \
			and sim.province.paving_site_at(tile) != 0 and not sim.province.grid.has_road(tile)):
		return RemoveQuayCommand.new(tile)
	return null


func _execute(command: Command) -> StringName:
	var error := sim.execute(command)
	for event: Dictionary in sim.events.drain():
		EventBus.sim_event_emitted.emit(event)
	return error


# --- Input ---------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_RIGHT:
		if mb.pressed and _tool.is_empty() and not _selected.is_empty():
			_order_at(get_global_mouse_position())
			return
		if mb.pressed:
			if _tool.get("kind", &"") == &"paving" and not _dragging 					and sim.province.cancel_paving_error(_hover) == &"":
				_start_cancelling()
			else:
				_set_tool({})
		elif _cancelling:
			_finish_cancelling()
		return
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_on_left_press()
		else:
			_on_left_release()
		return
	if event is InputEventMouseMotion and _box_from != Vector2.INF:
		var at := get_global_mouse_position()
		view.troops.box = Rect2(_box_from, at - _box_from) \
				if _box_from.distance_to(at) * camera.zoom.x > BOX_MIN else Rect2()
		return
	if event is InputEventMouseMotion and _dragging:
		var kind: StringName = _tool.get("kind", &"")
		if kind == &"palisade" or kind == &"stone_wall" or kind == &"stairs":
			var wall_line := BuildWallCommand.line(_drag_tiles[0], _hover)
			if wall_line != _drag_tiles:
				_drag_tiles = wall_line
				_update_preview()
		elif kind == &"bridge" or kind == &"stone_bridge":
			# Bridges are drawn like quays: a line in 8 directions from the first tile (B1).
			var line: Array[Vector2i] = sim.province.bridge_plan(_drag_tiles[0], _hover)["line"]
			if line != _drag_tiles:
				_drag_tiles = line
				_update_preview()
		elif kind == &"pier" or kind == &"quay":
			# Quays are drawn like walls: a straight line in 8 directions from the first tile (N1).
			var line := BuildQuayCommand.line(_drag_tiles[0], _hover)
			if line != _drag_tiles:
				_drag_tiles = line
				_update_preview()
		elif _drag_tiles.is_empty() or _drag_tiles.back() != _hover:
			_extend_drag(_hover)
			_update_preview()
		return
	if _world_map.visible:
		if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"world_map"):
			_toggle_world_map()
		return
	if event.is_action_pressed(&"world_map"):
		_toggle_world_map()
	elif event.is_action_pressed(&"toggle_build_menu"):
		_show_build_menu(not _build.visible)
	elif event.is_action_pressed(&"ui_cancel"):
		if not _tool.is_empty():
			_set_tool({})
		else:
			_close_panels()
	elif event.is_action_pressed(&"toggle_pause"):
		Game.toggle_pause()
	elif event.is_action_pressed(&"game_speed_up"):
		Game.set_speed_index(Game.speed_index + 1)
	elif event.is_action_pressed(&"game_speed_down"):
		Game.set_speed_index(Game.speed_index - 1)
	elif event.is_action_pressed(&"rotate_building") and _tool.get("kind", &"") == &"building":
		_turn.rotate(sim.data.get_building(_tool["def"]))
		_update_preview()
	elif event.is_action_pressed(&"cycle_look") and _tool.get("kind", &"") == &"building":
		var visual := BuildingVisualDef.for_building(_tool["def"])
		if visual != null and sim.data.get_building(_tool["def"]).is_house():
			_turn.cycle_look(visual.look_count(1))
			_update_preview()
	elif event.is_action_pressed(&"toggle_grid"):
		view.terrain.show_grid = not view.terrain.show_grid
	elif event is InputEventKey and event.pressed and not event.echo \
			and _group_key(event as InputEventKey):
		pass
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_F5: _quick_save()
			KEY_F9: _quick_load()
			KEY_F11: _toggle_pseudolocalization()
			KEY_F7: _execute(StartRaidCommand.new())   # a bandit raid now (M7 part 2, to try the defence)


func _on_left_press() -> void:
	var kind: StringName = _tool.get("kind", &"")
	match kind:
		&"":
			# Click, or the start of a box around soldiers (decided on release).
			_box_from = get_global_mouse_position()
		&"building":
			var def := sim.data.get_building(_tool["def"])
			var origin := _building_origin(def)
			var turn := _turn.update(sim.province, def, origin)
			if _execute(PlaceBuildingCommand.new(def.id, origin, false, turn, _turn.look)) == &"":
				_turn.placed()
			_update_preview()
		&"demolish":
			if sim.province.cancel_paving_error(_hover) == &"":
				_start_cancelling()
				return
			var command := _demolish_target(_hover)
			if command != null:
				_execute(command)
		&"road", &"paving", &"pier", &"quay", &"bridge", &"stone_bridge", &"field", &"plant", &"palisade", &"stone_wall", &"stairs":
			_dragging = true
			_drag_tiles = [_hover]
			_update_preview()


func _on_left_release() -> void:
	if _box_from != Vector2.INF:
		var at := get_global_mouse_position()
		var from := _box_from
		_box_from = Vector2.INF
		view.troops.box = Rect2()
		if from.distance_to(at) * camera.zoom.x > BOX_MIN:
			_select_soldiers(_soldiers_in(Rect2(from, at - from).abs()))
		else:
			_select_at(at)
		return
	if _cancelling:
		if _tool.get("kind", &"") == &"demolish":
			_finish_cancelling()
		return
	if not _dragging:
		return
	_dragging = false
	var kind: StringName = _tool.get("kind", &"")
	if kind == &"road" or kind == &"paving":
		# A road over a river brings a timber bridge, cobbles a stone one (B1, owner's request
		# 2026-11-08); the road goes on from the bridge's far ramp.
		var bridge := TileGrid.STONE_BRIDGE if kind == &"paving" else TileGrid.TIMBER_BRIDGE
		for crossing: Dictionary in sim.province.road_crossings(_drag_tiles):
			if (crossing["plan"] as Dictionary)["error"] == &"":
				_execute(BuildBridgeCommand.new(crossing["from"], crossing["to"], bridge))
				_drag_tiles.append_array(crossing["link"])
	if kind == &"road":
		var tiles: Array[Vector2i] = []
		for t: Vector2i in _drag_tiles:
			if sim.province.road_error(t) == &"":
				tiles.append(t)
		if not tiles.is_empty():
			_execute(BuildRoadCommand.new(tiles))
	elif kind == &"paving":
		var to_pave: Array[Vector2i] = []
		for t: Vector2i in _drag_tiles:
			if sim.province.paving_error(t) == &"":
				to_pave.append(t)
		if not to_pave.is_empty():
			_execute(BuildPavingCommand.new(to_pave))
	elif kind == &"bridge" or kind == &"stone_bridge":
		var bridge := TileGrid.STONE_BRIDGE if kind == &"stone_bridge" else TileGrid.TIMBER_BRIDGE
		_execute(BuildBridgeCommand.new(_drag_tiles[0], _hover, bridge))
	elif kind == &"pier" or kind == &"quay":
		var quay := TileGrid.STONE_QUAY if kind == &"quay" else TileGrid.PIER
		_execute(BuildQuayCommand.new(_drag_tiles.duplicate(), quay))
	elif kind == &"palisade" or kind == &"stone_wall" or kind == &"stairs":
		_execute(BuildWallCommand.new(_drag_tiles.duplicate(), _wall_kind(kind)))
	elif kind == &"plant":
		var marked: Array[Vector2i] = _drag_tiles.duplicate()
		_execute(SetPlantAreaCommand.new(int(_tool["building"]), marked))
	elif kind == &"field":
		for t: Vector2i in _drag_tiles:
			if sim.province.field_error(int(_tool["farm"]), t) == &"":
				_execute(PlaceFieldCommand.new(int(_tool["farm"]), t))
	_drag_tiles.clear()
	_update_preview()


## Marks the bridges a dragged road or cobbles would bring over a river (B1): the whole bridge
## green, or red with its reason when it cannot be built.
func _preview_crossings(tiles: Dictionary) -> void:
	if not _dragging:
		return
	for crossing: Dictionary in sim.province.road_crossings(_drag_tiles):
		var plan: Dictionary = crossing["plan"]
		var ok: bool = plan["error"] == &""
		for t: Vector2i in plan["line"]:
			tiles[t] = "ok" if ok else "bad"
		if ok:
			for t: Vector2i in crossing["link"]:
				tiles[t] = "ok"


static func _wall_kind(tool: StringName) -> int:
	match tool:
		&"palisade": return Walls.PALISADE
		&"stairs": return Walls.STAIRS
	return Walls.STONE


func _start_cancelling() -> void:
	_cancelling = true
	_dragging = true
	_drag_tiles = [_hover]
	_update_preview()


## Cancels the ordered cobbles on the dragged tiles.
func _finish_cancelling() -> void:
	var tiles: Array[Vector2i] = []
	for t: Vector2i in _drag_tiles:
		if sim.province.cancel_paving_error(t) == &"":
			tiles.append(t)
	_cancelling = false
	_dragging = false
	_drag_tiles.clear()
	if not tiles.is_empty():
		_execute(CancelPavingCommand.new(tiles))
	_update_preview()


## Adds the tiles from the last dragged tile to [param tile], one grid step at a time.
func _extend_drag(tile: Vector2i) -> void:
	var last: Vector2i = _drag_tiles.back()
	while last != tile:
		var d := tile - last
		if absi(d.x) >= absi(d.y):
			last.x += signi(d.x)
		else:
			last.y += signi(d.y)
		if not _drag_tiles.has(last):
			_drag_tiles.append(last)


func _select_at(world_pos: Vector2) -> void:
	var best: Agent = null
	var best_d := PICK_RADIUS / camera.zoom.x
	for agent: Agent in sim.province.agents.all():
		var feet := IsoMath.grid_to_screen(agent.prev_pos.lerp(agent.pos, Game.alpha()))
		# Click anywhere on the body: up to ~40 px above the feet.
		var body := Vector2(feet.x, clampf(world_pos.y, feet.y - 40.0, feet.y))
		var d := body.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = agent
	_close_panels()
	if best != null and Troops.is_soldier(sim.province, best):
		_select_soldiers([best.id])
		return
	if best != null:
		_agent_panel.show_agent(sim.province, best.id)
		return
	var ship := _ship_at(world_pos)
	if ship != 0:
		_ship_panel.show_ship(sim.province, ship)
		return
	# The building drawn under the cursor wins; the tile under it is only the fallback.
	var owner := view.buildings.building_at(world_pos)
	if owner == 0:
		owner = sim.province.grid.occupant(ProvinceView.tile_at(world_pos))
	if owner != 0:
		_building_panel.show_building(sim.province, owner)
	_update_preview()


# --- Soldiers (M7 part 2) -------------------------------------------------------------------

func _select_soldiers(ids: Array[int]) -> void:
	_close_panels()
	_selected.assign(ids)
	view.troops.selected = _selected
	if not _selected.is_empty():
		_army_panel.show_army(sim.province, _selected.duplicate())


## The player's soldiers whose feet or head lie in [param box] (world space).
func _soldiers_in(box: Rect2) -> Array[int]:
	var ids: Array[int] = []
	for agent: Agent in sim.province.agents.all():
		if not Troops.is_soldier(sim.province, agent):
			continue
		var feet := IsoMath.grid_to_screen(agent.prev_pos.lerp(agent.pos, Game.alpha()))
		var head: Vector2 = view.agents.heads.get(agent.id, feet)
		if box.has_point(feet) or box.has_point(head + Vector2(0, 20)):
			ids.append(agent.id)
	return ids


## Right click with soldiers selected: attack the enemy under the cursor, or go there (onto
## the wall-walk when the cursor is over a crown).
func _order_at(world_pos: Vector2) -> void:
	# A warship under the cursor: the soldiers go aboard (P2 part 2).
	var ship_id := _ship_at(world_pos)
	if ship_id != 0 and TroopTransport.carries_troops(sim.province, sim.province.ships[ship_id]):
		if _execute(BoardShipCommand.new(_selected.duplicate(), ship_id)) == &"":
			view.troops.show_order(world_pos)
			_select_soldiers([] as Array[int])
		return
	var enemy := _enemy_at(world_pos)
	if enemy != null:
		_execute(OrderTroopsCommand.new(_selected.duplicate(), OrderTroopsCommand.ATTACK,
				Vector2i(-1, -1), 0, enemy.id))
		view.troops.show_order(world_pos)
		return
	var target := _ground_or_wall(world_pos)
	# In an enemy's province (M7 part 3): a click on his wall, gate or town hall breaks it.
	if sim.province.home_faction != CombatState.PLAYER:
		var at: Vector2i = target[0]
		if target[1] == MilitaryNav.GROUND and not Troops.structure_standing(sim.province, at):
			at = ProvinceView.tile_at(world_pos + Vector2(0, BlockWallModel.HEIGHT / 2.0))
		if Troops.structure_standing(sim.province, at):
			if _execute(OrderTroopsCommand.new(_selected.duplicate(), OrderTroopsCommand.BREAK, at)) == &"":
				view.troops.show_order(world_pos)
			return
	if _execute(OrderTroopsCommand.new(_selected.duplicate(), OrderTroopsCommand.MOVE,
			target[0], target[1])) == &"":
		view.troops.show_order(world_pos)


## The tile under the cursor and its level: a crown (walls, gatehouse, tower tops) drawn under
## the cursor wins over the ground behind it.
func _ground_or_wall(world_pos: Vector2) -> Array:
	var walls := sim.province.walls
	if not walls.is_empty():
		for h: float in [BlockWallModel.HEIGHT + BlockWallModel.TOWER_EXTRA,
				BlockWallModel.HEIGHT + BlockWallModel.GATEHOUSE_EXTRA, BlockWallModel.HEIGHT]:
			var tile := ProvinceView.tile_at(world_pos + Vector2(0, h))
			if walls.is_walkway(tile) and is_equal_approx(
					FortLayer.height_at(sim.province, IsoMath.tile_center(tile), MilitaryNav.WALL), h):
				return [tile, MilitaryNav.WALL]
	return [ProvinceView.tile_at(world_pos), MilitaryNav.GROUND]


func _enemy_at(world_pos: Vector2) -> Agent:
	var best: Agent = null
	var best_d := PICK_RADIUS * 1.5 / camera.zoom.x
	for id: int in view.agents.heads:
		var agent := sim.province.agents.get_agent(id)
		if agent == null or agent.combat == null or agent.combat.faction == CombatState.PLAYER \
				or agent.combat.hp <= 0:
			continue
		var head: Vector2 = view.agents.heads[id]
		var body := Vector2(head.x, clampf(world_pos.y, head.y, head.y + 44.0))
		var d := body.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = agent
	return best


## Ctrl+digit remembers the selected soldiers as a group, the digit selects it again.
func _group_key(key: InputEventKey) -> bool:
	var digit := key.physical_keycode - KEY_0
	if digit < 1 or digit > 9:
		return false
	if key.ctrl_pressed:
		if _selected.is_empty():
			_groups.erase(digit)
		else:
			_groups[digit] = _selected.duplicate()
		_update_taken_digits()
		return true
	if not _groups.has(digit):
		return false
	var alive: Array[int] = []
	for id: int in _groups[digit]:
		if Troops.is_soldier(sim.province, sim.province.agents.get_agent(id)):
			alive.append(id)
	_groups[digit] = alive
	if alive.is_empty():
		_groups.erase(digit)
		_update_taken_digits()
		return false
	_select_soldiers(alive)
	return true


func _update_taken_digits() -> void:
	camera.taken_digits.clear()
	for digit: int in _groups:
		camera.taken_digits[digit] = true


## The ship whose hull is under [param world_pos] (M5 part 2), 0 if none.
func _ship_at(world_pos: Vector2) -> int:
	var best := 0
	var best_d := SHIP_PICK_RADIUS
	for ship: ShipUnit in sim.province.ships.values():
		if ship.is_away():
			continue
		var at := IsoMath.grid_to_screen(ship.prev_pos.lerp(ship.pos, Game.alpha()))
		# The hull and the sail above it.
		var body := Vector2(at.x, clampf(world_pos.y, at.y - SHIP_PICK_HEIGHT, at.y))
		var d := body.distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = ship.id
	return best


# --- Save, load, checks --------------------------------------------------------------------

func _quick_save() -> void:
	var error := SaveService.save_simulation(SaveService.slot_path(QUICK_SLOT), sim)
	_notes.push(tr("ui.note.saved") if error == OK else tr("ui.note.save_failed"))


## Going back to the menu quick-saves first, so a misclick never loses the game
## ("Load game" in the menu continues from it).
func _back_to_menu() -> void:
	_quick_save()
	get_tree().change_scene_to_file("res://src/main/main.tscn")


func _quick_load() -> void:
	var path := SaveService.slot_path(QUICK_SLOT)
	var loaded: Simulation = SaveService.load_simulation(path, Data.registry) \
			if FileAccess.file_exists(path) else null
	if loaded == null:
		_notes.push(tr("ui.note.load_failed"))
		return
	_start(loaded)
	_notes.push(tr("ui.note.loaded"))


func _toggle_pseudolocalization() -> void:
	TranslationServer.pseudolocalization_enabled = not TranslationServer.pseudolocalization_enabled
	TranslationServer.reload_pseudolocalization()
	EventBus.language_changed.emit(Loc.get_locale())
