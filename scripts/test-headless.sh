#!/usr/bin/env bash
# Build and exercise Vela in a private, software-rendered 1280x800 KWin session.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -e /run/.containerenv ] || exec distrobox enter vela-dev -- "$PWD/scripts/test-headless.sh" "$@"
export VELA_TEST_BUILD="$PWD/build/native"
cmake -S . -B "$VELA_TEST_BUILD" -DCMAKE_INSTALL_PREFIX=/usr
cmake --build "$VELA_TEST_BUILD" --parallel
ctest --test-dir "$VELA_TEST_BUILD" --output-on-failure
stage="$PWD/build/test-stage"
DESTDIR="$stage" cmake --install "$VELA_TEST_BUILD"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -m 700 "$scratch/runtime" "$scratch/config" "$scratch/data" "$scratch/cache"
export XDG_RUNTIME_DIR="$scratch/runtime" XDG_CONFIG_HOME="$scratch/config"
export XDG_DATA_HOME="$scratch/data" XDG_CACHE_HOME="$scratch/cache"
export XDG_CONFIG_DIRS="$stage/usr/share/vela/xdg:/etc/xdg"
export QT_PLUGIN_PATH="$stage/usr/lib64/qt6/plugins:${QT_PLUGIN_PATH:-/usr/lib64/qt6/plugins}"
export PATH="$stage/usr/bin:$PATH" VELA_QML="$stage/usr/share/vela/Main.qml"
export VELA_SESSION=1 QT_QPA_PLATFORM=offscreen LIBGL_ALWAYS_SOFTWARE=1 KWIN_COMPOSE=Q
# Pin one workspace so the add/rename/remove assertions use a known ID.
printf '[Desktops]\nNumber=1\nRows=1\n' > "$scratch/config/kwinrc"
timeout 25 dbus-run-session -- kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 --exit-with-session "$PWD/tests/session.sh"
