extends GdUnitTestSuite
## Both languages define the same keys, nothing is empty, every definition is named,
## and Polish plural forms come out right.

const LOCALES: PackedStringArray = ["pl", "en"]

var _po: Dictionary[String, PoFile] = {}
var _previous_locale: String


func before() -> void:
	for locale: String in LOCALES:
		_po[locale] = PoFile.read("res://localization/%s.po" % locale)
	_previous_locale = TranslationServer.get_locale()


func after() -> void:
	TranslationServer.set_locale(_previous_locale)


func test_languages_have_identical_keys() -> void:
	assert_array(Array(_po["en"].keys())).is_equal(Array(_po["pl"].keys()))


func test_no_empty_translations() -> void:
	for locale: String in LOCALES:
		assert_array(Array(_po[locale].empty_translations())).override_failure_message(
				"empty translations in %s.po" % locale).is_empty()


func test_every_definition_has_name_and_description() -> void:
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	for kind: StringName in registry.kinds():
		for def: GameDef in registry.all_of(kind):
			for locale: String in LOCALES:
				for key: String in [def.name_key(), def.desc_key()]:
					assert_bool(_po[locale].entries.has(key)).override_failure_message(
							"%s.po: missing key '%s'" % [locale, key]).is_true()


func test_every_good_has_plural_count() -> void:
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	for good: GoodDef in registry.goods():
		for locale: String in LOCALES:
			var po: PoFile = _po[locale]
			assert_str(po.plural_ids.get(good.count_key(), "")).is_equal(good.count_plural_key())


func test_polish_plural_forms() -> void:
	TranslationServer.set_locale("pl")
	var expected: Dictionary[int, String] = {
		0: "0 chlebów",
		1: "1 chleb",
		2: "2 chleby",
		4: "4 chleby",
		5: "5 chlebów",
		12: "12 chlebów",
		14: "14 chlebów",
		21: "21 chlebów",
		22: "22 chleby",
		104: "104 chleby",
		112: "112 chlebów",
	}
	for amount: int in expected:
		assert_str(LocFormat.good_count(&"bread", amount)).is_equal(expected[amount])


func test_english_plural_forms() -> void:
	TranslationServer.set_locale("en")
	assert_str(LocFormat.good_count(&"bread", 1)).is_equal("1 loaf")
	assert_str(LocFormat.good_count(&"bread", 2)).is_equal("2 loaves")
	assert_str(LocFormat.good_count(&"bread", 1250)).is_equal("1,250 loaves")


func test_number_formatting() -> void:
	assert_str(LocFormat.number(0, "pl")).is_equal("0")
	assert_str(LocFormat.number(999, "pl")).is_equal("999")
	assert_str(LocFormat.number(12345, "pl")).is_equal("12 345")
	assert_str(LocFormat.number(1234567, "en")).is_equal("1,234,567")
	assert_str(LocFormat.number(-4500, "en_US")).is_equal("-4,500")
