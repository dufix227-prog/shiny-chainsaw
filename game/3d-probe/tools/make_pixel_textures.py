"""Рисует маленькие пиксельные текстуры 16×16 для блочного мира.

Запуск: python3 game/3d-probe/tools/make_pixel_textures.py
Результат: game/3d-probe/assets/textures/pixel_own/*.png (собственные, без чужих лицензий).
Одинаковый результат при каждом запуске — генератор с фиксированным seed.
"""

import random
import struct
import zlib
from pathlib import Path

SIZE = 16
OUT = Path(__file__).resolve().parent.parent / "assets" / "textures" / "pixel_own"


def save_png(path: Path, pixels: list[list[tuple[int, int, int]]]) -> None:
    raw = b"".join(b"\x00" + bytes(channel for pixel in row for channel in pixel) for row in pixels)

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def hex_color(value: str) -> tuple[int, int, int]:
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def speckled(seed: int, palette: list[str], weights: list[int]) -> list[list[tuple[int, int, int]]]:
    """Случайные пиксели из палитры — листва, трава, земля."""
    rng = random.Random(seed)
    colors = [hex_color(c) for c in palette]
    return [[rng.choices(colors, weights)[0] for _ in range(SIZE)] for _ in range(SIZE)]


def leaves(seed: int, palette: list[str]) -> list[list[tuple[int, int, int]]]:
    """Листва: пятна тёмного и светлого, чтобы блок читался «пушистым»."""
    pixels = speckled(seed, palette[1:3], [3, 2])
    rng = random.Random(seed + 100)
    dark, light = hex_color(palette[0]), hex_color(palette[3])
    for _ in range(9):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        for dx, dy in [(0, 0), (1, 0), (0, 1)]:
            pixels[(y + dy) % SIZE][(x + dx) % SIZE] = dark
    for _ in range(7):
        pixels[rng.randrange(SIZE)][rng.randrange(SIZE)] = light
    return pixels


def bark_vertical(seed: int, palette: list[str]) -> list[list[tuple[int, int, int]]]:
    """Кора с вертикальными бороздами."""
    rng = random.Random(seed)
    colors = [hex_color(c) for c in palette]
    column_shade = [rng.choice([0, 1, 1, 2]) for _ in range(SIZE)]
    pixels = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            shade = column_shade[x]
            if rng.random() < 0.12:
                shade = min(shade + 1, len(colors) - 1)
            row.append(colors[shade])
        pixels.append(row)
    return pixels


def birch_bark(seed: int) -> list[list[tuple[int, int, int]]]:
    """Берёза: белая кора с чёрными горизонтальными чёрточками."""
    rng = random.Random(seed)
    pixels = speckled(seed, ["#e8e4d8", "#d6d1c3", "#f4f1e8"], [5, 2, 2])
    black, grey = hex_color("#2b2826"), hex_color("#6e6962")
    for _ in range(6):
        x, y, length = rng.randrange(SIZE), rng.randrange(SIZE), rng.randint(2, 5)
        for i in range(length):
            pixels[y][(x + i) % SIZE] = black if i not in (0, length - 1) else grey
    return pixels


def grass_side(seed: int) -> list[list[tuple[int, int, int]]]:
    """Бок верхнего блока земли: трава свисает неровной бахромой на землю."""
    rng = random.Random(seed)
    dirt = speckled(seed, ["#7a5534", "#6a4a2c", "#8c6440", "#5a3e25"], [4, 3, 2, 1])
    grass = speckled(seed + 1, ["#5f9a3a", "#4e8430", "#72ad47"], [4, 3, 2])
    for x in range(SIZE):
        depth = rng.choice([2, 3, 3, 4, 5])
        for y in range(depth):
            dirt[y][x] = grass[y][x]
    return dirt


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    textures = {
        "grass_top": speckled(1, ["#5f9a3a", "#4e8430", "#72ad47", "#3f7028"], [5, 4, 2, 1]),
        "grass_side": grass_side(2),
        "dirt": speckled(3, ["#7a5534", "#6a4a2c", "#8c6440", "#5a3e25"], [4, 3, 2, 1]),
        "path": speckled(4, ["#c19a63", "#b08a55", "#d2ad76", "#9c7747"], [5, 3, 2, 1]),
        "leaves_spruce": leaves(10, ["#123420", "#1e4a2c", "#285a34", "#3a7042"]),
        "leaves_pine": leaves(11, ["#1f4a22", "#2e6130", "#3b733a", "#55894a"]),
        "leaves_birch": leaves(12, ["#4a7a22", "#6a9c30", "#80b23c", "#a4cc5c"]),
        "leaves_oak": leaves(13, ["#284e18", "#3a6a22", "#4a7e2c", "#669a3e"]),
        "leaves_bush": leaves(14, ["#2a5a1e", "#3c742a", "#4c8834", "#6aa448"]),
        "bark_oak": bark_vertical(20, ["#6b4a2e", "#553a22", "#43301c"]),
        "bark_pine": bark_vertical(21, ["#a4643a", "#8a5230", "#6e4026"]),
        "bark_spruce": bark_vertical(22, ["#5a3f2a", "#4a3322", "#3a281a"]),
        "bark_dead": bark_vertical(23, ["#8e8a82", "#76726b", "#5e5b55"]),
        "bark_birch": birch_bark(24),
        "stone": speckled(30, ["#8a8a86", "#767672", "#9c9c96", "#62625e"], [4, 3, 2, 1]),
    }
    for name, pixels in textures.items():
        save_png(OUT / f"{name}.png", pixels)
    print(f"Текстур: {len(textures)} → {OUT}")


if __name__ == "__main__":
    main()
