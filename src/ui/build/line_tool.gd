class_name LineTool
extends RefCounted
## Roads and cobbles from two clicks (UI-2 part 1, owner 2026-11-13): the line from the first
## clicked tile to the cursor runs in an L, along one grid axis and then the other, as in Anno
## and Stronghold. R switches which axis goes first.


## The tiles of an L from [param from] to [param to]: along grid x first, then along y (or y
## first when [param y_first]), both ends included, each tile once.
static func l_path(from: Vector2i, to: Vector2i, y_first: bool = false) -> Array[Vector2i]:
	var line: Array[Vector2i] = [from]
	var at := from
	var axes: Array[int] = [0, 1]
	if y_first:
		axes = [1, 0]
	for axis: int in axes:
		while at[axis] != to[axis]:
			at[axis] += signi(to[axis] - at[axis])
			line.append(at)
	return line
