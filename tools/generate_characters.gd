extends SceneTree
## Final character art drawn in code (owner decision 2026-11-05: better than the placeholders,
## without PixelLab). Writes res://assets/characters/<kind>/<anim>.png (+ .anchors.png for
## carrying) in the layout of ART_SPEC §4: 64x64 frames, feet at (32, 58), rows S, SE, E, NE,
## N (the W side is mirrored by the game), 42 px tall people.
##
## Run: godot --headless --path . -s res://tools/generate_characters.gd   (then --import)
##
## A person is a set of body parts placed in body space (side s to the right hand, front f,
## height z), turned to the row's direction and squashed 2:1 like the ground. Parts are drawn
## from the back to the front, then a 1 px outline in a darker shade (ART_SPEC §1).
## Each profession has its own clothes, hat and tool (ART_SPEC §4.4).

const OUT := "res://assets/characters"
const FRAME := Vector2i(64, 64)
const FOOT := Vector2(32, 58)
const ROWS := 5
## People are drawn for 42 px and shrunk to about 34 px around the feet (owner decision
## 2026-11-05: closer to the size of doors and windows).
const SCALE := 0.81
const ANCHOR := Color(1, 0, 0)
const BEHIND := Color(0, 0, 1)

const SKIN := Color(0.93, 0.74, 0.58)
const C_IRON := Color(0.62, 0.64, 0.68)
const C_WOOD := Color(0.5, 0.33, 0.18)
const C_SHOE := Color(0.27, 0.18, 0.12)

## Kind -> look. shirt/legs/hair colours, hat, apron (colour or null), tool, dress.
const PEOPLE := {
	"farmer": {"shirt": Color(0.78, 0.66, 0.42), "legs": Color(0.42, 0.34, 0.24), "hair": Color(0.45, 0.3, 0.16),
			"hat": "straw", "tool": "sickle"},
	"hop_grower": {"shirt": Color(0.42, 0.58, 0.32), "legs": Color(0.38, 0.32, 0.24), "hair": Color(0.3, 0.2, 0.12),
			"hat": "straw", "tool": "hook"},
	"miller": {"shirt": Color(0.86, 0.84, 0.78), "legs": Color(0.55, 0.5, 0.42), "hair": Color(0.55, 0.42, 0.25),
			"hat": "flour_cap", "apron": Color(0.95, 0.94, 0.9), "tool": ""},
	"baker": {"shirt": Color(0.8, 0.62, 0.45), "legs": Color(0.4, 0.33, 0.26), "hair": Color(0.25, 0.17, 0.1),
			"hat": "baker_cap", "apron": Color(0.96, 0.95, 0.92), "tool": "peel"},
	"woodcutter": {"shirt": Color(0.72, 0.2, 0.16), "legs": Color(0.32, 0.28, 0.22), "hair": Color(0.35, 0.22, 0.12),
			"hat": "", "beard": true, "tool": "axe"},
	"porter": {"shirt": Color(0.5, 0.34, 0.2), "legs": Color(0.36, 0.3, 0.24), "hair": Color(0.2, 0.14, 0.1),
			"hat": "kerchief", "hat_colour": Color(0.75, 0.25, 0.2), "tool": ""},
	"builder": {"shirt": Color(0.6, 0.58, 0.55), "legs": Color(0.35, 0.3, 0.25), "hair": Color(0.4, 0.28, 0.15),
			"hat": "cap", "hat_colour": Color(0.45, 0.32, 0.2), "apron": Color(0.55, 0.38, 0.22), "tool": "hammer"},
	"sawyer": {"shirt": Color(0.38, 0.52, 0.36), "legs": Color(0.4, 0.33, 0.24), "hair": Color(0.55, 0.38, 0.2),
			"hat": "cap", "hat_colour": Color(0.3, 0.4, 0.28), "tool": "saw"},
	"stonecutter": {"shirt": Color(0.58, 0.6, 0.62), "legs": Color(0.32, 0.3, 0.28), "hair": Color(0.3, 0.3, 0.3),
			"hat": "", "beard": true, "apron": Color(0.5, 0.36, 0.22), "tool": "pick"},
	"angler": {"shirt": Color(0.36, 0.5, 0.7), "legs": Color(0.4, 0.36, 0.3), "hair": Color(0.5, 0.36, 0.2),
			"hat": "wide", "hat_colour": Color(0.55, 0.45, 0.3), "tool": "rod"},
	"brewer": {"shirt": Color(0.82, 0.74, 0.55), "legs": Color(0.42, 0.32, 0.24), "hair": Color(0.6, 0.3, 0.15),
			"hat": "cap", "hat_colour": Color(0.55, 0.25, 0.2), "apron": Color(0.48, 0.32, 0.2), "tool": "paddle"},
	"householder": {"shirt": Color(0.66, 0.3, 0.3), "legs": Color(0.45, 0.32, 0.4), "hair": Color(0.45, 0.28, 0.14),
			"hat": "kerchief", "hat_colour": Color(0.92, 0.9, 0.82), "dress": true, "apron": Color(0.92, 0.9, 0.84), "tool": ""},
	"settler": {"shirt": Color(0.45, 0.4, 0.32), "legs": Color(0.36, 0.3, 0.24), "hair": Color(0.3, 0.22, 0.14),
			"hat": "hood", "hat_colour": Color(0.4, 0.36, 0.3), "cloak": Color(0.4, 0.36, 0.3), "tool": "staff"},
	# M4b (patricians)
	"forester": {"shirt": Color(0.3, 0.5, 0.28), "legs": Color(0.36, 0.3, 0.22), "hair": Color(0.4, 0.26, 0.14),
			"hat": "cap", "hat_colour": Color(0.22, 0.38, 0.2), "tool": "spade"},
	"shepherd": {"shirt": Color(0.72, 0.66, 0.54), "legs": Color(0.42, 0.36, 0.28), "hair": Color(0.5, 0.45, 0.4),
			"hat": "wide", "hat_colour": Color(0.45, 0.35, 0.24), "beard": true,
			"cloak": Color(0.55, 0.5, 0.42), "tool": "crook"},
	"weaver": {"shirt": Color(0.38, 0.42, 0.7), "legs": Color(0.5, 0.36, 0.45), "hair": Color(0.55, 0.32, 0.16),
			"hat": "kerchief", "hat_colour": Color(0.85, 0.75, 0.45), "dress": true, "tool": ""},
	"tailor": {"shirt": Color(0.55, 0.28, 0.5), "legs": Color(0.3, 0.28, 0.3), "hair": Color(0.2, 0.15, 0.12),
			"hat": "cap", "hat_colour": Color(0.3, 0.2, 0.35), "tool": "shears"},
	"beekeeper": {"shirt": Color(0.9, 0.86, 0.72), "legs": Color(0.6, 0.55, 0.45), "hair": Color(0.45, 0.3, 0.15),
			"hat": "veil", "hat_colour": Color(0.88, 0.78, 0.48), "tool": "smoker"},
	"mead_maker": {"shirt": Color(0.85, 0.65, 0.3), "legs": Color(0.42, 0.32, 0.24), "hair": Color(0.35, 0.22, 0.12),
			"hat": "cap", "hat_colour": Color(0.6, 0.4, 0.15), "apron": Color(0.5, 0.34, 0.2), "tool": "paddle"},
	"clay_digger": {"shirt": Color(0.66, 0.5, 0.4), "legs": Color(0.45, 0.35, 0.28), "hair": Color(0.25, 0.18, 0.12),
			"hat": "kerchief", "hat_colour": Color(0.55, 0.4, 0.3), "tool": "spade"},
	"brickmaker": {"shirt": Color(0.72, 0.36, 0.26), "legs": Color(0.35, 0.3, 0.26), "hair": Color(0.3, 0.22, 0.15),
			"hat": "", "beard": true, "apron": Color(0.55, 0.38, 0.22), "tool": "spade"},
	"innkeeper": {"shirt": Color(0.6, 0.2, 0.2), "legs": Color(0.32, 0.26, 0.22), "hair": Color(0.45, 0.3, 0.18),
			"hat": "", "beard": true, "apron": Color(0.95, 0.93, 0.88), "tool": "mug"},
}

## Activity -> motion and the tool it uses (empty = the profession's own).
const WORK := {
	"chop": ["overhead", "axe"], "hew": ["overhead", "pick"], "build": ["overhead", "hammer"],
	"plow": ["overhead", "hoe"], "harvest": ["low", "sickle"], "shape": ["low", "hammer"],
	"saw": ["push", "saw"], "knead": ["push", ""], "bake": ["push", "peel"], "grind": ["stir", ""],
	"mash": ["stir", "paddle"], "brew": ["stir", "paddle"], "sow": ["throw", ""], "bind": ["bend", ""],
	"cast": ["cast", "rod"], "wait_bite": ["hold", "rod"], "reel": ["reel", "rod"],
	"dig": ["low", "spade"], "plant": ["bend", ""], "rest": ["rest", ""], "herd": ["rest", "crook"],
	"shear": ["low", "shears"], "spin": ["stir", ""], "weave": ["push", ""], "cut": ["push", "shears"],
	"sew": ["stir", ""], "tend_hives": ["low", "smoker"], "collect_honey": ["bend", ""],
	"mix": ["stir", "paddle"], "ferment": ["push", ""], "mould": ["push", ""], "fire": ["push", "spade"],
	"serve": ["push", "mug"],
}

## Activities each profession performs (recipes, fields, building).
const ACTIVITIES := {
	"farmer": ["plow", "sow", "harvest", "bind"], "hop_grower": ["plow", "sow", "harvest", "bind"],
	"miller": ["grind"], "baker": ["knead", "bake"], "woodcutter": ["chop", "bind"],
	"builder": ["build"], "sawyer": ["saw"], "stonecutter": ["hew", "shape"],
	"angler": ["cast", "wait_bite", "reel"], "brewer": ["mash", "brew"],
	"forester": ["dig", "plant", "rest"], "shepherd": ["herd", "shear"], "weaver": ["spin", "weave"],
	"tailor": ["cut", "sew"], "beekeeper": ["tend_hives", "collect_honey"], "mead_maker": ["mix", "ferment"],
	"clay_digger": ["dig"], "brickmaker": ["mould", "fire"], "innkeeper": ["serve"],
}

## Carry category -> hands (side, front, height) for both hands, the good's anchor and
## whether the good hides behind the body when facing the camera (true) or away (false).
const CARRY := {
	"sack": {"hands": [Vector3(3.5, 0.5, 31.0), Vector3(-5.0, 1.0, 17.0)], "anchor": Vector3(4.5, -0.5, 32.0), "behind_camera": false},
	"basket": {"hands": [Vector3(6.5, 2.5, 17.0), Vector3(-5.0, 0.0, 16.0)], "anchor": Vector3(7.5, 3.0, 15.0), "behind_camera": false},
	"bundle": {"hands": [Vector3(3.5, 2.0, 25.0), Vector3(-3.5, 2.0, 25.0)], "anchor": Vector3(0.0, -5.5, 27.0), "behind_camera": true},
	"log": {"hands": [Vector3(4.0, 1.5, 31.0), Vector3(-2.0, 2.5, 26.0)], "anchor": Vector3(4.0, 0.0, 33.0), "behind_camera": false},
	"barrel": {"hands": [Vector3(4.0, 0.5, 34.0), Vector3(-1.0, 1.5, 32.0)], "anchor": Vector3(4.5, -0.5, 35.0), "behind_camera": false},
	"stone": {"hands": [Vector3(3.5, 5.0, 20.0), Vector3(-3.5, 5.0, 20.0)], "anchor": Vector3(0.0, 6.5, 21.0), "behind_camera": false},
	"crate": {"hands": [Vector3(4.0, 5.0, 20.0), Vector3(-4.0, 5.0, 20.0)], "anchor": Vector3(0.0, 6.5, 21.0), "behind_camera": false},
}

var _look: Dictionary
## Parts of the frame being drawn: [depth, callable].
var _parts: Array = []
var _forward: Vector2
var _right: Vector2


func _init() -> void:
	for kind: String in PEOPLE:
		_look = PEOPLE[kind]
		_save(_sheet(4, func(_f: int, t: float) -> Dictionary: return {"breath": sin(t * TAU)}), kind, "idle")
		_save(_sheet(8, func(_f: int, t: float) -> Dictionary: return {"swing": sin(t * TAU)}), kind, "walk")
		for category: String in CARRY:
			var spec: Dictionary = CARRY[category]
			var pair := _sheet(8, func(_f: int, t: float) -> Dictionary:
				return {"swing": sin(t * TAU) * (0.6 if category == "stone" else 0.85), "carry": category}, spec)
			_save(pair, kind, "walk_carry_" + category)
		_save(_sheet(8, func(_f: int, t: float) -> Dictionary: return {"work": "overhead", "t": t,
				"tool": String(_look["tool"])}), kind, "work")
		for activity: String in ACTIVITIES.get(kind, []):
			var w: Array = WORK[activity]
			var tool: String = w[1] if w[1] != "" else String(_look["tool"])
			if w[1] == "" and w[0] in ["push", "stir", "throw", "bend"]:
				tool = ""
			_save(_sheet(8, func(_f: int, t: float) -> Dictionary: return {"work": w[0], "t": t, "tool": tool}),
					kind, "work_" + activity)
	_write_visuals()
	print("Characters written to ", OUT)
	quit()


## Renders [param frames] x 5 rows. [param pose_of] (frame, phase 0..1) -> pose dictionary.
## Returns [sheet, anchors or null].
func _sheet(frames: int, pose_of: Callable, carry: Dictionary = {}) -> Array:
	var sheet := Image.create_empty(FRAME.x * frames, FRAME.y * ROWS, false, Image.FORMAT_RGBA8)
	var anchors: Image = null
	if not carry.is_empty():
		anchors = Image.create_empty(sheet.get_width(), sheet.get_height(), false, Image.FORMAT_RGBA8)
	for row: int in ROWS:
		var angle := PI / 2.0 - row * TAU / 8.0
		_forward = Vector2(cos(angle), sin(angle))
		_right = Vector2(-_forward.y, _forward.x)
		for frame: int in frames:
			var t := float(frame) / frames
			var pose: Dictionary = pose_of.call(frame, t)
			var origin := Vector2i(frame * FRAME.x, row * FRAME.y)
			var img := Image.create_empty(FRAME.x, FRAME.y, false, Image.FORMAT_RGBA8)
			var bob := absf(pose.get("swing", 0.0)) * 1.0 if pose.has("swing") else 0.0
			_person(img, FOOT - Vector2(0, round(bob)), pose)
			_outline(img)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, FRAME), origin)
			if anchors != null:
				var a: Vector3 = carry["anchor"]
				var spot := _shrink(FOOT - Vector2(0, round(bob)) + _ground(a.x, a.y) - Vector2(0, a.z))
				anchors.set_pixelv(origin + Vector2i(spot.round()), ANCHOR)
				var faces_camera := _forward.y > 0.1
				var faces_away := _forward.y < -0.1
				if (faces_camera if carry["behind_camera"] else faces_away):
					anchors.set_pixelv(origin, BEHIND)
	return [sheet, anchors]


# --- The person ----------------------------------------------------------------------------

func _person(img: Image, foot: Vector2, pose: Dictionary) -> void:
	_parts = []
	var swing: float = pose.get("swing", 0.0)
	var work := String(pose.get("work", ""))
	var t: float = pose.get("t", 0.0)
	var lean := 0.0
	var crouch := 0.0
	if work == "bend":
		lean = 3.0 + sin(t * TAU) * 0.5
		crouch = 4.0
	elif work in ["low", "throw"]:
		lean = 1.5
		crouch = 1.0 + maxf(sin(t * TAU), 0.0) * 1.5 if work == "low" else 0.0
	var breath: float = pose.get("breath", 0.0)
	var top := 0.4 * breath - crouch
	var dress: bool = _look.get("dress", false)
	# Legs and shoes.
	for side: float in [-1.0, 1.0]:
		var step := swing * side * 3.5
		var hip := Vector3(side * 2.2, lean * 0.2, 13.0 - crouch)
		var knee := Vector3(side * 2.3, step * 0.5 + 0.8, 7.0 - crouch * 0.5)
		var ankle := Vector3(side * 2.3, step, 1.5)
		if not dress:
			_limb(foot, hip, knee, 3.4, _look["legs"])
			_limb(foot, knee, ankle, 3.0, _look["legs"].darkened(0.06))
		_blob(foot, ankle + Vector3(0, 1.0, -0.8), Vector2(2.2, 1.4), C_SHOE)
	# Body.
	var body := Vector3(0, lean, 21.0 + top)
	var shirt: Color = _look["shirt"]
	if dress:
		_skirt(foot, lean, top)
	_torso(foot, body, shirt)
	if _look.has("cloak"):
		var cloak: Color = _look["cloak"]
		_part(_depth(0, lean - 2.0) - 0.3, func() -> void: _ellipse_at(foot, Vector3(0, lean - 1.6, 19.0 + top), Vector2(_width(7.0), 10.0), cloak))
	if _look.has("apron"):
		var apron: Color = _look["apron"]
		_part(_depth(0, lean + 3.2) + 0.05, func() -> void:
			if _forward.y > -0.25:
				var w := _width(4.2)
				var waist := foot + _ground(0, lean + 3.0) - Vector2(0, 18.0 + top)
				var hem := foot + _ground(0, lean * 0.3 + 2.0) - Vector2(0, 6.0)
				_polygon(PackedVector2Array([waist - Vector2(w, 0), waist + Vector2(w, 0),
						hem + Vector2(w * 1.1, 0), hem - Vector2(w * 1.1, 0)]), apron)
				_line(waist - Vector2(w, 0), waist + Vector2(w, 0), apron.darkened(0.3), 1))
	# Belt.
	_part(_depth(0, lean + 2.8), func() -> void:
		if _forward.y > -0.6:
			var b := foot + _ground(0, lean + 2.6) - Vector2(0, 18.0 + top)
			var w := _width(5.6)
			_line(b - Vector2(w, 0), b + Vector2(w, 0), Color(0.3, 0.2, 0.12), 1))
	# Arms and the tool.
	var hands := _hands(pose, lean, top)
	var shoulder_z := 27.5 + top
	for i: int in 2:
		var side := 1.0 if i == 0 else -1.0
		var shoulder := Vector3(side * 5.0, lean * 0.9, shoulder_z)
		var hand: Vector3 = hands[i]
		var elbow := (shoulder + hand) * 0.5 + Vector3(side * 1.2, -0.8, -1.5)
		_limb(foot, shoulder, elbow, 2.8, shirt.darkened(0.22))
		_limb(foot, elbow, hand, 2.4, shirt.darkened(0.18))
		_blob(foot, hand, Vector2(1.5, 1.5), SKIN)
	var tool := String(pose.get("tool", ""))
	if tool == "" and work == "" and not pose.has("carry"):
		tool = String(_look["tool"]) if _look["tool"] in ["staff", "crook"] else ""
	if tool != "":
		_tool(foot, tool, hands[0], hands[1], work, t)
	# Head, hair, face, hat.
	var head := Vector3(0, lean * 1.4, 35.0 + top)
	_head(foot, head)
	_parts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for part: Array in _parts:
		(part[1] as Callable).call()
	_target_img = null
	_flush(img)


func _hands(pose: Dictionary, lean: float, top: float) -> Array:
	var swing: float = pose.get("swing", 0.0)
	var t: float = pose.get("t", 0.0)
	var c := TAU * t
	if pose.has("carry"):
		var hands: Array = (CARRY[String(pose["carry"])] as Dictionary)["hands"].duplicate()
		var free: Vector3 = hands[1]
		if pose["carry"] in ["sack", "basket", "log"]:
			hands[1] = free + Vector3(0, -swing * 2.5, 0)
		return hands
	match String(pose.get("work", "")):
		"overhead":
			# Raise over the head, strike down in front.
			var k := 0.5 - 0.5 * cos(c)
			var up := Vector3(2.0, -1.0, 38.0 + top)
			var down := Vector3(1.0, 7.0 + lean, 15.0 + top)
			var h := up.lerp(down, k * k)
			return [h, h + Vector3(-2.5, -0.5, -1.5)]
		"low":
			var h := Vector3(4.0 + sin(c) * 3.0, 6.0 + lean, 10.0 + top)
			return [h, Vector3(-4.0, 4.0 + lean, 13.0 + top)]
		"push":
			var f := 5.0 + lean + sin(c) * 2.5
			return [Vector3(3.0, f, 19.0 + top), Vector3(-3.0, f, 19.0 + top)]
		"stir":
			var h := Vector3(cos(c) * 2.5, 6.0 + sin(c) * 1.5, 21.0 + top)
			return [h, h + Vector3(-1.5, -0.5, 4.0)]
		"throw":
			var k := maxf(sin(c), 0.0)
			return [Vector3(5.5, 2.0 + 5.0 * k, 15.0 + 6.0 * k + top), Vector3(-5.0, 2.0, 17.0 + top)]
		"bend":
			var h := Vector3(1.5, 5.5 + lean, 9.0 + top + sin(c) * 1.0)
			return [h, h + Vector3(-3.0, 0, 0.5)]
		"cast":
			var k := 0.5 - 0.5 * cos(c)
			var h := Vector3(3.0, -2.0 + 9.0 * k, 34.0 - 10.0 * k + top)
			return [h, h + Vector3(-2.0, -1.0, -3.0)]
		"hold":
			var h := Vector3(3.0, 5.0, 21.0 + top + sin(c) * 0.5)
			return [h, h + Vector3(-2.5, -1.0, -2.0)]
		"reel":
			var k := 0.5 - 0.5 * cos(c)
			var h := Vector3(3.0, 5.0 - 3.0 * k, 21.0 + 9.0 * k + top)
			return [h, Vector3(-2.0, 4.0, 19.0 + top + sin(c * 2.0) * 1.5)]
	return [Vector3(5.5, -swing * 3.0, 16.0 + top), Vector3(-5.5, swing * 3.0, 16.0 + top)]


func _torso(foot: Vector2, body: Vector3, shirt: Color) -> void:
	_part(_depth(0, body.y), func() -> void:
		var c := foot + _ground(0, body.y) - Vector2(0, body.z)
		var w := _width(6.2)
		# Shoulders wider than the waist: two stacked ellipses.
		_ellipse(c + Vector2(0, 2.5), Vector2(w * 0.85, 6.5), shirt)
		_ellipse(c - Vector2(0, 3.0), Vector2(w, 4.5), shirt.lightened(0.04))
		# Collar / neckline.
		if _forward.y > -0.3:
			_ellipse(c - Vector2(0, 7.0) + _ground(0, 1.5), Vector2(2.0, 1.0), SKIN.darkened(0.08)))


func _skirt(foot: Vector2, lean: float, top: float) -> void:
	var colour: Color = _look["legs"]
	_part(_depth(0, lean) - 0.1, func() -> void:
		var waist := foot + _ground(0, lean * 0.6) - Vector2(0, 17.0 + top)
		var hem := foot - Vector2(0, 2.0)
		var w := _width(5.0)
		var poly := PackedVector2Array([waist - Vector2(w * 0.8, 0), waist + Vector2(w * 0.8, 0),
				hem + Vector2(w * 1.3, 0), hem - Vector2(w * 1.3, 0)])
		_polygon(poly, colour)
		_line(hem - Vector2(w * 1.25, 1), hem + Vector2(w * 1.25, 1), colour.darkened(0.25), 1))


func _head(foot: Vector2, head: Vector3) -> void:
	var hair: Color = _look["hair"]
	var hat := String(_look.get("hat", ""))
	var hat_colour: Color = _look.get("hat_colour", Color(0.85, 0.72, 0.4))
	_part(_depth(0, head.y) + 0.2, func() -> void: _draw_head(foot, head, hair, hat, hat_colour))


func _draw_head(foot: Vector2, head: Vector3, hair: Color, hat: String, hat_colour: Color) -> void:
	var c := foot + _ground(0, head.y) - Vector2(0, head.z)
	# Neck, then head.
	_ellipse(c + Vector2(0, 4.5), Vector2(1.8, 1.8), SKIN.darkened(0.1))
	_ellipse(c, Vector2(4.4, 4.8), SKIN)
	# Hair: back of the head, a fringe at the front.
	var back := c + _ground(0, -1.6) - Vector2(0, 1.2)
	_ellipse(back, Vector2(4.6, 4.0 if _forward.y < 0.0 else 3.2), hair)
	if _forward.y > -0.3:
		var face := c + _ground(0, 3.6)
		for side: float in [-1.0, 1.0]:
			var eye := face + _ground(side * 1.7, 0) - Vector2(0, 0.5)
			if absf(_right.x) > 0.4 or side * _right.x * -1.0 > -0.5:
				_pixel(eye, Color(0.15, 0.1, 0.08))
		_pixel(face + Vector2(0, 2.0), SKIN.darkened(0.2))
		if _look.get("beard", false):
			_ellipse(face + Vector2(0, 2.8), Vector2(2.6, 1.6), hair)
	match hat:
		"straw":
			var brim := c - Vector2(0, 3.5)
			_ellipse(brim, Vector2(8.5, 3.0), Color(0.88, 0.76, 0.42))
			_ellipse(brim - Vector2(0, 2.0), Vector2(4.2, 2.6), Color(0.92, 0.8, 0.46))
			_line(brim - Vector2(4, 0.5), brim + Vector2(4, -0.5), Color(0.6, 0.35, 0.2), 1)
		"veil":
			# Beekeeper: pale wide hat with a mesh veil over the face (dithered, not translucent).
			var vb := c - Vector2(0, 3.5)
			for y: int in range(int(vb.y), int(c.y + 5.0)):
				for x: int in range(int(c.x - 5.0), int(c.x + 6.0)):
					if (x + y) % 2 == 0:
						_pixel(Vector2(x, y), Color(0.82, 0.8, 0.74))
			_ellipse(vb, Vector2(8.0, 2.8), hat_colour)
			_ellipse(vb - Vector2(0, 2.0), Vector2(4.0, 2.4), hat_colour.lightened(0.08))
		"wide":
			var brim := c - Vector2(0, 3.5)
			_ellipse(brim, Vector2(7.5, 2.6), hat_colour)
			_ellipse(brim - Vector2(0, 2.0), Vector2(4.0, 2.4), hat_colour.lightened(0.08))
		"cap":
			_ellipse(c - Vector2(0, 3.5), Vector2(4.8, 2.6), hat_colour)
			_ellipse(c - Vector2(0, 3.0) + _ground(0, 3.5), Vector2(2.8, 1.0), hat_colour.darkened(0.15))
		"flour_cap":
			_ellipse(c - Vector2(0, 4.0), Vector2(5.0, 3.0), Color(0.95, 0.94, 0.9))
		"baker_cap":
			_ellipse(c - Vector2(0, 4.5), Vector2(4.6, 3.0), Color(0.97, 0.96, 0.93))
			_ellipse(c - Vector2(0, 7.0), Vector2(4.0, 2.6), Color(1, 1, 0.98))
		"kerchief":
			_ellipse(c - Vector2(0, 2.5), Vector2(5.0, 3.6), hat_colour)
			var knot := c + _ground(0, -4.0) + Vector2(0, -1.0)
			if _forward.y < 0.3:
				_ellipse(knot, Vector2(1.6, 1.4), hat_colour.darkened(0.15))
		"hood":
			_ellipse(c - Vector2(0, 1.5) + _ground(0, -0.8), Vector2(5.6, 5.4), hat_colour)
			if _forward.y > -0.3:
				_ellipse(c + _ground(0, 3.0), Vector2(3.0, 3.4), SKIN)
				_pixel(c + _ground(0, 3.6) + _ground(-1.4, 0) - Vector2(0, 0.5), Color(0.15, 0.1, 0.08))
				_pixel(c + _ground(0, 3.6) + _ground(1.4, 0) - Vector2(0, 0.5), Color(0.15, 0.1, 0.08))


func _tool(foot: Vector2, tool: String, hand: Vector3, other: Vector3, work: String, t: float) -> void:
	var h := foot + _ground(hand.x, hand.y) - Vector2(0, hand.z)
	var o := foot + _ground(other.x, other.y) - Vector2(0, other.z)
	# Direction the tool points, in screen space.
	var dir := Vector2(0, -1)
	match work:
		"overhead":
			var k := 0.5 - 0.5 * cos(TAU * t)
			dir = (_ground(0, -1.0) * 0.6 + Vector2(0, -1)).lerp(_ground(0, 1.0) * 1.2 + Vector2(0, 0.6), k).normalized()
		"low":
			dir = (_ground(0.5, 1.0) + Vector2(0, 0.4)).normalized()
		"push", "stir":
			dir = (_ground(0, 1.0) + Vector2(0, 0.9)).normalized()
		"cast", "hold", "reel":
			var lift: float = {"cast": 0.6 + 0.6 * cos(TAU * t), "hold": 0.35, "reel": 0.35 + 0.5 * (0.5 - 0.5 * cos(TAU * t))}[work]
			dir = (_ground(0, 1.0) * 1.3 + Vector2(0, -lift)).normalized()
		_:
			dir = (Vector2(0, -1) + _ground(0, 0.3)).normalized()
	var depth := _depth(hand.x, hand.y) + 0.3
	_part(depth, func() -> void: _draw_tool(tool, h, dir, work, t))
	var _o := o


func _draw_tool(tool: String, h: Vector2, dir: Vector2, work: String, t: float) -> void:
	match tool:
		"axe":
			var tip := h + dir * 11.0
			_line(h - dir * 2.0, tip, C_WOOD, 1)
			_polygon(PackedVector2Array([tip, tip + dir.orthogonal() * 4.0 - dir * 2.0, tip + dir.orthogonal() * 3.0 - dir * 4.0]), C_IRON)
		"pick":
			var tip := h + dir * 11.0
			_line(h - dir * 2.0, tip, C_WOOD, 1)
			_line(tip - dir.orthogonal() * 4.0 - dir, tip + dir.orthogonal() * 4.0 - dir, C_IRON, 1)
		"hammer":
			var tip := h + dir * 7.0
			_line(h - dir, tip, C_WOOD, 1)
			_line(tip - dir.orthogonal() * 2.0, tip + dir.orthogonal() * 2.0, C_IRON.darkened(0.2), 2)
		"hoe":
			var tip := h + dir * 15.0
			_line(h - dir * 3.0, tip, C_WOOD, 1)
			_line(tip, tip + dir.orthogonal() * 3.0 + dir * 1.5, C_IRON, 2)
		"sickle", "hook":
			_line(h, h + dir * 3.0, C_WOOD, 1)
			var c := h + dir * 6.0
			for k: int in 6:
				var a := dir.angle() - 1.2 + k * 0.45
				_pixel(c + Vector2(cos(a), sin(a)) * 3.5, C_IRON)
		"saw":
			var along := _ground(0, 1.0).normalized() if _ground(0, 1.0).length() > 0.1 else Vector2(1, 0)
			var a := h - along * 3.0
			var b := h + along * 9.0
			_line(a, b, C_IRON, 2)
			_line(a + Vector2(0, 2), b + Vector2(0, 2), C_IRON.darkened(0.35), 1)
			_line(a - along * 2.0, a, C_WOOD, 2)
		"peel":
			var tip := h + dir * 13.0
			_line(h - dir * 4.0, tip, C_WOOD.lightened(0.15), 1)
			_ellipse(tip, Vector2(2.5, 1.5), C_WOOD.lightened(0.25))
		"paddle":
			var tip := h + Vector2(0, 9.0) + _ground(0, 1.5)
			_line(h - Vector2(0, 5), tip, C_WOOD.lightened(0.1), 1)
			_ellipse(tip, Vector2(1.5, 2.5), C_WOOD.lightened(0.2))
		"rod":
			var tip := h + dir * 20.0
			_line(h - dir * 2.0, tip, C_WOOD.lightened(0.2), 1)
			if work in ["hold", "reel"]:
				var bob := tip + Vector2(0, 10.0 + sin(TAU * t) * 1.0)
				_line(tip, bob, Color(0.85, 0.85, 0.8, 0.8), 1)
				_pixel(bob, Color(0.9, 0.25, 0.2))
		"staff":
			_line(h + Vector2(0, 14), h - Vector2(0, 10), C_WOOD.lightened(0.1), 1)
		"crook":
			_line(h + Vector2(0, 14), h - Vector2(0, 14), C_WOOD.lightened(0.1), 1)
			var top := h - Vector2(0, 14)
			for k: int in 5:
				var a := PI + k * PI / 4.0
				_pixel(top + Vector2(2.0 + cos(a) * 2.0, sin(a) * 2.5), C_WOOD.lightened(0.1))
		"spade":
			var tip := h + dir * 13.0
			var side := dir.orthogonal()
			_line(h - dir * 4.0, tip, C_WOOD.lightened(0.1), 1)
			_line(h - dir * 4.0 - side * 1.5, h - dir * 4.0 + side * 1.5, C_WOOD, 1)
			_polygon(PackedVector2Array([tip - side * 2.0, tip + side * 2.0, tip + dir * 4.0 + side * 1.5,
					tip + dir * 4.0 - side * 1.5]), C_IRON)
		"shears":
			var tip := h + dir * 5.0
			_line(h, tip + dir.orthogonal(), C_IRON, 1)
			_line(h, tip - dir.orthogonal(), C_IRON.darkened(0.2), 1)
		"smoker":
			_ellipse(h + Vector2(0, 2.5), Vector2(2.0, 3.0), Color(0.6, 0.45, 0.28))
			_line(h - Vector2(0, 0.5), h - Vector2(-1, 3), C_IRON, 1)
			_pixel(h - Vector2(-2, 5.0 + sin(TAU * t)), Color(0.82, 0.82, 0.8))
		"mug":
			_ellipse(h - Vector2(0, 1.5), Vector2(1.6, 2.2), Color(0.8, 0.62, 0.3))
			_pixel(h - Vector2(0, 4), Color(0.97, 0.95, 0.88))
			_pixel(h - Vector2(-2, 1.5), Color(0.6, 0.45, 0.2))



# --- Drawing in body space -----------------------------------------------------------------

var _target_img: Image
var _queue: Array = []


func _ground(s: float, f: float) -> Vector2:
	var v := _right * s + _forward * f
	return Vector2(v.x, v.y * 0.5)


## Larger = nearer to the camera.
func _depth(s: float, f: float) -> float:
	var v := _right * s + _forward * f
	return v.y


## Apparent half-width of the body for the facing (narrower seen from the side).
func _width(full: float) -> float:
	return full * (0.62 + 0.38 * absf(_right.x))


func _part(depth: float, draw: Callable) -> void:
	_parts.append([depth, draw])


func _limb(foot: Vector2, a: Vector3, b: Vector3, width: float, colour: Color) -> void:
	_part(_depth((a.x + b.x) * 0.5, (a.y + b.y) * 0.5), func() -> void:
		var pa := foot + _ground(a.x, a.y) - Vector2(0, a.z)
		var pb := foot + _ground(b.x, b.y) - Vector2(0, b.z)
		_thick(pa, pb, width, colour))


func _blob(foot: Vector2, at: Vector3, radius: Vector2, colour: Color) -> void:
	_part(_depth(at.x, at.y) + 0.01, func() -> void:
		_ellipse(foot + _ground(at.x, at.y) - Vector2(0, at.z), radius, colour))


func _ellipse_at(foot: Vector2, at: Vector3, radius: Vector2, colour: Color) -> void:
	_ellipse(foot + _ground(at.x, at.y) - Vector2(0, at.z), radius, colour)


func _flush(img: Image) -> void:
	for op: Array in _queue:
		match String(op[0]):
			"px":
				var p: Vector2i = op[1]
				if Rect2i(Vector2i.ZERO, img.get_size()).has_point(p):
					img.set_pixelv(p, op[2])
	_queue = []


func _pixel(p: Vector2, colour: Color) -> void:
	_queue.append(["px", Vector2i(_shrink(p).floor()), colour])


func _shrink(p: Vector2) -> Vector2:
	return FOOT + (p - FOOT) * SCALE


func _ellipse(centre: Vector2, radius: Vector2, colour: Color) -> void:
	for y: int in range(int(floor(centre.y - radius.y)) - 1, int(ceil(centre.y + radius.y)) + 1):
		for x: int in range(int(floor(centre.x - radius.x)) - 1, int(ceil(centre.x + radius.x)) + 1):
			var d := Vector2((x + 0.5 - centre.x) / maxf(radius.x, 0.5), (y + 0.5 - centre.y) / maxf(radius.y, 0.5))
			if d.length() <= 1.0:
				# Light from above and the front: lighter top, darker bottom edge.
				var shade := clampf(d.y * 0.14 + d.x * 0.04, -0.12, 0.16)
				_pixel(Vector2(x, y), colour.darkened(shade) if shade > 0.0 else colour.lightened(-shade))


func _thick(a: Vector2, b: Vector2, width: float, colour: Color) -> void:
	var steps := maxi(1, int(ceil(a.distance_to(b) * 2.0)))
	for s: int in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		_ellipse(p, Vector2(width * 0.5, width * 0.5), colour)


func _line(a: Vector2, b: Vector2, colour: Color, width: int) -> void:
	var steps := maxi(1, int(ceil(a.distance_to(b))))
	for s: int in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		for dx: int in width:
			for dy: int in width:
				_pixel(p + Vector2(dx - width / 2, dy - width / 2), colour)


func _polygon(poly: PackedVector2Array, colour: Color) -> void:
	var bounds := Rect2(poly[0], Vector2.ZERO)
	for p: Vector2 in poly:
		bounds = bounds.expand(p)
	for y: int in range(int(bounds.position.y) - 1, int(bounds.end.y) + 2):
		for x: int in range(int(bounds.position.x) - 1, int(bounds.end.x) + 2):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				_pixel(Vector2(x, y), colour.darkened(0.08 * float((y - int(bounds.position.y)) > bounds.size.y * 0.6)))


## Selective outline: transparent pixels next to the figure get a dark version of it.
func _outline(img: Image) -> void:
	var size := img.get_size()
	var edge: Dictionary = {}
	for y: int in size.y:
		for x: int in size.x:
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if Rect2i(Vector2i.ZERO, size).has_point(q) and img.get_pixelv(q).a == 0.0 and not edge.has(q):
					edge[q] = Color(c.r * 0.32, c.g * 0.27, c.b * 0.25, 1.0)
	for q: Vector2i in edge:
		img.set_pixelv(q, edge[q])


func _save(pair: Array, kind: String, anim: String) -> void:
	var dir := OUT.path_join(kind)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	(pair[0] as Image).save_png(dir.path_join(anim + ".png"))
	if pair[1] != null:
		(pair[1] as Image).save_png(dir.path_join(anim + ".anchors.png"))


## Points every profession's visual definition at its own character, untinted.
func _write_visuals() -> void:
	for kind: String in PEOPLE:
		var path := "res://data/visuals/agents/%s.tres" % kind
		var text := "[gd_resource type=\"Resource\" script_class=\"AgentVisualDef\" format=3]\n\n" \
				+ "[ext_resource type=\"Script\" path=\"res://src/defs/visuals/agent_visual_def.gd\" id=\"1_vis\"]\n\n" \
				+ "[resource]\nscript = ExtResource(\"1_vis\")\ncharacter = &\"%s\"\n" % kind
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
