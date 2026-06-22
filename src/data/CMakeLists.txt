qt_add_library(data STATIC
    db/Database.cpp
    db/Database.h
    models/AppConfig.h
    models/Sensor.h
    models/SensorData.h
    models/AnalogDigitalLink.h
    models/ReportLog.h
    repositories/AppConfigDao.cpp
    repositories/AppConfigDao.h
    repositories/SensorDao.cpp
    repositories/SensorDao.h
    repositories/SensorDataDao.cpp
    repositories/SensorDataDao.h
    repositories/ReportLogDao.cpp
    repositories/ReportLogDao.h
)

target_include_directories(data PUBLIC ${CMAKE_SOURCE_DIR}/src)
target_include_directories(data PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/db
    ${CMAKE_CURRENT_SOURCE_DIR}/repositories
)

target_link_libraries(data PUBLIC Qt6::Core Qt6::Sql utils)

add_library(datalogger::data ALIAS data)
