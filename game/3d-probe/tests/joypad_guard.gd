extends RefCounted

## Заглушка живого контроллера Steam Deck для headless-тестов: физические
## joypad-события доходят даже без окна и сбивают кота с дороги посреди прогона.
## Сюиты без joypad-сценариев вызывают strip() сразу после создания пробы;
## сюиты, которые сами шлют joypad-события (inventory, menu), не вызывают.

static func strip() -> void:
	for action_name in InputMap.get_actions():
		var events := InputMap.action_get_events(action_name).duplicate()
		for event: InputEvent in events:
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				InputMap.action_erase_event(action_name, event)
