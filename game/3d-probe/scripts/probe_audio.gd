class_name ProbeAudio
extends Node

const MUSIC := preload("res://audio/ambient_loop.wav")
const WIND := preload("res://audio/wind_loop.wav")
const PICKUP := preload("res://audio/pickup.wav")
const EAT := preload("res://audio/eat.wav")
const FOOTSTEPS := [
	preload("res://audio/footstep_1.wav"),
	preload("res://audio/footstep_2.wav"),
	preload("res://audio/footstep_3.wav"),
]
const STEP_DISTANCE := 0.72

var music := AudioStreamPlayer.new()
var ambience := AudioStreamPlayer.new()
var one_shots: Array[AudioStreamPlayer] = []
var step_remainder := 0.0
var footstep_events := 0
var pickup_events := 0
var eat_events := 0
var variation := 0

func _ready() -> void:
	music.stream = MUSIC
	music.volume_db = -20.0
	add_child(music)
	ambience.stream = WIND
	ambience.volume_db = -26.0
	add_child(ambience)
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = -11.0
		add_child(player)
		one_shots.append(player)
	music.play()
	ambience.play()

func _exit_tree() -> void:
	# Looping players must stop before shutdown, or the audio server keeps
	# their playback objects alive past exit and smoke reports leaks.
	music.stop()
	ambience.stop()
	for player in one_shots:
		player.stop()

func advance_steps(distance: float, allowed: bool) -> void:
	if not allowed or distance <= 0:
		return
	step_remainder += distance
	while step_remainder >= STEP_DISTANCE:
		step_remainder -= STEP_DISTANCE
		_play_footstep()

func play_pickup() -> void:
	pickup_events += 1
	_play(PICKUP, -9.0)

func play_eat() -> void:
	eat_events += 1
	_play(EAT, -10.0)

func reset_steps() -> void:
	step_remainder = 0.0

func _play_footstep() -> void:
	footstep_events += 1
	var stream: AudioStream = FOOTSTEPS[variation % FOOTSTEPS.size()]
	variation += 1
	_play(stream, -15.0)

func _play(stream: AudioStream, volume_db: float) -> void:
	for player in one_shots:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return
	var player := one_shots[variation % one_shots.size()]
	player.stream = stream
	player.volume_db = volume_db
	player.play()
