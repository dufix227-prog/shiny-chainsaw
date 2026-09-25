shader_type spatial;

// Земля участка: трава, утоптанная тропа и камень на крутых склонах.
// Где тропа — задаёт сборщик участка: красный канал цвета вершины (1 = тропа).

uniform sampler2D grass_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 grass_tint : source_color = vec3(0.78, 0.9, 0.62);
uniform vec3 path_tint : source_color = vec3(1.0, 0.9, 0.78);
uniform float grass_scale = 0.22;
uniform float path_scale = 0.3;
uniform float rock_scale = 0.12;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 grass = texture(grass_texture, world_position.xz * grass_scale).rgb * grass_tint;
	vec3 path = texture(path_texture, world_position.xz * path_scale).rgb * path_tint;
	// Камень на склоне проецируется сбоку, иначе на крутизне текстура растягивается.
	vec3 rock = texture(rock_texture, vec2(world_position.x + world_position.z, world_position.y) * rock_scale).rgb;

	// Крупная неровность, чтобы край тропы не был идеальной линией.
	float edge_noise = texture(grass_texture, world_position.xz * 0.05).g - 0.5;
	float path_amount = smoothstep(0.3, 0.7, COLOR.r + edge_noise * 0.5);
	float steepness = smoothstep(0.45, 0.7, 1.0 - world_normal.y);

	ALBEDO = mix(mix(grass, path, path_amount), rock, steepness);
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
