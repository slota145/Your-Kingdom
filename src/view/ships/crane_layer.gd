class_name CraneLayer
extends Node2D
## Cargo cranes at work (N1 part 2, ARCHITECTURE §6.3): the jib slewing between the quay yard
## and the ship at the berth, the hoist rope from the treadwheel, and the hook with the load
## going up and down. The crane's art (mast, treadwheel) is the building's; this layer draws
## over the world (the jib is high above everything). Reads the operator's lift progress
## (Cranes.lift_progress) every frame; never changes the simulation.

## Mast foot and treadwheel axle in the art (tools/spritekiln/gen_port.py, "crane"), as drawn (orientation 0).
const MAST_FOOT := Vector2(1.15, 0.85)
const WHEEL_FOOT := Vector2(0.5, 1.5)
## Heights (screen px) of the jib's heel on the mast, of the mast cap, and of the jib head.
const HEEL_HEIGHT := 95.0
const CAP_HEIGHT := 118.0
const HEAD_HEIGHT := 100.0
const AXLE_HEIGHT := 25.0
## Hook heights over the ground: hoisted while the jib swings, down at the yard or on the
## ship's deck.
const HOOK_UP := 66.0
const HOOK_DOWN := 6.0
const HOOK_DECK := 26.0
## The jib at rest points this far from the yard towards the ship.
const REST := 0.35
const C_JIB := Color(0.36, 0.23, 0.14)
const C_JIB_LIGHT := Color(0.55, 0.38, 0.22)
const C_ROPE := Color(0.78, 0.68, 0.48)
const C_NET := Color(0.45, 0.33, 0.2)
const C_IRON := Color(0.24, 0.24, 0.26)

var province: ProvinceSim
var _icons: Dictionary[StringName, Texture2D] = {}


func setup(source: ProvinceSim) -> void:
	province = source


func update_view() -> void:
	queue_redraw()


func _draw() -> void:
	if province == null:
		return
	var operators: Dictionary[int, Agent] = {}
	for agent: Agent in province.agents.all():
		if agent.kind == Cranes.OPERATOR_KIND and agent.workplace_id != 0:
			operators[agent.workplace_id] = agent
	for crane: BuildingState in province.buildings.all():
		if crane.def.crane_reach <= 0 or not crane.is_complete():
			continue
		_draw_crane(crane, operators.get(crane.id) as Agent)


## Screen point of [param at] (as drawn) inside the footprint of [param crane].
static func _art_point(crane: BuildingState, at: Vector2) -> Vector2:
	var local := at if crane.orientation % 2 == 0 else Vector2(at.y, at.x)
	return IsoMath.grid_to_screen(Vector2(crane.origin) + local)


func _draw_crane(crane: BuildingState, operator: Agent) -> void:
	var port := Cranes.berth_building(province, crane.def, crane.origin)
	var mast := _art_point(crane, MAST_FOOT)
	var heel := mast - Vector2(0, HEEL_HEIGHT)
	var cap := mast - Vector2(0, CAP_HEIGHT)
	# Where the hook goes: the quay yard (the foot of the gangway) and the ship at the berth.
	var yard := IsoMath.grid_to_screen(Vector2(crane.origin) + Vector2(crane.def.footprint) * 0.5) \
			if port == null else IsoMath.tile_center_screen(port.gangway_tile())
	var ship := yard + Vector2(-40, 20) if port == null \
			else IsoMath.grid_to_screen(Harbour.moor_point(port.gangway_tile(), port.berth_tile()) \
			+ (Vector2(port.berth_tile() - port.gangway_tile()).normalized() * ShipLayer.MOORED_HULL_SHIFT \
			if port.berth_tile() != port.gangway_tile() else Vector2.ZERO))
	var t := Cranes.lift_progress(operator) if operator != null else -1.0
	var out := operator != null and operator.task != null and int(operator.task.bb.get("_out", 1)) == 1
	var from := yard if out else ship
	var to := ship if out else yard
	var at := yard.lerp(ship, REST)
	var hook := HOOK_UP
	var loaded := false
	if t >= 0.0:
		var ticks := t * Cranes.CYCLE_TICKS
		var h := float(Cranes.HOOK_TICKS)
		var s := float(Cranes.SWING_TICKS)
		var low_from := HOOK_DOWN if out else HOOK_DECK
		var low_to := HOOK_DECK if out else HOOK_DOWN
		if ticks < h:
			at = from
			hook = lerpf(low_from, HOOK_UP, ticks / h)
			loaded = true
		elif ticks < h + s:
			at = from.lerp(to, _ease((ticks - h) / s))
			loaded = true
		elif ticks < 2.0 * h + s:
			at = to
			hook = lerpf(HOOK_UP, low_to, (ticks - h - s) / h)
			loaded = ticks < 2.0 * h + s - 1.0
		else:
			at = to.lerp(from, _ease((ticks - 2.0 * h - s) / s))
	var head := at - Vector2(0, HEAD_HEIGHT)
	# Hoist rope from the treadwheel's drum up to the cap and along the jib.
	var axle := _art_point(crane, WHEEL_FOOT) - Vector2(0, AXLE_HEIGHT)
	draw_line(axle, cap, C_ROPE.darkened(0.2), 1.0)
	# The jib: a heavy beam (dark underside, lit top), a brace from lower on the mast to its
	# middle, the stay from the cap, a block with a sheave at its head.
	var brace := heel.lerp(head, 0.45)
	draw_line(heel + Vector2(0, 26), brace, C_JIB.darkened(0.15), 3.0)
	draw_line(heel, head, C_JIB.darkened(0.25), 6.0)
	draw_line(heel + Vector2(0, -2), head + Vector2(0, -2), C_JIB, 3.0)
	draw_line(heel + Vector2(0, -3), head + Vector2(0, -3), C_JIB_LIGHT, 1.0)
	for k: int in range(1, 5):
		var q := heel.lerp(head, k / 5.0)
		draw_line(q + Vector2(0, -3), q + Vector2(0, 3), C_IRON, 1.0)
	draw_line(cap, head, C_ROPE, 1.0)
	draw_line(cap, brace, C_ROPE.darkened(0.15), 1.0)
	draw_rect(Rect2(head - Vector2(4, 4), Vector2(8, 8)), C_JIB.darkened(0.3))
	draw_circle(head + Vector2(0, 1), 2.5, C_IRON)
	var hook_at := at - Vector2(0, hook)
	draw_line(head + Vector2(-1, 4), hook_at + Vector2(-1, -5), C_ROPE, 1.0)
	draw_line(head + Vector2(1, 4), hook_at + Vector2(1, -5), C_ROPE, 1.0)
	# The hook block and the iron hook.
	draw_rect(Rect2(hook_at - Vector2(3, 6), Vector2(6, 5)), C_JIB.darkened(0.2))
	draw_line(hook_at + Vector2(0, -1), hook_at + Vector2(0, 2), C_IRON, 2.0)
	draw_arc(hook_at + Vector2(-1.5, 2.5), 1.8, 0.0, PI, 6, C_IRON, 1.5)
	if loaded:
		_draw_load(hook_at + Vector2(0, 4), StringName(String(operator.task.bb.get("good", ""))),
				int(operator.task.bb.get("_load", 1)))


## A cargo net with [param count] goods under the hook.
func _draw_load(top: Vector2, good: StringName, count: int) -> void:
	var icon := _icon(good)
	var size := 14.0
	for i: int in count:
		var offset := Vector2((i - (count - 1) * 0.5) * 8.0, 5.0 - float(i % 2) * 4.0)
		var rect := Rect2(top + offset - Vector2(size * 0.5, 0), Vector2(size, size))
		if icon != null:
			draw_texture_rect(icon, rect, false)
		else:
			draw_rect(rect, Color(0.6, 0.45, 0.28))
	# The net: ropes from the hook down around the goods, and a mesh under them.
	var half := count * 4.0 + 4.0
	var left := top + Vector2(-half, 9.0)
	var right := top + Vector2(half, 9.0)
	for end: Vector2 in [left, right, top + Vector2(-half * 0.4, 12.0), top + Vector2(half * 0.4, 12.0)]:
		draw_line(top, end, C_NET, 1.0)
	draw_line(left, left + Vector2(2, 9), C_NET, 1.0)
	draw_line(right, right + Vector2(-2, 9), C_NET, 1.0)
	draw_line(left + Vector2(2, 9), right + Vector2(-2, 9), C_NET, 1.0)


func _icon(good: StringName) -> Texture2D:
	if not _icons.has(good):
		_icons[good] = ArtPaths.texture("goods/icons/%s.png" % good) if good != &"" else null
	return _icons[good]


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
