extends Node3D

const Art = preload("res://scripts/geometry.gd")
const MIN_X := -12.0
const MAX_X := 12.0
const CAR_SPEED := 5.2

var cars: Array[Node3D] = []
var paused := false

func _ready() -> void:
	var colors := [Color("b74c3c"), Color("537e9c"), Color("d5a943"), Color("667449")]
	for i in 4:
		var direction := 1.0 if i % 2 == 0 else -1.0
		var lane_z := -0.8 if direction > 0 else 0.9
		_add_car(i, Vector3(-9.0 + i * 6.0, 0.24, lane_z), direction, colors[i])

func _add_car(index: int, position: Vector3, direction: float, color: Color) -> void:
	var car := Node3D.new()
	car.name = "Car%d" % index
	car.position = position
	car.set_meta("direction", direction)
	car.set_meta("speed", CAR_SPEED + index * 0.35)
	add_child(car)
	var body := Art.material(color, true)
	var glass := Art.material(Color("78939a"))
	var dark := Art.material(Color("292b2a"))
	Art.box(car, Vector3.ZERO, Vector3(2.0, 0.55, 0.9), body)
	Art.box(car, Vector3(-0.15 * direction, 0.47, 0), Vector3(1.0, 0.45, 0.72), glass)
	for x in [-0.62, 0.62]:
		for z in [-0.48, 0.48]:
			Art.box(car, Vector3(x, -0.26, z), Vector3(0.35, 0.35, 0.16), dark)
	cars.append(car)

func _process(delta: float) -> void:
	if paused:
		return
	for car in cars:
		var direction: float = car.get_meta("direction")
		var speed: float = car.get_meta("speed")
		car.position.x += direction * speed * delta
		if car.position.x > MAX_X:
			car.position.x = MIN_X
		elif car.position.x < MIN_X:
			car.position.x = MAX_X

func set_paused(value: bool) -> void:
	paused = value
