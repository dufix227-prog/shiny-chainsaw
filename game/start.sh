#!/usr/bin/env bash
set -euo pipefail

VERSION="4.7.2"
ARCHIVE="Godot_v${VERSION}-stable_linux.x86_64.zip"
MEMBER="Godot_v${VERSION}-stable_linux.x86_64"
ARCHIVE_SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
BINARY_SHA512="ac9f3af3d8b62237694bc03e7422b8f7b1a39095cf4eeaa8361b7465f13bc9dbaad47f60ac0ac217c9f0b2b3712be207039cd83953f4c72087214bd0357cabbc"

fail() { printf 'Ошибка запуска: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "Нужна команда $1. Скрипт не меняет системные пакеты."; }

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    printf '%s\n' \
        'Запуск 3D-пробы: bash ./start.sh [аргументы Godot]' \
        '  --setup-only              подготовить движок и проект без окна игры' \
        '  --fullscreen              запустить в полноэкранном режиме' \
        '  --headless --quit-after 60 проверочный запуск без графики' \
        'GODOT_BIN=/полный/путь      использовать свой Godot 4.7.2 stable' \
        'Первый запуск может скачать официальный движок; далее работает офлайн.' \
        'Никаких sudo, Proton, браузера или export templates не требуется.'
    exit 0
fi

[[ "$(uname -s)" == "Linux" ]] || fail "Этот start.sh рассчитан на Linux / Steam Deck."
[[ "$(uname -m)" == "x86_64" ]] || fail "Нужен Linux x86_64; другая архитектура этим скриптом не поддерживается."
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT="$ROOT/3d-probe"
[[ -f "$PROJECT/project.godot" ]] || fail "Распакуй весь архив репозитория: рядом со start.sh (в папке game/) нужна папка 3d-probe."

setup_only=false
if [[ "${1:-}" == "--setup-only" ]]; then
    setup_only=true
    shift
    [[ $# == 0 ]] || fail "--setup-only используется без других аргументов."
fi

matches_version() {
    local reported
    [[ -x "$1" ]] || return 1
    reported="$("$1" --version 2>/dev/null)" || return 1
    [[ "$reported" == "$VERSION.stable" || "$reported" == "$VERSION.stable."* ]]
}

matches_digest() {
    local actual
    [[ -f "$1" ]] || return 1
    actual="$(sha512sum < "$1")" || return 1
    [[ "${actual%% *}" == "$2" ]]
}

install_editor() (
    local_cache="$1"
    need curl
    need unzip
    mkdir -p -- "$local_cache"
    temporary="$(mktemp -d "$local_cache/.install.XXXXXX")"
    trap 'rm -rf -- "$temporary"' EXIT
    printf 'Скачиваю официальный Godot %s (только движок для запуска)…\n' "$VERSION"
    curl --fail --location --show-error --proto '=https' --proto-redir '=https' \
        --connect-timeout 20 --max-time 600 --retry 2 \
        --output "$temporary/editor.zip" \
        "https://github.com/godotengine/godot/releases/download/${VERSION}-stable/$ARCHIVE" \
        || fail "Не удалось скачать движок. Проверь сеть и повтори запуск; неполная загрузка не будет использована."
    matches_digest "$temporary/editor.zip" "$ARCHIVE_SHA512" \
        || fail "Контрольная сумма архива не совпала. Ничего из него не запускалось."
    # Extract only the pinned executable, never arbitrary paths from the archive.
    unzip -p "$temporary/editor.zip" "$MEMBER" > "$temporary/godot" \
        || fail "Не удалось распаковать движок."
    matches_digest "$temporary/godot" "$BINARY_SHA512" \
        || fail "Контрольная сумма движка не совпала. Запуск отменён."
    chmod 755 "$temporary/godot"
    mv -f -- "$temporary/godot" "$local_cache/godot"
)

engine=""
if [[ -n "${GODOT_BIN:-}" ]]; then
    engine="$GODOT_BIN"
    matches_version "$engine" || fail "GODOT_BIN должен указывать на исполняемый файл Godot $VERSION stable."
elif matches_version "$ROOT/../.tools/godot/godot"; then
    engine="$ROOT/../.tools/godot/godot"
else
    for candidate in godot4 godot; do
        resolved="$(command -v "$candidate" || true)"
        if [[ -n "$resolved" ]] && matches_version "$resolved"; then
            engine="$resolved"
            break
        fi
    done
fi

if [[ -z "$engine" ]]; then
    need sha512sum
    cache_root="${XDG_CACHE_HOME:-${HOME:?Не задан HOME}/.cache}"
    [[ "$cache_root" == /* ]] || fail "XDG_CACHE_HOME должен быть абсолютным путём."
    cache="$cache_root/10000-metres-probe/godot-$VERSION-linux-x86_64"
    if ! matches_digest "$cache/godot" "$BINARY_SHA512"; then
        install_editor "$cache"
    fi
    engine="$cache/godot"
    matches_version "$engine" || fail "Godot не запустился. Его сообщение: выполни \"$engine\" --version в терминале."
fi

printf 'Подготавливаю текущие исходники пробы…\n'
import_log="$(mktemp)"
trap 'rm -f -- "$import_log"' EXIT
if ! "$engine" --headless --path "$PROJECT" --editor --import --quit > "$import_log" 2>&1 \
        || grep -Eq 'SCRIPT ERROR:|(^|[[:space:]])ERROR:|Parse Error' "$import_log"; then
    cat "$import_log" >&2
    fail "Импорт проекта завершился с ошибкой. Окно игры не открывалось."
fi
rm -f -- "$import_log"
trap - EXIT

if $setup_only; then
    printf 'Движок и проект готовы. Для игры: bash game/start.sh\n'
    exit 0
fi
printf 'Запускаю пробу. WASD — идти, F — прямо, N — нужды, E — еда / подбор, B — инвентарь, Space — отдых, P — пауза, Q — качество.\n'
exec "$engine" --path "$PROJECT" "$@"
