extends GdUnitTestSuite
## UI-3 part 1, a friend's second playtest (2026-11-23): readable build-menu tooltips with what
## a building makes per minute, the goods on a strip under the top bar, messages that fold away.

const OptionsScript := preload("res://src/core/options.gd")

var _path: String
var _values: Dictionary


func before_test() -> void:
	# The player's settings file stays untouched.
	_path = Options.path
	_values = Options.values.duplicate()
	Options.path = ""


func after_test() -> void:
	Options.values = _values
	Options.path = _path


func test_the_strip_shows_wood_stone_planks_and_food_by_default() -> void:
	Options.values.erase(GoodsStrip.OPTION)
	assert_array(Array(GoodsStrip.pinned())).contains_exactly(["wood", "stone", "planks", "food"])
	# The default keeps its type through the settings file (an Array).
	assert_int(typeof(OptionsScript.DEFAULTS[GoodsStrip.OPTION])).is_equal(TYPE_ARRAY)


func test_pinning_and_unpinning_goods() -> void:
	GoodsStrip.set_pinned(PackedStringArray(["wood"]))
	GoodsStrip.toggle("bread")
	assert_array(Array(GoodsStrip.pinned())).contains_exactly(["wood", "bread"])
	GoodsStrip.toggle("wood")
	assert_array(Array(GoodsStrip.pinned())).contains_exactly(["bread"])
	assert_int(typeof(Options.get_value(GoodsStrip.OPTION))).is_equal(TYPE_ARRAY)
	var many := PackedStringArray()
	for i: int in GoodsStrip.MAX_PINNED:
		many.append("good_%d" % i)
	GoodsStrip.set_pinned(many)
	GoodsStrip.toggle("wood")
	assert_int(GoodsStrip.pinned().size()).is_equal(GoodsStrip.MAX_PINNED)


func test_food_counts_every_food_together() -> void:
	var sim := SimFixture.make_sim()
	var store := SimFixture.place(sim, &"stockpile", Vector2i(4, 4))
	store.stock.add(&"bread", 12)
	store.stock.add(&"fish", 5)
	store.stock.add(&"wood", 7)
	assert_int(GoodsStrip.amount(sim.province, sim.data, "food")).is_equal(17)
	assert_int(GoodsStrip.amount(sim.province, sim.data, "wood")).is_equal(7)
	var strip := auto_free(GoodsStrip.new()) as GoodsStrip
	strip.province = sim.province
	GoodsStrip.set_pinned(PackedStringArray(["wood", "food", "no_such_good"]))
	strip.setup(sim.data)
	add_child(strip)
	# An unknown id is left out; the "+" button closes the row.
	var row := strip.get_child(0) as HBoxContainer
	assert_int(row.get_child_count()).is_equal(3)
	assert_str(((row.get_child(1) as HBoxContainer).get_child(1) as Label).text).is_equal("17")


func test_messages_fold_away_and_count_what_came_meanwhile() -> void:
	var notes := auto_free(Notifications.new()) as Notifications
	add_child(notes)
	notes.set_folded(false)
	for i: int in 5:
		notes.push("message %d" % i)
	assert_int(notes.shown_count()).is_equal(Notifications.MAX_SHOWN)
	notes.set_folded(true)
	assert_bool(notes.folded()).is_true()
	notes.push("while folded")
	assert_int(notes.history.size()).is_equal(6)
	assert_int(notes.shown_count()).is_equal(Notifications.MAX_SHOWN)
	notes.set_folded(false)
	assert_bool(notes.folded()).is_false()


func test_the_build_menu_tooltip_has_the_rates() -> void:
	var menu := auto_free(BuildMenu.new()) as BuildMenu
	menu.setup(SimFixture.registry())
	add_child(menu)
	var tip := menu.building_tip(SimFixture.registry().get_building(&"sawmill"))
	assert_str(tip).contains(tr("ui.build.rate_made").split("%")[0])
	assert_str(tip).contains(tr("ui.build.rate_used").split("%")[0])
	# The tooltip itself: a heading over wrapped ink text, never wider than the limit.
	var content := auto_free(UiKit.tooltip(tip, "Tartak")) as Control
	assert_int(content.get_child_count()).is_equal(2)
	assert_float((content.get_child(1) as Label).custom_minimum_size.x).is_less_equal(UiKit.TOOLTIP_WIDTH)
	# The boards (top bar, build menu) have readable tooltips too.
	assert_int(UiKit.board_theme().get_font_size(&"font_size", &"TooltipLabel")).is_equal(UiKit.TOOLTIP_FONT_SIZE)
	assert_bool(UiKit.board_theme().has_stylebox(&"panel", &"TooltipPanel")).is_true()
