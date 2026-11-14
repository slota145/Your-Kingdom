extends SceneTree
## M10 part 1 PROTOTYPE: which work sounds the big city makes. Loads the big city fixture,
## shows it in a ProvinceView, runs the game and counts the blows of each sound and the level
## of each background, for a screen over the middle of the town and over its edge.
## "$GODOT" --headless --path . -s res://src/prototype/m10/sound_probe.gd -- [--seconds=60] [--zoom=1]

const FRAME := 1.0 / 60.0


func _initialize() -> void:
	var seconds := 60.0
	var zoom := 1.0
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seconds="):
			seconds = float(a.trim_prefix("--seconds="))
		elif a.begins_with("--zoom="):
			zoom = float(a.trim_prefix("--zoom="))
	var sim: Simulation = load("res://tests/support/big_city.gd").call("load_fixture", root.get_node("/root/Data").get("registry"))
	var view := ProvinceView.new()
	root.add_child(view)
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
	while time < seconds:
		time += FRAME
		acc += FRAME
		while acc >= SimClock.TICK:
			acc -= SimClock.TICK
			sim.step()
		view.update_view(1.0, rect, time, FRAME)
		view.update_sounds(rect, zoom, false, FRAME)
		frames += 1
	var usec := float(Time.get_ticks_usec() - start) / frames
	print("big city, %d s at zoom %.1f, people on screen %d, working on screen %d" % [
			seconds, zoom, view.agents.visible_count, view.agents.work_ids.size()])
	var ids := view.work_sounds.played.keys()
	ids.sort()
	for id: StringName in ids:
		print("  %-12s %4d blows (%.1f/s)" % [id, view.work_sounds.played[id], view.work_sounds.played[id] / seconds])
	var activities: Dictionary[StringName, int] = {}
	for a: StringName in view.agents.work_activities:
		activities[a] = activities.get(a, 0) + 1
	print("  working now: ", activities)
	var shares := AmbiencePlayer.survey(sim.province, rect)
	print("  forest %.2f, water %.2f" % [shares[AmbienceDef.Source.FOREST], shares[AmbienceDef.Source.WATER]])
	print("  view + sounds per frame: %.2f ms" % (usec / 1000.0))
	quit()
