extends SceneTree
## E1 probe (prototype): does a save and load slow the big city's mills and bakeries down?
## The same city after 10 minutes runs 5 more minutes as it is and after a JSON round trip.
## Run: "$GODOT" --headless --path . -s res://src/prototype/e1/roundtrip_probe.gd


func _init() -> void:
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var sim: Simulation = load("res://tests/support/big_city.gd").load_fixture(registry)
	sim.run_ticks(SimClock.seconds_to_ticks(600))
	var state := JSON.parse_string(JSON.stringify(sim.to_dict(), "", false, true)) as Dictionary
	var copy := Simulation.from_dict(state, registry)
	for pair: Array in [["as it is", sim], ["after a save and load", copy]]:
		var s: Simulation = pair[1]
		var before := {}
		for good: StringName in [&"grain", &"flour", &"bread"]:
			before[good] = int(s.province.ledger.made_total.get(good, 0))
		s.run_ticks(SimClock.seconds_to_ticks(300))
		var line := "%s:" % pair[0]
		for good: StringName in [&"grain", &"flour", &"bread"]:
			line += " %s %d" % [good, int(s.province.ledger.made_total.get(good, 0)) - int(before[good])]
		print(line)
	quit()
