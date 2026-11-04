extends Node
## Autoload "Loc": current language and formatting helpers for UI code.

const SUPPORTED_LOCALES: PackedStringArray = ["pl", "en"]
const DEFAULT_LOCALE := "pl"


func _ready() -> void:
	set_locale(DEFAULT_LOCALE)


func set_locale(locale: String) -> void:
	if locale not in SUPPORTED_LOCALES:
		push_warning("Loc: unsupported locale '%s'" % locale)
		return
	TranslationServer.set_locale(locale)
	EventBus.language_changed.emit(locale)


func get_locale() -> String:
	return TranslationServer.get_locale().get_slice("_", 0)


## Switches to the next supported language (used by the language toggle).
func cycle_locale() -> void:
	var index := SUPPORTED_LOCALES.find(get_locale())
	set_locale(SUPPORTED_LOCALES[(index + 1) % SUPPORTED_LOCALES.size()])


func number(value: int) -> String:
	return LocFormat.number(value, get_locale())


func good_count(good: StringName, amount: int) -> String:
	return LocFormat.good_count(good, amount)
