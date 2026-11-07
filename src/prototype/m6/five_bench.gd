## M6 part 3 prototype: the tick with five provinces of the player (ROADMAP M6 DoD: at most
## 4 ms with the big city viewed and 4 provinces in the simplified mode). The big city of
## M4b-3 is viewed; Willow Vale, Mirror Lakes, Vine Hills and Amber Coast get small towns
## (the neutral town of Iron Wold, about 35 buildings and 80 people each) owned by the player;
## the two neutral towns wait. Prints the average and the slowest second, and the big city
## alone for comparison.
## Run: "$GODOT" --headless --path . -s res://src/prototype/m6/five_bench.gd [-- --minutes=5]
extends SceneTree

const OTHERS: Array[StringName] = [&"willow_vale", &"mirror_lakes", &"vine_hills", &"amber_coast"]


func _init() -> void:
	var minutes := 5
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			minutes = int(arg.trim_prefix("--minutes="))
	var reg := DataRegistry.new()
	reg.load_from("res://data")
	var alone := BigCity.load_fixture(reg)
	_measure(alone, minutes, "big city alone")
	var sim := BigCity.load_fixture(reg)
	sim.world = WorldSim.from_def(reg.get_world(&"kingdom"), reg)
	sim.world.get_province(sim.viewed_id).owner = ProvinceDef.OWNER_PLAYER
	var layout := reg.get_province(&"iron_wold")
	for name: StringName in OTHERS:
		var id := sim.world.id_of(name)
		var problems := NeutralTown.build(sim, id, layout)
		sim.world.get_province(id).owner = ProvinceDef.OWNER_PLAYER
		print("%s: %d buildings %s" % [name, sim.province_state(id).buildings.count(), problems])
	sim.run_ticks(SimClock.TICKS_PER_SECOND * 2)
	_measure(sim, minutes, "big city + 4 provinces (+2 neutral towns waiting)")
	quit()


func _measure(sim: Simulation, minutes: int, label: String) -> void:
	sim.run_ticks(SimClock.TICKS_PER_SECOND * 60)   # warm up
	var ticks := minutes * 60 * SimClock.TICKS_PER_SECOND
	var worst_second := 0
	var second_usec := 0
	var t0 := Time.get_ticks_usec()
	for i: int in ticks:
		var a := Time.get_ticks_usec()
		sim.step()
		sim.events.drain()
		second_usec += Time.get_ticks_usec() - a
		if i % SimClock.TICKS_PER_SECOND == SimClock.TICKS_PER_SECOND - 1:
			worst_second = maxi(worst_second, second_usec)
			second_usec = 0
	var per := (Time.get_ticks_usec() - t0) / float(ticks)
	print("%s: %.2f ms per tick on average, slowest second %.2f ms per tick, %d characters viewed" % [
			label, per / 1000.0, worst_second / 1000.0 / SimClock.TICKS_PER_SECOND, sim.province.agents.count()])
