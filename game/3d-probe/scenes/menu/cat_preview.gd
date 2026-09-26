extends Node3D

## Превью модели кота в меню новой игры: кот медленно поворачивается,
## кнопкой можно пролистать эмоции. Живёт в своём SubViewport (свой 3D-мир).

const CatModel = preload("res://scenes/player/cat_model.gd")

const TURN_SPEED := 0.5

var emotion_index := 0

@onready var pedestal: Node3D = $Pedestal
@onready var model: Node3D = $Pedestal/CatModel


func _process(delta: float) -> void:
	pedestal.rotation.y += TURN_SPEED * delta


func show_variant(id: String) -> void:
	model = CatModel.replace(model, id)
	model.footsteps_enabled = false
	model.emotion = CatModel.EMOTION_NAMES.keys()[emotion_index]


## Следующая эмоция; возвращает её название по-русски.
func next_emotion() -> String:
	var moods: Array = CatModel.EMOTION_NAMES.keys()
	emotion_index = (emotion_index + 1) % moods.size()
	model.emotion = moods[emotion_index]
	return CatModel.EMOTION_NAMES[moods[emotion_index]]
