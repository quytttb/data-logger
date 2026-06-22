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

include(${CMAKE_SOURCE_DIR}/cmake/CPackOptions.cmake)

