shader_type canvas_item;
// Draws the game as an open hardcover book lying on a desk.
// Everything rendered below this layer (the page) is warped onto the book's
// two pages in perspective. Each page curves down into the spine, has its own
// printed frame and paper shading, and the stacked edges of the other pages
// show around it. Around the pages: a cloth-bound cover with a gold rule,
// headbands at the spine, a ribbon bookmark, a soft shadow and the desk.

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
uniform vec4 cover_color : source_color = vec4(0.42, 0.11, 0.14, 1.0);
uniform vec4 gold : source_color = vec4(0.86, 0.68, 0.32, 1.0);
uniform vec4 paper : source_color = vec4(0.98, 0.94, 0.84, 1.0);
uniform vec4 frame_ink : source_color = vec4(0.36, 0.22, 0.16, 1.0);
uniform vec4 ribbon : source_color = vec4(0.16, 0.36, 0.42, 1.0);
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

	// The cover: cloth-bound boards with a woven texture and a gold rule.
	if (d_cover <= 0.0) {
		vec2 c = vec2(p.x * page_aspect, p.y) * 900.0;
		float weave = 0.5 * (sin(c.x) * 0.5 + 0.5) + 0.5 * (sin(c.y) * 0.5 + 0.5);
		float mottled = noise(p * vec2(page_aspect, 1.0) * 60.0);
		col = cover_color.rgb * (0.86 + 0.08 * weave + 0.12 * mottled);
		col = mix(col, gold.rgb, line(d_cover + cover_margin * 0.3, 0.0012) * 0.9);
		// Headbands: striped thread at the top and bottom of the spine.
		if (abs(spine_x) < 0.03 && (p.y < 0.0 || p.y > 1.0)) {
			float stripe = step(0.5, fract(spine_x * 140.0));
			col = mix(vec3(0.75, 0.62, 0.36), vec3(0.32, 0.12, 0.12), stripe);
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

	// The two pages, each curving down into the spine.
	vec2 q = vec2(p.x, (p.y - dip(p.x)) / (1.0 - dip(p.x)));
	float d_page = outside(q, 0.0);
	if (d_page <= 0.0) {
		col = texture(screen_tex, q).rgb;
		vec2 m = vec2(min(q.x, 1.0 - q.x) * page_aspect, min(q.y, 1.0 - q.y));
		float u = from_spine(q.x);
		// Blank paper margin round the outside of each page, with a printed
		// double-rule frame and little corner ornaments.
		float outer = min(m.x, m.y);
		if (outer < margin) {
			col = paper.rgb;
		}
		float rule = min(m.x, m.y);
		float frame = max(line(rule - margin, 0.0016), line(rule - margin * 0.62, 0.0008));
		// Inner rule beside the spine, in each page's own margin.
		float sx = abs(spine_x);
		if (m.y > margin * 0.6) {
			frame = max(frame, line(sx - margin * 0.55, 0.0008));
		}
		// Corner ornaments: small diamonds where the frame lines meet.
		vec2 corner = vec2(abs(abs(spine_x) - (half_w - margin * 0.8)), abs(m.y - margin * 0.8));
		float diamond = corner.x + corner.y;
		frame = max(frame, 1.0 - smoothstep(0.006, 0.006 + fwidth(diamond) * 1.2, diamond));
		// A small fleuron at the foot of each page, where a page number would be.
		vec2 foot = vec2(abs(sx - half_w * 0.5), abs(1.0 - q.y - margin * 0.55));
		float fleuron = min(foot.x * 0.6 + foot.y, length(foot - vec2(0.012, 0.0)) * 2.0);
		frame = max(frame, 1.0 - smoothstep(0.004, 0.004 + fwidth(fleuron) * 1.2, fleuron));
		col = mix(col, frame_ink.rgb, frame * 0.85);

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
	float page_edge = outside(q, 0.0);
	col = mix(col, ink.rgb, line(page_edge, 0.0012) * step(-stack_margin, p.y));
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
