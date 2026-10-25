#!/usr/bin/env bash
# Run Vela in a window on your current desktop, straight from this checkout.
# It uses a throwaway home under build/nested-home, so your real settings are untouched.
#   --fresh   start from a clean home, as on a first login
#   --size WxH  window size (default 1600x900)
set -euo pipefail
cd "$(dirname "$0")/.."
[ -e /run/.containerenv ] || exec distrobox enter vela-dev -- "$PWD/scripts/run-nested.sh" "$@"

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
STAGE="$ROOT/build/stage"
TEST_HOME="$ROOT/build/nested-home"

cmake -S . -B build/nested -DCMAKE_INSTALL_PREFIX=/usr \
      -DPLASMA_DBUS_HELPER=/usr/libexec/plasma-dbus-run-session-if-needed >/dev/null
rm -rf "$STAGE"
DESTDIR="$STAGE" cmake --install build/nested >/dev/null

[ "$FRESH" = 1 ] && rm -rf "$TEST_HOME"
mkdir -p "$TEST_HOME"/{config,data,cache,state}
export XDG_CONFIG_HOME="$TEST_HOME/config"
export XDG_DATA_HOME="$TEST_HOME/data"
export XDG_CACHE_HOME="$TEST_HOME/cache"
export XDG_STATE_HOME="$TEST_HOME/state"
export XDG_CONFIG_DIRS="$STAGE/usr/share/vela/xdg:/etc/xdg"
export XDG_DATA_DIRS="$STAGE/usr/share:/usr/share"
export XDG_CURRENT_DESKTOP=KDE
export KDE_FULL_SESSION=true
export KDE_SESSION_VERSION=6
export VELA_SESSION=1

# startplasma would write the look-and-feel defaults on login; do the same here.
plasma-apply-lookandfeel --apply org.vela.desktop >/dev/null 2>&1 || true

W=${SIZE%x*} H=${SIZE#*x}
exec dbus-run-session -- kwin_wayland --width "$W" --height "$H" --xwayland \
  --exit-with-session plasmashell
