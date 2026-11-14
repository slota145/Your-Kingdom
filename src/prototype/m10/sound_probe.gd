extends Node
## M10 part 1 PROTOTYPE: which work sounds the big city makes. Loads the big city fixture,
## shows it in a ProvinceView, runs the game and counts the blows of each sound and the level
## of each background, for a screen over the middle of the town and over its edge.
## "$GODOT" --headless --path . res://src/prototype/m10/sound_probe.tscn -- [--seconds=60] [--zoom=1]

const FRAME := 1.0 / 60.0


func _ready() -> void:
	var seconds := 60.0
	var zoom := 1.0
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seconds="):
			seconds = float(a.trim_prefix("--seconds="))
		elif a.begins_with("--zoom="):
			zoom = float(a.trim_prefix("--zoom="))
	var sim: Simulation = load("res://tests/support/big_city.gd").call("load_fixture", Data.registry)
	var view := ProvinceView.new()
	add_child(view)
	view.setup(sim.province)
	var centre := Vector2.ZERO
	var count := 0
	for b: BuildingState in sim.province.buildings.all():
		centre += IsoMath.tile_center_screen(b.origin)
		count += 1
	centre /= maxi(count, 1)
	var rect := Rect2(centre - Vector2(640, 360) / zoom, Vector2(1280, 720) / zoom)
	var time := 0.0
	var acc := 0.0
	var start := Time.get_ticks_usec()
	var frames := 0
	var work_seconds: Dictionary[StringName, float] = {}
	while time < seconds:
		time += FRAME
		acc += FRAME
		while acc >= SimClock.TICK:
			acc -= SimClock.TICK
			sim.step()
		view.update_view(1.0, rect, time, FRAME)
		view.update_sounds(rect, zoom, false, FRAME)
		for a: StringName in view.agents.work_activities:
			work_seconds[a] = work_seconds.get(a, 0.0) + FRAME
		frames += 1
	var usec := float(Time.get_ticks_usec() - start) / frames
	print("big city, %d s at zoom %.1f, people on screen %d, working on screen %d" % [
			seconds, zoom, view.agents.visible_count, view.agents.work_ids.size()])
	var ids := view.work_sounds.struck.keys()
	ids.sort()
	for id: StringName in ids:
		print("  %-12s %4d blows due (%.1f/s), %d played (headless: players never finish)" % [id,
				view.work_sounds.struck[id], view.work_sounds.struck[id] / seconds, view.work_sounds.played.get(id, 0)])
	var activities: Dictionary[StringName, int] = {}
	for a: StringName in view.agents.work_activities:
		activities[a] = activities.get(a, 0) + 1
	print("  working now: ", activities)
	var worked := work_seconds.keys()
	worked.sort()
	for a: StringName in worked:
		var sound := SoundBank.for_activity(a)
		print("  %-14s %5.1f worker-seconds on screen%s" % [a, work_seconds[a], "" if sound == null else " -> " + String(sound.id)])
	var shares := AmbiencePlayer.survey(sim.province, rect)
	print("  forest %.2f, water %.2f" % [shares[AmbienceDef.Source.FOREST], shares[AmbienceDef.Source.WATER]])
	print("  view + sounds per frame: %.2f ms" % (usec / 1000.0))
	get_tree().quit()
