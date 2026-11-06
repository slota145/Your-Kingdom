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
uniform sampler2D stony_tex : filter_nearest;
uniform sampler2D stony_alt_tex : filter_nearest;
uniform sampler2D lake_tex : filter_nearest;
uniform sampler2D lake_alt_tex : filter_nearest;
uniform sampler2D paving_tex : filter_nearest;
uniform sampler2D paving_alt_tex : filter_nearest;

// How far (in tiles) borders wander from the tile edges.
uniform float border_warp = 0.32;
uniform float road_warp = 0.22;
uniform bool organic = true;
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
	// A paved tile among dirt ones: cobbles where paving outweighs dirt within the road.
	return vec3(round(best_slot * 255.0), road > 0.5 ? 1.0 : 0.0, paved > 0.5 * road ? 1.0 : 0.0);
}

int slot_at(vec2 grid) {
	return int(smooth_sample(grid).x);
}

bool is_water(int slot) {
	return slot == WATER || slot == FORD || slot == SEA || slot == LAKE;
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

// Two variants of one texture swapped in soft dithered patches, so the 64x32 pattern does not
// repeat in a visible lattice.
vec3 mixed(sampler2D a, sampler2D b, vec2 grid, vec2 pixel, float seed) {
	vec2 squashed = vec2(pixel.x * 0.5, pixel.y);
	float t = smoothstep(0.42, 0.58, fbm(squashed / 30.0 + seed));
	return t > bayer4(pixel) ? sample_diamond(b, grid).rgb : sample_diamond(a, grid).rgb;
}

vec3 ground_colour(int slot, vec2 grid, vec2 pixel) {
	if (slot == MEADOW) return sample_diamond(meadow_tex, grid).rgb;
	if (slot == FOREST) return sample_diamond(forest_tex, grid).rgb;
	if (slot == WATER) return mixed(water_tex, water_alt_tex, grid, pixel, 5.3);
	if (slot == FORD) return sample_diamond(ford_tex, grid).rgb;
	if (slot == SEA) return mixed(sea_tex, sea_alt_tex, grid, pixel, 9.1);
	if (slot == SAND) return sample_diamond(sand_tex, grid).rgb;
	if (slot == STONY) return mixed(stony_tex, stony_alt_tex, grid, pixel, 31.7);
	if (slot == LAKE) return mixed(lake_tex, lake_alt_tex, grid, pixel, 17.3);
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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 pixel = floor(world_pos) + 0.5;
	vec2 grid = screen_to_grid(pixel);
	vec2 warped = grid;
	vec2 road_grid = grid;
	if (organic) {
		vec2 warp = vec2(fbm(grid * 0.9 + 3.7), fbm(grid * 0.9 + 21.4)) - 0.5;
		warped = grid + warp * 2.0 * border_warp;
		road_grid = grid + warp * 2.0 * road_warp;
	}
	vec3 here = organic ? smooth_sample(warped) : texel(floor(grid)) * vec3(255.0, 1.0, 1.0);
	int slot = int(round(here.x));
	float t = animated ? TIME : 0.0;
	// Water textures slide under a fixed shoreline.
	vec2 flow = vec2(0.0);
	if (slot == WATER) flow = floor(river_flow * t);
	else if (slot == FORD) flow = floor(river_flow * 0.5 * t);
	else if (slot == SEA) flow = floor(sea_drift * t);
	else if (slot == LAKE) flow = floor(lake_drift * t);
	vec2 moved_pixel = pixel - flow;
	vec2 moved_grid = screen_to_grid(moved_pixel);
	vec3 colour = ground_colour(slot, moved_grid, moved_pixel);
	if (organic) {
		if (is_water(slot)) {
			if (slot == SEA) {
				// Shallows along the shore, a dithered step towards deep water, surf on the sand.
				if (land_near(warped, 0.9)) {
					colour = sample_diamond(shallow_tex, moved_grid).rgb;
				} else if (land_near(warped, 1.5) && bayer4(pixel) < 0.5) {
					colour = sample_diamond(shallow_tex, moved_grid).rgb;
				}
				// Surf: the foam line runs up the sand and back, out of step along the coast.
				float wave = 0.5 + 0.5 * sin(t * 1.2 + fbm(grid * 0.6) * 6.283);
				if (land_near(warped, 0.05 + 0.13 * wave)) colour = mix(colour, vec3(0.92, 0.95, 0.9), 0.55);
			} else if (land_near(warped, 0.07)) {
				// Dark line where river water meets the bank, as if the bank threw a shadow.
				colour *= 0.78;
			}
			// Glints: single bright pixels that flicker on and off.
			vec2 cell = floor(pixel / vec2(2.0, 1.0));
			if (hash(cell + floor(t * 1.5) * vec2(7.13, 3.71)) > 0.9965) {
				colour = mix(colour, vec3(0.95, 0.98, 1.0), 0.7);
			}
		} else if (slot != SAND && water_near(warped, 0.2)) {
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
