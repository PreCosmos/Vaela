# Vela

A Wayland desktop inspired by Vivaldi, built on KWin and Plasma. Select **Vela**
on the login screen. Vela uses Plasma's services and system settings pages.

## Desktop controls

- The top-right switch selects **Float**, **Auto Tiling** (a grid), or
  **Scrollable** (horizontal, full-height columns). The choice is saved per activity.
  Drag a window edge to resize: Scrollable keeps an independent column width;
  Auto Tiling shares the new column/row boundary with neighbouring windows.
  Sizes are retained while the session and window remain open.
  Float restores window geometry saved before automatic arrangement. Layouts exclude
  dialogs, panels, pinned windows, minimized windows and fullscreen applications.
- The right-edge workspace bar reveals vertical tabs on hover. Click to switch;
  use **+ Workspace** to add and **⋮** to rename or remove. Hover for window titles.
- **F2** opens Quick Commands. Type to filter, use arrows and Enter to execute.
- Hold right-click still: the context menu appears at **0.25 seconds**, hides at
  **0.75 seconds**, and the radial menu appears at **1 second**. Move toward an
  action and release, or click an action after releasing in the centre. Escape cancels.
- Right-drag draws gestures. Short clicks retain application context menus;
  **Shift + right-click** bypasses gesture interception.
- **Meta+Ctrl+S** opens Vela Settings: layouts, spacing, gesture sensitivity,
  gesture bindings and links to Plasma's settings and shortcut editor.

| Gesture | Default action |
|---|---|
| Left / Right | Previous / next workspace |
| Up / Down | Maximize or restore / close the hovered window |
| Down, Right | Close the window under the initial press |
| Up, Down | Cycle layout |
| Down, Up | Terminal |
| Up, Left / Up, Right | Activities / Quick Commands |
| Right, Up / Left, Up | Move window to next / previous workspace |

**Meta+Ctrl+Space** cycles layouts; **Meta+Ctrl+R** opens the radial menu.
**Meta+Alt+Left/Right** focuses adjacent windows and scrolls columns into view.
**Meta+Plus/Minus** widens/narrows the active column in Scrollable and Auto Tiling.
These keys take priority over Plasma zoom while those layout modes are active.
**Ctrl+Meta+Left/Right** moves the active Scrollable column left/right in the strip.
It takes priority over Plasma workspace switching only in Scrollable mode.
**Meta+Ctrl+Alt+Left/Right** also narrows/widens columns; **Meta+Ctrl+Alt+Up/Down**
shrinks/grows tiled rows. Scrollable columns always use the available height.
Bindings and settings live in `~/.config/velarc`. The workspace bar currently
uses title previews; workspace stacks and live thumbnails remain future work.

## Customizing the radial menu

Open **Vela Settings → Customize Radial Menu…**, or click the gear at the bottom
of the radial menu. Choose **Add Application** to search installed applications;
the application name and icon are filled in automatically. Choose **Add Command**
to enter a name and shell command, with an optional **Run in a terminal** setting.

Every item has an image. Use **Edit** to choose a system icon or **Choose Image…**
for a local PNG, JPEG, SVG, WebP or BMP. Vela copies imported images into
`~/.local/share/vela-shell/radial-icons/`, so deleting the original image does not
break your menu. **Remove** deletes an application, command or desktop action
from the menu without uninstalling anything. The arrow buttons change the order.
Changes save immediately in the `[RadialMenu]` group of `~/.config/velarc`.
Menus with more than eight entries have additional pages; an empty menu keeps
its gear button so you can add entries again.

The editor takes inspiration from [Kando](https://kando.menu/creating-menus/).

## Developing

```bash
./scripts/dev-container.sh
./scripts/run-nested.sh --fresh
./scripts/build-rpm.sh
```

The Fedora 45 distrobox `vela-dev` holds build dependencies. Its home is
`.devbox/home`. Native plugins must be rebuilt for each KWin version; RPMs depend
on the exact KWin version used to build them. The plugin and shell only activate
when `VELA_SESSION=1`; other desktop sessions remain unaffected.

`./scripts/test-headless.sh` builds and tests a private software-rendered KWin session.
`ctest --test-dir build/native --output-on-failure` runs gesture tests after a
CMake build. `tests/windows.cpp` is a compositor integration probe: run
`vela-window-test` inside an isolated Vela KWin instance at 1280×800 to check
actual window sizes through all three modes and restoration to Float.

## Installing on Bazzite / Fedora Atomic

```bash
rpm-ostree install ./rpms/vela-desktop-0.3.0-1.fc45.x86_64.rpm
```

For an already layered local Vela RPM, use:

```bash
rpm-ostree install --uninstall vela-desktop ./rpms/vela-desktop-0.3.0-1.fc45.x86_64.rpm
```

Reboot and select **Vela** at login. Remove with `rpm-ostree uninstall vela-desktop`.
The shell upgrades the stock 0.1 panel shapes, removing the old pager and making
room for the layout switch. Other panel configurations are left as configured.

## Source layout

`src/` contains the native KWin plugin and Qt Quick shell. `session/` contains the
session launcher, autostart entry and panel upgrade. `config/xdg/` and
`lookandfeel/` provide session defaults. `packaging/` contains the RPM spec;
`scripts/` contains development tools. `docs/mockup/` is the original HTML reference.
