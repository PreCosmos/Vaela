Name:           vaela-desktop
Version:        0.5.0
Release:        1%{?dist}
Summary:        Vaela, a Vivaldi-style desktop built on KWin
License:        GPL-2.0-or-later
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
%{_datadir}/wayland-sessions/vaela.desktop
%{_datadir}/vaela/
%{_datadir}/plasma/look-and-feel/org.vaela.desktop/
%config(noreplace) %{_sysconfdir}/xdg/autostart/vaela-shell.desktop

%changelog
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
