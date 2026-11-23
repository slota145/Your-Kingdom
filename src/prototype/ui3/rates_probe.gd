extends SceneTree
## UI-3 part 1 (prototype): every building's full-crew rate per minute, to eyeball.
## Run: godot --headless --path . -s res://src/prototype/ui3/rates_probe.gd


func _init() -> void:
	var data := DataRegistry.new()
	data.load_from("res://data")
	for def: BuildingDef in data.buildings():
		var r := ProductionEstimate.full_crew(def, data)
		if (r["made"] as Dictionary).is_empty() and (r["used"] as Dictionary).is_empty():
			continue
		print("%-20s made %s used %s" % [def.id, _fmt(r["made"]), _fmt(r["used"])])
	quit()


func _fmt(d: Dictionary) -> String:
	var parts := PackedStringArray()
	for k: StringName in d:
		parts.append("%s %.1f" % [k, d[k]])
	return ", ".join(parts)
