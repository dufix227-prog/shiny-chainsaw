extends RefCounted

var portions := 0

func add_portion() -> void:
	portions += 1

func consume_portion() -> bool:
	if portions <= 0:
		return false
	portions -= 1
	return true
