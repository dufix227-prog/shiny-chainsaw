extends CanvasLayer

## Игровой интерфейс участка: пройденные метры, выносливость,
## подсказка управления в начале и сообщения по месту (например, у завала).

const CONTROLS_HINT_SECONDS := 12.0

@onready var metres_label: Label = %MetresLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var bush_label: Label = %BushLabel
@onready var controls_hint: Label = %ControlsHint
@onready var notice_label: Label = %NoticeLabel
@onready var toast_label: Label = %ToastLabel

var _toast_tween: Tween


func _ready() -> void:
	notice_label.visible = false
	bush_label.visible = false
	toast_label.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_interval(CONTROLS_HINT_SECONDS)
	fade.tween_property(controls_hint, "modulate:a", 0.0, 1.5)


## total ≤ 0 — показывать только пройденные метры.
func set_metres(walked: float, total: float) -> void:
	if total <= 0.0:
		metres_label.text = "%d м" % floori(walked)
	else:
		metres_label.text = "%d м из %d" % [floori(walked), roundi(total)]


func set_stamina(value: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = value


func set_in_bush(in_bush: bool) -> void:
	bush_label.visible = in_bush


func show_notice(text: String) -> void:
	notice_label.text = text
	notice_label.visible = true


func hide_notice() -> void:
	notice_label.visible = false


## Короткая подсказка сверху по центру (например, «Камера: первое лицо»).
func show_toast(text: String, seconds: float = 1.8) -> void:
	toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
