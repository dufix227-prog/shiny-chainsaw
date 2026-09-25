extends SceneTree

const Probe = preload("res://scripts/probe.gd")
const PigFollow = preload("res://scripts/pig_follow.gd")
const Route = preload("res://scripts/route.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	root.size = Vector2i(1280, 800)
	var probe := Probe.new()
	root.add_child(probe)
	await frames(8)
	var pig := probe.stolen_pig
	check(pig != null and is_equal_approx(Route.metres(pig.position), 205.0), "Stealable pig waits by the distant pen")
	check(PigFollow.SEAT_CAPACITY == 2, "Pig declares the canonical two-seat capacity")
	check(not pig.stolen and not pig.mounted, "Pig starts available without becoming a reward")
	probe.player.global_position = pig.global_position
	probe._interact_with_pig()
	check(pig.stolen and pig.mounted, "Interacting steals and mounts the pig at any time")
	check(is_equal_approx(probe.player.mount_speed_multiplier, PigFollow.SPEED_MULTIPLIER), "Mounted pig accelerates the player")
	pig.dismount(probe.player.global_position)
	probe.player.set_mount_speed_multiplier(1.0)
	check(pig.stolen and not pig.mounted, "Player can dismount wherever desired")
	check(pig.is_player_in_reach(probe.player.global_position), "Dismounted pig remains nearby")
	pig.mount(probe.player.global_position)
	pig.advance(PigFollow.MAX_HUNGER_SECONDS + 1.0, probe.player.global_position)
	check(not pig.stolen and not pig.mounted, "Long starvation makes the pig run away")
	check(pig.global_position == PigFollow.home_position() and pig.visible, "Hungry pig returns home without disappearing")
	probe.inventory.remove_one("hotbar:0")
	probe.inventory.remove_one("hotbar:0")
	probe._interact_with_pig()
	check(not pig.mounted and probe.dialogue_box.line_label.text.contains("Нужна обычная еда"), "Starving pig asks for ordinary food")
	probe._close_dialogue()
	probe.inventory.reset()
	var food_before := probe.inventory.food_count()
	pig.hungry_seconds = 1.0
	probe._interact_with_pig()
	check(pig.mounted and pig.hungry_seconds > 1.0, "Ordinary food restores hunger before mounting")
	check(probe.inventory.food_count() == food_before - 1, "Feeding consumes one ordinary food portion")
	probe.player.position = Vector3(0, 0.1, Route.world_z(211.0))
	probe._on_step(0.1, 0.1)
	check(pig.bratishkin_shouted and probe.dialogue_box.line_label.text == "Верни свинку!", "Bratishkin shouts once when the stolen pig leaves")
	probe._close_dialogue()
	probe._on_step(0.1, 0.1)
	check(not probe.dialogue_box.opened, "The theft shout is not repeated")
	probe._reset()
	check(not pig.stolen and not pig.mounted and pig.global_position == PigFollow.home_position(), "Full reset returns the pig and clears theft")
	probe.queue_free()
	await process_frame
	print("Pig follow tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
