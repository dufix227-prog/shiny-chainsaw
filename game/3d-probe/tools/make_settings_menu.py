"""Собирает сцену экрана настроек scenes/ui/settings_menu.tscn из списка ниже.

Запуск: python3 game/3d-probe/tools/make_settings_menu.py
Строки можно править и в редакторе Godot, но повторный запуск скрипта
перезапишет сцену — постоянные изменения вносите сюда.
Каждый элемент помечен metadata/setting_key — имя настройки в GameSettings;
строки перебинда — metadata/rebind_action + rebind_slot (Controls).
"""

from pathlib import Path

SCENE = Path(__file__).resolve().parent.parent / "scenes" / "ui" / "settings_menu.tscn"

# [ключ, подпись, вид, параметры]
TABS = [
    ("Graphics", "Графика", [
        ("window_mode", "Режим окна", "option", [["В окне", 0], ["Полный экран", 1], ["Без рамки", 2]]),
        ("vsync", "Вертикальная синхронизация", "check", None),
        ("max_fps", "Ограничение кадров", "option", [["Без ограничения", 0], ["30", 30], ["60", 60], ["90", 90], ["120", 120], ["144", 144]]),
        ("render_scale", "Разрешение 3D", "slider", (0.5, 1.0, 0.05, "percent")),
        ("antialiasing", "Сглаживание", "option", [["Выкл", 0], ["FXAA", 1], ["MSAA ×2", 2], ["MSAA ×4", 3], ["TAA", 4]]),
        ("shadow_quality", "Тени", "option", [["Выкл", 0], ["Низкие", 1], ["Средние", 2], ["Высокие", 3]]),
        ("ambient_occlusion", "Затенение в углах (SSAO)", "check", None),
        ("glow", "Свечение", "check", None),
        ("fog", "Туман и дымка", "check", None),
        ("draw_distance", "Дальность прорисовки", "slider", (100.0, 800.0, 50.0, "number")),
        ("brightness", "Яркость", "slider", (0.6, 1.4, 0.05, "percent")),
        ("pixel_size", "Пиксельность картинки", "option", [["Выкл", 1], ["×2", 2], ["×3", 3], ["×4", 4]]),
    ]),
    ("Interface", "Интерфейс", [
        ("ui_font", "Шрифт", "option", [["Пиксельный", 0], ["Обычный (читаемый)", 1], ["Жирный (читаемый)", 2]]),
        ("ui_scale", "Размер интерфейса", "slider", (0.8, 1.5, 0.05, "percent")),
    ]),
    ("Camera", "Камера", [
        ("camera_mode", "Вид камеры", "option", [["Третье лицо", 0], ["За спиной", 1], ["Первое лицо", 2], ["Своя", 3]]),
        ("camera_distance", "Расстояние до кота", "slider", (2.5, 16.0, 0.5, "number1")),
        ("field_of_view", "Угол обзора", "slider", (55.0, 100.0, 1.0, "degrees")),
        ("camera_height", "Своя камера: высота", "slider", (1.5, 7.0, 0.1, "number1")),
        ("camera_side", "Своя камера: сдвиг вбок", "slider", (-3.0, 3.0, 0.1, "number1")),
        ("camera_pitch", "Своя камера: наклон", "slider", (-60.0, 15.0, 1.0, "degrees")),
    ]),
    ("Controls", "Управление", [
        ("mouse_sensitivity", "Чувствительность мыши", "slider", (0.05, 1.0, 0.01, "percent")),
        ("stick_sensitivity", "Чувствительность стика", "slider", (0.3, 2.5, 0.05, "percent")),
        ("invert_camera_y", "Инвертировать камеру по вертикали", "check", None),
    ]),
    ("Sound", "Звук", [
        ("master_volume", "Общая громкость", "slider", (0.0, 1.0, 0.05, "percent")),
        ("music_volume", "Музыка", "slider", (0.0, 1.0, 0.05, "percent")),
        ("effects_volume", "Эффекты (шаги, машины)", "slider", (0.0, 1.0, 0.05, "percent")),
        ("ambient_volume", "Окружение (лес, ветер)", "slider", (0.0, 1.0, 0.05, "percent")),
        ("interface_volume", "Интерфейс", "slider", (0.0, 1.0, 0.05, "percent")),
        ("voice_volume", "Голоса", "slider", (0.0, 1.0, 0.05, "percent")),
        ("mute_unfocused", "Без звука, когда игра свёрнута", "check", None),
    ]),
]

# Действия для перебинда — порядок как в scenes/controls.gd.
REBIND = [
    ("move_up", "Вперёд"), ("move_down", "Назад"), ("move_left", "Влево"), ("move_right", "Вправо"),
    ("run", "Бег"), ("jump", "Прыжок"), ("look_up", "Камера вверх"), ("look_down", "Камера вниз"),
    ("look_left", "Камера влево"), ("look_right", "Камера вправо"), ("camera_zoom_in", "Камера ближе"),
    ("camera_zoom_out", "Камера дальше"), ("camera_mode", "Вид камеры"), ("pause", "Пауза"),
]


def camel(key: str) -> str:
    return "".join(word.capitalize() for word in key.split("_"))


def node(name: str, kind: str, parent: str, props: list[str]) -> str:
    body = "\n".join(props)
    return f'[node name="{name}" type="{kind}" parent="{parent}"]\n{body}\n' if body else f'[node name="{name}" type="{kind}" parent="{parent}"]\n'


def setting_row(base: str, key: str, label: str, kind: str, options) -> list[str]:
    row = f"{base}/{camel(key)}Row"
    out = [node(f"{camel(key)}Row", "HBoxContainer", base, ["layout_mode = 2", "theme_override_constants/separation = 16"]),
           node("Label", "Label", row, ["custom_minimum_size = Vector2(380, 0)", "layout_mode = 2", f'text = "{label}"'])]
    if kind == "check":
        out.append(node(camel(key), "CheckBox", row, ["layout_mode = 2", "size_flags_horizontal = 3", 'text = "вкл"',
                                                      f'metadata/setting_key = "{key}"']))
    elif kind == "option":
        items = [f'popup/item_{i}/text = "{text}"\npopup/item_{i}/id = {i}' for i, (text, _) in enumerate(options)]
        values = ", ".join(str(value) for _, value in options)
        out.append(node(camel(key), "OptionButton", row, ["layout_mode = 2", "size_flags_horizontal = 3",
                                                          f"item_count = {len(options)}", *items,
                                                          f'metadata/setting_key = "{key}"', f"metadata/option_values = [{values}]"]))
    else:
        low, high, step, fmt = options
        out.append(node(camel(key), "HSlider", row, ["custom_minimum_size = Vector2(0, 28)", "layout_mode = 2",
                                                     "size_flags_horizontal = 3", "size_flags_vertical = 4",
                                                     f"min_value = {low}", f"max_value = {high}", f"step = {step}",
                                                     f'metadata/setting_key = "{key}"', f'metadata/value_format = "{fmt}"']))
        out.append(node("Value", "Label", row, ["custom_minimum_size = Vector2(90, 0)", "layout_mode = 2", "horizontal_alignment = 2"]))
    return out


def rebind_rows(base: str) -> list[str]:
    out = [node("RebindTitle", "Label", base, ["layout_mode = 2", "theme_override_font_sizes/font_size = 22",
                                               "theme_override_colors/font_color = Color(1, 0.82, 0.55, 1)",
                                               'text = "Кнопки (нажмите, затем нужную клавишу; Backspace — очистить)"',
                                               "autowrap_mode = 3"]),
           node("RebindHeader", "HBoxContainer", base, ["layout_mode = 2", "theme_override_constants/separation = 8"])]
    header = f"{base}/RebindHeader"
    for name, text, width in [("Action", "Действие", 200), ("Key1", "Клавиша 1", 185), ("Key2", "Клавиша 2", 185), ("Pad", "Геймпад", 215)]:
        out.append(node(name, "Label", header, [f"custom_minimum_size = Vector2({width}, 0)", "layout_mode = 2",
                                                "theme_override_font_sizes/font_size = 20", f'text = "{text}"']))
    for action, label in REBIND:
        row = f"{base}/Rebind{camel(action)}"
        out.append(node(f"Rebind{camel(action)}", "HBoxContainer", base, ["layout_mode = 2", "theme_override_constants/separation = 8"]))
        out.append(node("Label", "Label", row, ["custom_minimum_size = Vector2(200, 0)", "layout_mode = 2", f'text = "{label}"']))
        for slot, width in [(0, 185), (1, 185), (2, 215)]:
            out.append(node(f"Slot{slot}", "Button", row, [f"custom_minimum_size = Vector2({width}, 0)", "layout_mode = 2",
                                                         "theme_override_font_sizes/font_size = 18", 'text = "—"',
                                                         "clip_text = true", f'metadata/rebind_action = "{action}"',
                                                         f"metadata/rebind_slot = {slot}"]))
    out.append(node("RebindMessage", "Label", base, ["unique_name_in_owner = true", "layout_mode = 2",
                                                     "theme_override_colors/font_color = Color(1, 0.82, 0.55, 1)",
                                                     "theme_override_font_sizes/font_size = 20", "autowrap_mode = 3"]))
    out.append(node("ResetControls", "Button", base, ["unique_name_in_owner = true", "layout_mode = 2",
                                                      "size_flags_horizontal = 0", 'text = "Сбросить кнопки"']))
    return out


def main() -> None:
    out = ['''[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scenes/ui/settings_menu.gd" id="1_script"]
[ext_resource type="Theme" path="res://scenes/ui/menu_theme.tres" id="2_theme"]

[node name="SettingsMenu" type="Control"]
process_mode = 3
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme = ExtResource("2_theme")
script = ExtResource("1_script")
''',
           node("Dim", "ColorRect", ".", ["layout_mode = 1", "anchors_preset = 15", "anchor_right = 1.0", "anchor_bottom = 1.0",
                                          "grow_horizontal = 2", "grow_vertical = 2", "color = Color(0.02, 0.02, 0.03, 0.55)"]),
           node("Panel", "PanelContainer", ".", ["layout_mode = 1", "anchors_preset = 8", "anchor_left = 0.5", "anchor_top = 0.5",
                                                 "anchor_right = 0.5", "anchor_bottom = 0.5", "offset_left = -470.0",
                                                 "offset_top = -360.0", "offset_right = 470.0", "offset_bottom = 360.0",
                                                 "grow_horizontal = 2", "grow_vertical = 2"]),
           node("Rows", "VBoxContainer", "Panel", ["layout_mode = 2", "theme_override_constants/separation = 12"]),
           node("Title", "Label", "Panel/Rows", ["layout_mode = 2", 'theme_type_variation = &"TitleLabel"',
                                                 "theme_override_font_sizes/font_size = 28", 'text = "Настройки"']),
           node("Tabs", "TabContainer", "Panel/Rows", ["unique_name_in_owner = true", "layout_mode = 2", "size_flags_vertical = 3",
                                                        "current_tab = 0"])]
    for index, (tab, title, rows) in enumerate(TABS):
        out.append(node(tab, "ScrollContainer", "Panel/Rows/Tabs", ["layout_mode = 2", "horizontal_scroll_mode = 0",
                                                                    f'metadata/tab_title = "{title}"', f"metadata/_tab_index = {index}"]))
        base = f"Panel/Rows/Tabs/{tab}/List"
        out.append(node("List", "VBoxContainer", f"Panel/Rows/Tabs/{tab}", ["layout_mode = 2", "size_flags_horizontal = 3",
                                                                            "theme_override_constants/separation = 10"]))
        for key, label, kind, options in rows:
            out.extend(setting_row(base, key, label, kind, options))
        if tab == "Interface":
            out.append(node("FontSample", "Label", base, ["layout_mode = 2", "autowrap_mode = 3",
                                                          'text = "Пример текста: халявная клубника через 500 метров. 0123456789"']))
        if tab == "Controls":
            out.extend(rebind_rows(base))
        if tab == "Sound":
            out.append(node("SoundNote", "Label", base, ["layout_mode = 2", "autowrap_mode = 3",
                                                         "theme_override_font_sizes/font_size = 18",
                                                         'text = "Музыки и голосов в игре пока нет — ползунки для них готовы заранее."']))
    out.append(node("Buttons", "HBoxContainer", "Panel/Rows", ["layout_mode = 2", "theme_override_constants/separation = 16"]))
    out.append(node("BackButton", "Button", "Panel/Rows/Buttons", ["unique_name_in_owner = true", "layout_mode = 2", 'text = "Назад"']))
    out.append(node("DefaultsButton", "Button", "Panel/Rows/Buttons", ["unique_name_in_owner = true", "layout_mode = 2",
                                                                        'text = "По умолчанию"']))
    SCENE.write_text("\n".join(out), encoding="utf-8")
    print("Экран настроек записан:", SCENE)


if __name__ == "__main__":
    main()
