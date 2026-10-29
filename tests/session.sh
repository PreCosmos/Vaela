#!/usr/bin/env bash
# Invoked by scripts/test-headless.sh inside a private compositor and D-Bus.
set -euo pipefail
: "${VAELA_TEST_BUILD:?Run scripts/test-headless.sh}"
export QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software
vaela-shell > "$VAELA_TEST_BUILD/shell-test.log" 2>&1 &
shell_pid=$!
trap 'kill "$shell_pid" 2>/dev/null || true' EXIT
for i in {1..60}; do
    if qdbus-qt6 org.vaela.Controller /Controller org.vaela.Controller.state > "$VAELA_TEST_BUILD/state.json" 2>/dev/null; then break; fi
    sleep .1
done
python3 - "$VAELA_TEST_BUILD/state.json" <<'PY'
import json,sys,os
s=json.load(open(sys.argv[1]))
assert s['mode']=='Float' and s['desktops'],s
assert s.get('version')==os.environ['VAELA_TEST_VERSION'],s
PY
# A competing tiler can load after Vaela or be restarted by KWin reconfigure.
# Its saved enable flag must survive, and unrelated scripts must stay loaded.
printf '// harmless fixture\n' > "$XDG_RUNTIME_DIR/tiler-fixture.js"
kwriteconfig6 --file kwinrc --group Plugins --key karouselEnabled true
qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$XDG_RUNTIME_DIR/tiler-fixture.js" karousel
qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$XDG_RUNTIME_DIR/tiler-fixture.js" vaela-unrelated-test
qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start
sleep 1.5
[ "$(qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded karousel)" = false ]
[ "$(qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded vaela-unrelated-test)" = true ]
[ "$(kreadconfig6 --file kwinrc --group Plugins --key karouselEnabled)" = true ]
# Opting out allows Karousel to load; opting back in suspends it immediately.
kwriteconfig6 --file vaelarc --group General --key SuspendKarousel false
qdbus-qt6 org.vaela.Controller /Controller org.vaela.Controller.reload
qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$XDG_RUNTIME_DIR/tiler-fixture.js" karousel
qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start
sleep 1.5
[ "$(qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded karousel)" = true ]
kwriteconfig6 --file vaelarc --group General --key SuspendKarousel true
qdbus-qt6 org.vaela.Controller /Controller org.vaela.Controller.reload
sleep .2
[ "$(qdbus-qt6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded karousel)" = false ]
# The window tests use fixed delays; start them once the shell has compiled its QML and
# shown the workspace bar's edge handle, so its start-up does not compete with them.
for i in {1..100}; do
    if qdbus-qt6 org.vaela.InputProbe /InputProbe org.vaela.InputProbe.surfaceAt 1275 400 2>/dev/null | grep -q '"w":10'; then break; fi
    sleep .1
done
sleep .5
# Run both programs even if the first fails, so one run reports every failure.
status=0
"$VAELA_TEST_BUILD/vaela-window-test" || status=1
"$VAELA_TEST_BUILD/vaela-mouse-test" || status=1
qdbus-qt6 org.vaela.Controller /Controller org.vaela.Controller.setMode 'Auto Tiling'
qdbus-qt6 org.vaela.Controller /Controller org.vaela.Controller.state | python3 -c 'import sys,json;assert json.load(sys.stdin)["mode"]=="Auto Tiling"'
qdbus-qt6 org.vaela.Controller /Controller org.vaela.Controller.setMode Scrollable
qdbus-qt6 org.vaela.Controller /Controller org.vaela.Controller.addDesktop
qdbus-qt6 org.vaela.Controller /Controller org.vaela.Controller.renameDesktop 2 Testing
qdbus-qt6 org.vaela.Controller /Controller org.vaela.Controller.desktop 2
qdbus-qt6 org.vaela.Controller /Controller org.vaela.Controller.state | python3 -c 'import sys,json;s=json.load(sys.stdin);assert s["mode"]=="Float";assert s["desktops"][1]["name"]=="Testing" and s["desktops"][1]["current"];assert all(not d["windows"] for d in s["desktops"]),s'
qdbus-qt6 org.vaela.Controller /Controller org.vaela.Controller.removeDesktop 2
for view in radial commands settings radial-settings; do
    qdbus-qt6 org.vaela.Shell /Shell org.vaela.Shell.showView "$view" 600 400
    sleep .4
    kill -0 "$shell_pid"
done
# Settings (680x660) chosen from the radial menu must stay open (0.4 hid it straight away).
qdbus-qt6 org.vaela.Shell /Shell org.vaela.Shell.showView dismiss 0 0
qdbus-qt6 org.vaela.Shell /Shell org.vaela.Shell.showView radial 640 400
sleep .8
qdbus-qt6 org.vaela.InputProbe /InputProbe org.vaela.InputProbe.motion 640 545
qdbus-qt6 org.vaela.InputProbe /InputProbe org.vaela.InputProbe.button 272 true
qdbus-qt6 org.vaela.InputProbe /InputProbe org.vaela.InputProbe.button 272 false
sleep 1
qdbus-qt6 org.vaela.InputProbe /InputProbe org.vaela.InputProbe.surfaceAt 640 400 | python3 -c 'import sys,json;s=json.load(sys.stdin);assert (s.get("w"),s.get("h"))==(680,660),s'
qdbus-qt6 org.vaela.Shell /Shell org.vaela.Shell.showView dismiss 0 0
qdbus-qt6 org.vaela.Controller /Controller org.vaela.Controller.setMode Float
# Breeze's TextArea and the portal registration warn about themselves, and Qt Multimedia names its
# FFmpeg once it loads; anything else fails.
if grep -vE 'org/kde/breeze/TextArea\.qml|qt\.qpa\.services: Failed to register with host portal|qt\.multimedia\.ffmpeg: Using Qt multimedia with FFmpeg' "$VAELA_TEST_BUILD/shell-test.log" | grep -q .; then
    cat "$VAELA_TEST_BUILD/shell-test.log"; exit 1
fi
exit "$status"
