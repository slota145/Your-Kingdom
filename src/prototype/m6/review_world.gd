## M6 review prototype: writes a quick save with a grown kingdom for the owner's game review
## (F9 in the game loads it). The big city of M4b-3 is the player's capital (with a town hall)
## in the world; Willow Vale and Mirror Lakes get small towns owned by the player; Iron Wold
## and Horse Haven stay neutral towns waiting to be bought; the other provinces are free to
## settle. An existing quick save is copied to quick_backup.sav first.
## Run: "$GODOT" --headless --path . -s res://src/prototype/m6/review_world.gd
extends SceneTree

const SAVE_PATH := "user://saves/quick.sav"
const BACKUP_PATH := "user://saves/quick_backup.sav"
const PLAYER_TOWNS: Array[StringName] = [&"willow_vale", &"mirror_lakes"]


func _init() -> void:
	var reg := DataRegistry.new()
	reg.load_from("res://data")
	var sim := BigCity.load_fixture(reg)
	sim.world = WorldSim.from_def(reg.get_world(&"kingdom"), reg)
	sim.world.get_province(sim.viewed_id).owner = ProvinceDef.OWNER_PLAYER
	var layout := reg.get_province(&"iron_wold")
	for name: StringName in PLAYER_TOWNS:
		var id := sim.world.id_of(name)
		var problems := NeutralTown.build(sim, id, layout)
		sim.world.get_province(id).owner = ProvinceDef.OWNER_PLAYER
		print("%s: %d buildings %s" % [name, sim.province_state(id).buildings.count(), problems])
	sim.run_ticks(SimClock.TICKS_PER_SECOND * 2)
	sim.events.drain()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
		print("old quick save copied to ", ProjectSettings.globalize_path(BACKUP_PATH))
	DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir())
	var file := FileAccess.open_compressed(SAVE_PATH, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	file.store_string(JSON.stringify({
		"header": {"save_version": SaveMigrations.CURRENT_VERSION, "game_version": "review",
			"saved_at": Time.get_datetime_string_from_system(true)},
		"state": sim.to_dict(),
	}, "", false, true))
	file.close()
	print("review world saved to ", ProjectSettings.globalize_path(SAVE_PATH))
	quit()
