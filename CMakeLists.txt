cmake_minimum_required(VERSION 3.22)
project(vela VERSION 0.1.0 LANGUAGES NONE)

include(GNUInstallDirs)

set(VELA_DATADIR "${CMAKE_INSTALL_FULL_DATADIR}/vela")
# Plasma's helper that starts a D-Bus session bus when the display manager didn't.
set(PLASMA_DBUS_HELPER "${CMAKE_INSTALL_FULL_LIBEXECDIR}/plasma-dbus-run-session-if-needed"
    CACHE FILEPATH "Path to plasma-dbus-run-session-if-needed")

configure_file(session/startvela.in startvela @ONLY)
configure_file(session/vela.desktop.in vela.desktop @ONLY)

install(PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/startvela" DESTINATION "${CMAKE_INSTALL_BINDIR}")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/vela.desktop" DESTINATION "${CMAKE_INSTALL_DATADIR}/wayland-sessions")

# Config defaults for the Vela session only; the user's own ~/.config still wins.
install(DIRECTORY config/xdg/ DESTINATION "${VELA_DATADIR}/xdg")

install(DIRECTORY lookandfeel/org.vela.desktop DESTINATION "${CMAKE_INSTALL_DATADIR}/plasma/look-and-feel")
