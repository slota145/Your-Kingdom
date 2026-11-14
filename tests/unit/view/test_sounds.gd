extends GdUnitTestSuite
## M10 part 1: work sounds, background and music (SoundBank, WorkSounds, AmbiencePlayer,
## the Music autoload): every file is there and credited, the blows keep time with the work
## animation, the nearest win when many work at once, the background follows the screen.

## Activities set in code rather than in recipe data.
const CODE_ACTIVITIES: Array[StringName] = [&"build"]
## A screen round the world origin (world pixels).
const SCREEN := Rect2(-640, -360, 1280, 720)


func test_every_sound_file_is_there() -> void:
	var files: Array[String] = []
	for sound: SoundDef in SoundBank.sounds():
		assert_bool(sound.files.is_empty()).override_failure_message(String(sound.id)).is_false()
		files.append_array(sound.files)
	for ambience: AmbienceDef in SoundBank.ambiences():
		if ambience.bed != "":
			files.append(ambience.bed)
		files.append_array(ambience.scatter)
	for track: MusicTrackDef in SoundBank.music():
		files.append(track.file)
	assert_int(files.size()).is_greater(20)
	for file: String in files:
		assert_object(SoundBank.stream(file)).override_failure_message(file).is_not_null()


func test_every_audio_file_is_credited() -> void:
	var credits := FileAccess.get_file_as_string("res://assets/audio/CREDITS.md")
	for file: String in _audio_files("res://assets/audio"):
		var relative := file.trim_prefix("res://assets/audio/")
		assert_bool(credits.contains("`%s`" % relative)).override_failure_message(relative).is_true()


func test_sounds_belong_to_real_activities() -> void:
	var known: Dictionary[StringName, bool] = {}
	for activity: StringName in CODE_ACTIVITIES:
		known[activity] = true
	for def: GameDef in SimFixture.registry().all_of(&"recipe"):
		for step: StepDef in (def as RecipeDef).steps:
			if "activity" in step:
				known[step.get("activity")] = true
	var heard := 0
	for sound: SoundDef in SoundBank.sounds():
		for activity: StringName in sound.activities:
			assert_bool(known.has(activity)).override_failure_message(String(activity)).is_true()
			heard += 1
	# The woodcutter, the quarryman, the builder and the smith are heard (first batch).
	for activity: StringName in [&"chop", &"hew", &"build", &"forge"]:
		assert_object(SoundBank.for_activity(activity)).override_failure_message(String(activity)).is_not_null()
	assert_object(SoundBank.for_activity(&"walk")).is_null()
	assert_int(heard).is_greater(8)


func test_event_sounds_belong_to_real_events() -> void:
	var emitted := _emitted_events()
	assert_bool(emitted.has(&"unit_struck")).is_true()
	var heard := 0
	for sound: SoundDef in SoundBank.sounds():
		for event: StringName in sound.events:
			assert_bool(event == &"ui_click" or emitted.has(event)).override_failure_message(String(event)).is_true()
			heard += 1
	for event: StringName in [&"unit_struck", &"arrow_shot", &"unit_died", &"wall_damaged", &"building_placed",
			&"building_removed", &"building_completed", &"ui_click"]:
		assert_object(SoundBank.for_event(event)).override_failure_message(String(event)).is_not_null()
	assert_int(heard).is_greater_equal(8)


func test_animal_sounds_belong_to_real_animals() -> void:
	var known: Dictionary[StringName, bool] = {&"bees": true}
	for kind: StringName in WildHerds.KINDS:
		known[kind] = true
	for def: GameDef in SimFixture.registry().all_of(&"building"):
		var building := def as BuildingDef
		if building.herd_good != &"":
			known[building.herd_good] = true
			assert_object(SoundBank.for_animal(building.herd_good)).override_failure_message(String(building.herd_good)).is_not_null()
	for sound: SoundDef in SoundBank.sounds():
		for animal: StringName in sound.animals:
			assert_bool(known.has(animal)).override_failure_message(String(animal)).is_true()


func test_herds_call_now_and_then_not_all_at_once() -> void:
	var voices := AnimalVoices.new(7)
	var herds: Array[Dictionary] = []
	for i: int in 6:
		herds.append({"key": "pen_%d" % i, "kind": &"sheep", "at": Vector2(i * 50, 0)})
	var sheep := SoundBank.for_animal(&"sheep")
	var calls := 0
	var first_second := 0
	for frame: int in 600:   # 60 s in tenths
		var due := voices.update(herds, 0.1)
		calls += due.size()
		if frame < 10:
			first_second += due.size()
	assert_int(first_second).is_less_equal(2)
	# Each pen about every (8 + 20) / 2 s: some 10 to 30 calls from 6 pens in a minute.
	assert_int(calls).is_between(6, int(6 * 60 / sheep.interval.x) + 6)
	# A herd off the screen is forgotten; an animal without a sound stays silent.
	var quiet: Array[Dictionary] = [{"key": "wild_1", "kind": &"unicorn", "at": Vector2.ZERO}]
	assert_int(voices.update(quiet, 100.0).size()).is_equal(0)


func test_event_sounds_are_heard_where_they_happen() -> void:
	var sim := SimFixture.make_sim()
	var hut := SimFixture.place(sim, &"hut", Vector2i(10, 10))
	var at: Variant = ProvinceView.event_point(sim.province, {"type": &"building_completed", "building": hut.id})
	assert_vector(at as Vector2).is_equal(IsoMath.grid_to_screen(Vector2(10, 10) + Vector2(hut.def.footprint) * 0.5))
	assert_vector(ProvinceView.event_point(sim.province, {"type": &"unit_died", "pos": Vector2(3, 4)}) as Vector2) \
			.is_equal(IsoMath.grid_to_screen(Vector2(3, 4)))
	# Gone already (a building pulled down): the middle of the screen.
	assert_object(ProvinceView.event_point(sim.province, {"type": &"building_removed", "building": 999})).is_null()
	var sounds := auto_free(WorkSounds.new()) as WorkSounds
	add_child(sounds)
	var pool := auto_free(AgentViewPool.new()) as AgentViewPool
	var clash := SoundBank.for_event(&"unit_struck")
	sounds.queue(clash, Vector2(100, 0))
	sounds.queue(clash, Vector2(90000, 0))   # far off the screen: not heard
	sounds.update_sounds(pool, SCREEN, 1.0, false)
	assert_int(sounds.struck.get(clash.id, 0)).is_equal(1)


func test_a_blow_is_heard_once_per_loop_of_the_animation() -> void:
	var sounds := auto_free(WorkSounds.new()) as WorkSounds
	add_child(sounds)
	var pool := auto_free(AgentViewPool.new()) as AgentViewPool
	var axe := SoundBank.for_activity(&"chop")
	# Just before the blow: nothing (and the first sight of a worker never plays).
	_work(pool, 7, &"chop", 3.0 + axe.hit - 0.05)
	sounds.update_sounds(pool, SCREEN, 1.0, false)
	assert_int(_playing(sounds)).is_equal(0)
	_work(pool, 7, &"chop", 3.0 + axe.hit - 0.01)
	sounds.update_sounds(pool, SCREEN, 1.0, false)
	assert_int(_playing(sounds)).is_equal(0)
	# The axe bites: one blow.
	_work(pool, 7, &"chop", 3.0 + axe.hit + 0.02)
	sounds.update_sounds(pool, SCREEN, 1.0, false)
	assert_int(_playing(sounds)).is_equal(1)
	# Paused: the swing goes on in the picture, the blow is not heard.
	for player: Node in sounds.get_children():
		(player as AudioStreamPlayer2D).stop()
	_work(pool, 7, &"chop", 4.0 + axe.hit + 0.02)
	sounds.update_sounds(pool, SCREEN, 1.0, true)
	assert_int(_playing(sounds)).is_equal(0)


func test_nearest_blows_win_and_one_sound_has_a_cap() -> void:
	var axe := SoundBank.for_activity(&"chop")
	var anvil := SoundBank.for_activity(&"forge")
	var due: Array[Dictionary] = []
	for i: int in 6:
		due.append({"sound": axe, "at": Vector2(i * 100, 0), "distance": float(i * 100)})
	due.append({"sound": anvil, "at": Vector2(900, 0), "distance": 900.0})
	var busy: Dictionary[StringName, int] = {}
	var picked := WorkSounds.choose(due, busy, 12)
	assert_int(picked.size()).is_equal(axe.max_voices + 1)
	assert_float(picked[0]["distance"]).is_equal(0.0)
	assert_float(picked[axe.max_voices - 1]["distance"]).is_equal(float((axe.max_voices - 1) * 100))
	# Axes still ringing count against the cap; few free voices take the nearest only.
	busy[axe.id] = axe.max_voices
	assert_int(WorkSounds.choose(due, busy, 12).size()).is_equal(1)
	assert_int(WorkSounds.choose(due, {} as Dictionary[StringName, int], 2).size()).is_equal(2)


func test_every_and_chance_do_not_depend_on_frames() -> void:
	var sheep := SoundBank.for_activity(&"shear")
	var heard := 0
	for blow: int in 400:
		var once := WorkSounds.heard(sheep, 11, blow)
		assert_bool(WorkSounds.heard(sheep, 11, blow)).is_equal(once)
		heard += 1 if once else 0
	# About one cut in five makes a sheep bleat.
	assert_int(heard).is_between(40, 140)
	var sound := SoundDef.new()
	sound.every = 3
	assert_bool(WorkSounds.heard(sound, 1, 3)).is_true()
	assert_bool(WorkSounds.heard(sound, 1, 4)).is_false()


func test_zoomed_out_is_quieter() -> void:
	assert_float(WorkSounds.zoom_db(1.0)).is_equal_approx(0.0, 0.001)
	assert_float(WorkSounds.zoom_db(3.0)).is_equal_approx(0.0, 0.001)
	assert_float(WorkSounds.zoom_db(0.5)).is_equal_approx(-6.0, 0.001)


func test_background_follows_forest_and_water_on_screen() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var water := SimFixture.registry().get_terrain(&"water")
	for y: int in 40:
		for x: int in 20:
			sim.province.grid.set_terrain(Vector2i(x, y), water.index)
	SimFixture.plant_trees(sim, Rect2i(20, 0, 20, 40))
	var on_water := _screen_round(Vector2i(8, 20))
	var on_trees := _screen_round(Vector2i(30, 20))
	var shares := AmbiencePlayer.survey(sim.province, on_water)
	assert_float(shares[AmbienceDef.Source.WATER]).is_greater(0.9)
	assert_float(shares[AmbienceDef.Source.FOREST]).is_less(0.1)
	shares = AmbiencePlayer.survey(sim.province, on_trees)
	assert_float(shares[AmbienceDef.Source.FOREST]).is_greater(0.9)
	assert_float(shares[AmbienceDef.Source.WATER]).is_less(0.1)
	# Off the map: nothing to hear.
	shares = AmbiencePlayer.survey(sim.province, Rect2(-50000, -50000, 400, 300))
	assert_float(shares[AmbienceDef.Source.FOREST]).is_equal(0.0)
	assert_float(AmbiencePlayer.level_db(-6.0, 0.0)).is_equal(AmbiencePlayer.SILENT_DB)
	assert_float(AmbiencePlayer.level_db(-6.0, 1.0)).is_equal_approx(-6.0, 0.001)


func test_music_does_not_repeat_a_piece_too_soon() -> void:
	var rng := RandomNumberGenerator.new()
	var a := MusicTrackDef.new()
	a.moods = [&"peace"]
	var b := MusicTrackDef.new()
	b.moods = [&"peace", &"menu"]
	var two: Array[MusicTrackDef] = [a, b]
	var after_a: Array[MusicTrackDef] = [a]
	for i: int in 10:
		assert_object(_pick(two, &"peace", after_a, rng)).is_same(b)
	var after_b: Array[MusicTrackDef] = [b]
	assert_object(_pick(two, &"menu", after_b, rng)).is_same(b)
	assert_object(_pick(two, &"war", [] as Array[MusicTrackDef], rng)).is_null()
	# The game's pieces: none comes back before about half of the others have played.
	var all := SoundBank.music()
	assert_int(all.size()).is_greater_equal(11)
	var played: Array[MusicTrackDef] = []
	var peaceful: Array[MusicTrackDef] = []
	for track: MusicTrackDef in all:
		if track.moods.has(&"peace"):
			peaceful.append(track)
	for i: int in 60:
		var next := _pick(peaceful, &"peace", played, rng)
		var since := played.size() - 1 - played.rfind(next) if played.has(next) else peaceful.size()
		assert_int(since).is_greater_equal(peaceful.size() / 2)
		played.append(next)
	# The game has music for the menu, for a province at peace and for a battle; battle
	# pieces never play in peace.
	assert_object(_pick(all, &"menu", [] as Array[MusicTrackDef], rng)).is_not_null()
	var war := _pick(all, &"war", [] as Array[MusicTrackDef], rng)
	assert_object(war).is_not_null()
	assert_bool(war.moods.has(&"peace")).is_false()


func test_audio_buses_exist() -> void:
	for bus: StringName in [WorkSounds.BUS, AmbiencePlayer.BUS, &"Music"]:
		assert_int(AudioServer.get_bus_index(bus)).override_failure_message(String(bus)).is_not_equal(-1)


func _pick(tracks: Array[MusicTrackDef], mood: StringName, played: Array[MusicTrackDef],
		rng: RandomNumberGenerator) -> MusicTrackDef:
	return Music.pick(tracks, mood, played, rng)


## Event types the simulation emits (province.events.emit(&"...")).
func _emitted_events() -> Dictionary[StringName, bool]:
	var found: Dictionary[StringName, bool] = {}
	var regex := RegEx.create_from_string("emit\\(&\"([a-z_]+)\"")
	for path: String in _gd_files("res://src/sim"):
		for m: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
			found[StringName(m.get_string(1))] = true
	return found


func _gd_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			result.append(dir_path.path_join(file))
	for sub: String in dir.get_directories():
		result.append_array(_gd_files(dir_path.path_join(sub)))
	return result


func _work(pool: AgentViewPool, id: int, activity: StringName, cycle: float) -> void:
	pool.work_ids = PackedInt32Array([id])
	pool.work_activities = [activity]
	pool.work_positions = PackedVector2Array([Vector2(10, 0)])
	pool.work_cycles = PackedFloat64Array([cycle])


func _playing(sounds: WorkSounds) -> int:
	var count := 0
	for child: Node in sounds.get_children():
		if (child as AudioStreamPlayer2D).playing:
			count += 1
	return count


## A small screen (world pixels) round [param tile].
func _screen_round(tile: Vector2i) -> Rect2:
	var centre := IsoMath.tile_center_screen(tile)
	return Rect2(centre - Vector2(200, 100), Vector2(400, 200))


func _audio_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	for file: String in dir.get_files():
		if file.ends_with(".ogg"):
			result.append(dir_path.path_join(file))
	for sub: String in dir.get_directories():
		result.append_array(_audio_files(dir_path.path_join(sub)))
	return result
