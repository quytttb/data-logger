# CPack DEB — included from root CMakeLists.txt after all install() rules.
set(CPACK_GENERATOR DEB)
set(CPACK_PACKAGE_NAME data-logger-app)
set(CPACK_PACKAGE_VENDOR "4M Technologies")
set(CPACK_PACKAGE_CONTACT "dev@local")
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})

if(NOT CPACK_DEBIAN_PACKAGE_ARCHITECTURE)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
        set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE arm64)
    else()
        set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE amd64)
    endif()
endif()

set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}_${CPACK_PACKAGE_VERSION}_${CPACK_DEBIAN_PACKAGE_ARCHITECTURE}")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Data Logger — industrial sensors monitor desktop client")
set(CPACK_DEBIAN_PACKAGE_SECTION utils)
# OFF: Qt deploy bundles optional SQL/ODBC plugins; shlibdeps fails on CI without libmysqlclient, libpq, …
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS OFF)
# libgbm1/libdrm2/libinput10 are needed by the eglfs KMS/GBM integration so the
# app can render directly on DRM (Raspberry Pi OS Lite, no desktop). fonts-dejavu-core
# guarantees a usable system font on a minimal image.
set(CPACK_DEBIAN_PACKAGE_DEPENDS
    "libxkbcommon0, libegl1, libgl1, libopengl0, libfontconfig1, libdbus-1-3, libgbm1, libdrm2, libinput10, fonts-dejavu-core, libssl3"
)
set(CPACK_PACKAGING_INSTALL_PREFIX "/usr")

# Maintainer scripts: auto-enable/start the systemd kiosk service on install and
# stop/disable it on removal. STRICT_PERMISSION forces 0755 so dpkg accepts them.
set(CPACK_DEBIAN_PACKAGE_CONTROL_EXTRA
    "${CMAKE_SOURCE_DIR}/packaging/linux/debian/postinst;${CMAKE_SOURCE_DIR}/packaging/linux/debian/prerm;${CMAKE_SOURCE_DIR}/packaging/linux/debian/postrm"
)
set(CPACK_DEBIAN_PACKAGE_CONTROL_STRICT_PERMISSION ON)

include(CPack)
