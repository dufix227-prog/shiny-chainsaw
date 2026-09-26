extends Node3D

## Проба графики «как в меню»: короткий кусок тропы. Сейчас сюда же ведёт
## «Новая игра» после катсцены — пока участок 40 м не переделан в этом стиле.

const Terrain = preload("res://scenes/style_probe/probe_terrain.gd")
const WORLD_UNITS_PER_METRE := 12.24

@onready var player: CharacterBody3D = $CatPlayer
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameSettings.apply_to_world(self)
	SaveGame.restore_into(self)


func _process(_delta: float) -> void:
	# Кот появляется на z = 4 (см. style_probe_builder.gd).
	var start_z := 4.0
	var walked := clampf((start_z - player.global_position.z) / WORLD_UNITS_PER_METRE, 0.0, 99.0)
	hud.set_metres(walked, (start_z - Terrain.BARRIER_Z) / WORLD_UNITS_PER_METRE)
	hud.set_stamina(player.stamina, player.STAMINA_MAX)
	hud.set_in_bush(player.is_in_bush())
