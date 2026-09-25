extends CanvasLayer

## Слой пикселизации. Размер пикселя берётся из настроек (1 — выключено).

@onready var screen: ColorRect = $Screen


func _ready() -> void:
	apply_setting()
	GameSettings.changed.connect(apply_setting)


func apply_setting() -> void:
	var size: int = GameSettings.pixel_size
	screen.visible = size > 1
	(screen.material as ShaderMaterial).set_shader_parameter("pixel_size", float(size))
