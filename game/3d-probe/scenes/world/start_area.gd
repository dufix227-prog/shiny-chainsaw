extends Node3D

## Игра на стартовом месте: кот появляется там, где кончилась катсцена (0 м),
## идёт по тропе первые 10 м до завала. Может вернуться к дороге — тогда
## столкновение с машиной запускает концовку С9-машина (канон, без невидимой стены).
## Мир — общая сцена start_area_world.tscn (та же, что в катсцене).

const StartArea = preload("res://scenes/world/start_area_builder.gd")

@onready var player: CharacterBody3D = $CatPlayer
@onready var hud: CanvasLayer = $HUD
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var car_ending: CanvasLayer = $CarEnding
@onready var end_zone: Area3D = $EndZone


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameSettings.apply_to_world(self)
	SaveGame.restore_into(self)
	player.struck_by_car.connect(_on_struck_by_car)
	end_zone.body_entered.connect(func(body: Node3D):
		if body == player:
			hud.show_notice("Дальше пока не сделано — это первые 10 м."))
	end_zone.body_exited.connect(func(body: Node3D):
		if body == player:
			hud.hide_notice())


func _process(_delta: float) -> void:
	hud.set_metres(metres_walked(), 0.0)
	hud.set_stamina(player.stamina, player.STAMINA_MAX)
	hud.set_in_bush(player.is_in_bush())


## Метры — продвижение по тропе от места, где началось управление.
func metres_walked() -> float:
	return maxf((StartArea.SPAWN_Z - player.global_position.z) / StartArea.WORLD_UNITS_PER_METRE, 0.0)


func _on_struck_by_car(_car: Node3D) -> void:
	pause_menu.enabled = false
	hud.visible = false
	car_ending.start(player)
