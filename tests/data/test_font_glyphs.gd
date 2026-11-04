extends GdUnitTestSuite
## The UI font must contain every Polish letter.

const POLISH_LETTERS := "ąćęłńóśźżĄĆĘŁŃÓŚŹŻ"


func test_ui_font_has_polish_glyphs() -> void:
	var path: String = ProjectSettings.get_setting("gui/theme/custom_font")
	var font := load(path) as Font
	assert_object(font).is_not_null()
	var missing := ""
	for letter: String in POLISH_LETTERS:
		if not font.has_char(letter.unicode_at(0)):
			missing += letter
	assert_str(missing).override_failure_message("font lacks glyphs: " + missing).is_empty()
