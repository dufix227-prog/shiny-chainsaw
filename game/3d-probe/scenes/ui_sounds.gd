extends Node

## Звуки интерфейса: щелчок при нажатии кнопки, тихий «тик» при переходе
## фокуса (стрелки, стик). Автозагрузка UiSounds; сама подключается ко всем
## кнопкам, которые появляются в игре. Шина Interface — её громкость в настройках.

const CLICK := preload("res://audio/ui_click.wav")
const MOVE := preload("res://audio/ui_move.wav")

var _click_player := AudioStreamPlayer.new()
var _move_player := AudioStreamPlayer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for player in [_click_player, _move_player]:
		player.bus = &"Interface"
		add_child(player)
	_click_player.stream = CLICK
	_move_player.stream = MOVE
	_move_player.volume_db = -8.0
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(_click_player.play)
		node.focus_entered.connect(_on_focus.bind(node))


func _on_focus(button: BaseButton) -> void:
	# Фокус от мыши не озвучиваем — только переход с клавиатуры/геймпада.
	if not button.is_hovered():
		_move_player.play()
