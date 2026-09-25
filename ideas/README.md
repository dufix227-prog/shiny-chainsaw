# Планы игры «10 000 метров до дома»

Здесь только навигация. Сначала открывай [полный план](FULL_PLAN.md), затем — подробный документ нужной темы. Статусы внутри планов различают канон автора, предложения и недописанные места.

[Правила агентов](../AGENTS.md) · [Структура проекта](../PROJECT_STRUCTURE.md) · [Общий контекст](../CONTEXT.md) · [Локальная версия](../LOCAL_CONTEXT.md) · [Hoplite-версия](../game/HOPLITE_CONTEXT.md)

## Главный план

| Документ | Что внутри |
| --- | --- |
| [FULL_PLAN.md](FULL_PLAN.md) | Единая история по метрам: пролог 500 м, основная история 10 000 м, каноническая подземная арка 5000–6000 м, бесконечный режим, кооп, концовки и явные пробелы. |

## Пролог — `prologue/`

| Тема | Документ |
| --- | --- |
| Общий план пролога | [prologue/plan.md](prologue/plan.md) |
| Полная роспись и каркас сцен | [story-full.md](prologue/story-full.md) · [story-skeleton.md](prologue/story-skeleton.md) |
| НПС и события | [npcs-events.md](prologue/npcs-events.md) |
| Ключевые карточки | [фывфыв](prologue/fyvfyv.md) · [Стинт](prologue/stint.md) · [Братишкин](prologue/bratishkin.md) · [бабушка](prologue/babushka.md) · [кража](prologue/strawberry-heist.md) · [церковь](prologue/church.md) · [концовка побега](prologue/escape-ending.md) · [концовка с машиной](prologue/car-ending.md) · [рыбалка](prologue/fishing.md) |
| Темп и масштаб | [prologue/pacing/plan.md](prologue/pacing/plan.md) |
| Разбор текстовых пробелов | [prologue/review/plan.md](prologue/review/plan.md) · [передача](prologue/review/handoff.md) |
| Пробы графики и анимационные требования | [prologue/art/plan.md](prologue/art/plan.md) · [prologue/animation/plan.md](prologue/animation/plan.md) |

## Основная история — `main-story/`

| Тема | Документ |
| --- | --- |
| Карта истории и события | [main-story/lore/plan.md](main-story/lore/plan.md) · [индекс событий](main-story/lore/events/README.md) |
| Каноническая подземная арка 5000–6000 м | [main-story/arcs/underground-5000-6000/00-README-arc.md](main-story/arcs/underground-5000-6000/00-README-arc.md) |
| Персонажи | [main-story/characters/README.md](main-story/characters/README.md) |
| Концовки | [main-story/endings/plan.md](main-story/endings/plan.md) |
| Телефон и связь | [main-story/phone/plan.md](main-story/phone/plan.md) |
| Семь грехов и церковь | [main-story/sins/plan.md](main-story/sins/plan.md) |
| Камео и витуберши | [main-story/lore/cameos/plan.md](main-story/lore/cameos/plan.md) · [main-story/vtubers/plan.md](main-story/vtubers/plan.md) |

## Общие правила игры — `common/`

### Дизайн

| Тема | Документ |
| --- | --- |
| Концепция и игровой цикл | [concept](common/design/concept/plan.md) · [gameplay](common/design/gameplay/plan.md) · [структура игры и механик](common/design/game-structure/plan.md) |
| Механики и характеристики | [механики](common/design/mechanics/plan.md) · [характеристики](common/design/mechanics/characteristics.md) · [200 предметов](common/design/mechanics/items-200.md) |
| Управление, инвентарь и отношения | [взаимодействия](common/design/mechanics/interaction/plan.md) · [инвентарь](common/design/mechanics/inventory/plan.md) · [отношения](common/design/mechanics/relationships/plan.md) |
| Сложность и сохранения | [сложность](common/design/difficulty/plan.md) · [сохранения](common/design/saves/plan.md) |
| Внешность и редактор внешности | [внешность и редактор](common/design/appearance/plan.md) — запрошено автором 19.09.2026, реализации нет |

### Системы, подача и производство

| Тема | Документ |
| --- | --- |
| Достижения, подсказки и мини-игры | [достижения](common/systems/achievements/plan.md) · [подсказки](common/systems/hints/plan.md) · [мини-игры](common/systems/minigames/plan.md) |
| Монетизация и секреты | [монетизация](common/systems/monetization/plan.md) · [секреты](common/systems/secrets/plan.md) |
| Диалоги, графика, звук и музыка | [диалоги](common/presentation/dialogues/plan.md) · [графика](common/presentation/art/plan.md) · [звук](common/presentation/audio/plan.md) · [музыка](common/presentation/music/plan.md) |
| Движок, выпуск и работа с LLM | [движок](common/production/engine/plan.md) · [выпуск](common/production/release/plan.md) · [LLM-разработка](common/production/ai-development/plan.md) |
| Вопросы, опросник и будущие задачи | [вопросы](common/planning/questions/README.md) · [опросник](common/planning/questionnaire/plan.md) · [будущее](common/planning/future/plan.md) |
| Разбор исходного мини-плана | [common/planning/review/mini-plan.md](common/planning/review/mini-plan.md) |

## Бесконечный режим — `endless/`

[План режима до 100 000 м и замка](endless/plan.md) — авторский набросок; подробные события и приоритет ещё открыты.

## Кооперативный режим — `coop/`

[Подробный план коопа](coop/plan.md) — будущий режим после одиночной версии: игроки могут драться, поднимать товарищей и вместе возвращаются к контрольной точке, если вся команда повержена. Сюжет, формат сети и точные правила недописаны.

## Источники и архивы

| Раздел | Что хранится |
| --- | --- |
| [requests/](requests/user-request.md) | Дословный журнал сообщений автора. Неизменяемые вложения: [mini-plan/source.txt](requests/mini-plan/source.txt) и [answers-2026-09-05/source.txt](requests/answers-2026-09-05/source.txt). |
| [archive/model-proposals/](archive/model-proposals/README.md) | Раздельные наборы предложений моделей. Они не становятся каноном без выбора автора. |

## Отдельно от дизайн-планов

Техническая последовательность, архитектура и проверки находятся в корневом [implementation-plan/](../implementation-plan/README.md). Игровой код и ресурсы, когда они присутствуют в рабочей копии, находятся в `game/` и не смешиваются с `ideas/`.
