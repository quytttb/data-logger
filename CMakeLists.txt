cmake_minimum_required(VERSION 3.16)
project(DataLogger VERSION 2.2.0 LANGUAGES CXX)

# Phiên bản Qt chính xác dùng cho CI + packaging scripts + build.sh:
# packaging/qt_version.txt (CI + scripts đọc file này). CMake tự derive min-version.
file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/packaging/qt_version.txt" QT_KIT_VERSION LIMIT_COUNT 1)
string(REGEX MATCH "^[0-9]+\\.[0-9]+" QT_MIN_VERSION "${QT_KIT_VERSION}")
if(NOT QT_MIN_VERSION)
    message(WARNING "packaging/qt_version.txt missing/invalid — fallback QT_MIN_VERSION=6.11")
    set(QT_MIN_VERSION 6.11)
endif()

# Phiên bản QML module — biến chung, trán cần lặp VERSION 1.0 ở 5 CMakeLists.txt.
set(DATALOGGER_QML_MODULE_VERSION 1.0)

# Phiên bản app binary — pass cho main.cpp qua compile definition để runtime
# đọc đúng (REST `/api/v1/health` dùng QCoreApplication::applicationVersion).
set(APP_VERSION "${PROJECT_VERSION}")

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2
    Sql
    SerialBus
    HttpServer
    Graphs
    Network
)

qt_standard_project_setup(REQUIRES ${QT_MIN_VERSION})

# QML sources live in subdirectories (qml/views, shell, layout, chart, ...).
# Opt into the Qt 6.8+ behaviour that generates a qmldir per subdirectory so
# components can resolve each other via the implicit import (silences QTP0004).
qt_policy(SET QTP0004 NEW)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}" CACHE PATH
    "QML build-tree root; qt_add_qml_module appends URI path segments")

# Aggregate qmllint target across every QML module (CI: cmake --build <dir> --target qmllint).
add_custom_target(qmllint)
foreach(_module IN ITEMS datalogger_theme datalogger_components app)
    if(TARGET "${_module}_qmllint")
        add_dependencies(qmllint "${_module}_qmllint")
    endif()
endforeach()

# Shared UI kit (git submodule) — provides LoggerKit.Theme + LoggerKit.Components.
# Built as STATIC QML modules; version tracks this app's QML module version.
set(LOGGERKIT_QML_MODULE_VERSION ${DATALOGGER_QML_MODULE_VERSION})
add_subdirectory(shared/logger-ui-kit)

# Layers: utils → data → network → core → theme → components → app
add_subdirectory(src/utils)
add_subdirectory(src/data)
add_subdirectory(src/network)
add_subdirectory(src/core)
add_subdirectory(src/theme)
add_subdirectory(src/components)
add_subdirectory(src/app)

option(BUILD_TESTS "Build unit tests" ON)
if(BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

include(${CMAKE_SOURCE_DIR}/cmake/CPackOptions.cmake)

