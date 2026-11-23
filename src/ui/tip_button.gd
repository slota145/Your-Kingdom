class_name TipButton
extends Button
## A button whose tooltip is a readable parchment note (UI-3 part 1, a friend's playtest: the
## build menu's tooltips were "very hard to read"): the name as a heading, the text in ink at
## the panels' size, wrapped to a sensible width.

## Heading over the tooltip text; empty = none.
var tip_title: String = ""


func _make_custom_tooltip(for_text: String) -> Object:
	return UiKit.tooltip(tr(for_text), tip_title)
