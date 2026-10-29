#!/usr/bin/env bash
# Build and exercise Vaela in a private, software-rendered 1280x800 KWin session.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/fedora.sh
run_in_container test-headless.sh "$@"
export LANG=C.UTF-8
export VAELA_TEST_BUILD="$PWD/build/native$SUFFIX"
cmake -S . -B "$VAELA_TEST_BUILD" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib64
cmake --build "$VAELA_TEST_BUILD" --parallel
ctest --test-dir "$VAELA_TEST_BUILD" --output-on-failure
stage="$PWD/build/test-stage$SUFFIX"
DESTDIR="$stage" cmake --install "$VAELA_TEST_BUILD"
cp "$VAELA_TEST_BUILD/libvaela-input-probe.so" "$stage/usr/lib64/qt6/plugins/kwin/plugins/"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -m 700 "$scratch/runtime" "$scratch/config" "$scratch/data" "$scratch/cache"
export XDG_RUNTIME_DIR="$scratch/runtime" XDG_CONFIG_HOME="$scratch/config"
export XDG_DATA_HOME="$scratch/data" XDG_CACHE_HOME="$scratch/cache"
export XDG_CONFIG_DIRS="$stage/usr/share/vaela/xdg:/etc/xdg"
export QT_PLUGIN_PATH="$stage/usr/lib64/qt6/plugins:${QT_PLUGIN_PATH:-/usr/lib64/qt6/plugins}"
export PATH="$stage/usr/bin:$PATH" VAELA_QML="$stage/usr/share/vaela/Main.qml"
export QT_FORCE_STDERR_LOGGING=1
export QT_LOGGING_RULES="qt.svg.warning=false"
export VAELA_TEST_SESSION=1
export VAELA_TEST_VERSION="$(sed -n 's/^project(vaela VERSION \([^ ]*\).*/\1/p' CMakeLists.txt)"
export VAELA_SESSION=1 QT_QPA_PLATFORM=offscreen LIBGL_ALWAYS_SOFTWARE=1 KWIN_COMPOSE=Q
# Pin one workspace so the add/rename/remove assertions use a known ID.
printf '[Desktops]\nNumber=1\nRows=1\n' > "$scratch/config/kwinrc"
timeout 45 dbus-run-session -- kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 --exit-with-session "$PWD/tests/session.sh"
