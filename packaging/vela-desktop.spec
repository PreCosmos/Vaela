Name:           vela-desktop
Version:        0.2.0
Release:        1%{?dist}
Summary:        Vela, a Vivaldi-style desktop built on KWin
License:        GPL-2.0-or-later
Source0:        %{name}-%{version}.tar.gz
%global kwin_version %(rpm -q --qf '%%{VERSION}' kwin-devel)

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  extra-cmake-modules
BuildRequires:  kwin-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  qt6-qtbase-devel
BuildRequires:  kf6-kglobalaccel-devel
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
# Settings pages Vela relies on: displays and HDR, sound, printers, power, system info.
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
Vela is a Wayland desktop that looks and works like the Vivaldi browser: a top
bar, a dock that moves out of the way of windows, and a workspace bar on the
right edge. It runs on KWin and reuses Plasma's settings and services, and
appears as its own "Vela" session on the login screen.

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
%{_bindir}/startvela
%{_bindir}/vela-shell
%{_libdir}/qt6/plugins/kwin/plugins/libvela.so
%{_datadir}/wayland-sessions/vela.desktop
%{_datadir}/vela/
%{_datadir}/plasma/look-and-feel/org.vela.desktop/

%changelog
* Sun Oct 25 2026 Vela contributors - 0.2.0-1
- Add native KWin gestures and per-activity layouts, radial menu, workspace tabs,
  Quick Commands and Vela Settings.

* Sun Oct 25 2026 Vela contributors - 0.1.0-1
- First package: Vela session, default panel layout and look-and-feel defaults.
