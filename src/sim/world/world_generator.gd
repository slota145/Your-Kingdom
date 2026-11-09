class_name WorldGenerator
extends RefCounted
## Makes a world from its number (ROADMAP M8 part 1, owner's survey 2026-11-09): the same number
## and settings always give the same world. A continent with a few islands is grown from noise
## on the parchment; it is cut into provinces (the cells around scattered points, their shared
## borders made a little wavy); sea cells between them. Each province is a variant of one of
## the four maps (coast, islands, lakeland, riverlands) with its riches and sometimes a rare
## resource. The player starts on the coast of the mainland (landing from a ship), the AI rulers
## as far from him and from each other as can be, in small towns; a few neutral settlements and
## the bandits' camp lie between. The world and its provinces are registered in the data like
## the hand-made ones (DataRegistry.register_generated), their names made of translated words
## (GeneratedNames).

const SIZE := Vector2(1600, 1100)
## Sea cells and land cells together, per land province.
const CELLS_PER_PROVINCE := 1.9
## Neighbours each cell is clipped against (the nearest sites).
const NEAREST := 14
const ADJECTIVES := 20
const NOUNS := 16
const RARE: Array[StringName] = [&"iron_ore", &"iron_ore", &"horses", &"vines", &"vines", &"salt"]
## Towns of the AI rulers (part 1: they wait, part 3: they grow from here) and of the neutral
## settlements (the hand-made world's two).
const RULER_TOWN: Dictionary[StringName, int] = {&"hut": 10, &"well": 2, &"stockpile": 2, &"woodcutter": 2,
		&"forester": 1, &"quarry": 1, &"sawmill": 1, &"farm": 2, &"mill": 1, &"bakery": 1, &"fishing_hut": 1,
		&"market": 1, &"chapel": 1}
const NEUTRAL_TOWNS: Array[StringName] = [&"iron_wold", &"horse_haven"]


static func world_id(seed_value: int) -> StringName:
	return StringName("gen_%d" % seed_value)


## Owner id of AI ruler [param index] (1-3).
static func ruler_owner(index: int) -> StringName:
	return StringName("ruler_%d" % index)


## Makes the world of [param settings] and registers it and its provinces in [param data].
static func generate(data: DataRegistry, settings: GameSettings) -> WorldDef:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["world", settings.world_seed, settings.province_count, settings.rulers])
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.0028
	noise.fractal_octaves = 4
	var land_count := clampi(settings.province_count, 8, 40)
	# Scattered points on a jittered grid over the parchment.
	var total := int(land_count * CELLS_PER_PROVINCE)
	var step := sqrt(SIZE.x * SIZE.y / total)
	var sites: Array[Vector2] = []
	var y := step * 0.5
	while y < SIZE.y:
		var x := step * (0.5 if int(y / step) % 2 == 0 else 1.0)
		while x < SIZE.x:
			sites.append(Vector2(x + rng.randf_range(-0.35, 0.35) * step, y + rng.randf_range(-0.35, 0.35) * step))
			x += step
		y += step
	# Land where the noise and the pull towards the middle are highest.
	var scores: Array[float] = []
	for p: Vector2 in sites:
		var d := ((p - SIZE * 0.5) / (SIZE * 0.5)).length()
		scores.append(noise.get_noise_2dv(p) * 0.9 + (1.0 - d * d) * 0.9)
	var order: Array[int] = []
	for i: int in sites.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])
	var is_land: Array[bool] = []
	is_land.resize(sites.size())
	for k: int in mini(land_count, sites.size()):
		is_land[order[k]] = true
	# Cells and their neighbours.
	var cells: Array[PackedVector2Array] = []
	var adjacent: Array[Array] = []
	for i: int in sites.size():
		var cell := _cell(sites, i)
		cells.append(cell[0])
		adjacent.append(cell[1])
	# Land provinces: index in sites -> province number.
	var land: Array[int] = []
	for i: int in sites.size():
		if is_land[i]:
			land.append(i)
	var ids: Dictionary[int, StringName] = {}
	for k: int in land.size():
		ids[land[k]] = StringName("%s_%d" % [world_id(settings.world_seed), k + 1])
	# Mainland: the biggest group of land cells joined by land.
	var group: Dictionary[int, int] = {}
	var sizes: Array[int] = []
	for i: int in land:
		if group.has(i):
			continue
		var g := sizes.size()
		var queue: Array[int] = [i]
		group[i] = g
		var n := 0
		while not queue.is_empty():
			var c: int = queue.pop_back()
			n += 1
			for j: int in adjacent[c]:
				if is_land[j] and not group.has(j):
					group[j] = g
					queue.append(j)
		sizes.append(n)
	var main_group := sizes.find(sizes.max())
	# Names: each adjective and each noun once before any comes again.
	var adjectives: Array[int] = []
	for k: int in ADJECTIVES:
		adjectives.append(k + 1)
	_shuffle(adjectives, rng)
	var nouns: Array[int] = []
	for k: int in NOUNS:
		nouns.append(k + 1)
	_shuffle(nouns, rng)
	# Province definitions.
	var defs: Dictionary[int, ProvinceDef] = {}
	for i: int in land:
		var def := ProvinceDef.new()
		def.id = ids[i]
		def.island = group[i] != main_group
		var coastal := def.island
		var neighbours: Array[StringName] = []
		for j: int in adjacent[i]:
			if is_land[j]:
				neighbours.append(ids[j])
			else:
				coastal = true
		if _touches_edge(cells[i]):
			coastal = true
		def.neighbours = neighbours
		def.coastal = coastal
		def.richness = rng.randi_range(1, 3)
		def.mirrored = rng.randf() < 0.5
		def.template = &"islands" if def.island else (&"coast" if coastal else
				(&"lakeland" if rng.randf() < 0.5 else &"riverlands"))
		def.outline = _wavy(cells[i], rng.seed)
		def.world_pos = _centroid(cells[i])
		def.name_parts = PackedStringArray(["world.adj.%d" % adjectives[land.find(i) % ADJECTIVES],
				"world.noun.%d" % nouns[land.find(i) % NOUNS]])
		def.desc_parts = PackedStringArray(["world.template.%s" % def.template])
		defs[i] = def
	# Starts: the player on the mainland's coast, the rulers as far as can be from everyone.
	var mainland_coast: Array[int] = []
	for i: int in land:
		if group[i] == main_group and defs[i].coastal:
			mainland_coast.append(i)
	var player := mainland_coast[rng.randi_range(0, mainland_coast.size() - 1)] if not mainland_coast.is_empty() else land[0]
	defs[player].template = &"coast"
	defs[player].owner = ProvinceDef.OWNER_PLAYER
	var taken: Array[int] = [player]
	for r: int in range(1, settings.rulers + 1):
		var best := _farthest(sites, land, taken, func(i: int) -> bool: return group[i] == main_group)
		if best < 0:
			break
		defs[best].owner = ruler_owner(r)
		defs[best].town_buildings = RULER_TOWN.duplicate()
		defs[best].town_burghers = 3
		taken.append(best)
	# Neutral settlements between them, with the hand-made towns' layouts and demands.
	var neutrals := maxi(2, land.size() / 9)
	for k: int in neutrals:
		var best := _farthest(sites, land, taken, func(i: int) -> bool: return not defs[i].island)
		if best < 0:
			break
		var layout := data.get_province(NEUTRAL_TOWNS[k % NEUTRAL_TOWNS.size()])
		var def := defs[best]
		def.owner = ProvinceDef.OWNER_NEUTRAL
		def.template = layout.template if not def.coastal or layout.template == &"coast" else def.template
		def.town_buildings = layout.town_buildings.duplicate()
		def.town_burghers = layout.town_burghers
		def.demand_gold = layout.demand_gold
		def.demand_goods = layout.demand_goods.duplicate()
		def.demand_minutes = layout.demand_minutes
		def.town_wall = layout.town_wall
		def.town_towers = layout.town_towers
		def.town_guards = layout.town_guards.duplicate()
		def.rare_resource = layout.rare_resource
		taken.append(best)
	# Rare resources on some of the empty provinces.
	var empty: Array[int] = []
	for i: int in land:
		if defs[i].owner == ProvinceDef.OWNER_NONE:
			empty.append(i)
	_shuffle(empty, rng)
	for k: int in mini(RARE.size(), empty.size()):
		defs[empty[k]].rare_resource = RARE[k]
	var world := WorldDef.new()
	world.id = world_id(settings.world_seed)
	world.size = SIZE
	world.name_parts = PackedStringArray(["ui.world.generated"])
	world.name_args = [settings.world_seed]
	var scale := 1.35
	world.ship_speed *= scale
	world.wagon_speed *= scale
	world.army_speed *= scale
	world.start_province = defs[player].id
	# The bandits' camp: an empty inland province far from the player.
	var only_player: Array[int] = [player]
	var camp := _farthest(sites, empty, only_player, func(i: int) -> bool: return not defs[i].island)
	if camp >= 0:
		world.bandit_camp = defs[camp].id
	for i: int in land:
		world.provinces.append(defs[i].id)
		data.register_generated(defs[i])
	data.register_generated(world)
	return world


## The cell of site [param i] (the part of the parchment nearer to it than to any other
## site) and the sites whose cells share a border with it: [polygon, neighbour indices].
static func _cell(sites: Array[Vector2], i: int) -> Array:
	var me := sites[i]
	var near: Array[int] = []
	for j: int in sites.size():
		if j != i:
			near.append(j)
	near.sort_custom(func(a: int, b: int) -> bool:
		return sites[a].distance_squared_to(me) < sites[b].distance_squared_to(me))
	near.resize(mini(NEAREST, near.size()))
	var poly := PackedVector2Array([Vector2.ZERO, Vector2(SIZE.x, 0), SIZE, Vector2(0, SIZE.y)])
	for j: int in near:
		poly = _clip(poly, me, sites[j])
	var neighbours: Array[int] = []
	for j: int in near:
		var mid := (me + sites[j]) * 0.5
		var normal := (sites[j] - me).normalized()
		var on := 0
		for p: Vector2 in poly:
			if absf((p - mid).dot(normal)) < 0.5:
				on += 1
		if on >= 2:
			neighbours.append(j)
	return [poly, neighbours]


## [param poly] cut to the side of the bisector of [param a]-[param b] nearer to [param a].
static func _clip(poly: PackedVector2Array, a: Vector2, b: Vector2) -> PackedVector2Array:
	var mid := (a + b) * 0.5
	var normal := b - a
	var out := PackedVector2Array()
	for k: int in poly.size():
		var p := poly[k]
		var q := poly[(k + 1) % poly.size()]
		var dp := (p - mid).dot(normal)
		var dq := (q - mid).dot(normal)
		if dp <= 0.0:
			out.append(p)
		if (dp < 0.0 and dq > 0.0) or (dp > 0.0 and dq < 0.0):
			out.append(p.lerp(q, dp / (dp - dq)))
	return out


static func _touches_edge(poly: PackedVector2Array) -> bool:
	for p: Vector2 in poly:
		if p.x < 1.0 or p.y < 1.0 or p.x > SIZE.x - 1.0 or p.y > SIZE.y - 1.0:
			return true
	return false


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p: Vector2 in poly:
		sum += p
	return (sum / maxi(poly.size(), 1)).round()


## The outline with each border bent a little (the same way from both sides: the bend comes
## from the border's two ends, not from the cell).
static func _wavy(poly: PackedVector2Array, salt: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k: int in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		out.append(a.round())
		var swap := a.x > b.x or (a.x == b.x and a.y > b.y)
		var lo := b if swap else a
		var hi := a if swap else b
		var mids := _bend(lo, hi, salt, 2)
		if swap:
			mids.reverse()
		for m: Vector2 in mids:
			out.append(m.round())
	return out


## Points between [param a] and [param b], each moved sideways by a bit decided by the ends.
static func _bend(a: Vector2, b: Vector2, salt: int, depth: int) -> PackedVector2Array:
	var length := a.distance_to(b)
	if depth == 0 or length < 18.0:
		return PackedVector2Array()
	var h := hash([a.round(), b.round(), salt])
	var shift := (float(h % 1000) / 1000.0 - 0.5) * 0.28 * length
	var mid := (a + b) * 0.5 + (b - a).orthogonal().normalized() * shift
	var result := _bend(a, mid, salt, depth - 1)
	result.append(mid)
	result.append_array(_bend(mid, b, salt, depth - 1))
	return result


## The site among [param from] (passing [param ok]) farthest from all of [param taken]; -1 if none.
static func _farthest(sites: Array[Vector2], from: Array[int], taken: Array[int], ok: Callable) -> int:
	var best := -1
	var best_d := -1.0
	for i: int in from:
		if taken.has(i) or not ok.call(i):
			continue
		var d := INF
		for t: int in taken:
			d = minf(d, sites[i].distance_to(sites[t]))
		if d > best_d:
			best_d = d
			best = i
	return best


static func _shuffle(list: Array[int], rng: RandomNumberGenerator) -> void:
	for k: int in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t := list[k]
		list[k] = list[j]
		list[j] = t
