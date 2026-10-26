cmake_minimum_required(VERSION 3.22)
project(vaela VERSION 1.1.0 LANGUAGES CXX)

include(GNUInstallDirs)
set(CMAKE_CXX_STANDARD 20)

set(VAELA_DATADIR "${CMAKE_INSTALL_FULL_DATADIR}/vaela")
# Plasma's helper that starts a D-Bus session bus when the display manager didn't.
set(PLASMA_DBUS_HELPER "${CMAKE_INSTALL_FULL_LIBEXECDIR}/plasma-dbus-run-session-if-needed"
    CACHE FILEPATH "Path to plasma-dbus-run-session-if-needed")

configure_file(session/startvaela.in startvaela @ONLY)
configure_file(session/vaela.desktop.in vaela.desktop @ONLY)

install(PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/startvaela" DESTINATION "${CMAKE_INSTALL_BINDIR}")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/vaela.desktop" DESTINATION "${CMAKE_INSTALL_DATADIR}/wayland-sessions")

# Config defaults for the Vaela session only; the user's own ~/.config still wins.
install(DIRECTORY config/xdg/ DESTINATION "${VAELA_DATADIR}/xdg")

install(DIRECTORY lookandfeel/org.vaela.desktop DESTINATION "${CMAKE_INSTALL_DATADIR}/plasma/look-and-feel")

find_package(ECM REQUIRED NO_MODULE)
list(APPEND CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
find_package(KWin REQUIRED)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 DBus Test Widgets)
find_package(KF6GlobalAccel REQUIRED)
find_package(PlasmaActivities REQUIRED)
find_package(LayerShellQt REQUIRED)
find_package(KF6Service REQUIRED)
find_package(KF6KIO REQUIRED)
set(CMAKE_AUTOMOC ON)
add_library(vaela MODULE src/plugin.cpp)
target_compile_definitions(vaela PRIVATE VAELA_VERSION="${PROJECT_VERSION}")
target_link_libraries(vaela PRIVATE KWin::kwin Qt6::DBus KF6::GlobalAccel Plasma::Activities)
install(TARGETS vaela DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt6/plugins/kwin/plugins)
add_library(vaela-radial STATIC src/radialmenu.cpp)
target_link_libraries(vaela-radial PUBLIC Qt6::Gui KF6::ConfigCore KF6::Service KF6::KIOGui)
add_executable(vaela-shell src/shell.cpp)
target_link_libraries(vaela-shell PRIVATE Qt6::Quick Qt6::Qml Qt6::QuickControls2 Qt6::DBus vaela-radial LayerShellQt::Interface KF6::ConfigCore)
target_compile_definitions(vaela-shell PRIVATE VAELA_QML_PATH="${VAELA_DATADIR}/Main.qml")
install(TARGETS vaela-shell DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES src/Main.qml src/RadialEditor.qml src/Theme.qml src/VButton.qml src/Shadow.qml src/qmldir session/migrate-layout.js DESTINATION ${VAELA_DATADIR})
# Per-workspace backgrounds: a Plasma wallpaper, and the QML module it hears from Vaela through.
qt_policy(SET QTP0001 NEW)
qt_add_qml_module(vaelabackground
    URI org.vaela.background
    VERSION 1.0
    PLUGIN_TARGET vaelabackground
    SOURCES src/background.cpp src/background.h
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/qml/org/vaela/background")
target_include_directories(vaelabackground PRIVATE src)
target_link_libraries(vaelabackground PRIVATE Qt6::Qml Qt6::DBus)
set(VAELA_QMLDIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml/org/vaela/background")
install(TARGETS vaelabackground LIBRARY DESTINATION "${VAELA_QMLDIR}")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/qml/org/vaela/background/qmldir"
              "${CMAKE_CURRENT_BINARY_DIR}/qml/org/vaela/background/vaelabackground.qmltypes"
        DESTINATION "${VAELA_QMLDIR}")
install(DIRECTORY wallpaper/org.vaela.background DESTINATION "${CMAKE_INSTALL_DATADIR}/plasma/wallpapers")
# Plasma's autostart goes through systemd, which only scans the standard autostart folders.
install(FILES session/vaela-shell.desktop DESTINATION ${CMAKE_INSTALL_FULL_SYSCONFDIR}/xdg/autostart)
include(CTest)
if(BUILD_TESTING)
    add_executable(gesture-test tests/gestures.cpp)
    target_include_directories(gesture-test PRIVATE src)
    target_link_libraries(gesture-test PRIVATE Qt6::Test Qt6::Gui)
    add_test(NAME gestures COMMAND gesture-test)
endif()
if(BUILD_TESTING)
    add_executable(background-test tests/background.cpp src/background.cpp)
    target_include_directories(background-test PRIVATE src)
    target_link_libraries(background-test PRIVATE Qt6::Qml Qt6::DBus Qt6::Test)
    add_test(NAME background COMMAND background-test)
endif()
if(BUILD_TESTING)
    add_executable(vaela-window-test tests/windows.cpp)
    target_link_libraries(vaela-window-test PRIVATE Qt6::Quick Qt6::DBus)
endif()
if(BUILD_TESTING)
    add_executable(radial-test tests/radialmenu.cpp)
    target_include_directories(radial-test PRIVATE src)
    target_link_libraries(radial-test PRIVATE vaela-radial Qt6::Test)
    add_test(NAME radial-menu COMMAND radial-test)
    set_tests_properties(radial-menu PROPERTIES ENVIRONMENT "XDG_DATA_HOME=${CMAKE_CURRENT_BINARY_DIR}/radial-test-data")
endif()
if(BUILD_TESTING)
    add_executable(radial-ui-test tests/radialui.cpp)
    target_include_directories(radial-ui-test PRIVATE src)
    target_link_libraries(radial-ui-test PRIVATE vaela-radial Qt6::Quick Qt6::Test)
    target_compile_definitions(radial-ui-test PRIVATE RADIAL_EDITOR_PATH="${CMAKE_CURRENT_SOURCE_DIR}/src/RadialEditor.qml" RADIAL_PREVIEW_PATH="${CMAKE_CURRENT_BINARY_DIR}/radial-editor-preview.png")
    add_test(NAME radial-editor COMMAND radial-ui-test)
    set_tests_properties(radial-editor PROPERTIES ENVIRONMENT "QT_FORCE_STDERR_LOGGING=1")
endif()

if(BUILD_TESTING)
    add_library(vaela-input-probe MODULE tests/inputprobe.cpp)
    target_link_libraries(vaela-input-probe PRIVATE KWin::kwin Qt6::DBus)
    add_executable(vaela-mouse-test tests/mouse.cpp)
    target_link_libraries(vaela-mouse-test PRIVATE Qt6::Widgets Qt6::DBus Qt6::Test)
endif()
