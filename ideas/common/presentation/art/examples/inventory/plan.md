# Референс полного инвентаря

**Статус: референс интерфейса и промпты, 07.09.2026.** Это не готовый UI, не игровой ассет и не реализация в текущей 3D-пробе.

## Источник и отзыв автора

Автор приложил [изображение](photo_2026-09-07_18-43-07.jpg) как пример желаемого направления: 3D-пиксельный интерфейс, полноростовой кот, предметные ячейки, характеристики и рюкзак.

Что в нём **не подходит**:

- базовых слотов слишком много;
- рюкзак даёт слишком мало вместимости;
- область рюкзака не должна быть видна, когда рюкзака нет.

Целевой дизайн: ровно 10 начальных ячеек — 5 быстрой панели и 5 карманов. Рюкзак появляется только после экипировки и даёт заметно большую область. Полные правила — в [карточке инвентаря](../../../../design/mechanics/inventory/plan.md).

## Требования к следующему референсу

- 3D pixel art, не плоская мобильная панель;
- Steam Deck/16:10, крупные читаемые подписи и элементы;
- полноростовой антропоморфный кот, видна спина и реальная загруженность рюкзака;
- без рюкзака на экране есть только 5 ячеек быстрой панели и 5 карманов;
- рюкзачная сетка не рисуется вовсе, пока рюкзака нет;
- максимум — 10-й уровень рюкзака; на каждом уровне существует два визуально разных варианта с одинаковой вместимостью;
- ЛКМ показывает перенос предмета между ячейками;
- ПКМ показывает контекстное меню «Использовать» / «Выбросить»;
- UI остаётся оригинальным: не копировать логотипы, текстуры, иконки или компоновку другой игры.

## Промпт: экран без рюкзака

```text
Create an original polished UI concept for a cozy but demanding 3D pixel-art adventure game about an anthropomorphic orange cat travelling home. Show a full-screen Russian inventory interface over a softly blurred isometric countryside road at warm evening light.

Style: high-quality 3D pixel art, clean low-poly geometry, dark moss-green panels, warm parchment item slots, thick charcoal outlines, subtle pixel texture, readable Cyrillic pixel font, Steam Deck friendly 16:10 layout at 1280x800. No copied game UI, logos, branding, or recognizable assets.

Title at top: “ИНВЕНТАРЬ”.

Required layout:
- Exactly 10 starting inventory slots total, no more.
- A clearly labelled “БЫСТРАЯ ПАНЕЛЬ” with exactly 5 horizontal slots.
- A clearly labelled “КАРМАНЫ” with exactly 5 slots.
- Some slots contain original generic survival items: water flask, food, folded map, bandage, fishing rod; some are empty.
- Full-body anthropomorphic orange cat character preview in the center, standing on two legs, no backpack equipped.
- Show compact Russian stat bars: health, hunger, thirst, stamina, speed.
- Show a selected item with a bright pixel outline.
- Near it show a right-click context menu with exactly two clear Russian actions: “Использовать” and “Выбросить”.
- Show a subtle left-click transfer state: one source slot selected and one target slot highlighted.
- Because no backpack is equipped, do not show any backpack inventory grid, locked panel, backpack silhouette, capacity row, or empty backpack space.

Avoid: more than 10 starting slots, mobile portrait UI, tiny unreadable text, photorealism, copied Minecraft UI, game logos, brand icons, real people, weapons focus, clutter.
```

## Промпт: максимальный рюкзак

```text
Use the same original 3D pixel-art inventory UI and the same Russian labels. Show the exact same 5-slot quick bar and 5-slot pockets, plus one of the two visually distinct maximum-level (level 10) backpack variants equipped on the cat’s back. The backpack storage grid is now unlocked and visibly much larger than the 10 base slots: a meaningful multi-row capacity expansion, not a tiny extra strip. Show page controls “1 / 2”: both level-10 backpack variants unlock the second storage page. The 80 kg carried-weight limit is shared across both pages, not doubled.

Show the backpack realistically fuller and larger with visible water, food, rolled blanket, tools and supplies. Show a clear carried-weight readout: “Загрузка: 62 / 80 кг”. Preserve a selected item, left-click source-to-target transfer highlight, and a right-click menu with “Использовать” and “Выбросить”. Keep the scene original, 16:10, Steam Deck readable, and free of copied UI, logos, brands, or copyrighted assets.
```

## Negative prompt

```text
Minecraft logo, copied Minecraft interface, existing game UI, copyrighted characters, real brands, real footballers, photorealism, mobile portrait layout, extra base slots, tiny text, unreadable Cyrillic, cluttered interface, weapon-heavy UI, gore
```

[К примерам](../plan.md) · [К механикам инвентаря](../../../../design/mechanics/inventory/plan.md) · [К оглавлению](../../../../../README.md)
