extends SceneTree
## Builds the large M4b-3 test city (tests/support/big_city.gd) and saves it as the fixture
## tests/fixtures/saves/big_city.json.
##   "$GODOT" --headless --path . -s res://tools/build_big_city.gd [-- --dry]
## --dry prints the city summary without writing the fixture.


func _init() -> void:
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var started := Time.get_ticks_msec()
	var sim := BigCity.build_new(registry)
	print("built and warmed up in %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	print(BigCity.summary(sim))
	if not OS.get_cmdline_user_args().has("--dry"):
		var document := {"header": {"save_version": SaveMigrations.CURRENT_VERSION},
				"state": sim.to_dict()}
		var file := FileAccess.open(BigCity.FIXTURE_PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify(document, "", false, true))
		file.close()
		print("saved ", BigCity.FIXTURE_PATH)
	quit()
