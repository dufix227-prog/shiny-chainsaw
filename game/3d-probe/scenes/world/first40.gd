extends Node3D

## Участок «первые 40 м»: связывает кота, интерфейс и зону у завала.
## Мир здесь не создаётся — он уже лежит в сцене (см. first40_builder.gd).

const Builder = preload("res://scenes/world/first40_builder.gd")

@onready var player: CharacterBody3D = $CatPlayer
@onready var hud: CanvasLayer = $HUD
@onready var end_zone: Area3D = $EndZone


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	end_zone.body_entered.connect(_on_end_zone_entered)
	end_zone.body_exited.connect(_on_end_zone_exited)


func _process(_delta: float) -> void:
	hud.set_metres(metres_walked(), Builder.SECTION_METRES)
	hud.set_stamina(player.stamina, player.STAMINA_MAX)
	hud.set_in_bush(player.is_in_bush())


## Метры считаются по продвижению вдоль участка, а не по сумме шагов.
func metres_walked() -> float:
	return clampf(-player.global_position.z / Builder.WORLD_UNITS_PER_METRE, 0.0, Builder.SECTION_METRES)


func _on_end_zone_entered(body: Node3D) -> void:
	if body == player:
		hud.show_notice("Дорогу перегородил завал. Участок 40 м пройден — дальше пока не сделано.")


func _on_end_zone_exited(body: Node3D) -> void:
	if body == player:
		hud.hide_notice()
