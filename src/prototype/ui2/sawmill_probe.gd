extends SceneTree
## UI-2 part 2 PROTOTYPE: in the big M4b-3 city, why the sawyers break off their work (failed
## recipe tasks by reason) and how many planks each sawmill makes, over 20 minutes.
## "$GODOT" --headless --path . -s res://src/prototype/ui2/sawmill_probe.gd


func _init() -> void:
	var reg := DataRegistry.new()
	reg.load_from("res://data")
	var sim := BigCity.load_fixture(reg)
	var reasons := {}
	var planks := 0
	for t: int in SimClock.TICKS_PER_SECOND * 60 * 20:
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] == &"task_failed" and e["task"] == Task.KIND_RECIPE:
				var agent := sim.province.agents.get_agent(int(e["agent"]))
				if agent != null and agent.kind == &"sawyer":
					var key := "%s step %d" % [e["reason"], int(e["step"])]
					reasons[key] = int(reasons.get(key, 0)) + 1
	planks = int(sim.province.ledger.made_total.get(&"planks", 0))
	var rates := PackedStringArray()
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == &"sawmill":
			rates.append("%.3f (%d)" % [sim.province.production.rate(b.id), sim.province.production.sample_count(b.id)])
	print("sawyer failures: ", reasons)
	print("planks made: ", planks, "; measured rates ", rates)
	quit()
