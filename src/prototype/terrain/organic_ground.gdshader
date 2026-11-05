shader_type canvas_item;
// ORGANIC GROUND PROTOTYPE: hides the tile grid. Every tile draws the same base texture;
// two world-space noise masks swap in a lighter and a darker texture in soft, round
// patches. The patch edges are ordered-dithered, so the result stays crisp pixel art.

uniform sampler2D light_tex : filter_nearest;
uniform sampler2D dark_tex : filter_nearest;
uniform float light_scale = 40.0;  // patch size in world px
uniform float dark_scale = 52.0;
uniform vec2 light_band = vec2(0.47, 0.59);  // noise range of the soft edge
uniform vec2 dark_band = vec2(0.59, 0.69);
uniform bool enabled = true;

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

// Ground is seen at 2:1, so patches are squashed like the tiles (x halved) and the noise
// lattice is rotated so its axes never line up with the screen. Three octaves keep the
// outlines irregular instead of blob-round.
const mat2 ROT_A = mat2(vec2(0.866, 0.5), vec2(-0.5, 0.866));
const mat2 ROT_B = mat2(vec2(0.6, -0.8), vec2(0.8, 0.6));

float patch_noise(vec2 p, float scale, vec2 seed) {
	vec2 q = ROT_A * vec2(p.x * 0.5, p.y) / scale + seed;
	float n = value_noise(q) * 0.6;
	q = ROT_B * q * 2.1 + 17.0;
	n += value_noise(q) * 0.28;
	q = ROT_A * q * 2.3 + 5.0;
	return n + value_noise(q) * 0.12;
}

float bayer4(vec2 pixel) {
	int x = int(mod(pixel.x, 4.0));
	int y = int(mod(pixel.y, 4.0));
	int index = x + y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[index]) + 0.5) / 16.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (enabled && base.a > 0.0) {
		vec2 pixel = floor(world_pos);
		float threshold = bayer4(pixel);
		float light = smoothstep(light_band.x, light_band.y, patch_noise(pixel, light_scale, vec2(3.1, 7.7)));
		float dark = smoothstep(dark_band.x, dark_band.y, patch_noise(pixel, dark_scale, vec2(41.3, 11.9)));
		if (light > threshold) {
			base.rgb = texture(light_tex, UV).rgb;
		}
		if (dark > threshold) {
			base.rgb = texture(dark_tex, UV).rgb;
		}
	}
	COLOR = base;
}
