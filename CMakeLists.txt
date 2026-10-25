cmake_minimum_required(VERSION 3.22)
project(vela VERSION 0.2.0 LANGUAGES CXX)

include(GNUInstallDirs)
set(CMAKE_CXX_STANDARD 20)

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

find_package(ECM REQUIRED NO_MODULE)
list(APPEND CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
find_package(KWin REQUIRED)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 DBus Test)
find_package(KF6GlobalAccel REQUIRED)
find_package(PlasmaActivities REQUIRED)
find_package(LayerShellQt REQUIRED)
set(CMAKE_AUTOMOC ON)
add_library(vela MODULE src/plugin.cpp)
target_link_libraries(vela PRIVATE KWin::kwin Qt6::DBus KF6::GlobalAccel Plasma::Activities)
install(TARGETS vela DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt6/plugins/kwin/plugins)
add_executable(vela-shell src/shell.cpp)
target_link_libraries(vela-shell PRIVATE Qt6::Quick Qt6::Qml Qt6::QuickControls2 Qt6::DBus LayerShellQt::Interface KF6::ConfigCore)
target_compile_definitions(vela-shell PRIVATE VELA_QML_PATH="${VELA_DATADIR}/Main.qml")
install(TARGETS vela-shell DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES src/Main.qml session/migrate-layout.js DESTINATION ${VELA_DATADIR})
install(FILES session/vela-shell.desktop DESTINATION ${VELA_DATADIR}/xdg/autostart)
include(CTest)
if(BUILD_TESTING)
    add_executable(gesture-test tests/gestures.cpp)
    target_include_directories(gesture-test PRIVATE src)
    target_link_libraries(gesture-test PRIVATE Qt6::Test Qt6::Gui)
    add_test(NAME gestures COMMAND gesture-test)
endif()
if(BUILD_TESTING)
    add_executable(vela-window-test tests/windows.cpp)
    target_link_libraries(vela-window-test PRIVATE Qt6::Quick Qt6::DBus)
endif()
