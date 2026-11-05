class_name StockpilePanel
extends PanelContainer
## Lists the goods of one stockpile. Reads the same slots as the stacks on the ground
## (Stockpile.totals), so the numbers always match what the player sees.

var stock: Stockpile

var _title: Label
## Two columns, so a full stockpile still fits above the build bar.
var _list: GridContainer
var _shown: Dictionary[StringName, int] = {}
var _initialized: bool = false


func _init() -> void:
	var box := VBoxContainer.new()
	add_child(box)
	_title = Label.new()
	box.add_child(_title)
	_list = GridContainer.new()
	_list.columns = 2
	box.add_child(_list)


func _process(_delta: float) -> void:
	if stock == null:
		return
	var totals := stock.totals()
	if _initialized and totals == _shown:
		return
	_initialized = true
	_shown = totals
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _list != null:
		_rebuild()


func _rebuild() -> void:
	_title.text = tr(&"ui.stockpile.title")
	for child: Node in _list.get_children():
		child.queue_free()
	if _shown.is_empty():
		var empty := Label.new()
		empty.text = tr(&"ui.stockpile.empty")
		_list.add_child(empty)
		return
	for good: StringName in _shown:
		var row := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = ArtPaths.texture("goods/icons/%s.png" % good)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(icon)
		var label := Label.new()
		label.text = Loc.good_count(good, _shown[good])
		row.add_child(label)
		_list.add_child(row)
