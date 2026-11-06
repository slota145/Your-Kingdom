extends SceneTree
## How the big city does every 10 minutes: characters, residents, unmet needs, stock and
## units made per good (for tuning tests/support/big_city.gd).
##   "$GODOT" --headless --path . -s res://src/prototype/m4b3/city_health.gd -- [--minutes=30]
const BigCityScript := preload("res://tests/support/big_city.gd")

func _init() -> void:
	var minutes := 30
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			minutes = int(arg.get_slice("=", 1))
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var sim: Simulation = BigCityScript.load_fixture(registry)
	var p := sim.province
	var made: Dictionary[StringName, int] = {}
	for m: int in range(1, minutes + 1):
		for i: int in 600:
			sim.step()
			for e: Dictionary in sim.events.drain():
				if e["type"] == &"good_produced":
					made[e["good"]] = made.get(e["good"], 0) + int(e["amount"])
		if m % 10 != 0:
			continue
		var res := 0
		var unmet: Dictionary[StringName, int] = {}
		for b: BuildingState in p.buildings.all():
			if b.house != null:
				res += b.house.residents
				for need: NeedDef in b.level_def().needs:
					if not b.house.satisfied.get(need.id, false):
						unmet[need.id] = unmet.get(need.id, 0) + 1
		var stock := ""
		for g: StringName in [&"bread", &"fish", &"meat", &"beer", &"wood", &"clothes", &"mead", &"flour", &"grain", &"hops", &"honey", &"planks", &"stone", &"bricks", &"wool", &"cloth", &"pig"]:
			stock += "%s %d/%d  " % [g, p.kingdom_stock(g), made.get(g, 0)]
		print("min %d: characters %d, residents %d, gold %d\n  unmet %s\n  stock/made %s" % [m, p.agents.all().size(), res, sim.treasury.gold, unmet, stock])
		made.clear()
	quit()
