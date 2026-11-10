extends GdUnitTestSuite
## Character sheets with 64 px frames, and bigger frames for a long weapon (a halberd,
## owner 2026-11-10): the frame size follows from the sheet's height.


func test_64_px_sheets_keep_their_frames() -> void:
	assert_int(CharacterSheet.frame_side(512)).is_equal(64)   # 8 rows
	assert_int(CharacterSheet.frame_side(320)).is_equal(64)   # 5 rows (mirrored)
	assert_int(CharacterSheet.frame_side(64)).is_equal(64)


func test_bigger_frames_from_the_height() -> void:
	assert_int(CharacterSheet.frame_side(768)).is_equal(96)   # 8 rows of 96
	assert_int(CharacterSheet.frame_side(480)).is_equal(96)   # 5 rows of 96
	assert_int(CharacterSheet.frame_side(1024)).is_equal(128)   # 8 rows of 128 (riders)


func test_the_halberdier_stands_on_his_feet_in_a_96_px_frame() -> void:
	var sheet := CharacterSheet.from_files(ArtPaths.resolve("characters/halberdier/idle.png"), "", 4.0)
	assert_int(sheet.rows).is_equal(8)
	assert_int(sheet.frame_size.x).is_equal(sheet.texture.get_height() / 8)
	assert_int(sheet.foot.y).is_equal(sheet.frame_size.y - CharacterSheet.FOOT_MARGIN)
	assert_int(sheet.foot.x).is_equal(sheet.frame_size.x / 2)


func test_a_rider_stands_higher_in_a_128_px_frame() -> void:
	var sheet := CharacterSheet.from_files(ArtPaths.resolve("characters/knight/idle.png"), "", 4.0)
	assert_int(sheet.rows).is_equal(8)
	assert_int(sheet.frame_size.x).is_equal(128)
	assert_vector(sheet.foot).is_equal(Vector2i(64, 128 - CharacterSheet.RIDER_FOOT_MARGIN))
