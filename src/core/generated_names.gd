class_name GeneratedNames
extends RefCounted
## Names of things a generator made (M8: a generated world and its provinces), put together
## from translated parts ("Silver" + "Hills") for every loaded language and added to the
## TranslationServer under the thing's usual key, so the UI shows them like any other name.

static var _translations: Dictionary[String, Translation] = {}


## Adds [param key] in every loaded language: the translations of [param parts] joined with
## spaces, then formatted with [param args] when given.
static func add(key: String, parts: PackedStringArray, args: Array = []) -> void:
	var locales := TranslationServer.get_loaded_locales()
	if locales.is_empty():
		locales = PackedStringArray(["en"])
	for locale: String in locales:
		var source := TranslationServer.get_translation_object(locale)
		var words := PackedStringArray()
		for part: String in parts:
			var word := String(source.get_message(part)) if source != null else ""
			words.append(word if word != "" else part)
		var text := " ".join(words)
		if not args.is_empty():
			text = text % args
		_target(locale).add_message(key, text)


static func _target(locale: String) -> Translation:
	if not _translations.has(locale):
		var t := Translation.new()
		t.locale = locale
		_translations[locale] = t
		TranslationServer.add_translation(t)
	return _translations[locale]
