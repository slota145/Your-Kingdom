## M6 prototype: cost of the simplified mode (ProvinceAbstract.step) on the big city and two
## small towns. Run: "$GODOT" --headless --path . -s res://src/prototype/m6/abstract_bench.gd
extends SceneTree
func _measure(sim: Simulation, label: String) -> void:
	sim.run_ticks(600)
	var a := ProvinceAbstract.freeze(sim.province, sim.clock.tick)
	var base := sim.clock.tick / 10 * 10
	var n := 600
	var t0 := Time.get_ticks_usec()
	for i: int in n:
		a.step(base + i * 10)
	var per := (Time.get_ticks_usec() - t0) / float(n)
	print("%s: %.2f ms per step = %.3f ms per tick, %d buildings" % [label, per / 1000.0, per / 10000.0, a.detail.buildings.all().size()])
func _init() -> void:
	var reg := DataRegistry.new()
	reg.load_from("res://data")
	_measure(BigCity.load_fixture(reg), "big city")
	for f: String in ["v7_town", "v11_voyage"]:
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/%s.json" % f))
		_measure(Simulation.from_dict(SaveMigrations.migrate(doc["state"], int(doc["header"]["save_version"])), reg), f)
	quit()
