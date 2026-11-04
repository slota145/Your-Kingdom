class_name WallGeometry
extends RefCounted
## Ground shapes and heights of wall pieces (ARCHITECTURE §6.3, ART_SPEC §6).
##
## Shared by the placeholder generator (to draw the pieces) and the wall view (to place and
## sort them), so the art and the sort points cannot drift apart. All shapes are in grid
## units relative to the tile center; heights are in screen pixels.

const HEIGHT := 56.0
const POST_HEIGHT := 64.0
const THICKNESS := 0.32
const POST_HALF := 0.22
const GATE_PILLAR_FROM := 0.3
const LINTEL_BOTTOM := 44.0

## Image canvas of every wall piece and the tile center inside it (ART_SPEC §6).
const CANVAS := Vector2i(64, 96)
const PIVOT := Vector2i(32, 80)


class Piece:
	extends RefCounted
	var name: String
	## Convex ground polygon, grid units relative to the tile center.
	var base: PackedVector2Array
	var z_bottom: float
	var z_top: float

	func _init(piece_name: String, ground: PackedVector2Array, bottom: float, top: float) -> void:
		name = piece_name
		base = ground
		z_bottom = bottom
		z_top = top

	## Sort point (screen offset from the tile center): projection of the ground centroid.
	func sort_offset() -> Vector2:
		var centroid := Vector2.ZERO
		for p: Vector2 in base:
			centroid += p
		return IsoMath.grid_to_screen(centroid / base.size())


static func post() -> Piece:
	var h := POST_HALF
	return Piece.new("post", PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]), 0.0, POST_HEIGHT)


## Half segment from the tile center to the edge (or corner) towards [param dir].
static func half(dir: int) -> Piece:
	var end := Vector2(WallConnectivity.OFFSETS[dir]) * 0.5
	return Piece.new("half_" + WallConnectivity.NAMES[dir],
			_bar(Vector2.ZERO, end, THICKNESS), 0.0, HEIGHT)


## Gate pillar on the outer part of an orthogonal half segment.
static func gate_half(dir: int) -> Piece:
	var step := Vector2(WallConnectivity.OFFSETS[dir])
	return Piece.new("gate_half_" + WallConnectivity.NAMES[dir],
			_bar(step * GATE_PILLAR_FROM, step * 0.5, THICKNESS * 1.25), 0.0, HEIGHT)


## Beam over the gate opening along grid axis &"x" or &"y".
static func gate_lintel(axis: StringName) -> Piece:
	var along := Vector2(1, 0) if axis == &"x" else Vector2(0, 1)
	return Piece.new("gate_lintel_" + String(axis),
			_bar(-along * GATE_PILLAR_FROM, along * GATE_PILLAR_FROM, THICKNESS), LINTEL_BOTTOM, HEIGHT)


## Every piece file a wall type needs.
static func all_pieces() -> Array[Piece]:
	var pieces: Array[Piece] = [post(), gate_lintel(&"x"), gate_lintel(&"y")]
	for dir: int in WallConnectivity.COUNT:
		pieces.append(half(dir))
		if not WallConnectivity.is_diagonal(dir):
			pieces.append(gate_half(dir))
	return pieces


## Pieces that render one wall tile with connection [param mask].
static func pieces_for(mask: int, is_gate: bool) -> Array[Piece]:
	var pieces: Array[Piece] = []
	var axis := WallConnectivity.gate_axis(mask) if is_gate else &""
	if axis != &"":
		pieces.append(gate_lintel(axis))
		for dir: int in WallConnectivity.half_dirs(mask):
			pieces.append(gate_half(dir) if not WallConnectivity.is_diagonal(dir) else half(dir))
		return pieces
	if WallConnectivity.needs_post(mask):
		pieces.append(post())
	for dir: int in WallConnectivity.half_dirs(mask):
		pieces.append(half(dir))
	return pieces


## Rectangle of width [param thickness] from [param a] to [param b], as a convex polygon.
static func _bar(a: Vector2, b: Vector2, thickness: float) -> PackedVector2Array:
	var n := (b - a).normalized().orthogonal() * thickness * 0.5
	return PackedVector2Array([a + n, b + n, b - n, a - n])
