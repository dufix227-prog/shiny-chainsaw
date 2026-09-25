extends SceneTree

const Probe = preload("res://scripts/probe.gd")

var failures := 0
var checks := 0
var quit_requested := false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func frames(count: int) -> void:
	for i in count:
		await process_frame

func run() -> void:
	root.size = Vector2i(1280, 800)
	var probe := Probe.new()
	root.add_child(probe)
	await frames(8)
	check(not probe.ending_screen.opened, "Ending starts closed")
	probe._finish_pig_work()
	check(probe.pig_work_completed, "Completed pig work remains a separate activity")
	check(not probe.moderator_offer_open, "Pig work does not offer or schedule the moderator outcome")
	check(probe.dialogue_box.line_label.text.contains("Красава"), "Pig work still ends with canonical thanks")
	probe._close_dialogue()
	check(not probe.ending_screen.opened, "Closing pig work thanks returns to the route")
	probe._choose_vtuber("myawa", "MyawA")
	check(probe.moderator_offer_open, "Choosing a vtuber opens Bratishkin's stay offer")
	check(probe.dialogue_box.line_label.text == "Братишкин предлагает остаться у него навсегда.", "Offer uses only the author's wording")
	check(probe.dialogue_box.option_buttons[0].text == "Неа, бро, у меня другой путь", "First answer continues the player's path")
	check(probe.dialogue_box.option_buttons[1].text == "Давай, конечно", "Second answer accepts the offer")
	probe._on_dialogue_option(0)
	check(probe.moderator_offer_resolved and not probe.ending_screen.opened, "Refusing the offer continues without an ending")
	probe._reset()
	probe._choose_vtuber("myawa", "MyawA")
	probe._on_dialogue_option(1)
	check(probe.ending_screen.opened and probe.ending_screen.visible, "Accepting the offer opens the separate prologue ending")
	check(probe.ending_screen.detail_label.text == "Остался модерировать витуберш", "Ending uses the author's clarified outcome")
	check(probe._simulation_stopped(), "Ending blocks gameplay")
	probe.ending_screen.quit_requested.connect(func(): quit_requested = true)
	probe.ending_screen.show_credits()
	check(probe.ending_screen.showing_credits, "Ending advances to credits")
	check(probe.ending_screen.detail_label.text.contains("Пролог"), "Credits identify this as the prologue")
	probe.ending_screen._process(probe.ending_screen.CREDITS_DURATION)
	check(quit_requested, "Credits request automatic exit")
	probe._reset()
	check(not probe.ending_screen.opened and not probe.moderator_offer_resolved, "Full reset clears the ending and offer")
	probe.queue_free()
	await process_frame
	print("Moderator ending tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
