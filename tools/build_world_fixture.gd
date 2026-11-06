extends SceneTree
## Builds the save fixture of M6 part 1 (save version 12): a new game in the world ("The
## Kingdom") two minutes in, with the landing under way in Landing Bay (viewed, in detail) and
## Willow Vale settled on the Riverlands start layout in the simplified mode.
## Run: "$GODOT" --headless --path . -s res://tools/build_world_fixture.gd

const PATH := "res://tests/fixtures/saves/v12_world.json"


func _init() -> void:
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var sim := Simulation.from_world(registry, registry.get_world(&"kingdom"))
	var vale := sim.world.id_of(&"willow_vale")
	sim.open_province(vale, registry.get_map(&"riverlands"))
	sim.run_ticks(1200)
	var document := {"header": {"save_version": SaveMigrations.CURRENT_VERSION}, "state": sim.to_dict()}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "", false, true))
	file.close()
	print("saved %s: provinces %s, viewed %d" % [PATH, sim.runtime_ids(), sim.viewed_id])
	quit()
