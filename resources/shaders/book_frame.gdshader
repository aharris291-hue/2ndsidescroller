shader_type canvas_item;
// Draws the game as an open pop-up book lying on a desk.
// Everything rendered below this layer (the page) is warped onto the book's
// pages in perspective; around it we draw the book's cover, the edge of the
// page block, a soft shadow and the desk.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D desk_tex : source_color, filter_linear_mipmap;
// Maps a screen position (0-1) to a page position (0-1 inside the pages).
uniform mat3 to_page;
uniform float page_aspect = 1.7778;
uniform float thickness = 0.03;
uniform float cover_margin = 0.014;
uniform float border_width = 0.03;
uniform vec4 cover_color : source_color = vec4(0.86, 0.23, 0.45, 1.0);
uniform vec4 border_color : source_color = vec4(0.38, 0.78, 0.74, 1.0);
uniform vec4 pages_color : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform vec4 ink : source_color = vec4(0.16, 0.12, 0.18, 1.0);

vec2 page_uv(vec2 s) {
	vec3 p = to_page * vec3(s, 1.0);
	return p.xy / p.z;
}

// Signed distance (in page units) outside the page rectangle grown by m.
float outside(vec2 p, float m) {
	vec2 d = max(vec2(-m) - p, p - vec2(1.0 + m));
	return max(d.x, d.y);
}

void fragment() {
	vec2 s = SCREEN_UV;
	vec2 p = page_uv(s);
	vec3 col = texture(desk_tex, UV).rgb;

	// Soft shadow of the book on the desk, cast down and to the left.
	vec2 sp = page_uv(s + vec2(0.012, -0.04));
	float sd = outside(sp, cover_margin);
	col *= mix(0.5, 1.0, smoothstep(-0.01, 0.06, sd));

	float d_cover = outside(p, cover_margin);
	float aa = fwidth(d_cover) * 1.5;

	// The side of the book: page block on top, the cover underneath.
	if (d_cover > 0.0) {
		for (int k = 1; k <= 8; k++) {
			float t = float(k) / 8.0;
			vec2 q = page_uv(s - vec2(0.0, thickness * t));
			if (outside(q, cover_margin) <= 0.0) {
				bool pages = t < 0.65;
				vec3 side = pages ? pages_color.rgb * (0.82 + 0.12 * step(0.5, fract(t * 24.0))) : cover_color.rgb * 0.72;
				col = side;
				break;
			}
		}
	}

	// The cover's lip around the pages.
	if (d_cover <= 0.0) {
		col = cover_color.rgb;
	}
	float d_page = outside(p, 0.0);
	if (d_page <= 0.0) {
		col = texture(screen_tex, p).rgb;
		// Scalloped border printed around the edge of each page.
		vec2 e2 = min(p, 1.0 - p) * vec2(page_aspect, 1.0);
		float e = min(e2.x, e2.y);
		float along = e2.x < e2.y ? p.y : p.x * page_aspect;
		float scallop = border_width + 0.012 * abs(sin(along * 3.14159 / 0.05));
		float bw = fwidth(e) * 1.5;
		if (e < scallop) {
			col = border_color.rgb;
		}
		col = mix(col, ink.rgb, 1.0 - smoothstep(0.0, bw * 2.0, abs(e - scallop)));
		// The gutter where the two pages meet, and a gentle curl toward it.
		float g = (p.x - 0.5) * page_aspect;
		col *= 1.0 - 0.38 * exp(-pow(g / 0.03, 2.0));
		col *= 1.0 - 0.10 * exp(-pow(g / 0.18, 2.0));
		col += 0.05 * exp(-pow((abs(g) - 0.12) / 0.06, 2.0));
	}
	// Ink outlines around the pages and the cover.
	col = mix(col, ink.rgb, 1.0 - smoothstep(0.0, fwidth(d_page) * 2.0, abs(d_page)));
	col = mix(col, ink.rgb, 1.0 - smoothstep(0.0, aa, abs(d_cover)));

	// Warm desk-lamp falloff toward the corners.
	vec2 v = UV - vec2(0.5, 0.45);
	col *= 1.0 - 0.25 * dot(v, v);
	COLOR = vec4(col, 1.0);
}
