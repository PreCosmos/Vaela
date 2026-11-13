#!/usr/bin/env bash
# Build and exercise Vaela in a private 1280x800 KWin session. KWin 6.8 composites only with OpenGL,
# so this needs a GPU driver the container can use.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "${VAELA_NATIVE:-0}" = 1 ]; then
    SUFFIX=-arch
    libdir=lib
    libexecdir=lib
else
    . scripts/fedora.sh
    run_in_container test-headless.sh "$@"
    libdir=lib64
    libexecdir=libexec
fi
export LANG=C.UTF-8
export VAELA_TEST_BUILD="$PWD/build/native$SUFFIX"
cmake -S . -B "$VAELA_TEST_BUILD" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR="$libdir" -DCMAKE_INSTALL_LIBEXECDIR="$libexecdir"
cmake --build "$VAELA_TEST_BUILD" --parallel "${VAELA_BUILD_JOBS:-2}"
XDG_CACHE_HOME="$VAELA_TEST_BUILD/test-cache" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    dbus-run-session -- ctest --test-dir "$VAELA_TEST_BUILD" --output-on-failure --timeout 60
stage="$PWD/build/test-stage$SUFFIX"
DESTDIR="$stage" cmake --install "$VAELA_TEST_BUILD"
cp "$VAELA_TEST_BUILD/libvaela-input-probe.so" "$stage/usr/$libdir/qt6/plugins/kwin/plugins/"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
# Fedora calls this qdbus-qt6; Arch installs qdbus6.
if ! command -v qdbus-qt6 >/dev/null && command -v qdbus6 >/dev/null; then
    mkdir -p "$scratch/bin"
    ln -s "$(command -v qdbus6)" "$scratch/bin/qdbus-qt6"
    export PATH="$scratch/bin:$PATH"
fi
mkdir -m 700 "$scratch/runtime" "$scratch/config" "$scratch/data" "$scratch/cache"
export XDG_RUNTIME_DIR="$scratch/runtime" XDG_CONFIG_HOME="$scratch/config"
export XDG_DATA_HOME="$scratch/data" XDG_CACHE_HOME="$scratch/cache"
export XDG_CONFIG_DIRS="$stage/usr/share/vaela/xdg:/etc/xdg"
export QT_PLUGIN_PATH="$stage/usr/$libdir/qt6/plugins:${QT_PLUGIN_PATH:-/usr/$libdir/qt6/plugins}"
export PATH="$stage/usr/bin:$PATH" VAELA_QML="$stage/usr/share/vaela/Main.qml"
export QT_FORCE_STDERR_LOGGING=1
export QT_LOGGING_RULES="qt.svg.warning=false"
export VAELA_TEST_SESSION=1
export VAELA_TEST_VERSION="$(sed -n 's/^project(vaela VERSION \([^ ]*\).*/\1/p' CMakeLists.txt)"
export VAELA_SESSION=1 QT_QPA_PLATFORM=offscreen LIBGL_ALWAYS_SOFTWARE=1 KWIN_COMPOSE=O
# Pin one workspace so the add/rename/remove assertions use a known ID.
printf '[Desktops]\nNumber=1\nRows=1\n' > "$scratch/config/kwinrc"
timeout 45 dbus-run-session -- kwin_wayland --virtual --no-lockscreen --width 1280 --height 800 --exit-with-session "$PWD/tests/session.sh"
