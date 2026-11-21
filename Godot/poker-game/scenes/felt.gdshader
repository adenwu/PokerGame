shader_type canvas_item;
// Card-table felt: a soft pool of light in the middle, darker edges,
// fine fibre grain and a faint woven pattern. Works at any screen size.

uniform vec4 base_color : source_color = vec4(0.09, 0.35, 0.2, 1.0);
uniform float vignette = 0.55;     // how much darker the corners get
uniform float spotlight = 0.12;    // how much brighter the middle gets
uniform float grain = 0.05;        // fine per-pixel fibre noise
uniform float weave = 0.025;       // faint cloth pattern
uniform float mottle = 0.05;       // large soft patches, like worn felt

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 pixel = FRAGCOORD.xy;
	vec2 uv = UV - 0.5;

	// Light from above: brighter centre, darker corners.
	float dist = length(uv * vec2(1.0, 1.25));
	float light = 1.0 + spotlight * (1.0 - smoothstep(0.0, 0.45, dist));
	light *= 1.0 - vignette * smoothstep(0.25, 0.85, dist);

	// Large soft patches.
	float patches = value_noise(pixel / 180.0) * 0.6 + value_noise(pixel / 60.0) * 0.4;
	light *= 1.0 + mottle * (patches - 0.5) * 2.0;

	// Fibres: short streaks of noise stretched along one direction, plus fine grain.
	float fibre = value_noise(pixel * vec2(0.9, 0.15));
	float speck = hash(floor(pixel));
	light *= 1.0 + grain * ((fibre - 0.5) + (speck - 0.5));

	// Faint diagonal weave.
	float w = sin((pixel.x + pixel.y) * 1.6) * sin((pixel.x - pixel.y) * 1.6);
	light *= 1.0 + weave * w;

	COLOR = vec4(base_color.rgb * light, 1.0);
}
