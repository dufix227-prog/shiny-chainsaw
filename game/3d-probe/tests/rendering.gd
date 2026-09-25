extends SceneTree

const Probe = preload("res://scripts/probe.gd")
const JoypadGuard = preload("res://tests/joypad_guard.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func run() -> void:
	check(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand", "Scene adapts to display aspect instead of fixed 16:10")
	check(Probe.render_size(Vector2(1920, 1080), 720) == Vector2i(1280, 720), "HD is real 1280x720 at 16:9")
	check(Probe.render_size(Vector2(1920, 1080), 1080) == Vector2i(1920, 1080), "Full HD is real 1920x1080")
	check(Probe.render_size(Vector2(1280, 800), 720) == Vector2i(1152, 720), "HD preserves 16:10 aspect")
	check(Probe.render_size(Vector2(1280, 800), 1080) == Vector2i(1728, 1080), "Full HD preserves 16:10 aspect")
	check(Probe.render_size(Vector2(1280, 800), 400) == Vector2i(640, 400), "Original lightweight resolution retained")
	check(Probe.render_size(Vector2(3440, 1440), 1080) == Vector2i(2580, 1080), "Ultrawide aspect retained")
	check(Probe.render_size(Vector2.ZERO, 720) == Vector2i(1, 720), "Zero-sized layout is safe")
	var probe := Probe.new()
	root.add_child(probe)
	JoypadGuard.strip()
	probe.size = Vector2(1920, 1080)
	await process_frame
	check(probe.world_viewport.size == Vector2i(1280, 720), "Scene starts in HD")
	check(probe.quality_button.text == "Q · 720p", "Button reports default quality")
	check(probe.canvas.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "HD scales smoothly")
	probe.player.set_physics_process(false)
	# Seed both current and earlier visits before the first scene update.
	probe.route.discover(probe.player.position)
	probe.route.discover(Vector3(0, 0, -10))
	var position: Vector3 = probe.player.position
	var discovered: Dictionary = probe.route.discovered.duplicate()
	var projection: int = probe.camera.projection
	probe.quality_button.pressed.emit()
	check(probe.world_viewport.size == Vector2i(1920, 1080), "Button changes actual render target to Full HD")
	check(probe.quality_button.text == "Q · 1080p", "Button reports Full HD")
	probe.size = Vector2(1280, 800)
	check(probe.world_viewport.size == Vector2i(1728, 1080), "Resize retains selected render height")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Q
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	check(probe.world_viewport.size == Vector2i(640, 400), "Q changes quality to lightweight mode")
	check(probe.quality_button.text == "Q · 400p", "Button reports lightweight mode")
	check(probe.canvas.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Lightweight mode keeps original pixel scaling")
	event.echo = true
	Input.parse_input_event(event)
	await process_frame
	check(probe.quality_index == 0, "Held Q does not repeatedly change quality")
	event.echo = false
	event.pressed = false
	Input.parse_input_event(event)
	probe.quality_button.pressed.emit()
	check(probe.world_viewport.size == Vector2i(1152, 720), "Quality cycle returns to HD")
	check(probe.player.position == position, "Quality does not move player")
	check(probe.route.discovered == discovered, "Quality does not reset map discoveries")
	check(probe.camera.projection == projection, "Quality does not change camera projection")
	probe._toggle_camera()
	check(probe.world_viewport.size == Vector2i(1152, 720), "Camera toggle retains quality")
	probe._reset()
	check(probe.quality_index == 1, "Route reset retains quality")
	probe.queue_free()
	await process_frame
	print("Rendering tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
