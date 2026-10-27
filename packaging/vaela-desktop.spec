Name:           vaela-desktop
Version:        1.1.3
Release:        1%{?dist}
Summary:        Vaela, a Vivaldi-style desktop built on KWin
License:        GPL-2.0-or-later
URL:            https://github.com/PreCosmos/Vaela
Source0:        %{name}-%{version}.tar.gz
%global kwin_version %(rpm -q --qf '%%{VERSION}' kwin-devel)
# Vela was renamed to Vaela in 0.5.0.
Obsoletes:      vela-desktop < 0.5.0
Provides:       vela-desktop = %{version}-%{release}

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  extra-cmake-modules
BuildRequires:  kwin-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qtbase-devel
BuildRequires:  kf6-kglobalaccel-devel
BuildRequires:  kf6-kservice-devel
BuildRequires:  kf6-kio-devel
BuildRequires:  plasma-activities-devel
BuildRequires:  layer-shell-qt-devel
BuildRequires:  libepoxy-devel
BuildRequires:  libdrm-devel
BuildRequires:  vulkan-loader-devel

# The session itself.
Requires:       kwin = %{kwin_version}
Requires:       plasma-workspace >= 6.7
Requires:       plasma-desktop
Requires:       plasma-breeze
Requires:       breeze-icon-theme
Requires:       kscreenlocker
Requires:       polkit-kde
Requires:       xdg-desktop-portal-kde
# Settings pages Vaela relies on: displays and HDR, sound, printers, power, system info.
Requires:       plasma-systemsettings
Requires:       kscreen
Requires:       plasma-pa
Requires:       plasma-print-manager
Requires:       powerdevil
Requires:       kinfocenter
# The dock's default terminal launcher.
Requires:       layer-shell-qt
Requires:       spectacle
Requires:       qt6-qtdeclarative
# Video backgrounds play through Qt Multimedia in plasmashell.
Requires:       qt6-qtmultimedia
Requires:       konsole
Recommends:     dolphin
Recommends:     plasma-nm
Recommends:     kde-gtk-config

%description
Vaela is a Wayland desktop that looks and works like the Vivaldi browser: a top
bar, a dock that moves out of the way of windows, and a workspace bar on the
right edge. It runs on KWin and reuses Plasma's settings and services, and
appears as its own "Vaela" session on the login screen.

%prep
%autosetup

%build
%cmake -DPLASMA_DBUS_HELPER=%{_libexecdir}/plasma-dbus-run-session-if-needed
%cmake_build

%check
ctest --test-dir %{__cmake_builddir} --output-on-failure

%install
%cmake_install

%files
%license LICENSES/GPL-2.0-or-later.txt
%doc README.md
%{_bindir}/startvaela
%{_bindir}/vaela-shell
%{_libdir}/qt6/plugins/kwin/plugins/libvaela.so
%{_libdir}/qt6/plugins/kwin/effects/plugins/libvaelaclip.so
%{_datadir}/wayland-sessions/vaela.desktop
%{_datadir}/vaela/
%{_datadir}/plasma/look-and-feel/org.vaela.desktop/
%{_datadir}/plasma/wallpapers/org.vaela.background/
%{_libdir}/qt6/qml/org/vaela/
%config(noreplace) %{_sysconfdir}/xdg/autostart/vaela-shell.desktop

%changelog
* Tue Oct 27 2026 Vaela contributors - 1.1.3-1
- Scrollable on several monitors: a column wider than its monitor, or peeking past its
  edge, now shows up to that edge and is cut off there, instead of disappearing. A new
  KWin effect, vaelaclip, draws each tiled window only on its own monitor.
- Clicks and scrolling on a monitor never reach the unseen part of a window from the
  next monitor; that monitor's own windows get them.
- Widening or growing a window that Vaela does not tile (Float mode, or a monitor Vaela
  does not run on) stops at the monitor's size inside the gaps and keeps the window on
  that monitor; tiled windows already stop at the edge of the screen.

* Tue Oct 27 2026 Vaela contributors - 1.1.2-1
- Tile each monitor on its own when Vaela runs on several. A window keeps its monitor
  until you drag it or send it to another, instead of joining whichever monitor a
  scrolled-away column happened to cross.
- Scrollable: each monitor centres its own focused column, so Meta+Left/Right on one
  monitor no longer moves the other's windows; columns that would slide onto a
  neighbouring monitor wait off-screen until you scroll to them.
- Auto Tiling: an uneven last row now shares the full width of the screen, so
  widening a window fills it and the gap setting is the only space between windows.
- Meta+Left/Right focus the window to the left or right in Auto Tiling too, instead of
  Plasma's quick tiling pulling a window out of the grid; a window quick-tiled another
  way (dragged to an edge) goes back into the grid.
- Layout keys act on the monitor of the focused window, wherever the pointer is.

* Tue Oct 27 2026 Vaela contributors - 1.1.1-1
- Open the radial menu at the pointer on whichever monitor it is on, as long as
  Vaela runs there, from the right button or Meta+Ctrl+M. Vaela's views are now
  placed by monitor name, so they no longer land on the wrong monitor when
  monitors differ in size or scale.

* Mon Oct 26 2026 Vaela contributors - 1.1.0-1
- Play background sound on Plasma's default output and follow it when it changes,
  for example to headphones; it used to stay on the device that was the default
  when Plasma started.
- Give each workspace its own background options: scaling, mute, volume, speed,
  dim and blur, with a button to use one workspace's options on all of them.
- Add "Pause videos while any window is open" and "Pause videos even when their
  sound is on".
- A background that failed to load is tried again once its workspace gets a new one.

* Mon Oct 26 2026 Vaela contributors - 1.0.0-1
- Give each workspace its own video or picture background, chosen in Vaela Settings
  or from the workspace bar's menu, and crossfaded when you switch. Workspaces
  without one keep the Plasma wallpaper, which comes back once none are set.
- Background options: Fill, Fit or Stretch; mute and volume (sound plays from one
  monitor); playback speed; dim; blur; crossfade length; pausing while windows
  cover the screen and on battery. Videos carry on where they left off.
- Script backgrounds over D-Bus: org.vaela.Shell.setBackground(workspace, url).

* Mon Oct 26 2026 Vaela contributors - 0.7.0-1
- Choose the monitors Vaela runs on in Settings: the primary one (the default, and
  it follows Plasma's primary monitor), all of them, or a chosen set. The layout
  switch and workspace bar appear on each, and other monitors keep plain Plasma
  behaviour. Fixes Vaela appearing on the left monitor instead of the primary one.
- Open Quick Commands, Settings and the keyboard radial menu on the active monitor.
- Edit every Vaela shortcut in Settings, including the layout keys (Meta+arrows,
  Meta+Plus/Minus, Meta+Ctrl+arrows), with conflict checks and reset to default.
- Set how long to hold the right button before the radial menu opens.
- Move the radial menu shortcut from Meta+Ctrl+R, which Spectacle uses for window
  recording, to Meta+Ctrl+M.

* Mon Oct 26 2026 Vaela contributors - 0.6.0-1
- Build for Fedora 44 as well as Fedora 45.
- Open the radial menu after a half-second hold. A quick right-click opens the
  application's context menu on release; no menu flashes open during the hold.
- Remove the timed context-menu dismissal, which could crash KWin.
- Move the layout switch to the top edge, left of the corner, clear of a maximized
  window's close button.

* Mon Oct 26 2026 Vaela contributors - 0.5.0-1
- Rename Vela to Vaela; carry over velarc, radial menu images and the look-and-feel choice.
- Start the shell from /etc/xdg/autostart and detect the session through the KWin
  plugin's D-Bus service, so it loads when Plasma autostarts through systemd.
- Fix Settings not opening from the radial menu.
- Scrollable: centre the focused column, remember each app's column width after it
  closes, and move focus with Meta+Left/Right.
- Hide the layout switch until the pointer reaches the top-right corner; the top bar
  spans the full width again.

* Sun Oct 25 2026 Vaela contributors - 0.4.0-1
- Fix workspace button D-Bus types and edge-bar interaction.
- Save layouts per workspace and reflow neighbours during interactive resize.

* Sun Oct 25 2026 Vaela contributors - 0.3.0-1
- Add a persistent radial menu editor, application picker, commands and item images.
- Register native input filtering, add staged context/radial hold timing and down-to-close.
- Fix preview plugin discovery and reserve room for the Float layout switch.

* Sun Oct 25 2026 Vaela contributors - 0.2.0-1
- Add native KWin gestures and per-activity layouts, radial menu, workspace tabs,
  Quick Commands and Vaela Settings.

* Sun Oct 25 2026 Vaela contributors - 0.1.0-1
- First package: Vaela session, default panel layout and look-and-feel defaults.
