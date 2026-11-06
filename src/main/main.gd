extends Control
## Start screen: new game in the world, single-province games on the old maps, the quick save.

const PLURAL_SAMPLES: PackedInt32Array = [1, 2, 5, 12, 22, 1250]
const GAME_SCENE := "res://src/main/game_scene.tscn"
const SANDBOX_SCENE := "res://src/prototype/m2/m2_sandbox.tscn"
const BENCHMARK_SCENE := "res://src/prototype/m2/m2_bench.tscn"

@onready var _plural_list: Label = %PluralList
@onready var _toggle_button: Button = %ToggleLanguageButton


func _ready() -> void:
	_toggle_button.pressed.connect(Loc.cycle_locale)
	_add_map_buttons()
	var quick := SaveService.slot_path("quick")
	(%LoadGameButton as Button).pressed.connect(_start_game.bind(quick))
	(%LoadGameButton as Button).disabled = not FileAccess.file_exists(quick)
	(%SandboxButton as Button).pressed.connect(_open.bind(SANDBOX_SCENE))
	(%BenchmarkButton as Button).pressed.connect(_open.bind(BENCHMARK_SCENE))
	EventBus.language_changed.connect(_on_language_changed)
	_refresh()


## "New game" starts in the world (M6); below it one "Single province" button per map (the
## old maps, M4b-3). The scene's button becomes the world's; the others are copies after it.
func _add_map_buttons() -> void:
	var first := %NewGameButton as Button
	var worlds := Data.registry.all_of(&"world")
	var at := first.get_index()
	var maps := Data.registry.all_of(&"map")
	for i: int in maps.size():
		var map := maps[i] as MapDef
		var button := first.duplicate() as Button
		first.get_parent().add_child(button)
		first.get_parent().move_child(button, at + 1 + i)
		button.set_meta(&"map", map.id)
		button.add_theme_font_size_override(&"font_size", 26)
		button.pressed.connect(func() -> void:
			Game.start_request = {"map": map.id}
			_open(GAME_SCENE))
	# Connected after the copies were made (duplicate() copies connections too).
	if not worlds.is_empty():
		var world_id := worlds[0].id
		first.pressed.connect(func() -> void:
			Game.start_request = {"world": world_id}
			_open(GAME_SCENE))
	first.disabled = worlds.is_empty()
	_refresh_map_buttons()


func _refresh_map_buttons() -> void:
	for child: Node in (%NewGameButton as Button).get_parent().get_children():
		if child is Button and child.has_meta(&"map"):
			var id: StringName = child.get_meta(&"map")
			(child as Button).text = tr("ui.main.single_on") % tr("map.%s.name" % id)
			(child as Button).tooltip_text = tr("map.%s.desc" % id)


func _open(scene: String) -> void:
	get_tree().change_scene_to_file(scene)


func _start_game(load_path: String) -> void:
	Game.start_request = {"load": load_path} if load_path != "" else {}
	_open(GAME_SCENE)


func _on_language_changed(_locale: String) -> void:
	_refresh()
	_refresh_map_buttons()


func _refresh() -> void:
	var lines := PackedStringArray()
	for good: GoodDef in Data.registry.goods():
		var samples := PackedStringArray()
		for amount: int in PLURAL_SAMPLES:
			samples.append(Loc.good_count(good.id, amount))
		lines.append("%s: %s" % [tr(good.name_key()), ", ".join(samples)])
	_plural_list.text = "\n".join(lines)
