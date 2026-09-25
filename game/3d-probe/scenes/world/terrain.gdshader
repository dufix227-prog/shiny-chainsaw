shader_type spatial;

// Блочная земля участка. Каждая грань — одна пиксельная текстура 16×16 на блок.
// Цвет вершины (задаёт сборщик): R = 1 — тропа, G = 1 — верхний слой боковой грани.

uniform sampler2D grass_top_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D grass_side_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D path_texture : source_color, filter_nearest, repeat_enable;
// Лёгкий разброс яркости по блокам, чтобы поле не было одним ковром.
uniform float block_brightness_spread = 0.07;

varying vec3 world_position;
varying vec3 world_normal;

float block_random(vec2 block) {
	return fract(sin(dot(block, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	// Стороны блоков лежат на полуцелых X/Z и на целых Y.
	vec3 grid = world_position + vec3(0.5, 0.0, 0.5);
	vec3 albedo;
	vec2 block;
	if (abs(world_normal.y) > 0.5) {
		block = floor(grid.xz);
		vec2 uv = fract(grid.xz);
		albedo = COLOR.r > 0.5 ? texture(path_texture, uv).rgb : texture(grass_top_texture, uv).rgb;
	} else {
		vec2 side = abs(world_normal.x) > 0.5 ? vec2(grid.z, -grid.y) : vec2(grid.x, -grid.y);
		block = floor(side);
		vec2 uv = fract(side);
		bool top_layer = COLOR.g > 0.5 && COLOR.r < 0.5;
		albedo = top_layer ? texture(grass_side_texture, uv).rgb : texture(dirt_texture, uv).rgb;
	}
	albedo *= 1.0 + (block_random(block) - 0.5) * 2.0 * block_brightness_spread;
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
