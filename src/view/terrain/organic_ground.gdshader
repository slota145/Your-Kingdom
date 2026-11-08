shader_type canvas_item;
// Organic ground (ART_SPEC §8.1). Every tile only rasterises its diamond; the colour of each
// pixel comes from here. The terrain of a pixel is read from map_tex at a noise-warped grid
// position, so borders between terrains (and road edges) are round and irregular instead
// of following the tile diamonds. Textures are 64x32 diamonds sampled periodically in world
// space, so neighbouring tiles never show a seam. Rendering only: the simulation still sees
// whole tiles.

// map_tex: one texel per tile. R = art slot (TerrainLayer.Slot) / 255, G = road (1.0),
// B = paved road (1.0, M4b-3).
uniform sampler2D map_tex : filter_nearest, repeat_disable;
uniform vec2 map_size = vec2(64.0, 64.0);

uniform sampler2D grass_tex : filter_nearest;
uniform sampler2D grass_light_tex : filter_nearest;
uniform sampler2D grass_dark_tex : filter_nearest;
uniform sampler2D meadow_tex : filter_nearest;
uniform sampler2D forest_tex : filter_nearest;
uniform sampler2D water_tex : filter_nearest;
uniform sampler2D water_alt_tex : filter_nearest;
uniform sampler2D ford_tex : filter_nearest;
uniform sampler2D sea_tex : filter_nearest;
uniform sampler2D sea_alt_tex : filter_nearest;
uniform sampler2D shallow_tex : filter_nearest;
uniform sampler2D sand_tex : filter_nearest;
uniform sampler2D bank_tex : filter_nearest;
uniform sampler2D road_tex : filter_nearest;
uniform sampler2D road_alt_tex : filter_nearest;
// Review fixes 2026-11-07: lake and stony ground repeat only every 4x4 tiles (256x128
// pictures of a 4x4 tile diamond, tools/generate_terrain_variants.py), 3 variants each.
uniform sampler2D stony_a_tex : filter_nearest;
uniform sampler2D stony_b_tex : filter_nearest;
uniform sampler2D stony_c_tex : filter_nearest;
// Rocks over the stony soil: two transparent layers repeating every 5 and 7 tiles.
uniform sampler2D rocks_a_tex : filter_nearest;
uniform sampler2D rocks_b_tex : filter_nearest;
uniform sampler2D lake_a_tex : filter_nearest;
uniform sampler2D lake_b_tex : filter_nearest;
uniform sampler2D lake_c_tex : filter_nearest;
uniform sampler2D paving_tex : filter_nearest;
uniform sampler2D paving_alt_tex : filter_nearest;
uniform sampler2D vine_tex : filter_nearest;

// How far (in tiles) borders wander from the tile edges.
uniform float border_warp = 0.32;
uniform float road_warp = 0.22;
uniform bool organic = true;
// Soft shoreline (B1 part 2); off: the shore follows the tiles as before.
uniform bool soft_shore = true;
// How far (0-0.5, Chebyshev, in tiles) the middle of a tile keeps its own terrain whatever
// the soft shoreline says, so a land tile never looks like water under people and buildings.
uniform float shore_core = 0.14;
// How far (in tiles) the shoreline wanders from its smooth line (border_warp for the rest).
uniform float shore_warp = 0.12;
// Water flows (texture drift in whole pixels, so it stays crisp), glitters and laps the beach.
uniform bool animated = true;
uniform vec2 river_flow = vec2(7.0, 3.5);  // px per second
uniform vec2 sea_drift = vec2(-4.0, 2.0);
uniform vec2 lake_drift = vec2(-1.5, 0.75);

const int GRASS = 0;
const int MEADOW = 1;
const int FOREST = 2;
const int WATER = 3;
const int FORD = 4;
const int SEA = 5;
const int SAND = 6;
const int STONY = 7;
const int LAKE = 8;
// Shallow sea (M5): boats sail here, cogs do not. Deep sea is SEA.
const int SHALLOW = 9;
const int VINE = 10;

varying vec2 world_pos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

const mat2 ROT_A = mat2(vec2(0.866, 0.5), vec2(-0.5, 0.866));
const mat2 ROT_B = mat2(vec2(0.6, -0.8), vec2(0.8, 0.6));

// Smooth 0..1 noise; the lattice is rotated so its axes never line up with the screen.
float fbm(vec2 q) {
	q = ROT_A * q;
	float n = value_noise(q) * 0.6;
	q = ROT_B * q * 2.1 + 17.0;
	n += value_noise(q) * 0.28;
	q = ROT_A * q * 2.3 + 5.0;
	return n + value_noise(q) * 0.12;
}

// Integer hash for per-pixel randomness (glints): no stripes far from the origin.
float hash_cell(vec2 cell) {
	uvec2 q = uvec2(ivec2(cell) + ivec2(65536));
	uint h = q.x * 1597334677u ^ q.y * 3812015801u;
	h = (h ^ (h >> 16u)) * 2246822519u;
	h ^= h >> 13u;
	return float(h & 16777215u) / 16777216.0;
}

float bayer4(vec2 pixel) {
	int x = int(mod(pixel.x, 4.0));
	int y = int(mod(pixel.y, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[x + y * 4]) + 0.5) / 16.0;
}

vec2 screen_to_grid(vec2 s) {
	return vec2(s.x / 32.0 + s.y / 16.0, s.y / 16.0 - s.x / 32.0) * 0.5;
}

vec2 grid_to_screen(vec2 g) {
	return vec2((g.x - g.y) * 32.0, (g.x + g.y) * 16.0);
}

vec3 texel(vec2 tile) {
	tile = clamp(tile, vec2(0.0), map_size - 1.0);
	return texture(map_tex, (tile + 0.5) / map_size).rgb;
}

bool slot_is_water(float raw) {
	int s = int(round(raw * 255.0));
	return s == WATER || s == FORD || s == SEA || s == LAKE || s == SHALLOW;
}

// Cubic B-spline weights of the 4 tile centres around a point (f = fraction past the second).
vec4 bspline(float f) {
	float f2 = f * f;
	float f3 = f2 * f;
	return vec4((1.0 - f) * (1.0 - f) * (1.0 - f), 3.0 * f3 - 6.0 * f2 + 4.0,
			-3.0 * f3 + 3.0 * f2 + 3.0 * f + 1.0, f3) / 6.0;
}

// How much water there is around a grid point (0-1), the water tiles blurred with a cubic
// B-spline over the 4x4 nearest tile centres (B1 part 2): its 0.5 line is a smooth shoreline,
// a staircase of tiles becomes a gentle slant and corners round off.
float kind_field(vec2 grid, bool deep) {
	vec2 p = grid - 0.5;
	vec2 base = floor(p) - 1.0;
	vec2 f = fract(p);
	vec4 wx = bspline(f.x);
	vec4 wy = bspline(f.y);
	float sum = 0.0;
	for (int j = 0; j < 4; j++) {
		for (int i = 0; i < 4; i++) {
			float raw = texel(base + vec2(float(i), float(j))).r;
			bool hit = deep ? int(round(raw * 255.0)) == SEA : slot_is_water(raw);
			if (hit) sum += wx[i] * wy[j];
		}
	}
	return sum;
}

float water_field(vec2 grid) {
	return kind_field(grid, false);
}

// The same blur for deep sea among the shallows, so the line where the water darkens is
// smooth too.
float deep_field(vec2 grid) {
	return kind_field(grid, true);
}


// Terrain at a grid point, smoothed between the 4 nearest tile centres: each slot gets the
// bilinear weight of the centres holding it and the heaviest wins. A diagonal staircase of
// tiles becomes a straight edge and square corners become round. .x = slot, .y = road (0/1),
// .z = paved (0/1).
vec3 smooth_sample(vec2 grid) {
	vec2 p = grid - 0.5;
	vec2 base = floor(p);
	vec2 f = fract(p);
	vec3 t00 = texel(base);
	vec3 t10 = texel(base + vec2(1.0, 0.0));
	vec3 t01 = texel(base + vec2(0.0, 1.0));
	vec3 t11 = texel(base + vec2(1.0, 1.0));
	float w00 = (1.0 - f.x) * (1.0 - f.y);
	float w10 = f.x * (1.0 - f.y);
	float w01 = (1.0 - f.x) * f.y;
	float w11 = f.x * f.y;
	float road = t00.g * w00 + t10.g * w10 + t01.g * w01 + t11.g * w11;
	float paved = t00.b * w00 + t10.b * w10 + t01.b * w01 + t11.b * w11;
	float slots[4] = float[](t00.r, t10.r, t01.r, t11.r);
	float weights[4] = float[](w00, w10, w01, w11);
	float best_slot = t00.r;
	float best_weight = -1.0;
	for (int i = 0; i < 4; i++) {
		float total = 0.0;
		for (int j = 0; j < 4; j++) {
			if (abs(slots[j] - slots[i]) < 0.002) total += weights[j];
		}
		if (total > best_weight) {
			best_weight = total;
			best_slot = slots[i];
		}
	}
	// Soft shoreline (B1 part 2): where water meets land, the blurred water decides which side
	// a point is on (outside the middle of each tile), so the shore runs smooth and round.
	bool mixed = false;
	bool any_water = false;
	bool any_land = false;
	for (int i = 0; i < 4; i++) {
		if (slot_is_water(slots[i])) any_water = true; else any_land = true;
	}
	mixed = any_water && any_land;
	bool core = max(abs(fract(grid).x - 0.5), abs(fract(grid).y - 0.5)) < shore_core;
	if (!mixed && soft_shore && !core) {
		// Deep sea and shallows: the darker water follows a smooth line as well.
		bool any_deep = false;
		bool any_shallow = false;
		for (int i = 0; i < 4; i++) {
			int k = int(round(slots[i] * 255.0));
			if (k == SEA) any_deep = true;
			if (k == SHALLOW) any_shallow = true;
		}
		if (any_deep && any_shallow) {
			float want = deep_field(grid) > 0.5 ? float(SEA) : float(SHALLOW);
			if (abs(round(best_slot * 255.0) - want) > 0.5) best_slot = want / 255.0;
		}
	}
	if (mixed && soft_shore) {
		vec2 own = fract(grid) - 0.5;
		bool water_here;
		if (max(abs(own.x), abs(own.y)) < shore_core) {
			water_here = slot_is_water(texel(floor(grid)).r);
		} else {
			water_here = water_field(grid) > 0.5;
		}
		if (water_here != slot_is_water(best_slot)) {
			float pick = -1.0;
			for (int i = 0; i < 4; i++) {
				if (slot_is_water(slots[i]) == water_here && weights[i] > pick) {
					pick = weights[i];
					best_slot = slots[i];
				}
			}
		}
	}
	// A paved tile among dirt ones: cobbles where paving outweighs dirt within the road.
	return vec3(round(best_slot * 255.0), road > 0.5 ? 1.0 : 0.0, paved > 0.5 * road ? 1.0 : 0.0);
}

int slot_at(vec2 grid) {
	return int(smooth_sample(grid).x);
}

bool is_water(int slot) {
	return slot == WATER || slot == FORD || slot == SEA || slot == LAKE || slot == SHALLOW;
}

const vec2 RING[4] = vec2[](vec2(0.707, 0.707), vec2(-0.707, 0.707), vec2(0.707, -0.707), vec2(-0.707, -0.707));

// Any of 4 samples on a ring of radius r (tiles) around grid on water / on land / off road.
bool water_near(vec2 grid, float r) {
	for (int i = 0; i < 4; i++) {
		if (is_water(slot_at(grid + RING[i] * r))) return true;
	}
	return false;
}

bool land_near(vec2 grid, float r) {
	for (int i = 0; i < 4; i++) {
		if (!is_water(slot_at(grid + RING[i] * r))) return true;
	}
	return false;
}

bool shallow_near(vec2 grid, float r) {
	for (int i = 0; i < 4; i++) {
		if (slot_at(grid + RING[i] * r) == SHALLOW) return true;
	}
	return false;
}

bool off_road_near(vec2 grid, float r) {
	for (int i = 0; i < 4; i++) {
		if (smooth_sample(grid + RING[i] * r).y < 0.5) return true;
	}
	return false;
}

// Periodic lookup: any world pixel maps to the same spot of a 64x32 diamond texture.
vec4 sample_diamond(sampler2D tex, vec2 grid) {
	vec2 local = grid_to_screen(fract(grid)) + vec2(32.0, 0.0);
	return texture(tex, (floor(local) + 0.5) / vec2(64.0, 32.0));
}

// Periodic lookup of a big texture: a picture of a period x period tile diamond, so the
// pattern repeats only every period tiles. Placeholders may be smaller (scaled to fit).
const float BIG = 4.0;

vec4 sample_periodic(sampler2D tex, vec2 grid, float period) {
	vec2 local = grid_to_screen(fract(grid / period) * period) + vec2(32.0 * period, 0.0);
	vec2 size = vec2(textureSize(tex, 0));
	vec2 texel = floor(local * size / vec2(64.0 * period, 32.0 * period));
	return texture(tex, (clamp(texel, vec2(0.0), size - 1.0) + 0.5) / size);
}

vec4 sample_big(sampler2D tex, vec2 grid) {
	return sample_periodic(tex, grid, BIG);
}

// Three big variants swapped in soft dithered patches of two independent noises.
vec3 mixed3(sampler2D a, sampler2D b, sampler2D c, vec2 grid, vec2 pixel, float seed) {
	vec2 squashed = vec2(pixel.x * 0.5, pixel.y);
	float threshold = bayer4(pixel);
	if (smoothstep(0.44, 0.56, fbm(squashed / 70.0 + seed)) > threshold) {
		return sample_big(c, grid).rgb;
	}
	if (smoothstep(0.44, 0.56, fbm(squashed / 45.0 + seed * 1.7 + 13.0)) > threshold) {
		return sample_big(b, grid).rgb;
	}
	return sample_big(a, grid).rgb;
}

// Two variants of one texture swapped in soft dithered patches, so the 64x32 pattern does not
// repeat in a visible lattice.
vec3 mixed(sampler2D a, sampler2D b, vec2 grid, vec2 pixel, float seed) {
	vec2 squashed = vec2(pixel.x * 0.5, pixel.y);
	float t = smoothstep(0.42, 0.58, fbm(squashed / 30.0 + seed));
	return t > bayer4(pixel) ? sample_diamond(b, grid).rgb : sample_diamond(a, grid).rgb;
}

vec3 ground_colour(int slot, vec2 grid, vec2 pixel) {
	if (slot == MEADOW) return sample_diamond(meadow_tex, grid).rgb;
	if (slot == VINE) return sample_diamond(vine_tex, grid).rgb;
	if (slot == FOREST) return sample_diamond(forest_tex, grid).rgb;
	if (slot == WATER) return mixed(water_tex, water_alt_tex, grid, pixel, 5.3);
	if (slot == FORD) return sample_diamond(ford_tex, grid).rgb;
	if (slot == SEA) return mixed(sea_tex, sea_alt_tex, grid, pixel, 9.1);
	if (slot == SAND) return sample_diamond(sand_tex, grid).rgb;
	if (slot == SHALLOW) return mixed(shallow_tex, sea_tex, grid, pixel, 4.7) * 0.15 + sample_diamond(shallow_tex, grid).rgb * 0.85;
	if (slot == STONY) {
		vec3 soil = mixed3(stony_a_tex, stony_b_tex, stony_c_tex, grid, pixel, 31.7);
		vec4 rock = sample_periodic(rocks_b_tex, grid + vec2(2.3, 0.6), 7.0);
		if (rock.a < 0.5) rock = sample_periodic(rocks_a_tex, grid, 5.0);
		return rock.a > 0.5 ? rock.rgb : soil;
	}
	if (slot == LAKE) return mixed3(lake_a_tex, lake_b_tex, lake_c_tex, grid, pixel, 17.3);
	// Grass: lighter and darker patches with dithered edges.
	vec3 colour = sample_diamond(grass_tex, grid).rgb;
	float threshold = bayer4(pixel);
	vec2 squashed = vec2(pixel.x * 0.5, pixel.y);
	float light = smoothstep(0.47, 0.59, fbm(squashed / 40.0 + vec2(3.1, 7.7)));
	float dark = smoothstep(0.62, 0.72, fbm(squashed / 52.0 + vec2(41.3, 11.9)));
	if (light > threshold) colour = sample_diamond(grass_light_tex, grid).rgb;
	if (dark > threshold) colour = sample_diamond(grass_dark_tex, grid).rgb;
	return colour;
}

// Texture drift of a water slot: whole pixels, so the water stays crisp.
vec2 water_flow(int slot, float t) {
	if (slot == WATER) return floor(river_flow * t);
	if (slot == FORD) return floor(river_flow * 0.5 * t);
	if (slot == SEA || slot == SHALLOW) return floor(sea_drift * t);
	if (slot == LAKE) return floor(lake_drift * t);
	return vec2(0.0);
}

// Kind of water: 0 river (and ford), 1 lake, 2 sea; -1 land.
int water_kind(int slot) {
	if (slot == WATER || slot == FORD) return 0;
	if (slot == LAKE) return 1;
	if (slot == SEA || slot == SHALLOW) return 2;
	return -1;
}

const vec2 RING8[8] = vec2[](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
		vec2(0.707, 0.707), vec2(-0.707, 0.707), vec2(0.707, -0.707), vec2(-0.707, -0.707));

// Mixes in the other kind of water near a river mouth: samples on two rings (0.7 and 1.5 tiles)
// give the share of the other water around this pixel, and that share of pixels (ordered
// dither, nudged by noise so the band is uneven) shows the other water, with its own drift.
vec3 water_meeting(int slot, vec2 grid, vec2 pixel, float t, vec3 colour) {
	int kind = water_kind(slot);
	// Cheap test first: raw tiles 2 apart around here; most water is far from a mouth.
	bool mouth = false;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			int k = water_kind(int(round(texel(floor(grid) + vec2(float(dx), float(dy)) * 2.0).r * 255.0)));
			if (k >= 0 && k != kind) mouth = true;
		}
	}
	if (!mouth) return colour;
	int other_slot = -1;
	float other = 0.0;
	for (int i = 0; i < 8; i++) {
		for (int r = 0; r < 2; r++) {
			int s = slot_at(grid + RING8[i] * (r == 0 ? 0.7 : 1.5));
			int k = water_kind(s);
			if (k >= 0 && k != kind) {
				other += r == 0 ? 1.0 : 0.6;
				other_slot = s;
			}
		}
	}
	if (other_slot < 0) return colour;
	float share = other / (8.0 * 1.6 + 1.0) * 1.1 + (fbm(grid * 1.3 + 7.1) - 0.5) * 0.35;
	if (share <= bayer4(pixel)) return colour;
	vec2 moved = pixel - water_flow(other_slot, t);
	if (water_kind(other_slot) == 2) {
		// The sea at a river mouth is shallow.
		return sample_diamond(shallow_tex, screen_to_grid(moved)).rgb;
	}
	return ground_colour(other_slot, screen_to_grid(moved), moved);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 pixel = floor(world_pos) + 0.5;
	vec2 grid = screen_to_grid(pixel);
	vec2 warped = grid;
	vec2 shore = grid;
	vec2 road_grid = grid;
	if (organic) {
		vec2 warp = vec2(fbm(grid * 0.9 + 3.7), fbm(grid * 0.9 + 21.4)) - 0.5;
		warped = grid + warp * 2.0 * border_warp;
		// The shoreline wanders less (B1 part 2): gentle bends instead of a jagged edge.
		shore = grid + warp * 2.0 * (soft_shore ? shore_warp : border_warp);
		road_grid = grid + warp * 2.0 * road_warp;
	}
	vec3 here = organic ? smooth_sample(warped) : texel(floor(grid)) * vec3(255.0, 1.0, 1.0);
	if (organic && soft_shore) {
		// Water or land, and deep or shallow sea, as the gently warped shoreline says.
		vec3 by_shore = smooth_sample(shore);
		int a = int(here.x);
		int b = int(by_shore.x);
		if (is_water(a) != is_water(b) || (is_water(a) && is_water(b) && a != b)) here.x = by_shore.x;
	}
	int slot = int(round(here.x));
	float t = animated ? TIME : 0.0;
	// Water textures slide under a fixed shoreline.
	vec2 moved_pixel = pixel - water_flow(slot, t);
	vec2 moved_grid = screen_to_grid(moved_pixel);
	vec3 colour = ground_colour(slot, moved_grid, moved_pixel);
	if (organic) {
		if (is_water(slot)) {
			if (slot == SEA || slot == SHALLOW) {
				// Shallows along the shore, a dithered step towards deep water, surf on the sand.
				// Shallow sea tiles (M5) are shallow water whatever is near; deep sea next to
				// them steps down in a dithered band.
				if (slot == SHALLOW || land_near(shore, 0.9)) {
					colour = sample_diamond(shallow_tex, moved_grid).rgb;
				} else if ((land_near(shore, 1.5) || shallow_near(shore, 0.6)) && bayer4(pixel) < 0.5) {
					colour = sample_diamond(shallow_tex, moved_grid).rgb;
				}
				// Surf: the foam line runs up the sand and back, out of step along the coast.
				float wave = 0.5 + 0.5 * sin(t * 1.2 + fbm(grid * 0.6) * 6.283);
				if (land_near(shore, 0.05 + 0.13 * wave)) colour = mix(colour, vec3(0.92, 0.95, 0.9), 0.55);
			} else if (land_near(shore, 0.07)) {
				// Dark line where river water meets the bank, as if the bank threw a shadow.
				colour *= 0.78;
			}
			// Where a river runs into a lake or the sea, the two waters mix in a wide dithered
			// band instead of meeting on a sharp line (review fixes 2026-11-07).
			colour = water_meeting(slot, shore, pixel, t, colour);
			// Glints: single bright pixels that flicker on and off.
			vec2 cell = floor(pixel / vec2(2.0, 1.0));
			if (hash_cell(cell + floor(t * 1.5) * vec2(7.0, 3.0)) > 0.9965) {
				colour = mix(colour, vec3(0.95, 0.98, 1.0), 0.7);
			}
		} else if (slot != SAND && water_near(shore, 0.2)) {
			// Low earthen bank along rivers and lakes.
			colour = sample_diamond(bank_tex, grid).rgb;
		}
	}
	vec3 road_sample = organic ? smooth_sample(road_grid) : here;
	float road_here = road_sample.y;
	if (!is_water(slot) && road_here > 0.5) {
		vec3 road = road_sample.z > 0.5 ? mixed(paving_tex, paving_alt_tex, grid, pixel, 21.1)
				: mixed(road_tex, road_alt_tex, grid, pixel, 13.7);
		// Worn edge: road and ground mix in a dithered band.
		bool edge = organic && off_road_near(road_grid, 0.12);
		if (!edge || bayer4(pixel) < 0.5) colour = road;
	}
	COLOR = vec4(colour, texture(TEXTURE, UV).a);
}
