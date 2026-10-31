shader_type canvas_item;
// Draws the game as an open, hand-made paper book lying on a desk, in the same
// papercraft style as the characters (see docs/art/patch_turnaround.png).
// Everything rendered below this layer (the page) is warped onto the book's
// two pages in perspective. Each page curves down into the spine, has a torn
// edge and a stitched border, and the stacked edges of the other pages show
// around it. Around the pages: a cover of folded navy paper with a running
// stitch, thread binding at the spine, a ribbon bookmark, a soft shadow and the desk.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D desk_tex : source_color, filter_linear_mipmap;
// Maps a screen position (0-1) to a page position (0-1 across both pages).
uniform mat3 to_page;
uniform float page_aspect = 1.7778;
uniform float thickness = 0.03;
// How far the cover reaches past the pages, and how much of that is page edges.
uniform float cover_margin = 0.024;
uniform float stack_margin = 0.013;
// How far each page's top edge sinks into the spine.
uniform float spine_dip = 0.018;
// The blank paper margin, and where the printed frame lines sit inside it.
uniform float margin = 0.026;
uniform vec4 cover_color : source_color = vec4(0.17, 0.25, 0.52, 1.0);
uniform vec4 thread : source_color = vec4(0.93, 0.77, 0.45, 1.0);
uniform vec4 paper : source_color = vec4(0.98, 0.94, 0.84, 1.0);
uniform vec4 frame_ink : source_color = vec4(0.50, 0.30, 0.20, 1.0);
uniform vec4 ribbon : source_color = vec4(0.82, 0.18, 0.24, 1.0);
uniform vec4 ink : source_color = vec4(0.14, 0.10, 0.12, 1.0);

vec2 page_uv(vec2 s) {
	vec3 p = to_page * vec3(s, 1.0);
	return p.xy / p.z;
}

// Signed distance (in page units) outside the page rectangle grown by m.
float outside(vec2 p, float m) {
	vec2 d = max(vec2(-m) - p, p - vec2(1.0 + m));
	return max(d.x, d.y);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Folded paper: a Voronoi pattern of flat facets. Returns (gap to the nearest
// crease, a random tilt for this facet).
vec2 fold(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float tilt = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 17.3));
			float d = length(g + o * 0.85 + 0.075 - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				tilt = hash(i + g + 41.7);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(d2 - d1, tilt);
}

// Light on folded paper: each facet a slightly different brightness, darker creases.
float folded(vec2 p, float strength) {
	vec2 f = fold(p);
	float light = 1.0 + (f.y - 0.5) * 0.16 * strength;
	return light * (1.0 - 0.08 * strength * (1.0 - smoothstep(0.0, 0.06, f.x)));
}

// Dashes along a line: 1 on a stitch, 0 in the gaps.
float dashes(float along, float period) {
	return step(0.45, fract(along / period));
}

// A thin line of width w (in the same units as d), anti-aliased.
float line(float d, float w) {
	float aa = fwidth(d) * 1.2;
	return 1.0 - smoothstep(w, w + aa, abs(d));
}

// 0 at the spine, 1 at the outer edge of either page.
float from_spine(float x) {
	return abs(x - 0.5) * 2.0;
}

// How far the page surface has sunk at this point (it curves down into the spine).
float dip(float x) {
	float u = from_spine(x);
	return spine_dip * exp(-u * 9.0) + spine_dip * 0.25 * (1.0 - u);
}

void fragment() {
	vec2 s = SCREEN_UV;
	vec2 p = page_uv(s);
	vec3 col = texture(desk_tex, UV).rgb;
	float half_w = page_aspect * 0.5;
	float spine_x = (p.x - 0.5) * page_aspect;

	// Soft shadow of the book on the desk, cast down and to the left.
	vec2 sp = page_uv(s + vec2(0.012, -0.04));
	float sd = outside(sp, cover_margin);
	col *= mix(0.45, 1.0, smoothstep(-0.01, 0.07, sd));

	float d_cover = outside(p, cover_margin);

	// The side of the book: page block on top, the cover boards underneath.
	if (d_cover > 0.0) {
		for (int k = 1; k <= 10; k++) {
			float t = float(k) / 10.0;
			vec2 q = page_uv(s - vec2(0.0, thickness * t));
			if (outside(q, cover_margin) <= 0.0) {
				bool pages = t < 0.7;
				float leaf = 0.84 + 0.1 * step(0.5, fract(t * 40.0 + q.x * 3.0));
				vec3 side = pages ? paper.rgb * leaf * 0.92 : cover_color.rgb * 0.62;
				col = side;
				break;
			}
		}
	}

	// The cover: thick navy paper folded into facets, with a running stitch round it.
	if (d_cover <= 0.0) {
		vec2 c = vec2(p.x * page_aspect, p.y);
		col = cover_color.rgb * folded(c * 22.0, 1.4) * (0.94 + 0.08 * noise(c * 500.0));
		float stitch_d = d_cover + cover_margin * 0.5;
		float along = abs(spine_x) + p.y;
		col = mix(col, thread.rgb, line(stitch_d, 0.0011) * dashes(along, 0.012));
		// Binding: X stitches of thread across the spine at the top and bottom.
		if (abs(spine_x) < 0.035 && (p.y < 0.0 || p.y > 1.0)) {
			vec2 xs = vec2(abs(spine_x), (p.y < 0.0 ? -p.y : p.y - 1.0) - cover_margin * 0.5);
			col = mix(col, thread.rgb, max(line(xs.x - abs(xs.y) * 1.6, 0.0012), line(xs.x - 0.02, 0.0012) * 0.0)
				* step(xs.x, 0.02));
		}
	}

	// The stacked edges of all the other pages, between the cover and the top page.
	float d_stack = outside(p, stack_margin);
	if (d_stack <= 0.0) {
		vec2 edge_d = max(-p, p - 1.0);
		float depth = max(edge_d.x * page_aspect, edge_d.y);
		float leaf = step(0.5, fract(depth * 900.0));
		col = paper.rgb * (0.78 + 0.1 * leaf) * mix(1.0, 0.8, depth / stack_margin);
	}

	// The two pages, each curving down into the spine, with torn outer edges.
	vec2 q = vec2(p.x, (p.y - dip(p.x)) / (1.0 - dip(p.x)));
	float rough = (noise(vec2(q.x * page_aspect, q.y) * 160.0) - 0.5) * 0.004 + (noise(vec2(q.x * page_aspect, q.y) * 40.0) - 0.5) * 0.004;
	float d_page = outside(q, 0.0) + rough * step(0.004, from_spine(q.x));
	// A white rim of torn paper fibres just outside the torn edge.
	if (d_page > 0.0 && d_page < 0.0028 && outside(p, stack_margin) <= 0.0) {
		col = mix(paper.rgb, vec3(1.0), 0.5);
	}
	if (d_page <= 0.0) {
		col = texture(screen_tex, q).rgb;
		vec2 m = vec2(min(q.x, 1.0 - q.x) * page_aspect, min(q.y, 1.0 - q.y));
		float u = from_spine(q.x);
		// Blank paper margin round the outside of each page, with a running
		// stitch sewn round it and X stitches at the corners.
		float outer = min(m.x, m.y);
		if (outer < margin) {
			col = paper.rgb;
		}
		float sx = abs(spine_x);
		float along = m.x < m.y ? q.y : sx;
		float frame = line(outer - margin * 0.6, 0.0012) * dashes(along, 0.014);
		// The same stitch runs down each page's spine side, in the margins only.
		if (m.y < margin) {
			frame = max(frame, line(sx - margin * 0.6, 0.0012) * dashes(m.y, 0.014));
		}
		vec2 corner = abs(vec2(sx - (half_w - margin * 0.6), m.y - margin * 0.6));
		frame = max(frame, max(line(corner.x - corner.y, 0.0012), line(corner.x + corner.y - 0.0, 0.0012)) * step(max(corner.x, corner.y), 0.009));
		// A sewn-on button at the foot of each page, where a page number would be.
		vec2 foot = vec2(sx - half_w * 0.5, 1.0 - q.y - margin * 0.5);
		float button_d = length(foot) - 0.008;
		col = mix(col, vec3(0.16, 0.22, 0.5) * (1.0 - 0.3 * smoothstep(-0.004, 0.0, button_d)), 1.0 - smoothstep(0.0, fwidth(button_d) * 1.5, button_d));
		frame = max(frame, max(line(foot.x - foot.y, 0.0007), line(foot.x + foot.y, 0.0007)) * step(max(abs(foot.x), abs(foot.y)), 0.0035));
		col = mix(col, frame_ink.rgb, frame * 0.9);
		// The page paper is folded too, very gently.
		col *= folded(vec2(q.x * page_aspect, q.y) * 7.0, 0.35);

		// Paper: fine fibres and slightly aged, warmer edges.
		vec2 f = vec2(q.x * page_aspect, q.y);
		float fibre = noise(f * 420.0) * 0.6 + noise(f * 90.0) * 0.4;
		col *= 0.95 + 0.07 * fibre;
		float age = smoothstep(0.08, 0.0, outer);
		col = mix(col, col * vec3(0.92, 0.84, 0.70), age * 0.5);

		// Light across each curved page: deep shadow in the spine, a soft
		// highlight where the page rises, and a gentle fall-off to the outer edge.
		col *= 1.0 - 0.52 * exp(-pow(u / 0.035, 2.0));
		col *= 1.0 - 0.22 * exp(-pow(u / 0.16, 2.0));
		col *= 1.0 + 0.06 * exp(-pow((u - 0.3) / 0.15, 2.0));
		col *= 1.0 - 0.08 * smoothstep(0.75, 1.0, u);
		// The page on the right sits a touch brighter; light comes from the right.
		col *= q.x > 0.5 ? 1.02 : 0.97;
	} else if (outside(p, 0.0) <= 0.0) {
		// Where a page has sunk away at the spine, the leaves below show.
		col = paper.rgb * 0.72;
	}

	// The spine crease: where the two separate pages meet.
	col = mix(col, ink.rgb, line(spine_x, 0.0011) * step(0.0, p.y) * step(p.y, 1.0) * 0.9);

	// Ink outlines: each page, the page block and the cover.
	col = mix(col, frame_ink.rgb * 0.6, line(d_page, 0.0008) * step(-stack_margin, p.y) * 0.8);
	col = mix(col, ink.rgb * 1.6, line(d_stack, 0.0008) * 0.8);
	col = mix(col, ink.rgb, line(d_cover, 0.0016));

	// A ribbon bookmark tucked in at the spine, hanging off the bottom of the book.
	float rx = spine_x - 0.045;
	float tail = p.y - 1.0;
	// Its end is cut into a V notch.
	float ribbon_end = 0.1 - (0.011 - abs(rx)) * 1.6;
	if (abs(rx) < 0.011 && tail > 0.0 && tail < ribbon_end) {
		float sheen = 0.85 + 0.25 * smoothstep(0.011, 0.0, abs(rx + 0.004));
		col = ribbon.rgb * sheen;
		col = mix(col, ink.rgb, line(abs(rx) - 0.011, 0.0008));
	}

	// Warm desk-lamp falloff toward the corners.
	vec2 v = UV - vec2(0.55, 0.42);
	col *= 1.0 - 0.3 * dot(v, v);
	COLOR = vec4(col, 1.0);
}
