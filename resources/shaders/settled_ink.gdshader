shader_type canvas_item;
// Settled ink in Watermark Marsh: near-black and still, deepening with depth, with an
// oily blue-violet sheen sliding slowly over the top and a few pale paper fibres
// drifting in it. `rect_size` is the pool's size in px; `surface` draws the skin.

uniform vec2 rect_size = vec2(128.0, 128.0);
uniform bool surface = true;
uniform vec4 deep : source_color = vec4(0.012, 0.012, 0.022, 0.97);
uniform vec4 shallow : source_color = vec4(0.05, 0.055, 0.085, 0.95);
uniform vec4 sheen : source_color = vec4(0.42, 0.46, 0.7, 1.0);

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 px = UV * rect_size;
	float depth = surface ? clamp(px.y / 220.0, 0.0, 1.0) : 1.0;
	vec4 col = mix(shallow, deep, depth);
	// slow oily bands, strongest just under the skin
	float n = noise(world * vec2(0.006, 0.02) + vec2(TIME * 0.05, 0.0));
	float n2 = noise(world * vec2(0.013, 0.04) - vec2(TIME * 0.03, TIME * 0.01));
	float band = smoothstep(0.55, 0.85, n * 0.6 + n2 * 0.5);
	col.rgb += sheen.rgb * band * 0.3 * (1.0 - depth * 0.6);
	// a few pale fibres hanging in it
	vec2 cell = floor(world / 46.0);
	float fibre = step(0.97, hash(cell));
	vec2 local = fract(world / 46.0) - 0.5;
	local.y += sin(TIME * 0.4 + hash(cell + 3.0) * 6.28) * 0.15;
	float speck = fibre * smoothstep(0.08, 0.0, abs(local.y + local.x * 0.4)) * smoothstep(0.32, 0.1, abs(local.x));
	col.rgb += vec3(0.6, 0.57, 0.5) * speck * 0.55;
	if (surface) {
		// the skin: a thin cold highlight, gently rippling, and a darker meniscus below
		float ripple = sin(world.x * 0.045 + TIME * 0.9) * 1.6 + sin(world.x * 0.11 - TIME * 1.3) * 0.8;
		float line = smoothstep(2.4, 0.0, abs(px.y - 3.0 - ripple));
		float glow = smoothstep(26.0, 0.0, px.y) * 0.5;
		float glint = smoothstep(0.7, 0.95, noise(vec2(world.x * 0.02 + TIME * 0.2, 0.0)));
		col.rgb += sheen.rgb * (line * (0.35 + glint * 0.5) + glow * 0.12);
		col.a *= smoothstep(-1.0, 2.0, px.y - ripple * 0.5);
	}
	COLOR = col;
}
