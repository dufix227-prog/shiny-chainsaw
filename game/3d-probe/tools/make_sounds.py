"""Синтезирует собственные временные звуки (без чужих лицензий).

Запуск: python3 game/3d-probe/tools/make_sounds.py
Результат: game/3d-probe/audio/{engine_loop,whoosh,ui_click,ui_move}.wav.
Одинаковый результат при каждом запуске — генератор с фиксированным seed.
Это заглушки до настоящих звуков (план: ideas/common/presentation/audio/plan.md).
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "audio"


def save(name: str, samples: list[float]) -> None:
    peak = max(0.001, max(abs(s) for s in samples))
    with wave.open(str(OUT / f"{name}.wav"), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.85 * 32767)) for s in samples))


def engine_loop() -> list[float]:
    """Гул мотора: низкий «пилообразный» тон с гармониками и шумом.
    Частоты кратны 1 Гц, длина ровно 1 с — петля сходится без щелчка."""
    rng = random.Random(1)
    count = RATE
    noise = [rng.uniform(-1, 1) for _ in range(count)]
    smooth = 0.0
    out = []
    for i in range(count):
        t = i / RATE
        tone = sum(math.sin(2 * math.pi * 55 * k * t) / k for k in range(1, 7))
        wobble = 1.0 + 0.25 * math.sin(2 * math.pi * 6 * t)
        smooth += (noise[i] - smooth) * 0.08
        out.append(tone * 0.5 * wobble + smooth * 0.9)
    return out


def whoosh() -> list[float]:
    """Свист полёта: шум, у которого «окно» частот плавно поднимается."""
    rng = random.Random(2)
    count = int(RATE * 1.2)
    low = band = 0.0
    out = []
    for i in range(count):
        t = i / count
        cutoff = 0.02 + 0.3 * t
        low += (rng.uniform(-1, 1) - low) * cutoff
        band += (low - band) * cutoff * 0.5
        envelope = math.sin(math.pi * t) ** 1.5
        out.append((low - band) * envelope)
    return out


def click(length: float, pitch: float, seed: int) -> list[float]:
    """Короткий мягкий щелчок интерфейса."""
    rng = random.Random(seed)
    count = int(RATE * length)
    out = []
    for i in range(count):
        t = i / RATE
        envelope = math.exp(-t * 90)
        out.append((math.sin(2 * math.pi * pitch * t) + rng.uniform(-0.2, 0.2)) * envelope)
    return out


def main() -> None:
    save("engine_loop", engine_loop())
    save("whoosh", whoosh())
    save("ui_click", click(0.08, 880, 3))
    save("ui_move", click(0.05, 1320, 4))
    print("Звуки записаны в", OUT)


if __name__ == "__main__":
    main()
