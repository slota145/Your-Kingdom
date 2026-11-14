class_name AmbiencePlayer
extends Node
## The background of a province (ROADMAP M10 part 1): birds over the forest, waves and
## gulls by the water, the hubbub of a town. Each AmbienceDef is as loud as there is of its
## source on screen, so panning from the woods to the harbour changes what you hear.

const BUS := &"Ambience"
## Seconds between looks at the screen (the share of forest and water).
const SURVEY_EVERY := 0.5
## At most this many tiles looked at per survey (the rest are stepped over).
const SURVEY_SAMPLES := 600
## How fast the volume follows the screen (share of the full range per second).
const FADE_SPEED := 0.6
## Silence, in decibels.
const SILENT_DB := -60.0

var _defs: Array[AmbienceDef] = []
var _beds: Array[AudioStreamPlayer] = []
var _shots: Array[AudioStreamPlayer] = []
## Current and wanted level of each def (0..1).
var _level: PackedFloat32Array = PackedFloat32Array()
var _target: PackedFloat32Array = PackedFloat32Array()
var _next_shot: PackedFloat32Array = PackedFloat32Array()
var _survey_time: float = 0.0
var _rng := RandomNumberGenerator.new()
static var _terrains: Array[TerrainDef] = []


func _init() -> void:
	_defs = SoundBank.ambiences()
	for def: AmbienceDef in _defs:
		var bed := AudioStreamPlayer.new()
		bed.bus = BUS
		bed.volume_db = SILENT_DB
		if def.bed != "":
			bed.stream = SoundBank.looping(def.bed)
		add_child(bed)
		_beds.append(bed)
		var shot := AudioStreamPlayer.new()
		shot.bus = BUS
		add_child(shot)
		_shots.append(shot)
	_level.resize(_defs.size())
	_target.resize(_defs.size())
	_next_shot.resize(_defs.size())
	for i: int in _defs.size():
		_next_shot[i] = _rng.randf_range(_defs[i].scatter_every.x, _defs[i].scatter_every.y)


func update_sounds(province: ProvinceSim, visible_rect: Rect2, people: int, delta: float) -> void:
	_survey_time -= delta
	if _survey_time <= 0.0:
		_survey_time = SURVEY_EVERY
		var shares := survey(province, visible_rect)
		for i: int in _defs.size():
			var def := _defs[i]
			var amount: float = float(people) / 100.0 if def.source == AmbienceDef.Source.TOWN else float(shares[def.source])
			_target[i] = clampf(amount / def.full_at, 0.0, 1.0)
	for i: int in _defs.size():
		var def := _defs[i]
		_level[i] = move_toward(_level[i], _target[i], FADE_SPEED * delta)
		var bed := _beds[i]
		if bed.stream != null:
			bed.volume_db = level_db(def.bed_db, _level[i])
			if _level[i] > 0.0 and not bed.playing:
				# Each bed starts at a random point, so two visits do not sound the same.
				bed.play(_rng.randf_range(0.0, bed.stream.get_length()))
			elif _level[i] <= 0.0 and bed.playing:
				bed.stop()
		if def.scatter.is_empty():
			continue
		_next_shot[i] -= delta
		if _next_shot[i] > 0.0:
			continue
		# Fewer gulls and birds where there is less sea and forest.
		_next_shot[i] = _rng.randf_range(def.scatter_every.x, def.scatter_every.y) / maxf(_level[i], 0.25)
		if _level[i] < 0.1:
			continue
		var shot := _shots[i]
		shot.stream = SoundBank.stream(def.scatter[_rng.randi() % def.scatter.size()])
		shot.volume_db = level_db(def.scatter_db, _level[i])
		shot.pitch_scale = _rng.randf_range(0.94, 1.06)
		shot.play()


## Share of the tiles in [param rect] (world pixels) with trees and with water, as
## {Source.FOREST: share, Source.WATER: share}. Tiles off the map are not counted.
static func survey(province: ProvinceSim, rect: Rect2) -> Dictionary:
	var shares := {AmbienceDef.Source.FOREST: 0.0, AmbienceDef.Source.WATER: 0.0}
	var corners: Array[Vector2i] = [
		IsoMath.tile_at_screen(rect.position), IsoMath.tile_at_screen(rect.end),
		IsoMath.tile_at_screen(Vector2(rect.end.x, rect.position.y)),
		IsoMath.tile_at_screen(Vector2(rect.position.x, rect.end.y)),
	]
	var low := corners[0]
	var high := corners[0]
	for c: Vector2i in corners:
		low = Vector2i(mini(low.x, c.x), mini(low.y, c.y))
		high = Vector2i(maxi(high.x, c.x), maxi(high.y, c.y))
	low = Vector2i(maxi(low.x, 0), maxi(low.y, 0))
	high = Vector2i(mini(high.x, province.grid.size.x - 1), mini(high.y, province.grid.size.y - 1))
	if high.x < low.x or high.y < low.y:
		return shares
	var span := high - low + Vector2i.ONE
	var step := maxi(1, ceili(sqrt(float(span.x * span.y) / SURVEY_SAMPLES)))
	if _terrains.is_empty():
		_terrains = Data.registry.terrains_by_index()
	var terrains := _terrains
	var total := 0
	var trees := 0
	var water := 0
	for y: int in range(low.y, high.y + 1, step):
		for x: int in range(low.x, high.x + 1, step):
			var tile := Vector2i(x, y)
			# The bounding box of the diamond view holds tiles off the screen; keep those inside.
			if not rect.has_point(IsoMath.tile_center_screen(tile)):
				continue
			total += 1
			var node := province.resources.def_at(tile)
			if node != null and node.good == &"wood":
				trees += 1
			var index := province.grid.terrain(tile)
			if index < terrains.size() and terrains[index] != null and terrains[index].is_kind(&"water"):
				water += 1
	if total > 0:
		shares[AmbienceDef.Source.FOREST] = float(trees) / total
		shares[AmbienceDef.Source.WATER] = float(water) / total
	return shares


## Decibels of a sound at [param base_db] played at [param level] (0..1).
static func level_db(base_db: float, level: float) -> float:
	if level <= 0.0:
		return SILENT_DB
	return maxf(SILENT_DB, base_db + linear_to_db(level))
