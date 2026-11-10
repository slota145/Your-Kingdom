class_name PenLayer
extends Node2D
## Animal pens (Z1): a fence round every pen (touching pen tiles of one building, Pens.groups),
## a gate on the side nearest the building's door, and the herd's animals walking, standing
## and rooting inside. Child of the y-sorted world.
##
## Only the view: the simulation counts the animals of a herd (its yard), this layer gives each
## one a place and a stroll inside its pen (no paths, nothing saved). The fence is drawn in code
## like the bridge rails (posts and two rails, ART_SPEC §10.21); each fence edge is its own node
## sorted at the edge's middle, so animals and people stand before the back fence and behind the
## front one.

## Height of a fence post and of its two rails above the ground (screen px).
const POST_H := 13.0
const RAILS: Array[float] = [5.0, 10.0]
const POST_W := 2.0
const GATE_POST_H := 16.0
const WOOD := Color(0.47, 0.33, 0.2)
const WOOD_DARK := Color(0.3, 0.2, 0.12)
const WOOD_LIGHT := Color(0.62, 0.46, 0.28)
## Animals drawn at most per building (a crowded pen still shows a crowd).
const MAX_ANIMALS := 40
## Walking speed of an animal (tiles per second) and how far from a fence it keeps.
const SPEED := 0.55
const MARGIN := 0.2
## How far x + y of a resting spot may be from the middle of its tile (_point_in).
const CORNER := 0.42
## Seconds an animal stands, roots or grazes before it walks again (from, to).
const REST := Vector2(1.5, 5.0)

var province: ProvinceSim
## Building id -> its animals (_Animal).
var _herds: Dictionary[int, Array] = {}
## Building id -> its pens: [{tiles: Dictionary[Vector2i, bool], gate: [tile, side]}].
var _pens: Dictionary[int, Array] = {}
## Fence nodes by "x,y,side" key.
var _fences: Dictionary[String, _Fence] = {}
var _sheets: Dictionary[StringName, _Sheet] = {}
var _dirty: bool = true
var _rng := RandomNumberGenerator.new()


class _Sheet:
	var textures: Dictionary[String, Texture2D] = {}
	var frames: Dictionary[String, int] = {}
	var frame_time: Dictionary[String, float] = {}
	var foot: Vector2 = Vector2(16, 21)
	var size: int = 32


class _Animal:
	var sprite: Sprite2D
	var sheet: _Sheet
	var pen: int = 0
	var pos: Vector2
	var target: Vector2
	var walking: bool = false
	var rest: float = 0.0
	var anim: String = "idle"
	var dir: int = 0
	var clock: float = 0.0


class _Fence:
	extends Node2D
	## Ends of the edge relative to the node (screen px, on the ground).
	var a: Vector2
	var b: Vector2
	## Gate: 0 none, 1 closed, 2 open (swung into the pen towards [member inward]).
	var gate: int = 0
	var inward: Vector2

	func _draw() -> void:
		var up := Vector2(0, -1)
		if gate == 0:
			for h: float in RAILS:
				draw_line(a + up * h, b + up * h, WOOD_DARK, 2.0)
				draw_line(a + up * (h + 1.0), b + up * (h + 1.0), WOOD_LIGHT, 1.0)
			_post(a, POST_H)
			_post(b, POST_H)
			return
		_post(a, GATE_POST_H)
		_post(b, GATE_POST_H)
		# The gate leaf: planks with a brace, hinged at [member a].
		var end := b if gate == 1 else a + inward * (b - a).length() * 0.9
		var top := 12.0
		var low := 3.0
		draw_colored_polygon(PackedVector2Array([a + up * low, end + up * low, end + up * top, a + up * top]), WOOD)
		draw_line(a + up * low, end + up * low, WOOD_DARK, 1.0)
		draw_line(a + up * top, end + up * top, WOOD_LIGHT, 1.0)
		draw_line(a + up * low, end + up * top, WOOD_DARK, 1.0)
		for k: int in range(1, 4):
			var p := a.lerp(end, k / 4.0)
			draw_line(p + up * low, p + up * top, WOOD_DARK.lerp(WOOD, 0.5), 1.0)

	func _post(at: Vector2, height: float) -> void:
		var r := Rect2(at + Vector2(-POST_W * 0.5, -height), Vector2(POST_W, height))
		draw_rect(r, WOOD)
		draw_line(at + Vector2(-POST_W * 0.5, -height), at + Vector2(-POST_W * 0.5, 0), WOOD_LIGHT, 1.0)
		draw_rect(Rect2(at + Vector2(-POST_W * 0.5 - 0.5, -height - 1.0), Vector2(POST_W + 1.0, 1.0)), WOOD_DARK)


func _init() -> void:
	y_sort_enabled = true
	_rng.seed = 7


func setup(source: ProvinceSim) -> void:
	province = source
	_dirty = true


## Pens changed (a pen tile placed or removed, a building gone): rebuilt on the next frame.
func on_sim_event(event: Dictionary) -> void:
	match event["type"]:
		&"field_changed", &"building_removed", &"building_completed", &"building_placed":
			_dirty = true


func update_view(delta: float) -> void:
	if province == null:
		return
	if _dirty:
		_dirty = false
		_rebuild_pens()
	for id: int in _pens:
		var building := province.buildings.get_building(id)
		if building == null:
			continue
		_update_gates(building)
		_update_herd(building, delta)


# --- Fences and gates ------------------------------------------------------------------------

func _rebuild_pens() -> void:
	var seen: Dictionary[String, bool] = {}
	var live: Dictionary[int, bool] = {}
	_pens.clear()
	for building: BuildingState in province.buildings.all():
		if not building.def.has_pens():
			continue
		var pens: Array = []
		for group: Array in Pens.groups(province, building.id):
			var tiles: Dictionary[Vector2i, bool] = {}
			for tile: Vector2i in group:
				tiles[tile] = true
			var gate := Pens.gate(building, group)
			pens.append({"tiles": tiles, "list": group, "gate": gate})
			for tile: Vector2i in group:
				for side: Vector2i in Pens.SIDES:
					if tiles.has(tile + side):
						continue
					var key := "%d,%d,%d,%d" % [tile.x, tile.y, side.x, side.y]
					seen[key] = true
					var fence := _fence(key, tile, side)
					var is_gate: bool = gate[0] == tile and gate[1] == side
					if is_gate and fence.gate == 0:
						fence.gate = 1
						fence.queue_redraw()
					elif not is_gate and fence.gate != 0:
						fence.gate = 0
						fence.queue_redraw()
		if not pens.is_empty():
			_pens[building.id] = pens
			live[building.id] = true
	for key: String in _fences.keys():
		if not seen.has(key):
			_fences[key].queue_free()
			_fences.erase(key)
	for id: int in _herds.keys():
		if not live.has(id):
			for animal: _Animal in _herds[id]:
				animal.sprite.queue_free()
			_herds.erase(id)


func _fence(key: String, tile: Vector2i, side: Vector2i) -> _Fence:
	var fence: _Fence = _fences.get(key)
	if fence != null:
		return fence
	fence = _Fence.new()
	# The edge's ends in grid space: the side of the tile facing [param side].
	var c := Vector2(tile) + Vector2(0.5, 0.5) + Vector2(side) * 0.5
	var along := Vector2(-side.y, side.x) * 0.5
	var ga := c - along
	var gb := c + along
	var mid := IsoMath.grid_to_screen(c)
	fence.position = mid
	fence.a = IsoMath.grid_to_screen(ga) - mid
	fence.b = IsoMath.grid_to_screen(gb) - mid
	var into := IsoMath.grid_to_screen(c - Vector2(side) * 0.5) - mid
	fence.inward = into.normalized() if into.length() > 0.0 else Vector2.UP
	add_child(fence)
	_fences[key] = fence
	return fence


## A gate stands open while somebody is on its tile or right outside it.
func _update_gates(building: BuildingState) -> void:
	for pen: Dictionary in _pens[building.id]:
		var gate: Array = pen["gate"]
		var tile: Vector2i = gate[0]
		var side: Vector2i = gate[1]
		var open := false
		for id: int in building.workers:
			var agent := province.agents.get_agent(id)
			if agent != null and (agent.tile() == tile or agent.tile() == tile + side):
				open = true
		var fence: _Fence = _fences.get("%d,%d,%d,%d" % [tile.x, tile.y, side.x, side.y])
		var state := 2 if open else 1
		if fence != null and fence.gate != state:
			fence.gate = state
			fence.queue_redraw()


# --- Animals -------------------------------------------------------------------------------

func _update_herd(building: BuildingState, delta: float) -> void:
	var pens: Array = _pens[building.id]
	var count := 0
	if building.yard != null and building.def.herd_good != &"":
		count = mini(building.yard.total(building.def.herd_good), MAX_ANIMALS)
	var herd: Array = _herds.get(building.id, [])
	var sheet := _sheet(building.def.herd_good)
	while herd.size() > count:
		var gone: _Animal = herd.pop_back()
		gone.sprite.queue_free()
	while herd.size() < count:
		herd.append(_new_animal(sheet, pens, herd))
	_herds[building.id] = herd
	for animal: _Animal in herd:
		if animal.pen >= pens.size() or not (pens[animal.pen]["tiles"] as Dictionary).has(_tile_of(animal.pos)):
			# Its pen changed: a new place in a pen.
			animal.pen = _emptiest_pen(pens, herd, animal)
			animal.pos = _spot(pens[animal.pen]["list"], herd, animal)
			animal.walking = false
		_step(animal, pens[animal.pen], delta)
		_show(animal, sheet)


func _new_animal(sheet: _Sheet, pens: Array, herd: Array) -> _Animal:
	var animal := _Animal.new()
	animal.sheet = sheet
	animal.pen = _emptiest_pen(pens, herd, null)
	animal.pos = _spot(pens[animal.pen]["list"], herd, null)
	animal.dir = _rng.randi_range(0, IsoMath.DIR_COUNT - 1)
	animal.rest = _rng.randf_range(0.0, REST.y)
	animal.clock = _rng.randf_range(0.0, 2.0)
	animal.sprite = Sprite2D.new()
	animal.sprite.centered = false
	animal.sprite.offset = -sheet.foot
	add_child(animal.sprite)
	return animal


## The pen with the fewest animals for its size (animals spread over the pens).
func _emptiest_pen(pens: Array, herd: Array, except: _Animal) -> int:
	var best := 0
	var best_load := INF
	for i: int in pens.size():
		var n := 0
		for other: _Animal in herd:
			if other != except and other.pen == i:
				n += 1
		var load := n / float((pens[i]["list"] as Array).size())
		if load < best_load:
			best_load = load
			best = i
	return best


## A place on the tile of [param tiles] with the fewest animals of [param herd] (the herd
## spreads over its pen), the first of them from a random start.
func _spot(tiles: Array, herd: Array, except: _Animal) -> Vector2:
	var start := _rng.randi_range(0, tiles.size() - 1)
	var best: Vector2i = tiles[start]
	var best_n := 1 << 20
	for k: int in tiles.size():
		var tile: Vector2i = tiles[(start + k) % tiles.size()]
		var n := 0
		for other: _Animal in herd:
			if other != except and other.sprite != null and _tile_of(other.pos) == tile:
				n += 1
		if n < best_n:
			best_n = n
			best = tile
	return _point_in(best)


## A random point of [param tile] away from its fences: also away from the front and back
## corners (x + y within the middle of the tile), so a resting animal always sorts between the
## fence behind it and the fence in front of it (each sorted at the middle of its edge).
func _point_in(tile: Vector2i) -> Vector2:
	var p := Vector2(0.5, 0.5)
	for attempt: int in 8:
		p = Vector2(_rng.randf_range(MARGIN, 1.0 - MARGIN), _rng.randf_range(MARGIN, 1.0 - MARGIN))
		if absf(p.x + p.y - 1.0) <= CORNER:
			break
	if absf(p.x + p.y - 1.0) > CORNER:
		p = Vector2(0.5, 0.5)
	return Vector2(tile) + p


## Rests, then walks to a spot in its own tile or a neighbouring tile of the pen (a straight
## line between them stays inside, also in an L-shaped pen).
func _step(animal: _Animal, pen: Dictionary, delta: float) -> void:
	animal.clock += delta
	if animal.walking:
		var to := animal.target - animal.pos
		var step := SPEED * delta
		if to.length() <= step:
			animal.pos = animal.target
			animal.walking = false
			animal.rest = _rng.randf_range(REST.x, REST.y)
			# Pigs root in the mud, sheep and horses graze (whichever the sheet has).
			animal.anim = "idle"
			if _rng.randf() < 0.5:
				animal.anim = "graze" if animal.sheet.textures.has("graze") else "root"
			animal.clock = 0.0
		else:
			animal.pos += to.normalized() * step
		return
	animal.rest -= delta
	if animal.rest > 0.0:
		return
	var here := _tile_of(animal.pos)
	var options: Array[Vector2i] = [here]
	for side: Vector2i in Pens.SIDES:
		if (pen["tiles"] as Dictionary).has(here + side):
			options.append(here + side)
	var tile := options[_rng.randi_range(0, options.size() - 1)]
	animal.target = _point_in(tile)
	var dir := IsoMath.screen_dir(animal.target - animal.pos)
	if dir >= 0:
		animal.dir = dir
	animal.walking = true
	animal.anim = "walk"


func _show(animal: _Animal, sheet: _Sheet) -> void:
	var anim := animal.anim if sheet.textures.has(animal.anim) else "idle"
	var texture: Texture2D = sheet.textures.get(anim)
	if texture == null:
		animal.sprite.visible = false
		return
	if animal.sprite.texture != texture:
		animal.sprite.texture = texture
		animal.sprite.hframes = sheet.frames[anim]
		animal.sprite.vframes = IsoMath.DIR_COUNT
	var frame := int(animal.clock / sheet.frame_time[anim]) % sheet.frames[anim]
	animal.sprite.frame = animal.dir * sheet.frames[anim] + frame
	animal.sprite.position = IsoMath.grid_to_screen(animal.pos).round()


static func _tile_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x), floori(pos.y))


## Sheets of an animal (assets/animals/<good>/, tools/spritekiln/export_animal.py).
func _sheet(good: StringName) -> _Sheet:
	if _sheets.has(good):
		return _sheets[good]
	var sheet := _Sheet.new()
	var info: Variant = null
	var path := ArtPaths.resolve("animals/%s/sheet.json" % good)
	if FileAccess.file_exists(path):
		info = JSON.parse_string(FileAccess.get_file_as_string(path))
	if info is Dictionary:
		var d := info as Dictionary
		sheet.size = int(d.get("frame", 32))
		var foot: Array = d.get("foot", [16, 21])
		sheet.foot = Vector2(float(foot[0]), float(foot[1]))
		var anims: Dictionary = d.get("anims", {})
		for anim: Variant in anims:
			var a := anims[anim] as Dictionary
			var texture := ArtPaths.texture("animals/%s/%s.png" % [good, anim])
			if texture == null:
				continue
			sheet.textures[String(anim)] = texture
			sheet.frames[String(anim)] = int(a.get("frames", 1))
			sheet.frame_time[String(anim)] = float(a.get("ms", 120)) / 1000.0
	_sheets[good] = sheet
	return sheet
