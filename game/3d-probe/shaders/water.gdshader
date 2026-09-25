shader_type spatial;
render_mode unshaded;

// Вода не участвует в расчёте света (unshaded), поэтому сутки и дождь приходят
// сюда параметрами: иначе ночью вода остаётся дневной, и кадр не читается ночным
// (на это указал автор 19.09.2026).
uniform float night : hint_range(0.0, 1.0) = 0.0;   // 0 — день, 1 — глубокая ночь
uniform float wet : hint_range(0.0, 1.0) = 0.0;     // 0 — ясно, 1 — ливень

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 grid = floor(world_position.xz * vec2(2.0, 5.0));
	float patch = fract(sin(dot(floor(grid * vec2(0.22, 0.5)), vec2(12.9898, 78.233))) * 43758.5453);
	float wave = sin(grid.y * 0.6 + grid.x * 0.12 + TIME * 0.7);
	vec3 base = mix(vec3(0.22, 0.40, 0.48), vec3(0.26, 0.45, 0.53), step(0.75, patch));
	vec3 surface = mix(base, vec3(0.47, 0.65, 0.67), step(0.92, patch) * step(0.8, wave));
	// Ночь уводит воду в тёмно-синий, дождь снимает блики. Множители —
	// технические, до решения автора.
	vec3 night_tint = mix(vec3(1.0), vec3(0.16, 0.20, 0.30), night);
	ALBEDO = surface * night_tint * mix(1.0, 0.78, wet);
}
