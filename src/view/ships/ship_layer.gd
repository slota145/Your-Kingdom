class_name ShipLayer
extends Node2D
## Ships on the water and ships on shipyard slipways (M5, ART_SPEC §9). Child of the y-sorted
## world; sprites are kept per ship and per ship build and refreshed every frame from the
## simulation state (there are few of them). The crew is part of the boat art: a fisherman
## aboard is not drawn by the AgentViewPool.

## Boat centre at the waterline in each frame of ships/<id>/<anim>.png (tools/generate_ships.gd).
const BOAT_PIVOT := Vector2(40, 46)
const FRAMES := {&"idle": 1, &"row": 4, &"cast_net": 4, &"wait_net": 4, &"haul_net": 4}
## Frames per second of the boat animations.
const FPS := 5.0
## A ship on the slipway sorts at the front of the slipway (over the building), drawn this
## far back up from there (px).
const SLIP_SORT_OFFSET := 24.0

var province: ProvinceSim
var _ships: Dictionary[int, Sprite2D] = {}
var _builds: Dictionary[int, Sprite2D] = {}
var _textures: Dictionary[String, Texture2D] = {}


func _init() -> void:
	y_sort_enabled = true


func setup(source: ProvinceSim) -> void:
	province = source


func update_view(alpha: float, time: float) -> void:
	_update_ships(alpha, time)
	_update_builds()


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
		# Frame and keel while the first stage is worked on, the planked hull after it.
		var shown := clampi(build.stage if not build.stage_started else build.stage, 0, 1)
		sprite.texture = _texture("ships/%s/build_%d.png" % [build.ship, shown])
		sprite.hframes = 1
		sprite.vframes = IsoMath.DIR_COUNT
		# The slipway runs towards the berth: along +y as drawn, along +x mirrored.
		var towards := shipyard.def.turned(Vector2i(0, 1), shipyard.orientation) - shipyard.def.turned(Vector2i.ZERO, shipyard.orientation)
		var dir := IsoMath.screen_dir(Vector2(towards))
		sprite.frame = maxi(dir, 0)
		var slip := shipyard.def.water_tiles_at(shipyard.origin, shipyard.orientation)
		var centre := Vector2.ZERO
		for tile: Vector2i in slip:
			centre += IsoMath.tile_center(tile)
		centre /= maxf(slip.size(), 1.0)
		sprite.position = IsoMath.grid_to_screen(centre) + Vector2(0, SLIP_SORT_OFFSET)
		sprite.offset = -BOAT_PIVOT - Vector2(0, SLIP_SORT_OFFSET + 4.0)


func _sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	add_child(sprite)
	return sprite


func _texture(relative: String) -> Texture2D:
	if not _textures.has(relative):
		_textures[relative] = ArtPaths.texture(relative)
	return _textures[relative]
