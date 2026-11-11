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
## One province in this many is rich in stone (E3 part 3; at least one, near the player).
const STONE_EVERY := 10
## Towns of the AI rulers (part 1: they wait, part 3: they grow from here) and of the neutral
## settlements (the hand-made world's two).
const RULER_TOWN: Dictionary[StringName, int] = {&"hut": 10, &"well": 2, &"stockpile": 2, &"woodcutter": 2,
		&"forester": 1, &"quarry": 1, &"sawmill": 1, &"farm": 2, &"mill": 1, &"bakery": 1, &"fishing_hut": 1,
		&"market": 1, &"chapel": 1, &"orchard": 1}
const NEUTRAL_TOWNS: Array[StringName] = [&"iron_wold", &"horse_haven"]
## The capital of a ruler in the Divided continent (M8 part 5: towns ready at the start, the
## first part of his plan of growth with barracks; the town hall comes by itself).
const CAPITAL_TOWN: Dictionary[StringName, int] = {&"hut": 16, &"well": 3, &"stockpile": 3, &"woodcutter": 3,
		&"forester": 1, &"quarry": 1, &"sawmill": 1, &"farm": 3, &"mill": 1, &"bakery": 1, &"fishing_hut": 2,
		&"market": 1, &"chapel": 1, &"hop_farm": 1, &"brewery": 1, &"trading_post": 1, &"barracks": 1,
		&"orchard": 1, &"hunter_lodge": 1}
## Share of the provinces of the Divided continent the rulers hold together (each at least 2,
## at most [constant MAX_REALM]); the rest are neutral settlements.
const RULERS_SHARE := 0.45
const MAX_REALM := 6
## Sea cells and land cells together per province of the Merchant islands (more sea).
const ISLAND_CELLS_PER_PROVINCE := 4.5
## How much bigger the sheet of the Merchant islands is (as for this many times the provinces).
const ISLAND_SHEET := 1.8
## How much more a ruler keeps away from the player than from another ruler.
const RULER_AWAY := 1.6


static func world_id(seed_value: int) -> StringName:
	return StringName("gen_%d" % seed_value)


## Owner id of AI ruler [param index] (1-3).
static func ruler_owner(index: int) -> StringName:
	return StringName("ruler_%d" % index)


## Makes the world of [param settings] and registers it and its provinces in [param data].
static func generate(data: DataRegistry, settings: GameSettings) -> WorldDef:
	var world := geography(data, settings)
	assign(data, world, settings)
	return world


## The parchment of a world of [param count] provinces: bigger worlds on a bigger sheet, so the
## provinces keep about the same size (owner's survey 2026-11-09: the map scrolls and zooms).
static func size_for(count: int) -> Vector2:
	return (SIZE * sqrt(maxf(count, 9) / 22.0)).round()


## The land, the sea, the islands and the provinces of the world of [param settings], all
## still without owners (step 1; [method assign] gives them out). Registered in [param data].
static func geography(data: DataRegistry, settings: GameSettings) -> WorldDef:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["world", settings.world_seed, settings.province_count, settings.islands])
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.fractal_octaves = 4
	var count := clampi(settings.province_count, GameSettings.MIN_PROVINCES, GameSettings.MAX_PROVINCES)
	var islands := clampi(settings.islands, 0, mini(GameSettings.MAX_ISLANDS, count / 3))
	var archipelago := settings.scenario == GameSettings.ISLANDS
	# (The Merchant islands: a bigger sheet, so the islands have sea round them.)
	var size := size_for(roundi(count * ISLAND_SHEET)) if archipelago else size_for(count)
	noise.frequency = 0.0028 * SIZE.x / size.x
	# Scattered points on a jittered grid over the parchment; more sea for more islands.
	var total := int(count * (ISLAND_CELLS_PER_PROVINCE if archipelago else CELLS_PER_PROVINCE + 0.12 * islands))
	var step := sqrt(size.x * size.y / total)
	var sites: Array[Vector2] = []
	var y := step * 0.5
	while y < size.y:
		var x := step * (0.5 if int(y / step) % 2 == 0 else 1.0)
		while x < size.x:
			sites.append(Vector2(x + rng.randf_range(-0.35, 0.35) * step, y + rng.randf_range(-0.35, 0.35) * step))
			x += step
		y += step
	# The continent where the noise and the pull towards the middle are highest; with islands
	# it keeps away from the edge, so there is sea round it for them.
	var pull := 1.0 + 0.05 * islands
	var scores: Array[float] = []
	for p: Vector2 in sites:
		var d := ((p - size * 0.5) / (size * 0.5)).length() * pull
		scores.append(noise.get_noise_2dv(p) * 0.9 + (1.0 - d * d) * 0.9)
	var order: Array[int] = []
	for i: int in sites.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return scores[a] > scores[b])
	var is_land: Array[bool] = []
	is_land.resize(sites.size())
	if not archipelago:
		for k: int in mini(count - islands, sites.size()):
			is_land[order[k]] = true
	var cells: Array[PackedVector2Array] = []
	var adjacent: Array[Array] = []
	for i: int in sites.size():
		var cell := _cell(sites, i, size)
		cells.append(cell[0])
		adjacent.append(cell[1])
	var group_of: Dictionary[int, int] = {}
	if archipelago:
		_archipelago(sites, cells, adjacent, is_land, group_of, count, size, step, rng)
		islands = 0
	# Islands: sea cells touching no land, far from the land and from each other.
	var placed := 0
	while placed < islands:
		var best := -1
		var best_d := -1.0
		for i: int in sites.size():
			if is_land[i]:
				continue
			var lonely := true
			for j: int in adjacent[i]:
				if is_land[j]:
					lonely = false
					break
			if not lonely:
				continue
			var d := INF
			for j: int in sites.size():
				if is_land[j]:
					d = minf(d, sites[i].distance_to(sites[j]))
			# Not too far out either: a little noise decides between the spots.
			d = minf(d, step * 2.2) + rng.randf() * step - (step if _touches_edge(cells[i], size) else 0.0)
			if d > best_d:
				best_d = d
				best = i
		if best < 0:
			break
		is_land[best] = true
		placed += 1
	# Islands that found no place go to the continent: the world keeps its number of provinces.
	for k: int in range(count - islands, sites.size()):
		if placed >= islands:
			break
		var i := order[k]
		if is_land[i]:
			continue
		for j: int in adjacent[i]:
			if is_land[j]:
				is_land[i] = true
				placed += 1
				break
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
	var main_group := sizes.find(sizes.max()) if not archipelago else -1
	# Names: each adjective and each noun once before any comes again.
	var adjectives: Array[int] = []
	for k: int in ADJECTIVES:
		adjectives.append(k + 1)
	_shuffle(adjectives, rng)
	var nouns: Array[int] = []
	for k: int in NOUNS:
		nouns.append(k + 1)
	_shuffle(nouns, rng)
	var world := WorldDef.new()
	world.id = world_id(settings.world_seed)
	world.size = size
	world.name_parts = PackedStringArray(["ui.world.generated"])
	world.name_args = [settings.world_seed]
	var scale := 1.35
	world.ship_speed *= scale
	world.wagon_speed *= scale
	world.army_speed *= scale
	for k: int in land.size():
		var i := land[k]
		var def := ProvinceDef.new()
		def.id = ids[i]
		def.island = group[i] != main_group
		var coastal := def.island or _touches_edge(cells[i], size)
		var neighbours: Array[StringName] = []
		for j: int in adjacent[i]:
			if is_land[j]:
				neighbours.append(ids[j])
			else:
				coastal = true
		def.neighbours = neighbours
		def.coastal = coastal
		def.richness = rng.randi_range(1, 3)
		def.mirrored = rng.randf() < 0.5
		def.template = &"islands" if def.island else (&"coast" if coastal else
				(&"lakeland" if rng.randf() < 0.5 else &"riverlands"))
		if archipelago and sizes[group[i]] > 1:
			def.template = &"coast"   # (an island of 2-3 provinces: coasts with land borders)
		def.outline = _wavy(cells[i], rng.seed)
		def.world_pos = _centroid(cells[i])
		def.name_parts = PackedStringArray(["world.adj.%d" % adjectives[k % ADJECTIVES],
				"world.noun.%d" % nouns[(k + k / NOUNS) % NOUNS]])
		def.desc_parts = PackedStringArray(["world.template.%s" % def.template])
		world.provinces.append(def.id)
		data.register_generated(def)
	data.register_generated(world)
	return world


## Provinces the player may start in (owner's surveys 2026-11-09 and 2026-11-10): one on the
## coast or an island, in every scenario (he comes by ship).
static func start_choices(data: DataRegistry, world: WorldDef, _settings: GameSettings) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in world.provinces:
		var def := data.get_province(id)
		if def.coastal:
			result.append(id)
	return result


## Gives out the provinces of [param world] (step 2, after the player chose where to start):
## the player's start (settings.start, or a random allowed one), the AI rulers as far as can be
## from him and from each other, the neutral settlements, the rare resources, the bandits' camp.
static func assign(data: DataRegistry, world: WorldDef, settings: GameSettings) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["owners", settings.world_seed, settings.province_count, settings.islands,
			settings.rulers, settings.start])
	var defs: Array[ProvinceDef] = []
	for id: StringName in world.provinces:
		defs.append(data.get_province(id))
	var choices := start_choices(data, world, settings)
	var start := StringName(settings.start)
	if not choices.has(start):
		start = choices[rng.randi_range(0, choices.size() - 1)] if not choices.is_empty() else defs[0].id
	var taken: Array[ProvinceDef] = []
	var player := data.get_province(start)
	player.owner = ProvinceDef.OWNER_PLAYER
	player.template = &"islands" if player.island and player.template != &"coast" else &"coast"
	var divided := settings.scenario == GameSettings.DIVIDED
	var anywhere := divided or settings.scenario == GameSettings.ISLANDS
	taken.append(player)
	world.start_province = start
	# Far from the player first, then from each other (a ruler is never put between them).
	for r: int in range(1, settings.rulers + 1):
		var best := _farthest_def(defs, taken, func(d: ProvinceDef) -> bool: return not d.island, player)
		if best == null:
			best = _farthest_def(defs, taken, func(_d: ProvinceDef) -> bool: return true, player)
		if best == null:
			break
		best.owner = ruler_owner(r)
		best.town_buildings = (CAPITAL_TOWN if divided else RULER_TOWN).duplicate()
		best.town_burghers = 6 if divided else 3
		taken.append(best)
	if divided:
		_realms(data, defs, taken, player, settings.rulers)
	var neutrals := defs.size() if divided else maxi(2, defs.size() / 9)
	for k: int in neutrals:
		var best := _farthest_def(defs, taken, func(d: ProvinceDef) -> bool: return anywhere or not d.island)
		if best == null:
			break
		var layout := data.get_province(NEUTRAL_TOWNS[k % NEUTRAL_TOWNS.size()])
		best.owner = ProvinceDef.OWNER_NEUTRAL
		if not best.coastal:
			best.template = layout.template
		best.town_buildings = layout.town_buildings.duplicate()
		best.town_burghers = layout.town_burghers
		best.demand_gold = layout.demand_gold
		best.demand_goods = layout.demand_goods.duplicate()
		best.demand_minutes = layout.demand_minutes
		best.town_wall = layout.town_wall
		best.town_towers = layout.town_towers
		best.town_guards = layout.town_guards.duplicate()
		best.rare_resource = layout.rare_resource
		taken.append(best)
	var empty: Array[ProvinceDef] = []
	for d: ProvinceDef in defs:
		if d.owner == ProvinceDef.OWNER_NONE:
			empty.append(d)
	for k: int in range(empty.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t := empty[k]
		empty[k] = empty[j]
		empty[j] = t
	var rare := mini(RARE.size() * maxi(defs.size() / 20, 1), empty.size())
	for k: int in rare:
		empty[k].rare_resource = RARE[k % RARE.size()]
	var only_player: Array[ProvinceDef] = [player]
	var camp := _farthest_def(empty, only_player, func(d: ProvinceDef) -> bool: return not d.island)
	# (No camp in the Invasion from the sea: the waves are the danger there.)
	world.bandit_camp = camp.id if camp != null and settings.scenario != GameSettings.INVASION else &""
	_rich_in_stone(data, defs, player, settings)


## Gives the trait "rich in stone" (ROADMAP E3 part 3, owner's survey 2026-11-11) to about one
## province in [constant STONE_EVERY], never the player's start: the first one near him (a
## neighbour, else a neighbour's neighbour), the rest anywhere. A die of its own, so the rest of
## the world comes out as before (a save from before part 3 loads with the trait from its seed).
## A neutral town there quarries in a stone pit instead of a quarry.
static func _rich_in_stone(data: DataRegistry, defs: Array[ProvinceDef], player: ProvinceDef,
		settings: GameSettings) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["stone", settings.world_seed, settings.province_count, settings.islands,
			settings.rulers, settings.start])
	var count := maxi(1, roundi(defs.size() / float(STONE_EVERY)))
	var chosen: Array[ProvinceDef] = []
	var near: Array[ProvinceDef] = []
	for id: StringName in player.neighbours:
		var d := data.get_province(id)
		if d != null and d != player:
			near.append(d)
	if near.is_empty():
		for id: StringName in player.neighbours:
			var d := data.get_province(id)
			if d == null:
				continue
			for id2: StringName in d.neighbours:
				var d2 := data.get_province(id2)
				if d2 != null and d2 != player and not near.has(d2):
					near.append(d2)
	# Rather an empty province near him than a ruler's or a settlement's.
	var empty_near := near.filter(func(d: ProvinceDef) -> bool: return d.owner == ProvinceDef.OWNER_NONE)
	if not empty_near.is_empty():
		near.assign(empty_near)
	if not near.is_empty():
		chosen.append(near[rng.randi_range(0, near.size() - 1)])
	var rest: Array[ProvinceDef] = []
	for d: ProvinceDef in defs:
		if d != player and not chosen.has(d):
			rest.append(d)
	while chosen.size() < count and not rest.is_empty():
		chosen.append(rest.pop_at(rng.randi_range(0, rest.size() - 1)))
	for d: ProvinceDef in chosen:
		var own := d.traits.duplicate()
		own.append(ProvinceDef.RICH_STONE)
		d.traits = own
		if d.owner == ProvinceDef.OWNER_NEUTRAL:
			d.town_buildings.erase(&"quarry")
			d.town_buildings[&"stone_pit"] = 1


## The Divided continent: each ruler's capital gets the provinces nearest it (land neighbours of
## his realm first) in turn, never one bordering the player's start, until the rulers hold
## RULERS_SHARE of the world; their towns are ready (RULER_TOWN).
static func _realms(data: DataRegistry, defs: Array[ProvinceDef], taken: Array[ProvinceDef], player: ProvinceDef,
		rulers: int) -> void:
	if rulers <= 0:
		return
	var each := clampi(roundi(defs.size() * RULERS_SHARE / rulers), 2, MAX_REALM)
	var realms: Array[Array] = []
	for d: ProvinceDef in taken:
		if d != player:
			realms.append([d])
	for _r: int in each - 1:
		for realm: Array in realms:
			var capital: ProvinceDef = realm[0]
			var best: ProvinceDef = null
			var best_d := INF
			for d: ProvinceDef in defs:
				if d.owner != ProvinceDef.OWNER_NONE or d == player or player.neighbours.has(d.id) \
						or d.neighbours.has(player.id):
					continue
				var touches := false
				for r: ProvinceDef in realm:
					if r.neighbours.has(d.id) or d.neighbours.has(r.id):
						touches = true
						break
				var gap := d.world_pos.distance_to(capital.world_pos) + (0.0 if touches else 10000.0)
				if gap < best_d:
					best_d = gap
					best = d
			if best == null:
				continue
			best.owner = capital.owner
			best.town_buildings = RULER_TOWN.duplicate()
			best.town_burghers = 3
			realm.append(best)
			taken.append(best)


## The Merchant islands: islands of 1 to 3 provinces on a sea cell touching no other land and
## not the edge of the parchment, spread over it (away from each other).
## Marks [param is_land] and the island of each cell in [param group_of].
static func _archipelago(sites: Array[Vector2], cells: Array[PackedVector2Array], adjacent: Array[Array],
		is_land: Array[bool], group_of: Dictionary[int, int], count: int, size: Vector2, step: float,
		rng: RandomNumberGenerator) -> void:
	var left := count
	var island := 0
	while left > 0:
		var want := mini(rng.randi_range(1, 3), left)
		var best := -1
		var best_d := -INF
		for i: int in sites.size():
			if is_land[i] or _touches_edge(cells[i], size) or not _lonely(i, adjacent, is_land, group_of, -1):
				continue
			var d := INF
			for j: int in group_of:
				d = minf(d, sites[i].distance_to(sites[j]))
			var middle := ((sites[i] - size * 0.5) / (size * 0.5)).length()
			d = minf(d, step * 2.5) + rng.randf() * step - middle * step * 0.6
			if d > best_d:
				best_d = d
				best = i
		if best < 0:
			# No room left for a lonely island: the rest join the smallest islands there are.
			while left > 0:
				var pick := -1
				var pick_size := 1 << 20
				for i: int in sites.size():
					if is_land[i] or _touches_edge(cells[i], size):
						continue
					for j: int in adjacent[i]:
						if is_land[j] and _lonely(i, adjacent, is_land, group_of, group_of[j]):
							var n := group_of.values().count(group_of[j])
							if n < pick_size:
								pick_size = n
								pick = i
								group_of[-1] = group_of[j]   # (the island it would join)
				if pick < 0:
					break
				is_land[pick] = true
				group_of[pick] = group_of[-1]
				group_of.erase(-1)
				left -= 1
			group_of.erase(-1)
			break
		is_land[best] = true
		group_of[best] = island
		left -= 1
		var members: Array[int] = [best]
		while members.size() < want and left > 0:
			var grown := false
			for m: int in members.duplicate():
				for j: int in adjacent[m]:
					if members.size() >= want or is_land[j] or _touches_edge(cells[j], size) \
							or not _lonely(j, adjacent, is_land, group_of, island):
						continue
					is_land[j] = true
					group_of[j] = island
					members.append(j)
					left -= 1
					grown = true
			if not grown:
				break
		island += 1


## Whether cell [param i] touches no land but that of island [param island].
static func _lonely(i: int, adjacent: Array[Array], is_land: Array[bool], group_of: Dictionary[int, int],
		island: int) -> bool:
	for j: int in adjacent[i]:
		if is_land[j] and int(group_of.get(j, -2)) != island:
			return false
	return true


## The province among [param defs] (free, passing [param ok]) farthest from all of [param taken];
## the distance to [param first] counts RULER_AWAY times less (keeps rulers away from him).
static func _farthest_def(defs: Array[ProvinceDef], taken: Array[ProvinceDef], ok: Callable,
		first: ProvinceDef = null) -> ProvinceDef:
	var best: ProvinceDef = null
	var best_d := -1.0
	for d: ProvinceDef in defs:
		if taken.has(d) or d.owner != ProvinceDef.OWNER_NONE or not ok.call(d):
			continue
		var far := INF
		for t: ProvinceDef in taken:
			var gap := d.world_pos.distance_to(t.world_pos)
			far = minf(far, gap / RULER_AWAY if t == first else gap)
		if far > best_d:
			best_d = far
			best = d
	return best


## The cell of site [param i] (the part of the parchment nearer to it than to any other
## site) and the sites whose cells share a border with it: [polygon, neighbour indices].
static func _cell(sites: Array[Vector2], i: int, size: Vector2) -> Array:
	var me := sites[i]
	var near: Array[int] = []
	for j: int in sites.size():
		if j != i:
			near.append(j)
	near.sort_custom(func(a: int, b: int) -> bool:
		return sites[a].distance_squared_to(me) < sites[b].distance_squared_to(me))
	near.resize(mini(NEAREST, near.size()))
	var poly := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
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


static func _touches_edge(poly: PackedVector2Array, size: Vector2) -> bool:
	for p: Vector2 in poly:
		if p.x < 1.0 or p.y < 1.0 or p.x > size.x - 1.0 or p.y > size.y - 1.0:
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


static func _shuffle(list: Array[int], rng: RandomNumberGenerator) -> void:
	for k: int in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var t := list[k]
		list[k] = list[j]
		list[j] = t
