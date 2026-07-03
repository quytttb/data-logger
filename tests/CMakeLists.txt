find_package(Qt6 6.11 REQUIRED COMPONENTS Core Sql Test)

add_executable(tt10_test tt10_test.cpp)
target_include_directories(tt10_test PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/src/core
)
target_link_libraries(tt10_test PRIVATE
    Qt6::Core
    Qt6::Sql
    utils
    datalogger_core
)

add_test(NAME tt10_test COMMAND tt10_test)
