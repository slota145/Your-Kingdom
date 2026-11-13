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


## G3 (SpriteKiln townsfolk): every clip the game asks for, 8 unmirrored rows of 64 px frames,
## and a carried-good anchor in every frame of every carry walk.
const SPRITEKILN_TOWNSFOLK: Dictionary[String, Array] = {
	"porter": ["load"],
	"farmer": ["plow", "sow", "harvest", "bind", "weed"],
	"builder": ["build"],
	# G3 part 2a
	"woodcutter": ["chop", "bind"],
	"forester": ["dig", "plant", "rest"],
	"stonecutter": ["hew", "shape", "hoist"],
	"miner": ["pick", "shape", "descend", "wind"],
	"clay_digger": ["dig"],
	"fisher": [],
	"angler": ["cast", "wait_bite", "reel"],
	"hunter": ["carve", "skin", "bend", "aim"],
	"shepherd": ["herd", "shear"],
	"swineherd": ["feed", "muck"],
	"groom": ["feed", "groom"],
	"beekeeper": ["tend_hives", "collect_honey"],
	"orchardist": ["plow", "sow", "harvest", "bind", "weed"],
	"hop_grower": ["plow", "sow", "harvest", "bind", "weed"],
	"winegrower": ["plow", "sow", "harvest", "bind", "weed"],
	"carter": ["load"],
	"docker": ["hand_over"],
}
const CARRY_CATEGORIES: Array[String] = ["sack", "barrel", "log", "basket", "bundle", "crate", "stone"]


func test_spritekiln_townsfolk_have_every_clip() -> void:
	for id: String in SPRITEKILN_TOWNSFOLK:
		var anims: Array[String] = ["idle", "walk", "work"]
		for activity: String in SPRITEKILN_TOWNSFOLK[id]:
			anims.append("work_" + activity)
		for category: String in CARRY_CATEGORIES:
			anims.append("walk_carry_" + category)
		for anim: String in anims:
			var path := ArtPaths.resolve("characters/%s/%s.png" % [id, anim])
			assert_bool(ResourceLoader.exists(path)).override_failure_message("%s %s" % [id, anim]).is_true()
			var sheet := CharacterSheet.from_files(path, "", 8.0)
			assert_int(sheet.rows).override_failure_message("%s %s" % [id, anim]).is_equal(8)
			assert_int(sheet.frame_size.x).is_equal(64)


func test_spritekiln_townsfolk_carry_anchors_in_every_frame() -> void:
	for id: String in SPRITEKILN_TOWNSFOLK:
		for category: String in CARRY_CATEGORIES:
			var anim := "characters/%s/walk_carry_%s" % [id, category]
			var sheet := CharacterSheet.from_files(ArtPaths.resolve(anim + ".png"),
					ArtPaths.resolve(anim + ".anchors.png"), 10.0)
			assert_int(sheet.anchors.size()).is_equal(sheet.rows * sheet.frames)
			for i: int in sheet.anchors.size():
				var a := sheet.anchors[i]
				# Somewhere on the body: above the feet, within the frame.
				assert_bool(a.y < -8.0 and a.y > -40.0 and absf(a.x) < 16.0) \
						.override_failure_message("%s frame %d anchor %s" % [anim, i, a]).is_true()


func test_overlays_of_an_8_row_person_flip_on_the_west_side() -> void:
	# 5-row goods and vehicles: rows 0-4 as they are, NW/W/SW the flipped NE/E/SE.
	assert_vector(AgentSprite.overlay_row_flip(Vector2i(2, 0))).is_equal(Vector2i(2, 0))
	assert_vector(AgentSprite.overlay_row_flip(Vector2i(4, 0))).is_equal(Vector2i(4, 0))
	assert_vector(AgentSprite.overlay_row_flip(Vector2i(5, 0))).is_equal(Vector2i(3, 1))
	assert_vector(AgentSprite.overlay_row_flip(Vector2i(6, 0))).is_equal(Vector2i(2, 1))
	assert_vector(AgentSprite.overlay_row_flip(Vector2i(7, 0))).is_equal(Vector2i(1, 1))
	# A mirrored 5-row person already gives the overlay's row and flip.
	assert_vector(AgentSprite.overlay_row_flip(Vector2i(1, 1))).is_equal(Vector2i(1, 1))
