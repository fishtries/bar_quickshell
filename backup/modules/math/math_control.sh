#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  math_control.sh — управление режимом «Математический анализ»
#
#  Использование:
#    math_control.sh start   — запуск сессии (блокировка YouTube, submap, обои, музыка)
#    math_control.sh stop    — завершение сессии (если прогресс = 100%)
# ══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ─── Конфигурация ────────────────────────────────────────────────────────────
VALIDATOR="$SCRIPT_DIR/math_validator.py"
LOCKFILE="/tmp/math_mode.lock"
HOSTS_MARKER="# MATH_MODE_BLOCK"
HOSTS_HELPER="$SCRIPT_DIR/math_hosts_helper.sh"

# Обои для режима матана
MATH_WALLPAPER="$HOME/wallpapers/math.jpg"

# Плейлист/файл/ссылка для фоновой музыки через mpv
MUSIC_SOURCE="https://www.youtube.com/playlist?list=PLfGibfZATlGq6mNVJP_IbPQINKUVAYa9w"
# ─────────────────────────────────────────────────────────────────────────────

info()  { echo "[INFO]  $*"; }
ok()    { echo "[OK]    $*"; }
warn()  { echo "[WARN]  $*"; }
err()   { echo "[ERR]   $*" >&2; }

# ══════════════════════════════════════════════════════════════════════════════
#  start — Начать сессию
# ══════════════════════════════════════════════════════════════════════════════
do_start() {
    if [[ -f "$LOCKFILE" ]]; then
        warn "Сессия уже активна."
        exit 1
    fi

    info "Запуск Math Mode..."

    # 1) Lockfile
    date +%s > "$LOCKFILE"

    # 2) Снапшот
    info "Создаём снапшот..."
    python "$VALIDATOR" --sync 2>/dev/null || warn "Не удалось создать снапшот"

    # 3) Блокировка сайтов (через вспомогательный скрипт, без GUI)
    if [[ -x "$HOSTS_HELPER" ]]; then
        sudo -n "$HOSTS_HELPER" block 2>/dev/null || warn "Не удалось заблокировать сайты (настройте sudoers)."
    fi

    # 4) Submap
    hyprctl dispatch submap MATH_MODE 2>/dev/null || true

    # 5) Обои
    if [[ -f "$MATH_WALLPAPER" ]]; then
        waypaper --wallpaper "$MATH_WALLPAPER" 2>/dev/null || true
    fi

    # 6) Музыка
    mpv --no-video --really-quiet --loop-playlist "$MUSIC_SOURCE" &>/dev/null &
    echo $! > /tmp/math_mpv.pid

    ok "Math Mode АКТИВЕН."
}

# ══════════════════════════════════════════════════════════════════════════════
#  stop — Завершить сессию
# ══════════════════════════════════════════════════════════════════════════════
do_stop() {
    # Проверяем прогресс
    RESULT=$(python "$VALIDATOR" --check 2>/dev/null || echo '{}')

    IS_READY=$(echo "$RESULT" | python -c "import sys,json; d=json.load(sys.stdin); print(d.get('is_ready', False))" 2>/dev/null || echo "False")

    if [[ "$IS_READY" != "True" ]]; then
        err "ВЫХОД ЗАПРЕЩЁН! Допиши лекцию."
        exit 1
    fi

    info "Завершаем сессию..."

    # 1) Разблокировка сайтов (без GUI)
    if [[ -x "$HOSTS_HELPER" ]]; then
        sudo -n "$HOSTS_HELPER" unblock 2>/dev/null || true
    fi

    # 2) Submap reset
    hyprctl dispatch submap reset 2>/dev/null || true

    # 3) Музыка
    if [[ -f /tmp/math_mpv.pid ]]; then
        kill "$(cat /tmp/math_mpv.pid)" 2>/dev/null || true
        rm -f /tmp/math_mpv.pid
    fi

    # 4) Обои
    waypaper --folder "$HOME/wallpapers" --random 2>/dev/null || true

    # 5) Cleanup
    rm -f "$LOCKFILE" /tmp/math_snapshot.md

    ok "Math Mode ДЕАКТИВИРОВАН."
}

# ══════════════════════════════════════════════════════════════════════════════
case "${1:-}" in
    start)  do_start ;;
    stop)   do_stop  ;;
    *)
        echo "Использование: $0 {start|stop}"
        exit 1
        ;;
esac
