// Glitter on the open sea of the main menu picture (ROADMAP UI-1): the texture is the sea mask
// (white = sea); on the sea, a few art pixels light up and fade in slow moving rows.
shader_type canvas_item;

uniform float speed = 1.0;

void fragment() {
	float sea = texture(TEXTURE, UV).a;
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
	float wave = sin(px.x * 0.31 + px.y * 1.9 - TIME * 1.4 * speed)
			* sin(px.x * 0.07 + TIME * 0.6 * speed + px.y * 0.43);
	float glint = step(0.9, wave);
	float soft = smoothstep(0.6, 0.9, wave) * 0.1;
	COLOR = vec4(1.0, 1.0, 0.96, sea * (glint * 0.45 + soft));
}
