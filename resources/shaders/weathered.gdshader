shader_type canvas_item;
// Dark rebuild: drains the colour out of the old bright storybook art (props, NPCs,
// bosses) so it sits in the drowned world until each piece is repainted.
uniform float desaturate : hint_range(0.0, 1.0) = 0.62;
uniform float darken : hint_range(0.0, 1.0) = 0.74;
uniform vec3 tint : source_color = vec3(0.9, 0.93, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(l), desaturate) * darken * tint;
	COLOR = c;
}
