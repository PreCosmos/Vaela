#!/usr/bin/env bash
# Run Vaela in a window on your current desktop, straight from this checkout.
# It uses a throwaway home under build/nested-home, so your real settings are untouched.
#   --fresh   start from a clean home, as on a first login
#   --size WxH  window size (default 1600x900)
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/fedora.sh
if [ ! -e /run/.containerenv ]; then
  # Numeric UID also works when distrobox's named-user lookup is unavailable.
  podman start "$CONTAINER" >/dev/null
  for _ in $(seq 100); do podman exec "$CONTAINER" test -e "$PWD/scripts/run-nested.sh" && break; sleep .3; done
  exec podman exec -u "$(id -u)" -e FEDORA -e XDG_RUNTIME_DIR -e WAYLAND_DISPLAY -e DISPLAY \
    -e LANG -e QT_QPA_PLATFORM=wayland "$CONTAINER" "$PWD/scripts/run-nested.sh" "$@"
fi

SIZE=1600x900
FRESH=0
while [ $# -gt 0 ]; do
  case "$1" in
    --fresh) FRESH=1 ;;
    --size) SIZE="$2"; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

ROOT="$PWD"
STAGE="$ROOT/build/stage$SUFFIX"
TEST_HOME="$ROOT/build/nested-home"

cmake -S . -B "build/nested$SUFFIX" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib64 \
      -DPLASMA_DBUS_HELPER=/usr/libexec/plasma-dbus-run-session-if-needed >/dev/null
cmake --build "build/nested$SUFFIX" --parallel
rm -rf "$STAGE"
DESTDIR="$STAGE" cmake --install "build/nested$SUFFIX" >/dev/null

[ "$FRESH" = 1 ] && rm -rf "$TEST_HOME"
mkdir -p "$TEST_HOME"/{config,data,cache,state}
export XDG_CONFIG_HOME="$TEST_HOME/config"
export XDG_DATA_HOME="$TEST_HOME/data"
export XDG_CACHE_HOME="$TEST_HOME/cache"
export XDG_STATE_HOME="$TEST_HOME/state"
export XDG_CONFIG_DIRS="$STAGE/usr/share/vaela/xdg:/etc/xdg"
export XDG_DATA_DIRS="$STAGE/usr/share:/usr/share"
export XDG_CURRENT_DESKTOP=KDE
export KDE_FULL_SESSION=true
export KDE_SESSION_VERSION=6
export VAELA_SESSION=1

# startplasma would write the look-and-feel defaults on login; do the same here.
plasma-apply-lookandfeel --apply org.vaela.desktop >/dev/null 2>&1 || true

W=${SIZE%x*} H=${SIZE#*x}
# The native KWin plugin must be installed in the dev container first.
# QT_PLUGIN_PATH makes the staged plugin available without changing the host.
export QT_PLUGIN_PATH="$STAGE/usr/lib64/qt6/plugins:$STAGE/usr/lib/qt6/plugins:${QT_PLUGIN_PATH:-/usr/lib64/qt6/plugins}"
export VAELA_QML="$STAGE/usr/share/vaela/Main.qml"
export PATH="$STAGE/usr/bin:$PATH"
cat > "$ROOT/build/nested-session.sh" <<'SESSION'
#!/bin/sh
plasmashell &
plasma_pid=$!
vaela-shell &
vaela_pid=$!
trap 'kill "$plasma_pid" "$vaela_pid" 2>/dev/null' EXIT INT TERM
wait "$plasma_pid"
SESSION
chmod +x "$ROOT/build/nested-session.sh"
exec dbus-run-session -- kwin_wayland --width "$W" --height "$H" --xwayland \
  --exit-with-session "$ROOT/build/nested-session.sh"
