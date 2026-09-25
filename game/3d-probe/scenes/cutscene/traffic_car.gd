extends Node3D

## Машина едет по полосе вдоль оси X и, доехав до края улицы, возвращается
## к её началу — поток машин не кончается. Направление — по повороту узла:
## машина всегда едет «носом» (+X в своих координатах).

@export var speed := 11.0
@export var x_min := -75.0
@export var x_max := 55.0


func _process(delta: float) -> void:
	position += global_transform.basis.x * speed * delta
	if position.x > x_max:
		position.x = x_min
	elif position.x < x_min:
		position.x = x_max
