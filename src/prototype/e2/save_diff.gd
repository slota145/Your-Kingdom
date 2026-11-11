extends SceneTree
## E2 probe (prototype): what differs after loading an old save fixture and saving it again.
## Run: "$GODOT" --headless --path . -s res://src/prototype/e2/save_diff.gd -- --fixture=v34_hives --version=34


func _init() -> void:
	var fixture := "v34_hives"
	var version := 34
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="):
			fixture = arg.trim_prefix("--fixture=")
		elif arg.begins_with("--version="):
			version = int(arg.trim_prefix("--version="))
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/%s.json" % fixture))
	var state := SaveMigrations.migrate(doc["state"], version)
	var again := Simulation.from_dict(state, registry).to_dict()
	var a := JSON.parse_string(SimCodec.canonical(state)) as Dictionary
	var b := JSON.parse_string(SimCodec.canonical(again)) as Dictionary
	_diff(a, b, "", [0])
	quit()


func _diff(a: Variant, b: Variant, path: String, shown: Array) -> void:
	if shown[0] > 12:
		return
	if a is Dictionary and b is Dictionary:
		for k: Variant in (a as Dictionary).keys() + (b as Dictionary).keys():
			_diff((a as Dictionary).get(k), (b as Dictionary).get(k), path + "/" + str(k), shown)
	elif a is Array and b is Array and (a as Array).size() == (b as Array).size():
		for i: int in (a as Array).size():
			_diff(a[i], b[i], path + "[%d]" % i, shown)
	elif str(a) != str(b):
		shown[0] += 1
		print(path, ": ", str(a).left(160), "  ->  ", str(b).left(160))
