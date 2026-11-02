shader_type canvas_item;
// Screen overlay for the Dark Rebuild: drifting low fog, a heavy vignette and film grain.

uniform float drift = 0.02;
uniform vec4 fog_color : source_color = vec4(0.42, 0.48, 0.58, 1.0);
uniform float fog_amount = 0.32;
uniform float vignette = 0.6;
// Detail: fog noise layers (2 is much cheaper on older GPUs) and film grain strength.
uniform int octaves : hint_range(1, 5) = 5;
uniform float grain_amount = 0.05;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		if (i >= octaves) {
			break;
		}
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * drift;
	float n = fbm(vec2(uv.x * 3.0 + t * 4.0, uv.y * 2.2 + t));
	float low = smoothstep(0.3, 1.0, uv.y);
	float fog = n * (0.3 + 0.7 * low) * fog_amount;
	vec2 d = uv - 0.5;
	float vig = smoothstep(0.3, 0.85, length(d * vec2(1.05, 1.0)));
	float grain = (hash(uv * vec2(1920.0, 1080.0) + fract(TIME) * 91.0) - 0.5) * grain_amount;
	vec3 col = mix(fog_color.rgb, vec3(0.0), clamp(vig * 1.2, 0.0, 1.0)) + grain;
	COLOR = vec4(col, clamp(fog + vig * vignette, 0.0, 0.92));
}
