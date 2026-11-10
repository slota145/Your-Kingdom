class_name SiegeLayer
extends Node2D
## Siege engines in the world (M7 part 2): rams and ballistas from SpriteKiln sheets (8
## directions, owner's survey 2026-11-10) and ladders leaning on walls, drawn in code. Child of
## the y-sorted world; every engine sorts at its foot.

var province: ProvinceSim
var _rams: Dictionary[int, _Ram] = {}
var _ballistas: Dictionary[int, _Ballista] = {}
var _ladders: Dictionary[Vector2i, _Ladder] = {}


func _init() -> void:
	y_sort_enabled = true


func setup(source: ProvinceSim) -> void:
	province = source


func update_view(alpha: float, time: float) -> void:
	var seen: Dictionary[int, bool] = {}
	for agent: Agent in province.agents.all():
		if agent.kind == Troops.BALLISTA:
			seen[agent.id] = true
			var ballista: _Ballista = _ballistas.get(agent.id)
			if ballista == null:
				ballista = _Ballista.new()
				_ballistas[agent.id] = ballista
				add_child(ballista)
			ballista.position = IsoMath.grid_to_screen(agent.prev_pos.lerp(agent.pos, alpha)).round()
			ballista.facing = agent.facing
			ballista.walking = agent.activity == &"walk"
			ballista.loaded = agent.combat == null or agent.combat.cooldown <= SimClock.seconds_to_ticks(2.0)
			ballista.time = time + agent.id * 0.37
			ballista.hostile = agent.combat != null and agent.combat.faction != CombatState.PLAYER
			ballista.queue_redraw()
			continue
		if agent.kind != &"ram":
			continue
		seen[agent.id] = true
		var ram: _Ram = _rams.get(agent.id)
		if ram == null:
			ram = _Ram.new()
			_rams[agent.id] = ram
			add_child(ram)
		var at := agent.prev_pos.lerp(agent.pos, alpha)
		ram.position = IsoMath.grid_to_screen(at).round()
		ram.facing = agent.facing
		ram.walking = agent.activity == &"walk"
		ram.striking = agent.activity == &"drill"
		ram.time = time + agent.id * 0.37
		ram.hostile = agent.combat != null and agent.combat.faction != CombatState.PLAYER
		ram.queue_redraw()
	for id: int in _rams.keys():
		if not seen.has(id):
			_rams[id].queue_free()
			_rams.erase(id)
	for id: int in _ballistas.keys():
		if not seen.has(id):
			_ballistas[id].queue_free()
			_ballistas.erase(id)
	var ladders := province.mil.ladders
	for foot: Vector2i in _ladders.keys():
		if not ladders.has(foot):
			_ladders[foot].queue_free()
			_ladders.erase(foot)
	for foot: Vector2i in ladders:
		if not _ladders.has(foot):
			var ladder := _Ladder.new()
			ladder.foot = foot
			ladder.wall = ladders[foot]
			var s := IsoMath.tile_center_screen(foot)
			ladder.position = Vector2(roundf(s.x), roundf(s.y))
			_ladders[foot] = ladder
			add_child(ladder)


## Draws frame [param frame] of a SpriteKiln sheet facing [param facing] (IsoMath.Dir) with its
## pivot at [param at] (ART_SPEC §10.20: 8 rows, nothing mirrored).
static func _draw_sheet(item: CanvasItem, sheet: CharacterSheet, facing: int, frame: int, at: Vector2) -> void:
	if sheet == null or sheet.texture == null:
		return
	var row := sheet.row_for(facing)
	var side := Vector2(sheet.frame_size)
	var src := Rect2(Vector2(posmod(frame, sheet.frames), row.x) * side, side)
	item.draw_texture_rect_region(sheet.texture, Rect2(at - Vector2(sheet.foot), side), src)


## A battering ram (SpriteKiln, owner's survey 2026-11-10): a shed of planks under wet hides on
## four wheels, an iron-headed log hung inside, the legs of six men under the eaves. Sheets
## characters/ram (ram_enemy: a black pennon) with idle, walk and work (the blow).
class _Ram:
	extends Node2D
	## Frames per second of rolling: a wheel's quarter turn (its spokes look the same again)
	## per 8 frames at the ram's pace.
	const WALK_FPS := 20.0
	## One blow of the log: drawn back, then swung forward (SiegeLayer plays it while drilling).
	const STRIKE_SECONDS := 1.5
	var facing: int = 0
	var walking: bool = false
	var striking: bool = false
	var hostile: bool = false
	var time: float = 0.0

	func _draw() -> void:
		var visual := CharacterVisual.get_visual(&"ram_enemy" if hostile else &"ram")
		var sheet: CharacterSheet
		var frame := 0
		if walking:
			sheet = visual.get_sheet(&"walk")
			frame = int(time * WALK_FPS)
		elif striking:
			sheet = visual.get_sheet(&"work")
			frame = int(fposmod(time, STRIKE_SECONDS) / STRIKE_SECONDS * sheet.frames)
		else:
			sheet = visual.get_sheet(&"idle")
		SiegeLayer._draw_sheet(self, sheet, facing, frame, Vector2.ZERO)


## A ballista (SpriteKiln, owner's survey 2026-11-10): a great crossbow on a two-wheeled cart,
## drawn with a bolt in the groove while loaded, the arms and the string forward after the shot
## while the winch turns; two crewmen (characters/siege_crew) behind it push it while it moves
## and wind the winch after a shot. Sheets characters/ballista (ballista_enemy: a black pennon).
class _Ballista:
	extends Node2D
	## Frames per second of rolling: a sixth of a wheel's turn per 8 frames at its pace.
	const WALK_FPS := 20.0
	const RELOAD_FPS := 7.0
	## Where the crew stand, in tiles: behind the winch, either side of the stock.
	const CREW_BACK := 0.85
	const CREW_SIDE := 0.2
	var facing: int = 0
	var walking: bool = false
	var loaded: bool = true
	var hostile: bool = false
	var time: float = 0.0

	func _draw() -> void:
		var visual := CharacterVisual.get_visual(&"ballista_enemy" if hostile else &"ballista")
		var crew := CharacterVisual.get_visual(&"siege_crew")
		var sheet: CharacterSheet
		var crew_sheet: CharacterSheet
		var frame := 0
		var crew_frame := 0
		if walking:
			sheet = visual.get_sheet(&"walk")
			frame = int(time * WALK_FPS)
			crew_sheet = crew.get_sheet(&"walk")
		elif not loaded:
			sheet = visual.get_sheet(&"work")
			frame = int(time * RELOAD_FPS)
			crew_sheet = crew.get_sheet(&"work")
		else:
			sheet = visual.get_sheet(&"idle")
			crew_sheet = crew.get_sheet(&"idle")
		crew_frame = crew_sheet.frame_at(time)
		var along := Vector2(IsoMath.DIR_GRID_STEP[facing]).normalized()
		var across := Vector2(-along.y, along.x)
		var spots: Array[Vector2] = []
		for side: float in [-1.0, 1.0]:
			spots.append(IsoMath.grid_to_screen(-along * CREW_BACK + across * side * CREW_SIDE))
		spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
		# Crewmen further from the viewer than the engine's centre are drawn before it.
		for spot: Vector2 in spots:
			if spot.y < 0.0:
				SiegeLayer._draw_sheet(self, crew_sheet, facing, crew_frame, spot.round())
		SiegeLayer._draw_sheet(self, sheet, facing, frame, Vector2.ZERO)
		for spot: Vector2 in spots:
			if spot.y >= 0.0:
				SiegeLayer._draw_sheet(self, crew_sheet, facing, crew_frame, spot.round())


## A ladder leaning from a ground tile onto the wall.
class _Ladder:
	extends Node2D
	var foot: Vector2i
	var wall: Vector2i

	func _draw() -> void:
		var d := Vector2(wall - foot)
		var across := Vector2(-d.y, d.x) * 0.16
		var base := IsoMath.grid_to_screen(IsoMath.tile_center(foot) - d * 0.1) - position
		var top := IsoMath.grid_to_screen(IsoMath.tile_center(foot) + d * 0.5) - position \
				- Vector2(0, BlockWallModel.HEIGHT + 10.0)
		var sa := IsoMath.grid_to_screen(across) - IsoMath.grid_to_screen(Vector2.ZERO)
		var wood := Color(0.56, 0.41, 0.25)
		var dark := Color(0.28, 0.2, 0.12)
		for side: float in [-1.0, 1.0]:
			draw_line(base + sa * side, top + sa * side, dark, 3.0)
			draw_line(base + sa * side, top + sa * side, wood, 1.5)
		for k: int in range(1, 9):
			var t := k / 9.0
			var c := base.lerp(top, t)
			draw_line(c - sa, c + sa, wood, 1.5)
