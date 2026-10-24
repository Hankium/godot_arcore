shader_type canvas_item;

// Fake darkness over the AR camera feed: darkened feed, flashlight cone,
// vignette, grain and scanlines. ghost_proximity adds warp and colour drain.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float darkness : hint_range(0.0, 1.0) = 0.85;
uniform float cone_radius : hint_range(0.05, 1.0) = 0.32;
uniform float grain : hint_range(0.0, 0.5) = 0.10;
uniform float ghost_proximity : hint_range(0.0, 1.0) = 0.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * 40.0 + TIME * 8.0) * 0.006 * ghost_proximity;

	vec3 col = texture(screen_tex, uv).rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), 0.5 + 0.5 * ghost_proximity);

	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
	float d = length(p);
	float cone = 1.0 - smoothstep(cone_radius * 0.55, cone_radius, d);
	col *= mix(1.0 - darkness, 1.0, cone);
	col *= 1.0 - smoothstep(0.45, 1.0, d);

	float n = rand(FRAGCOORD.xy + vec2(TIME * 61.0, TIME * 37.0));
	col += (n - 0.5) * (grain + 0.25 * ghost_proximity);
	col *= 0.93 + 0.07 * sin(FRAGCOORD.y * 1.5);

	COLOR = vec4(col, 1.0);
}
