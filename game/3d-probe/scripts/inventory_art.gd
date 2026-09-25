class_name InventoryArt
extends RefCounted

## Временные пиксельные пробы для окна инвентаря: полноростовой кот, иконки
## предметов и лапа-украшение. Нарисовано кодом по двум одобренным автором
## референсам; это проба подачи, а не финальный арт игры.

static func cat_texture() -> ImageTexture:
	var img := _image(24, 48)
	var fur := Color("e08a3c")
	var fur_dark := Color("c06c28")
	var cream := Color("f6eedd")
	var dark := Color("2a2320")
	var pink := Color("e08888")
	var hood := Color("4d6b45")
	var hood_dark := Color("37503a")
	var pants := Color("3a3733")
	var shoe := Color("5a4a3e")
	var sole := Color("d8d0c0")
	var halves := [1, 1, 2, 2, 3, 3]
	for row in range(6):
		var half: int = halves[row]
		for x in range(6 - half, 7 + half):
			img.set_pixel(x, row, fur)
		for x in range(17 - half, 18 + half):
			img.set_pixel(x, row, fur)
	for ear in [Vector2i(6, 3), Vector2i(5, 4), Vector2i(6, 4), Vector2i(17, 3), Vector2i(17, 4), Vector2i(18, 4)]:
		img.set_pixel(ear.x, ear.y, pink)
	_ellipse(img, 11.5, 10.0, 8.5, 7.5, fur)
	for y in range(15, 18):
		for x in range(3, 21):
			if img.get_pixel(x, y).is_equal_approx(fur):
				img.set_pixel(x, y, fur_dark)
	_ellipse(img, 11.5, 14.5, 4.5, 3.0, cream)
	_rect(img, 8, 9, 2, 3, dark)
	_rect(img, 14, 9, 2, 3, dark)
	img.set_pixel(8, 9, cream)
	img.set_pixel(14, 9, cream)
	_rect(img, 11, 13, 2, 1, pink)
	img.set_pixel(10, 15, fur_dark)
	img.set_pixel(13, 15, fur_dark)
	_rect(img, 6, 16, 4, 3, hood_dark)
	_rect(img, 14, 16, 4, 3, hood_dark)
	_rect(img, 10, 18, 4, 1, hood_dark)
	_rect(img, 6, 19, 12, 14, hood)
	_rect(img, 11, 19, 2, 14, hood_dark)
	_rect(img, 8, 27, 8, 1, hood_dark)
	_rect(img, 8, 28, 1, 2, hood_dark)
	_rect(img, 15, 28, 1, 2, hood_dark)
	_rect(img, 4, 19, 2, 11, hood)
	_rect(img, 18, 19, 2, 11, hood)
	_rect(img, 4, 30, 2, 2, cream)
	_rect(img, 18, 30, 2, 2, cream)
	_rect(img, 7, 32, 10, 1, pants)
	_rect(img, 7, 33, 4, 11, pants)
	_rect(img, 13, 33, 4, 11, pants)
	_rect(img, 6, 44, 5, 2, shoe)
	_rect(img, 6, 46, 5, 1, sole)
	_rect(img, 13, 44, 5, 2, shoe)
	_rect(img, 13, 46, 5, 1, sole)
	_rect(img, 2, 24, 3, 3, fur_dark)
	_rect(img, 2, 27, 3, 12, fur)
	_rect(img, 5, 35, 2, 4, fur)
	return ImageTexture.create_from_image(img)

static func item_texture(id: String) -> ImageTexture:
	match id:
		"food":
			return food_texture()
		"water":
			return water_texture()
		"map":
			return map_texture()
		"coffee":
			return coffee_texture()
	return unknown_texture()

static func food_texture() -> ImageTexture:
	var img := _image(10, 10)
	_rect(img, 2, 0, 6, 2, Color("b8bcc0"))
	_rect(img, 2, 2, 6, 6, Color("d9823c"))
	_rect(img, 2, 4, 6, 2, Color("b5662a"))
	_rect(img, 2, 8, 6, 2, Color("8a8f94"))
	_rect(img, 2, 2, 1, 6, Color("c06c28"))
	return ImageTexture.create_from_image(img)

static func water_texture() -> ImageTexture:
	var img := _image(10, 10)
	_rect(img, 4, 0, 2, 1, Color("aeb6bd"))
	_rect(img, 4, 1, 2, 2, Color("bfe0f2"))
	_rect(img, 3, 3, 4, 1, Color("bfe0f2"))
	_rect(img, 3, 4, 4, 5, Color("4f9fe8"))
	_rect(img, 3, 4, 1, 3, Color("bfe0f2"))
	_rect(img, 3, 7, 4, 2, Color("2f6db8"))
	_rect(img, 3, 9, 4, 1, Color("24507e"))
	return ImageTexture.create_from_image(img)

static func map_texture() -> ImageTexture:
	var img := _image(10, 10)
	_rect(img, 1, 1, 8, 8, Color("ead9a8"))
	_rect(img, 2, 2, 3, 2, Color("7aa860"))
	_rect(img, 6, 5, 2, 3, Color("5a90c8"))
	_rect(img, 3, 1, 1, 8, Color("c9b788"))
	_rect(img, 6, 1, 1, 8, Color("c9b788"))
	return ImageTexture.create_from_image(img)

static func coffee_texture() -> ImageTexture:
	var img := _image(10, 10)
	_rect(img, 2, 2, 6, 6, Color("d8c8aa"))
	_rect(img, 3, 3, 4, 3, Color("67412c"))
	_rect(img, 8, 3, 2, 4, Color("d8c8aa"))
	_rect(img, 3, 8, 5, 1, Color("8f785d"))
	return ImageTexture.create_from_image(img)

static func unknown_texture() -> ImageTexture:
	var img := _image(10, 10)
	_rect(img, 2, 2, 6, 6, Color("9aa89a"))
	return ImageTexture.create_from_image(img)

static func paw_texture() -> ImageTexture:
	var img := _image(10, 10)
	var paw := Color("f2dfb6")
	_ellipse(img, 5.0, 6.5, 3.0, 2.5, paw)
	_ellipse(img, 2.5, 3.5, 1.2, 1.2, paw)
	_ellipse(img, 5.0, 2.5, 1.2, 1.2, paw)
	_ellipse(img, 7.5, 3.5, 1.2, 1.2, paw)
	return ImageTexture.create_from_image(img)

static func _image(width: int, height: int) -> Image:
	return Image.create_empty(width, height, false, Image.FORMAT_RGBA8)

static func _rect(img: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	for dy in range(height):
		for dx in range(width):
			var px := x + dx
			var py := y + dy
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, color)

static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	for y in range(maxi(0, int(cy - ry)), mini(img.get_height(), int(cy + ry) + 1)):
		for x in range(maxi(0, int(cx - rx)), mini(img.get_width(), int(cx + rx) + 1)):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, color)
