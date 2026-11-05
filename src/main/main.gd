extends Control
## Start screen: proves localization, plural forms, the font and the data registry.

const PLURAL_SAMPLES: PackedInt32Array = [1, 2, 5, 12, 22, 1250]
const SANDBOX_SCENE := "res://src/prototype/m2/m2_sandbox.tscn"
const BENCHMARK_SCENE := "res://src/prototype/m2/m2_bench.tscn"

@onready var _plural_list: Label = %PluralList
@onready var _toggle_button: Button = %ToggleLanguageButton


func _ready() -> void:
	_toggle_button.pressed.connect(Loc.cycle_locale)
	(%SandboxButton as Button).pressed.connect(_open.bind(SANDBOX_SCENE))
	(%BenchmarkButton as Button).pressed.connect(_open.bind(BENCHMARK_SCENE))
	EventBus.language_changed.connect(_on_language_changed)
	_refresh()


func _open(scene: String) -> void:
	get_tree().change_scene_to_file(scene)


func _on_language_changed(_locale: String) -> void:
	_refresh()


func _refresh() -> void:
	var lines := PackedStringArray()
	for good: GoodDef in Data.registry.goods():
		var samples := PackedStringArray()
		for amount: int in PLURAL_SAMPLES:
			samples.append(Loc.good_count(good.id, amount))
		lines.append("%s: %s" % [tr(good.name_key()), ", ".join(samples)])
	_plural_list.text = "\n".join(lines)
