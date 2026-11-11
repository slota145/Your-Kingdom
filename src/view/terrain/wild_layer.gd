class_name WildLayer
extends Node2D
## Wild deer and boar (E2 part 2): every herd of the simulation (WildHerds) is shown as its
## animals grazing and rooting around the herd's spot; when the spot moves they walk after it,
## when a hunter shoots they run (an arrow flies, one animal falls out of the herd). The
## animals' own paths are the view's: nothing of them is saved. Child of the y-sorted world.

## Tiles a second walking, running from a shot.
const WALK_SPEED := 0.5
const RUN_SPEED := 2.6
## Animals stay this far (tiles) around their herd's spot.
const SPREAD := 1.3
## Seconds an animal rests (idle, graze, root) between two steps.
const REST := Vector2(2.0, 6.0)
## Seconds an arrow flies.
const ARROW_TIME := 0.35
const ARROW_COLOUR := Color(0.36, 0.26, 0.16)
const FLETCH_COLOUR := Color(0.9, 0.88, 0.8)

var province: ProvinceSim
var _herds: Dictionary[int, Array] = {}
var _centres: Dictionary[int, Vector2i] = {}
var _sheets: Dictionary[StringName, _Sheet] = {}
var _arrows: _Arrows
var _rng := RandomNumberGenerator.new()


class _Sheet:
	var textures: Dictionary[String, Texture2D] = {}
	var frames: Dictionary[String, int] = {}
	var frame_time: Dictionary[String, float] = {}
	var foot: Vector2 = Vector2(16, 21)


class _Animal:
	var sprite: Sprite2D
	var sheet: _Sheet
	var pos: Vector2
	var target: Vector2
	var walking: bool = false
	var running: bool = false
	var rest: float = 0.0
	var anim: String = "idle"
	var dir: int = 0
	var clock: float = 0.0


## Arrows in flight, drawn as short lines over everything on the ground.
class _Arrows:
	extends Node2D
	var flights: Array[Dictionary] = []

	func _draw() -> void:
		for f: Dictionary in flights:
			var k: float = clampf(float(f["t"]) / ARROW_TIME, 0.0, 1.0)
			var a: Vector2 = f["from"]
			var b: Vector2 = f["to"]
			var at := a.lerp(b, k) + Vector2(0, -10.0 - sin(k * PI) * 8.0)
			var dir := (b - a).normalized()
			draw_line(at - dir * 6.0, at, ARROW_COLOUR, 1.0)
			draw_line(at - dir * 6.0, at - dir * 4.0, FLETCH_COLOUR, 1.0)


func _init() -> void:
	y_sort_enabled = true
	_rng.seed = 7


func setup(source: ProvinceSim) -> void:
	province = source
	_arrows = _Arrows.new()
	_arrows.z_index = 2
	add_child(_arrows)


func on_sim_event(event: Dictionary) -> void:
	if event["type"] == &"hunt_shot":
		var from: Vector2 = IsoMath.grid_to_screen(SimCodec.to_vec2(event["from"]))
		var to: Vector2 = IsoMath.tile_center_screen(SimCodec.to_vec2i(event["to"]))
		_arrows.flights.append({"from": from, "to": to, "t": 0.0})


func update_view(delta: float) -> void:
	if province == null:
		return
	var seen: Dictionary[int, bool] = {}
	for herd: WildHerds.Herd in province.wild.herds.values():
		seen[herd.id] = true
		_sync(herd)
	for id: int in _herds.keys():
		if not seen.has(id):
			for animal: _Animal in _herds[id]:
				animal.sprite.queue_free()
			_herds.erase(id)
			_centres.erase(id)
	for id: int in _herds:
		for animal: _Animal in _herds[id]:
			_step(animal, _centres[id], delta)
			_show(animal)
	if not _arrows.flights.is_empty():
		for f: Dictionary in _arrows.flights:
			f["t"] = float(f["t"]) + delta
		_arrows.flights = _arrows.flights.filter(func(f: Dictionary) -> bool: return float(f["t"]) < ARROW_TIME)
		_arrows.queue_redraw()


## Matches the animals of [param herd] to its count and its spot.
func _sync(herd: WildHerds.Herd) -> void:
	var animals: Array = _herds.get(herd.id, [])
	var sheet := _sheet(herd.kind)
	while animals.size() < herd.count:
		var animal := _Animal.new()
		animal.sheet = sheet
		animal.sprite = Sprite2D.new()
		animal.sprite.centered = false
		animal.sprite.offset = -sheet.foot
		animal.pos = _around(herd.tile)
		animal.target = animal.pos
		animal.rest = _rng.randf_range(0.0, REST.y)
		animal.dir = _rng.randi_range(0, IsoMath.DIR_COUNT - 1)
		add_child(animal.sprite)
		animals.append(animal)
	while animals.size() > herd.count:
		var gone: _Animal = animals.pop_back()
		gone.sprite.queue_free()
	_herds[herd.id] = animals
	var old: Vector2i = _centres.get(herd.id, herd.tile)
	_centres[herd.id] = herd.tile
	if old != herd.tile:
		# The herd moved on (or fled a shot): everyone heads for the new spot.
		var flight := (herd.tile - old).length() > WildHerds.WANDER_TILES + 1.5
		for animal: _Animal in animals:
			_walk_to(animal, _around(herd.tile), flight)


func _step(animal: _Animal, centre: Vector2i, delta: float) -> void:
	animal.clock += delta
	if animal.walking:
		var to := animal.target - animal.pos
		var step := (RUN_SPEED if animal.running else WALK_SPEED) * delta
		if to.length() <= step:
			animal.pos = animal.target
			animal.walking = false
			animal.running = false
			animal.rest = _rng.randf_range(REST.x, REST.y)
			animal.anim = "idle"
			if _rng.randf() < 0.6:
				animal.anim = "graze" if animal.sheet.textures.has("graze") else "root"
			animal.clock = 0.0
		else:
			animal.pos += to.normalized() * step
		return
	animal.rest -= delta
	if animal.rest <= 0.0:
		_walk_to(animal, _around(centre), false)


func _walk_to(animal: _Animal, target: Vector2, run: bool) -> void:
	animal.target = target
	animal.walking = true
	animal.running = run
	animal.anim = "walk"
	var dir := IsoMath.screen_dir(target - animal.pos)
	if dir >= 0:
		animal.dir = dir


func _around(tile: Vector2i) -> Vector2:
	var a := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * SPREAD
	return Vector2(tile) + Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * r


func _show(animal: _Animal) -> void:
	var sheet := animal.sheet
	var anim := animal.anim if sheet.textures.has(animal.anim) else "idle"
	var texture: Texture2D = sheet.textures.get(anim)
	if texture == null:
		animal.sprite.visible = false
		return
	if animal.sprite.texture != texture:
		animal.sprite.texture = texture
		animal.sprite.hframes = sheet.frames[anim]
		animal.sprite.vframes = IsoMath.DIR_COUNT
	var pace := 2.0 if animal.running else 1.0
	var frame := int(animal.clock * pace / sheet.frame_time[anim]) % sheet.frames[anim]
	animal.sprite.frame = animal.dir * sheet.frames[anim] + frame
	animal.sprite.position = IsoMath.grid_to_screen(animal.pos).round()


## Sheets of an animal (assets/animals/<kind>/, tools/spritekiln/export_animal.py).
func _sheet(kind: StringName) -> _Sheet:
	if _sheets.has(kind):
		return _sheets[kind]
	var sheet := _Sheet.new()
	var path := ArtPaths.resolve("animals/%s/sheet.json" % kind)
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if info is Dictionary:
		var d := info as Dictionary
		var foot: Array = d.get("foot", [16, 21])
		sheet.foot = Vector2(float(foot[0]), float(foot[1]))
		var anims: Dictionary = d.get("anims", {})
		for anim: Variant in anims:
			var a := anims[anim] as Dictionary
			var texture := ArtPaths.texture("animals/%s/%s.png" % [kind, anim])
			if texture == null:
				continue
			sheet.textures[String(anim)] = texture
			sheet.frames[String(anim)] = int(a.get("frames", 1))
			sheet.frame_time[String(anim)] = float(a.get("ms", 120)) / 1000.0
	_sheets[kind] = sheet
	return sheet
