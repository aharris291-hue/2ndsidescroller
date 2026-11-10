shader_type canvas_item;
// Reprints Patch's painting on another paper (Papers): the paint's light and shade
// are kept, and recoloured between a dark and a light ink. Strong reds (his stitches)
// keep some of their own colour. `marble` swirls a second tone through it, like the
// marbled endpapers of an old book.

uniform vec4 dark : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 light : source_color = vec4(1.0);
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float keep_red : hint_range(0.0, 1.0) = 0.6;
uniform float marble : hint_range(0.0, 1.0) = 0.0;
uniform vec4 marble_color : source_color = vec4(0.5, 0.2, 0.2, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 inked = mix(dark.rgb, light.rgb, smoothstep(0.02, 0.85, lum));
	if (marble > 0.0) {
		vec2 p = UV * 9.0;
		float w = sin(p.x * 1.7 + sin(p.y * 2.3 + sin(p.x * 3.1)) * 2.2);
		inked = mix(inked, marble_color.rgb * (0.4 + lum), marble * smoothstep(0.35, 0.9, w));
	}
	float red = clamp((c.r - max(c.g, c.b)) * 3.0, 0.0, 1.0) * keep_red;
	vec3 outc = mix(c.rgb, inked, amount * (1.0 - red));
	COLOR = vec4(outc, c.a);
}
