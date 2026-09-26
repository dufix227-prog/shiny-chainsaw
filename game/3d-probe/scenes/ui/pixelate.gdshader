shader_type canvas_item;

// Пикселизация всей 3D-картинки: экран делится на квадраты pixel_size×pixel_size,
// каждый заливается одним цветом. Интерфейс рисуется поверх и не пикселизуется.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float pixel_size = 3.0;

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(SCREEN_UV * screen_size / pixel_size) * pixel_size + pixel_size * 0.5;
	COLOR = texture(screen_texture, cell / screen_size);
}
