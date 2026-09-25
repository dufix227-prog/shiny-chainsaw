# Структура проекта «10 000 метров до дома»

Это карта: **где что хранить и где искать**. Она не заменяет тематические планы, не превращает все идеи в канон и не требует внешних сервисов вроде Notion или Jira.

## С чего начинать

1. [README.md](README.md) — запуск и главная навигация.
2. Этот файл — физическая структура папок.
3. [CONTEXT.md](CONTEXT.md) — что сейчас сделано и что открыто.
4. [AGENTS.md](AGENTS.md) — правила работы с авторскими решениями и кодом.
5. [Оглавление планов](ideas/README.md) — подробная тематическая навигация.

## Карта верхнего уровня

```text
PROJECT_STRUCTURE.md    карта структуры проекта
README.md               вход, запуск и ссылки
AGENTS.md               правила работы
CONTEXT.md              актуальная передача состояния
MODELS.md               короткий журнал моделей
game/start.sh           запуск текущей пробы на Linux / Steam Deck

game/                   исходники и реальные игровые проверки
ideas/                  дизайн, решения автора, референсы и архивы
implementation-plan/    порядок разработки, архитектура и приёмка
prototypes/             исторические указатели на пробы
```

## Код игры — `game/`

**Код, сцены, игровые данные и автоматические тесты живут только здесь.** Не добавлять сюда сценарные тексты, архивы идей или общие дизайн-документы.

| Путь | Назначение |
| --- | --- |
| [game/README.md](game/README.md) | Вход в игровую часть проекта. |
| [game/3d-probe/](game/3d-probe/README.md) | Реальная маленькая 3D-проба Godot, не весь пролог. |
| `game/3d-probe/scripts/` | Поведение кота, мира, маршрута, HUD, карты, инвентаря, звука и ввода. |
| `game/3d-probe/data/` | Временные параметры пробы, например профиль нужд. |
| `game/3d-probe/audio/` | Временные локальные звуки пробы. |
| `game/3d-probe/shaders/` | Шейдеры, сейчас — вода. |
| `game/3d-probe/tests/` | Проверки движения, карты, нужд, инвентаря, меню и рендера. |
| `game/tests/` | Проверки лаунчера `game/start.sh`. |
| [game/steam-deck/README.md](game/steam-deck/README.md) | Запуск и управление на Steam Deck. |

### Статус пробы

Текущая проба проверяет кота, ходьбу, бег, прыжок, нужды, отдых, одну еду, карту, камеры, меню и звук. Она **не** является полным прологом, полным инвентарём, основной историей или релизной сборкой.

## Дизайн и решения автора — `ideas/`

**Дизайн, сюжет, механики, референсы и текстовые решения живут здесь.** Не весь материал в `ideas/` является каноном: каждый план обязан различать «подтверждено автором», «предложение», «открыто» и «отложено».

| Область | Где искать |
| --- | --- |
| Авторские сообщения | [ideas/requests/](ideas/requests/user-request.md) — дословный журнал, не переписывать цитаты. |
| Полная история и режимы | [ideas/FULL_PLAN.md](ideas/FULL_PLAN.md) — единая точка входа: пролог, 10 000 м, бесконечный режим и кооп; события по метрам, исходы и явные пробелы. |
| Пролог 500 м | [ideas/prologue/](ideas/prologue/plan.md) |
| Основная история и события | [ideas/main-story/](ideas/main-story/lore/plan.md) |
| Подземная арка 5000–6000 м | [ideas/main-story/arcs/underground-5000-6000/](ideas/main-story/arcs/underground-5000-6000/00-README-arc.md) — канон основной истории; отдельно помеченные неподтверждённые детали остаются предложениями. |
| Персонажи и концовки | [characters/](ideas/main-story/characters/README.md) · [endings/](ideas/main-story/endings/plan.md) |
| Общие механики, подача и производство | [ideas/common/](ideas/common/design/concept/plan.md) |
| Бесконечный режим | [ideas/endless/](ideas/endless/plan.md) |
| Кооперативный режим | [ideas/coop/](ideas/coop/plan.md) |
| Предложения моделей | [ideas/archive/model-proposals/](ideas/archive/model-proposals/README.md) — отдельно от канона. |

## Механики, характеристики, вода и рюкзак

| Тема | Текущее место | Статус |
| --- | --- | --- |
| Характеристики героя | [ideas/common/design/mechanics/characteristics.md](ideas/common/design/mechanics/characteristics.md) | Действующая карта показателей; полные числа и состав ещё развиваются. |
| Общие механики | [ideas/common/design/mechanics/](ideas/common/design/mechanics/plan.md) | Правила игры, не код. |
| Управление и будущий полный инвентарь | [interaction/](ideas/common/design/mechanics/interaction/plan.md) | Контракт действий, телефон, перебинд и будущие окна. |
| Полный инвентарь и рюкзак | [inventory/](ideas/common/design/mechanics/inventory/plan.md) | 5 быстрых слотов + 5 карманов, 20 вариантов / 10 уровней, скрытая безрюкзачная область, будущая вместимость/вес, ЛКМ/ПКМ и выброс на землю. |
| Отношения персонажей | [relationships/](ideas/common/design/mechanics/relationships/plan.md) | Отдельные 0–100 и тип связи у каждого персонажа; инфо-бар, пороги и конкретные реакции. |
| Вода как визуальный объект пробы | [game/3d-probe/shaders/water.gdshader](game/3d-probe/shaders/water.gdshader) | Реальный шейдер, не шкала жажды. |
| Вода как будущая потребность | [ideas/common/design/gameplay/](ideas/common/design/gameplay/plan.md) | Требует отдельного подтверждённого баланса. |
| UI-проба инвентаря | [game/3d-probe/scripts/probe_inventory.gd](game/3d-probe/scripts/probe_inventory.gd) и [inventory_hud.gd](game/3d-probe/scripts/inventory_hud.gd) | 5+5, тестовые рюкзаки, перенос/выброс на землю/повторный подбор; не финальная прогрессия 20 вариантов. |
| План тестового подбора | [implementation-plan/3d-probe/inventory/](implementation-plan/3d-probe/inventory/plan.md) | Границы уже существующей маленькой пробы. |

### Будущий рюкзак

Полный рюкзак — отдельная система, не расширение текущей еды одним файлом. Будущие правила веса, отображения на спине, уровней рюкзака, доступных ячеек и предела **80 кг** должны попасть в отдельную карточку внутри `ideas/common/design/mechanics/` после того, как автор одобрит визуальный референс. В коде ему будут соответствовать отдельные данные/система в `game/`, а не тексты планов.

## Графика, UI-референсы и промпты

| Что | Где хранить |
| --- | --- |
| Общий визуальный стиль | [ideas/common/presentation/art/](ideas/common/presentation/art/plan.md) |
| Анимационные требования пролога | [ideas/prologue/animation/](ideas/prologue/animation/plan.md) |
| Общие примеры и варианты | [ideas/common/presentation/art/examples/](ideas/common/presentation/art/examples/plan.md) |
| Арт-референсы | `ideas/common/presentation/art/references/` |
| Реальный UI пробы | `game/3d-probe/scripts/` — `inventory_hud.gd`, `needs_hud.gd`, `menu_hud.gd`, `full_map_hud.gd` |
| Запросы автора и промпты | [ideas/requests/](ideas/requests/user-request.md); [референс инвентаря и промпты](ideas/common/presentation/art/examples/inventory/plan.md); новые промпты — рядом с соответствующим UI/арт-планом, а не в коде |

Генераторная картинка — **референс**, не готовый игровой ассет. Перед добавлением внешнего ассета проверять лицензию и права; не складывать случайно скачанные файлы в `game/`.

## Реализация, тесты и выпуск

| Задача | Где хранить |
| --- | --- |
| Очерёдность технической работы | [implementation-plan/](implementation-plan/README.md) |
| Архитектура и приёмка будущего пролога | [implementation-plan/prologue/](implementation-plan/prologue/plan.md) |
| Передача следующей модели | [implementation-plan/handoff/](implementation-plan/handoff/plan.md) |
| Тесты текущей пробы | `game/3d-probe/tests/` |
| Тесты запуска | `game/tests/` |
| Планы релиза | [ideas/common/production/release/](ideas/common/production/release/plan.md) |
| Запуск на Deck/Linux | [game/start.sh](game/start.sh) и [game/steam-deck/README.md](game/steam-deck/README.md) |

Успешные тесты пробы не означают, что полный пролог готов или что игра Steam Deck Verified. Физический отзыв автора и отдельная приёмка остаются важнее одной автоматической проверки.

## Архивы и история

| Путь | Что это |
| --- | --- |
| [ideas/archive/model-proposals/](ideas/archive/model-proposals/README.md) | Раздельные наборы предложений Muse Spark, DeepSeek и GLM; **не канон**. |
| [ideas/archive/model-proposals/hoplite-working/](ideas/archive/model-proposals/hoplite-working/README.md) | Предложения текущих моделей, тоже не канон до выбора автора. |
| `prototypes/` | Исторические указатели и старые пробы; не выдавать за текущую игру. |
| [MODELS.md](MODELS.md) | Кто и что делал, кратко. |

Всегда искать действующее правило сначала в тематическом плане, а не в архиве модели.

## Правила для новых файлов

1. **Новый код, сцена, игровой ресурс или тест** → `game/`.
2. **Новая авторская механика, персонаж, история, UI-решение или баланс** → подходящая тема в `ideas/`.
3. **Технический порядок, архитектура, миграция, приёмка** → `implementation-plan/`.
4. **Пакет идей отдельной модели** → `ideas/archive/model-proposals/<источник>/`; не смешивать с действующими решениями.
5. **Референс/генераторный промпт** → рядом с соответствующим арт- или UI-планом, с пометкой «референс» или «проба».
6. Не создавать один огромный файл на всю игру и не дублировать один факт в коде, плане и архиве без ссылки между ними.
7. При смене корневой структуры обновлять этот файл; при обычной правке механики обновлять тематический план, а не карту структуры.

[К главному README](README.md) · [К оглавлению идей](ideas/README.md)
