#!/usr/bin/env bash
# Запуск редактора Godot для 3D-пробы. Подробности — ГАЙД-РЕДАКТОР.md
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
GODOT="$ROOT/../.tools/godot/godot"
PROJECT="$ROOT/3d-probe"

[[ -f "$PROJECT/project.godot" ]] || { echo "Не найден 3d-probe/project.godot рядом со start-editor.sh" >&2; exit 1; }

if [[ ! -x "$GODOT" ]]; then
    echo "Godot не найден в .tools/godot/ — скачаю через start.sh --setup-only..." >&2
    bash "$ROOT/start.sh" --setup-only
fi

exec "$GODOT" --path "$PROJECT" -e "$@"
