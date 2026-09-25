extends SceneTree

const Probe = preload("res://scripts/probe.gd")
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

func npc(probe, id: String):
	for candidate in probe.npcs:
		if candidate.npc_id == id:
			return candidate
	return null

func run() -> void:
	root.size = Vector2i(1280, 800)
	var probe := Probe.new()
	root.add_child(probe)
	await frames(8)
	probe.stint_help_accepted = true
	probe._finish_stream(true)
	check(probe.mime_hint_label.text.contains("вернуться к Стинту"), "Folder discovery hints at the optional return")
	probe._close_dialogue()
	probe._open_dialogue(npc(probe, "stint"))
	check(probe.dialogue_box.line_label.text == "Рассказать Стинту о найденной папке?", "Stint offers the report choice without invented speech")
	probe._on_dialogue_option(1)
	check(not probe.stint_report_resolved, "Not now keeps the optional return open")
	probe._open_dialogue(npc(probe, "stint"))
	check(probe.dialogue_box.opened, "Player can return to the report choice later")
	probe.selected_vtuber = "myawa"
	probe._on_dialogue_option(0)
	check(probe.stint_report_resolved and probe.bratishkin_locked, "Reporting resolves the choice and forbids returning to Bratishkin")
	check(probe.vtuber_stolen, "A gifted companion becomes the stolen companion in the report branch")
	check(probe.dialogue_box.line_label.text == "Всё, достал! Папку верни, и разойдёмся!", "Confrontation uses Stint's canonical line")
	check(is_equal_approx(Route.metres(probe.player.position), 189.0), "Stint and the player reach Bratishkin for the confrontation")
	probe._close_dialogue()
	probe._open_dialogue(npc(probe, "bratishkin"))
	check(not probe.dialogue_box.opened, "Bratishkin cannot be revisited after the confrontation")
	probe._reset()
	check(not probe.stint_report_resolved and not probe.bratishkin_locked and not probe.vtuber_stolen, "Full reset clears the report branch")
	probe.stint_help_accepted = true
	probe.folder_found = true
	probe._open_dialogue(npc(probe, "stint"))
	probe._on_dialogue_option(0)
	check(not probe.vtuber_stolen, "Reporting without a companion does not create one")
	probe.queue_free()
	await process_frame
	print("Stint report tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
