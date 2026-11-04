class_name LocFormat
extends RefCounted
## Locale-aware formatting helpers. Static and stateless, so they are easy to test.

## Thousands separators per language. Polish uses a (non-breaking) space.
const THOUSANDS_SEPARATOR: Dictionary[String, String] = {
	"pl": " ",
	"en": ",",
}


## Formats an integer with the language's thousands separator, e.g. 12 345 / 12,345.
static func number(value: int, locale: String) -> String:
	var lang := locale.get_slice("_", 0)
	var separator: String = THOUSANDS_SEPARATOR.get(lang, ",")
	var digits := str(absi(value))
	var groups := PackedStringArray()
	while digits.length() > 3:
		groups.insert(0, digits.right(3))
		digits = digits.left(digits.length() - 3)
	groups.insert(0, digits)
	var text := separator.join(groups)
	return "-" + text if value < 0 else text


## Translated amount of a good with the correct plural form, e.g. "5 chlebów".
static func good_count(good: StringName, amount: int) -> String:
	var key := "good.%s.count" % good
	var pattern := TranslationServer.translate_plural(key, key + "_plural", amount)
	return String(pattern) % number(amount, TranslationServer.get_locale())
