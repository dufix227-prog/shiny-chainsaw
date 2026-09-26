extends Node3D

## Куст проходим, но пока кот внутри — он идёт вдвое медленнее
## (решение автора 09.09.2026: «все кусты проходимы, но замедляют в два раза»).


func _ready() -> void:
	$SlowZone.body_entered.connect(_on_body_entered)
	$SlowZone.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("enter_bush"):
		body.enter_bush()


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("leave_bush"):
		body.leave_bush()
