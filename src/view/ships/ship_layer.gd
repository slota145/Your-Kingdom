class_name ShipLayer
extends Node2D
## Ships on the water and ships on shipyard slipways (M5, ART_SPEC §9). Child of the y-sorted
## world; sprites are kept per ship and per ship build and refreshed every frame from the
## simulation state (there are few of them). The crew is part of the boat art: a fisherman
## aboard is not drawn by the AgentViewPool.

## Boat centre at the waterline in each frame of ships/<id>/<anim>.png (tools/generate_ships.gd).
const BOAT_PIVOT := Vector2(40, 46)
const FRAMES := {&"idle": 1, &"row": 4, &"cast_net": 4, &"wait_net": 4, &"haul_net": 4}
## Ships with bigger frames (M5 part 2): frame size and the centre at the waterline. Their
## sheets have 8 rows (directions) and as many frames per row as fit (tools/render_cog.py).
const BIG_FRAMES := {&"foreign_cog": [Vector2i(220, 220), Vector2(110, 168)],
		&"cog": [Vector2i(220, 220), Vector2(110, 168)]}
## A big ship on the slipway (M5 part 3): build_<n>.png of the same frame size, one frame per
## direction; the hull stands on keel blocks, this far (px) above the slipway centre.
const SLIP_LIFT := 6.0
## How far (tiles) a cog on the slipway lies past the slipway centre, towards the water.
const COG_ON_SLIP := 0.9
## The launch (review fix 2026-11-07): the shipwrights spend the launch stage knocking out the
## blocks; the hull slides down the slipway and floats out to the berth in the last this many
## seconds of the stage, speeding up on the slipway and slowing down on the water.
const LAUNCH_SLIDE := 8.0
## A cog this close (tiles) to a shipyard's berth sorts in front of the shipyard.
const LAUNCH_REACH := 1.2
## Gangway plank between a port's quay and a moored ship (M5 part 2).
const PLANK := Color(0.55, 0.4, 0.25)
const PLANK_EDGE := Color(0.3, 0.21, 0.13)
## Height (px) of the quay deck and of the ship's gunwale over the water, where the plank lies.
const QUAY_HEIGHT := 8.0
const GUNWALE_HEIGHT := 16.0
## How far (tiles) from the berth centre towards the quay the plank ends on the ship.
const PLANK_INBOARD := 0.3
## Frames per second of the boat animations.
const FPS := 5.0
## A ship on the slipway sorts at the front of the slipway (over the building), drawn this
## far back up from there (px).
const SLIP_SORT_OFFSET := 24.0

var province: ProvinceSim
var _ships: Dictionary[int, Sprite2D] = {}
var _builds: Dictionary[int, Sprite2D] = {}
var _planks: Dictionary[int, Polygon2D] = {}
var _textures: Dictionary[String, Texture2D] = {}


func _init() -> void:
	y_sort_enabled = true


func setup(source: ProvinceSim) -> void:
	province = source


func update_view(alpha: float, time: float) -> void:
	_update_ships(alpha, time)
	_update_builds()
	_update_planks()


func _update_ships(alpha: float, time: float) -> void:
	for id: int in _ships.keys():
		if not province.ships.has(id):
			_ships[id].queue_free()
			_ships.erase(id)
	for ship: ShipUnit in province.ships.values():
		var sprite: Sprite2D = _ships.get(ship.id)
		if sprite == null:
			sprite = _sprite()
			_ships[ship.id] = sprite
		# Over the horizon on a trade voyage (M5 part 3): not on the map.
		sprite.visible = not ship.is_away()
		if BIG_FRAMES.has(ship.def.art_id()):
			_show_big(sprite, ship, alpha, time)
			continue
		var anim := _anim(ship)
		var frames: int = FRAMES[anim]
		sprite.texture = _texture("ships/%s/%s.png" % [ship.def.id, anim])
		sprite.hframes = frames
		sprite.vframes = IsoMath.DIR_COUNT
		var frame := int(time * FPS + ship.id * 0.37) % frames
		sprite.frame = ship.facing * frames + frame
		# Boats moored at one berth lie side by side.
		var berth_shift := Vector2(float((ship.id * 5) % 7) - 3.0, 0.0) if ship.crew == 0 else Vector2.ZERO
		sprite.position = IsoMath.grid_to_screen(ship.prev_pos.lerp(ship.pos, alpha)) + berth_shift
		sprite.offset = -BOAT_PIVOT


## A moored cog's hull is drawn this much further from the quay than the ship's position
## (tiles; owner's request 2026-11-07): the plank and the dockers on deck reach its near
## side. Grows as the ship comes in, so it does not jump.
const MOORED_HULL_SHIFT := 0.5


## Grid-space shift of the hull of [param ship] away from the quay of the berth it holds.
static func hull_shift(province: ProvinceSim, ship: ShipUnit) -> Vector2:
	var port := province.buildings.get_building(ship.berth_id) if ship.berth_id != 0 else null
	if port == null or not port.def.is_port():
		return Vector2.ZERO
	var away := Vector2(port.berth_tile() - port.gangway_tile())
	if away == Vector2.ZERO:
		return Vector2.ZERO
	var near := clampf(1.0 - ship.pos.distance_to(IsoMath.tile_center(port.berth_tile())) / 1.5, 0.0, 1.0)
	return away.normalized() * MOORED_HULL_SHIFT * near


## A cog: one sheet (ships/<id>/idle.png) whose frames rock it gently on the waves.
func _show_big(sprite: Sprite2D, ship: ShipUnit, alpha: float, time: float) -> void:
	var size: Vector2i = BIG_FRAMES[ship.def.art_id()][0]
	var pivot: Vector2 = BIG_FRAMES[ship.def.art_id()][1]
	var texture := _texture("ships/%s/idle.png" % ship.def.art_id())
	sprite.texture = texture
	var frames := maxi(texture.get_width() / size.x, 1) if texture != null else 1
	sprite.hframes = frames
	sprite.vframes = IsoMath.DIR_COUNT
	sprite.frame = ship.facing * frames + int(time * FPS * 0.5 + ship.id * 0.37) % frames
	var screen := IsoMath.grid_to_screen(ship.prev_pos.lerp(ship.pos, alpha) + hull_shift(province, ship))
	# Just launched, by the shipyard: sorted in front of it like the hull on the slipway was,
	# so the end of the slipway does not cut into the stern (review fix 2026-11-07).
	var sort_y := maxf(screen.y, _slipway_front(ship.pos))
	sprite.position = Vector2(screen.x, sort_y)
	sprite.offset = -pivot - Vector2(0, sort_y - screen.y)


## Sort y of the front of a shipyard whose berth lies within LAUNCH_REACH tiles of
## [param at] (one past its front corner, as the hull on its slipway), -INF if none.
func _slipway_front(at: Vector2) -> float:
	for building: BuildingState in province.buildings.all():
		if building.def.ship_kinds.is_empty() or not building.def.has_berth():
			continue
		if IsoMath.tile_center(building.berth_tile()).distance_to(at) <= LAUNCH_REACH:
			return IsoMath.grid_to_screen(Vector2(building.origin + building.def.footprint)).y + 1.0
	return -INF


## A plank from the quay up to the gunwale of every ship moored at a port.
func _update_planks() -> void:
	var seen: Dictionary[int, bool] = {}
	for ship: ShipUnit in province.ships.values():
		var port := Harbour.port_of(province, ship.id)
		if port == null:
			continue
		seen[ship.id] = true
		var plank: Polygon2D = _planks.get(ship.id)
		if plank == null:
			plank = Polygon2D.new()
			plank.color = PLANK
			add_child(plank)
			var edge := Line2D.new()
			edge.width = 1.0
			edge.default_color = PLANK_EDGE
			plank.add_child(edge)
			_planks[ship.id] = plank
		var foot := IsoMath.tile_center(port.gangway_tile())
		var berth := Harbour.moor_point(port.gangway_tile(), port.berth_tile())
		var top := berth + (foot - berth).normalized() * PLANK_INBOARD
		# Sorted just in front of the ship: the plank lies on its gunwale, over the hull.
		plank.position = IsoMath.grid_to_screen(berth) + Vector2(0, 1)
		var a := IsoMath.grid_to_screen(foot) - plank.position + Vector2(0, -QUAY_HEIGHT)
		var b := IsoMath.grid_to_screen(top) - plank.position + Vector2(0, -GUNWALE_HEIGHT)
		var side := (b - a).orthogonal().normalized() * 4.0
		plank.polygon = PackedVector2Array([a - side, b - side, b + side, a + side])
		(plank.get_child(0) as Line2D).points = PackedVector2Array([a - side, b - side, b + side, a + side, a - side])
	for id: int in _planks.keys():
		if not seen.has(id):
			_planks[id].queue_free()
			_planks.erase(id)


## Which boat animation shows what the ship (and its crew) is doing.
static func _anim(ship: ShipUnit) -> StringName:
	if ship.crew == 0:
		return &"idle"
	if FRAMES.has(ship.activity) and ship.activity != &"idle":
		return ship.activity
	return &"row"


func _update_builds() -> void:
	for id: int in _builds.keys():
		if not province.ship_builds.has(id):
			_builds[id].queue_free()
			_builds.erase(id)
	for build: ShipBuild in province.ship_builds.values():
		var shipyard := province.buildings.get_building(build.shipyard_id)
		var visible := shipyard != null and (build.stage > 0 or build.stage_started)
		var sprite: Sprite2D = _builds.get(build.id)
		if not visible:
			if sprite != null:
				sprite.visible = false
			continue
		if sprite == null:
			sprite = _sprite()
			_builds[build.id] = sprite
		sprite.visible = true
		# The stage being worked on: frame and keel, the planked hull, the mast with the sail
		# (a boat has 2 stages, a cog 4; the cog's last one, the launch, slides it down).
		var big := BIG_FRAMES.has(build.ship)
		var shown := clampi(build.stage, 0, 2 if big else 1)
		sprite.texture = _texture("ships/%s/build_%d.png" % [build.ship, shown])
		sprite.hframes = 1
		sprite.vframes = IsoMath.DIR_COUNT
		# The slipway runs towards the berth: along +y as drawn, along +x mirrored.
		var towards := shipyard.def.turned(Vector2i(0, 1), shipyard.orientation) - shipyard.def.turned(Vector2i.ZERO, shipyard.orientation)
		var dir := IsoMath.screen_dir(Vector2(towards))
		var slip := shipyard.def.water_tiles_at(shipyard.origin, shipyard.orientation)
		var centre := Vector2.ZERO
		for tile: Vector2i in slip:
			centre += IsoMath.tile_center(tile)
		centre /= maxf(slip.size(), 1.0)
		if not big:
			sprite.frame = maxi(dir, 0)
			sprite.position = IsoMath.grid_to_screen(centre) + Vector2(0, SLIP_SORT_OFFSET)
			sprite.offset = -BOAT_PIVOT - Vector2(0, SLIP_SORT_OFFSET + 4.0)
			continue
		# A cog lies along the slipway, bow to the water, sliding down at the launch.
		sprite.frame = maxi(dir, 0)
		var slide := launch_slide(build)
		if slide > 0.0:
			# Off its blocks: the hull as it will float (ShipLayer._show_big draws it the same
			# way at the berth, so nothing jumps when the ship takes over).
			sprite.texture = _texture("ships/%s/idle.png" % build.ship)
			var frames := maxi(sprite.texture.get_width() / (BIG_FRAMES[build.ship][0] as Vector2i).x, 1)
			sprite.hframes = frames
			sprite.frame = maxi(dir, 0) * frames
		var berth := IsoMath.tile_center(shipyard.berth_tile())
		# A cog is longer than the slipway: it lies with its stern at the shore end of the
		# slipway and its bow over the water, so the workshop never covers the stern.
		var start := centre + Vector2(towards) * COG_ON_SLIP
		var at := start.lerp(berth, slide)
		var pivot: Vector2 = BIG_FRAMES[build.ship][1]
		var lift := SLIP_LIFT * (1.0 - slide)
		# Sorted just in front of the whole shipyard (its front corner, where the building
		# sorts): the tall hull on its blocks is drawn over the slipway, the low jetty beside it
		# and the workshop behind it.
		var front := IsoMath.grid_to_screen(Vector2(shipyard.origin + shipyard.def.footprint)).y
		var sort_y := maxf(front, IsoMath.grid_to_screen(at).y) + 1.0
		var screen := IsoMath.grid_to_screen(at)
		sprite.position = Vector2(screen.x, sort_y)
		sprite.offset = -pivot - Vector2(0, sort_y - screen.y + lift)


## How far (0..1) the hull of a cog being launched has come from the slipway to the berth:
## 0 until the last LAUNCH_SLIDE seconds of the launch stage, then eased in and out.
static func launch_slide(build: ShipBuild) -> float:
	if build.stage < 3 or not build.stage_started:
		return 0.0
	var slide_ticks := minf(SimClock.seconds_to_ticks(LAUNCH_SLIDE), maxf(build.stage_ticks, 1.0))
	var u := clampf(1.0 - float(build.work_left) / slide_ticks, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


func _sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	add_child(sprite)
	return sprite


func _texture(relative: String) -> Texture2D:
	if not _textures.has(relative):
		_textures[relative] = ArtPaths.texture(relative)
	return _textures[relative]
