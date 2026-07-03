cmake_minimum_required(VERSION 3.16)
project(DataLogger VERSION 2.0.0 LANGUAGES CXX)

find_package(Qt6 6.11 REQUIRED COMPONENTS
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

qt_standard_project_setup(REQUIRES 6.11)

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

