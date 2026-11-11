class_name AgentViewPool
extends Node2D
## Pooled sprites for the people inside the camera rectangle (ARCHITECTURE §6.4). People
## outside have no node. Child of the y-sorted world. The animation follows only the
## agent's activity, facing and carried good.

const VIEW_MARGIN := 96.0
## Used when a profession has no art of its own yet.
const FALLBACK_CHARACTER := &"peasant"

## How far into a building (tiles) a person walking in has faded out completely.
const DOORWAY_FADE := 0.4

var visible_count: int = 0
## Duration of the last update in microseconds.
var last_update_usec: int = 0

var _pool: Array[AgentSprite] = []
var _categories: Dictionary[StringName, String] = {}
var _characters: Dictionary[StringName, StringName] = {}
var _tints: Dictionary[StringName, Color] = {}
## Building def id -> its visual (work spot offsets).
var _building_visuals: Dictionary[StringName, BuildingVisualDef] = {}
## The province the agents live in (work spots); optional.
var province: ProvinceSim
## The walls (M7 part 2): soldiers on the wall-walk sort with the crown; optional.
var forts: FortLayer
## Screen positions of the fighters' heads drawn last update (agent id -> point), for the
## life bars over them (TroopsLayer).
var heads: Dictionary[int, Vector2] = {}


func _init() -> void:
	y_sort_enabled = true


## Loads the art of every character the province has or will soon hire (its people and the
## workers of its buildings) while the game is loading: a character drawn for the first time
## loaded its sheets then, a visible stutter of ~90 ms each (review fix 2026-11-07).
func warm_up(source: ProvinceSim) -> void:
	var kinds: Dictionary[StringName, bool] = {}
	for agent: Agent in source.agents.all():
		kinds[agent.kind] = true
	for building: BuildingState in source.buildings.all():
		for kind: StringName in building.def.worker_kinds:
			kinds[kind] = true
	for kind: StringName in kinds:
		CharacterVisual.get_visual(_character(kind))


func update_view(agents: AgentStore, alpha: float, world_rect: Rect2, time: float) -> void:
	var start := Time.get_ticks_usec()
	var rect := world_rect.grow(VIEW_MARGIN)
	var used := 0
	heads.clear()
	for agent: Agent in agents.all():
		if agent.vehicle == Ships.ABOARD:
			continue   # drawn in his boat by the ShipLayer (M5)
		var at := agent.prev_pos.lerp(agent.pos, alpha)
		var screen := IsoMath.grid_to_screen(at)
		if not rect.has_point(screen):
			continue
		if agent.kind == &"ram" or agent.kind == Troops.BALLISTA:
			# Drawn by the SiegeLayer (M7 part 2, J1 part 2).
			heads[agent.id] = screen - Vector2(0, 46.0 if agent.kind == &"ram" else 34.0)
			continue
		var spot := _spot_offset(agent)
		# Going in through a door: the last step fades out (owner's decision 2026-11-05), and
		# people resting inside are not drawn. Workers at a work spot stay visible.
		var open := _on_open_ground(at)
		var raised := agent.level != 0
		var fade := _doorway_fade(at) if spot == Vector2.ZERO and not open and not raised else 1.0
		if fade <= 0.0:
			continue
		var sprite := _sprite(used)
		used += 1
		# Small stable offset so people sharing a tile do not overlap exactly (ARCHITECTURE §5.3).
		var jitter := Vector2(float((agent.id * 7) % 9) - 4.0, float((agent.id * 5) % 5) - 2.0)
		var lift := 0.0
		if agent.combat != null:
			jitter = Vector2.ZERO   # fighters keep their places in the formation
			if province != null and forts != null and not province.walls.is_empty():
				lift = FortLayer.height_at(province, at, agent.level)
				if agent.level != 0:
					# On the wall-walk: sorted after the crown he stands on, drawn up there.
					var key := forts.crown_sort_key(at)
					lift += key - screen.y
					screen.y = key
				elif lift > 0.0:
					lift += 1.0
					screen.y += 1.0
		sprite.position = screen + jitter + spot
		sprite.set_lift(lift)
		if agent.combat != null:
			heads[agent.id] = sprite.position - Vector2(0, lift + 44.0)
		# A docker who went up the gangway onto a moored ship stands on its deck: drawn over
		# the hull and the sail (M5 part 2, owner's wish 2026-11-06).
		# On open ground inside a footprint (a pen): over the flat art of the building.
		sprite.z_index = 1 if open or _on_ship(agent) else 0
		sprite.self_modulate = _tint(agent.kind)
		sprite.modulate.a = fade
		var good := agent.carry_good if agent.is_carrying() else &""
		var category := _category(good)
		var anim := StringName("work_" + String(agent.activity))
		if agent.activity == &"walk":
			# A led animal walks beside a person with free hands (M4b-2); a handcart is pushed
			# with free hands too (M4b-3).
			anim = StringName("walk_carry_" + category) if good != &"" and category != "animal" \
					and agent.vehicle == &"" else &"walk"
		elif agent.activity == &"idle":
			anim = &"idle"
		sprite.show_state(CharacterVisual.get_visual(_character(agent.kind)), anim, agent.facing,
				time + agent.id * 0.137, category, good if agent.activity == &"walk" else &"",
				Carriers.WAGON if agent.vehicle == Carriers.SETTLER_WAGON else agent.vehicle,
				good != &"" or agent.vehicle == Carriers.SETTLER_WAGON \
						or agent.vehicle == Carriers.TRADE_WAGON)
	for j: int in range(used, _pool.size()):
		_pool[j].visible = false
	visible_count = used
	last_update_usec = Time.get_ticks_usec() - start


## Whether [param agent] is out over the water on the gangway or on a ship's deck.
func _on_ship(agent: Agent) -> bool:
	if province == null or agent.task == null or not agent.task.bb.has("_gw"):
		return false
	var tile := agent.tile()
	return province.grid.is_inside(tile) and province.grid.occupant(tile) == 0


## Whether [param at] lies inside the footprint of a building drawn as open ground.
func _on_open_ground(at: Vector2) -> bool:
	var tile := Vector2i(floori(at.x), floori(at.y))
	if province == null or not province.grid.is_inside(tile):
		return false
	var building := province.buildings.get_building(province.grid.occupant(tile))
	if building == null:
		return false
	var visual := _visual_of(building.def.id)
	return visual != null and visual.open_ground


func _visual_of(def_id: StringName) -> BuildingVisualDef:
	if not _building_visuals.has(def_id):
		_building_visuals[def_id] = BuildingVisualDef.for_building(def_id)
	return _building_visuals[def_id]


## 1 outside buildings, falling to 0 within [constant DOORWAY_FADE] tiles inside a footprint.
func _doorway_fade(at: Vector2) -> float:
	var tile := Vector2i(floori(at.x), floori(at.y))
	if province == null or not province.grid.is_inside(tile):
		return 1.0
	var building := province.buildings.get_building(province.grid.occupant(tile))
	if building == null or building.def.is_port():
		return 1.0   # a port is open ground: dockers are seen on the quay yard and the quay
	var rect := Rect2(Vector2(building.origin), Vector2(building.def.footprint))
	var depth := minf(minf(at.x - rect.position.x, rect.end.x - at.x), minf(at.y - rect.position.y, rect.end.y - at.y))
	return clampf(1.0 - depth / DOORWAY_FADE, 0.0, 1.0)


func _sprite(index: int) -> AgentSprite:
	if index >= _pool.size():
		var sprite := AgentSprite.new()
		add_child(sprite)
		_pool.append(sprite)
	var s := _pool[index]
	s.visible = true
	return s


func _category(good: StringName) -> String:
	if good == &"":
		return ""
	if not _categories.has(good):
		var def := Data.registry.get_good(good)
		_categories[good] = def.carry_category if def != null else "crate"
	return _categories[good]


func _character(kind: StringName) -> StringName:
	if not _characters.has(kind):
		var visual := AgentVisualDef.for_kind(kind)
		var id := visual.character if visual != null else kind
		var has_art := not ArtPaths.list_files("characters/%s" % id).is_empty()
		_characters[kind] = id if has_art else FALLBACK_CHARACTER
	return _characters[kind]


func _tint(kind: StringName) -> Color:
	if not _tints.has(kind):
		var visual := AgentVisualDef.for_kind(kind)
		_tints[kind] = visual.tint if visual != null else Color.WHITE
	return _tints[kind]


## Pixel offset of the named work spot (oven, table...) while the agent works there.
func _spot_offset(agent: Agent) -> Vector2:
	if province == null or agent.task == null or agent.path_state == Agent.PathState.MOVING:
		return Vector2.ZERO
	var step := agent.task.current_step() as WorkStepDef
	if step == null or step.spot == &"":
		return Vector2.ZERO
	var workplace := province.buildings.get_building(agent.workplace_id)
	if workplace == null:
		return Vector2.ZERO
	var visual := _visual_of(workplace.def.id)
	if visual == null:
		return Vector2.ZERO
	# A spot per worker ("face_1", "face_2"...: the stone pit's three stonecutters, E3) when
	# the building has them, else the shared one.
	var own := StringName("%s_%d" % [step.spot, workplace.workers.find(agent.id) + 1])
	if visual.spot_offsets.has(own):
		return visual.spot_offsets[own]
	return visual.spot_offsets.get(step.spot, Vector2.ZERO)
