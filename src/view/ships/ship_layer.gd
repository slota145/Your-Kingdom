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
	sprite.position = IsoMath.grid_to_screen(ship.prev_pos.lerp(ship.pos, alpha))
	sprite.offset = -pivot


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
		var berth := IsoMath.tile_center(port.berth_tile())
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
		var slide := 0.0
		if build.stage >= 3 and build.stage_started:
			slide = 1.0 - float(build.work_left) / maxf(build.stage_ticks, 1.0)
		var berth := IsoMath.tile_center(shipyard.berth_tile())
		var at := centre.lerp(berth, slide * slide)
		var pivot: Vector2 = BIG_FRAMES[build.ship][1]
		var lift := SLIP_LIFT * (1.0 - slide)
		sprite.position = IsoMath.grid_to_screen(at) + Vector2(0, SLIP_SORT_OFFSET)
		sprite.offset = -pivot - Vector2(0, SLIP_SORT_OFFSET + lift)


func _sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	add_child(sprite)
	return sprite


func _texture(relative: String) -> Texture2D:
	if not _textures.has(relative):
		_textures[relative] = ArtPaths.texture(relative)
	return _textures[relative]
