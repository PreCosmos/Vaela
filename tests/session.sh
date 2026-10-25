#!/usr/bin/env bash
# Invoked by scripts/test-headless.sh inside a private compositor and D-Bus.
set -euo pipefail
: "${VELA_TEST_BUILD:?Run scripts/test-headless.sh}"
export QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software
vela-shell > "$VELA_TEST_BUILD/shell-test.log" 2>&1 &
shell_pid=$!
trap 'kill "$shell_pid" 2>/dev/null || true' EXIT
for i in {1..60}; do
    if qdbus-qt6 org.vela.Controller /Controller org.vela.Controller.state > "$VELA_TEST_BUILD/state.json" 2>/dev/null; then break; fi
    sleep .1
done
python3 - "$VELA_TEST_BUILD/state.json" <<'PY'
import json,sys,os
s=json.load(open(sys.argv[1]))
assert s['mode']=='Float' and s['desktops'],s
assert s.get('version')==os.environ['VELA_TEST_VERSION'],s
PY
"$VELA_TEST_BUILD/vela-window-test"
"$VELA_TEST_BUILD/vela-mouse-test"
qdbus-qt6 org.vela.Controller /Controller org.vela.Controller.setMode 'Auto Tiling'
qdbus-qt6 org.vela.Controller /Controller org.vela.Controller.state | python3 -c 'import sys,json;assert json.load(sys.stdin)["mode"]=="Auto Tiling"'
qdbus-qt6 org.vela.Controller /Controller org.vela.Controller.setMode Scrollable
qdbus-qt6 org.vela.Controller /Controller org.vela.Controller.addDesktop
qdbus-qt6 org.vela.Controller /Controller org.vela.Controller.renameDesktop 2 Testing
qdbus-qt6 org.vela.Controller /Controller org.vela.Controller.desktop 2
qdbus-qt6 org.vela.Controller /Controller org.vela.Controller.state | python3 -c 'import sys,json;s=json.load(sys.stdin);assert s["mode"]=="Scrollable";assert s["desktops"][1]["name"]=="Testing" and s["desktops"][1]["current"];assert all(not d["windows"] for d in s["desktops"]),s'
qdbus-qt6 org.vela.Controller /Controller org.vela.Controller.removeDesktop 2
for view in radial commands settings radial-settings; do
    qdbus-qt6 org.vela.Shell /Shell org.vela.Shell.showView "$view" 600 400
    sleep .4
    kill -0 "$shell_pid"
done
qdbus-qt6 org.vela.Controller /Controller org.vela.Controller.setMode Float
if test -s "$VELA_TEST_BUILD/shell-test.log"; then cat "$VELA_TEST_BUILD/shell-test.log"; exit 1; fi
