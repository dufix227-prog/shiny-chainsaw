extends Node3D

## Машина едет по полосе вдоль оси X и, доехав до края улицы, возвращается
## к её началу — поток машин не кончается. Направление — по повороту узла:
## машина всегда едет «носом» (+X в своих координатах).
## Если в зону машины попадает кот, у него вызывается hit_by_car(машина) —
## так запускается концовка «глупый суицидник» (С9-машина).

@export var speed := 11.0
@export var x_min := -75.0
@export var x_max := 55.0


func _ready() -> void:
	var hit_zone := get_node_or_null("HitZone")
	if hit_zone:
		hit_zone.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("hit_by_car"):
		body.hit_by_car(self)


func _process(delta: float) -> void:
	position += global_transform.basis.x * speed * delta
	if position.x > x_max:
		position.x = x_min
	elif position.x < x_min:
		position.x = x_max
