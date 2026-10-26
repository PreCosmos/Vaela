# Vaela

A Wayland desktop inspired by Vivaldi, built on KWin and Plasma. Select **Vaela**
on the login screen. Vaela uses Plasma's services and system settings pages.

## Desktop controls

- The layout switch selects **Float**, **Auto Tiling** (a grid), or
  **Scrollable** (horizontal, full-height columns). It stays hidden as a thin handle at the
  right end of the top bar and opens when the pointer reaches the top-right corner.
  The choice is saved independently per workspace in each activity.
  Drag a window edge to resize: Scrollable keeps an independent column width;
  Auto Tiling shares the new column/row boundary with neighbouring windows.
  Neighbouring tiles reflow during the drag. Scrollable neighbours keep their widths
  and move to preserve gaps. In Scrollable the focused column always sits in the middle
  of the screen, so new windows open centred, and each application's column width is
  remembered after its window closes. Auto Tiling sizes last while the window is open.
  Float restores window geometry saved before automatic arrangement. Layouts exclude
  dialogs, panels, pinned windows, minimized windows and fullscreen applications.
- The right-edge workspace bar reveals vertical tabs on hover, with each workspace’s layout. Click to switch;
  use **+ Workspace** to add and **⋮** to rename or remove. Hover for window titles.
- **F2** opens Quick Commands. Type to filter, use arrows and Enter to execute.
- Hold right-click still: the context menu appears at **0.25 seconds**, hides at
  **0.75 seconds**, and the radial menu appears at **1 second**. Keep holding and move
  onto an item: it grows and the centre reads "Release to open". Release the right
  button to open it. Releasing over the centre keeps the menu open, so you can also
  pick an item with a left click. Escape cancels.
- Right-drag draws gestures. Short clicks retain application context menus;
  **Shift + right-click** bypasses gesture interception.
- **Meta+Ctrl+S** opens Vaela Settings: layouts, spacing, gesture sensitivity,
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
**Meta+Left/Right** focuses the window to the left/right in Scrollable and centres it;
it takes priority over Plasma's quick tiling only in Scrollable mode.
**Meta+Alt+Left/Right** focuses the previous/next window in any layout.
**Meta+Plus/Minus** widens/narrows the active column in Scrollable and Auto Tiling.
These keys take priority over Plasma zoom while those layout modes are active.
**Ctrl+Meta+Left/Right** moves the active Scrollable column left/right in the strip.
It takes priority over Plasma workspace switching only in Scrollable mode.
**Meta+Ctrl+Alt+Left/Right** also narrows/widens columns; **Meta+Ctrl+Alt+Up/Down**
shrinks/grows tiled rows. Scrollable columns always use the available height.
Bindings, settings and remembered column widths live in `~/.config/vaelarc`. The workspace bar currently
uses title previews; workspace stacks and live thumbnails remain future work.

## Customizing the radial menu

Open **Vaela Settings → Customize Radial Menu…**, or click the gear at the bottom
of the radial menu. Choose **Add Application** to search installed applications;
the application name and icon are filled in automatically. Choose **Add Command**
to enter a name and shell command, with an optional **Run in a terminal** setting.

Every item has an image. Use **Edit** to choose a system icon or **Choose Image…**
for a local PNG, JPEG, SVG, WebP or BMP. Vaela copies imported images into
`~/.local/share/vaela-shell/radial-icons/`, so deleting the original image does not
break your menu. **Remove** deletes an application, command or desktop action
from the menu without uninstalling anything. The arrow buttons change the order.
Changes save immediately in the `[RadialMenu]` group of `~/.config/vaelarc`.
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
on the exact KWin version used to build them. The KWin plugin only activates when
`VAELA_SESSION=1`, which `startvaela` sets. The shell autostarts from
`/etc/xdg/autostart` and exits unless the plugin's `org.vaela.Controller` D-Bus service
appears, so other desktop sessions remain unaffected.

`./scripts/test-headless.sh` builds and tests a private software-rendered KWin session.
`ctest --test-dir build/native --output-on-failure` runs gesture tests after a
CMake build. `tests/windows.cpp` is a compositor integration probe: run
`vaela-window-test` inside an isolated Vaela KWin instance at 1280×800 to check
actual window sizes through all three modes and restoration to Float.

## Installing on Bazzite / Fedora Atomic

```bash
rpm-ostree install ./rpms/vaela-desktop-0.5.0-1.fc45.x86_64.rpm
```

To replace an already layered local RPM (including the old `vela-desktop`), use:

```bash
rpm-ostree install --uninstall vela-desktop ./rpms/vaela-desktop-0.5.0-1.fc45.x86_64.rpm
```

Reboot and select **Vaela** at login. Remove with `rpm-ostree uninstall vaela-desktop`.
On first login `startvaela` copies `~/.config/velarc` to `vaelarc` and switches the
look-and-feel from `org.vela.desktop` to `org.vaela.desktop`. The shell upgrades the
stock panel shapes of earlier versions: it removes the old pager and gives the top bar
its full width back. Other panel configurations are left as configured.

## Source layout

`src/` contains the native KWin plugin and Qt Quick shell. `session/` contains the
session launcher, autostart entry and panel upgrade. `config/xdg/` and
`lookandfeel/` provide session defaults. `packaging/` contains the RPM spec;
`scripts/` contains development tools. `docs/mockup/` is the original HTML reference.
