# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# Use C++ 20 for ODBC and its subdirectory
# GH-44792: Arrow will switch to C++ 20
set(CMAKE_CXX_STANDARD 20)

if(WIN32)
  if(MSVC_VERSION GREATER_EQUAL 1900)
    set(ODBCINST legacy_stdio_definitions odbccp32 shlwapi)
  elseif(MINGW)
    set(ODBCINST odbccp32 shlwapi)
  endif()
elseif(APPLE)
  set(ODBCINST iodbcinst)
else()
  set(ODBCINST odbcinst)
endif()

# On Windows, deephaven libraries may only be built for Debug configuration.
# Map all configurations to use Debug libraries to avoid IMPORTED_IMPLIB errors.
# TODO remove when the deephaven libraries are available for Release and RelWithDebInfo configurations
if(WIN32)
  set(CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL Debug)
  set(CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO Debug)
  set(CMAKE_MAP_IMPORTED_CONFIG_RELEASE Debug)
endif()

find_package(deephaven CONFIG REQUIRED)
find_package(deephaven_enterprise CONFIG REQUIRED)

add_subdirectory(odbc_impl)
add_subdirectory(tests)

arrow_install_all_headers("arrow/flight/sql/odbc")

# ODBC Release information
# Flight SQL ODBC version uses Arrow version
set(ODBC_PACKAGE_VERSION_MAJOR "${arrow_VERSION_MAJOR}")
set(ODBC_PACKAGE_VERSION_MINOR "${arrow_VERSION_MINOR}")
set(ODBC_PACKAGE_VERSION_PATCH "${arrow_VERSION_PATCH}")
set(ODBC_PACKAGE_NAME "Deephaven Enterprise Flight SQL ODBC")
set(ODBC_PACKAGE_VENDOR "Deephaven Data Labs")

set(ARROW_FLIGHT_SQL_ODBC_SRCS entry_points.cc odbc_api.cc)

if(WIN32)
  set(VER_FILEVERSION
      "${ODBC_PACKAGE_VERSION_MAJOR},${ODBC_PACKAGE_VERSION_MINOR},${ODBC_PACKAGE_VERSION_PATCH},0"
  )
  set(VER_FILEVERSION_STR
      ${ODBC_PACKAGE_VERSION_MAJOR}.${ODBC_PACKAGE_VERSION_MINOR}.${ODBC_PACKAGE_VERSION_PATCH}
  )
  set(VER_COMPANYNAME_STR ${ODBC_PACKAGE_VENDOR})
  set(VER_PRODUCTNAME_STR ${ODBC_PACKAGE_NAME})

  configure_file("install/windows/versioninfo.rc.in" "install/versioninfo.rc" @ONLY)

  list(APPEND ARROW_FLIGHT_SQL_ODBC_SRCS odbc.def install/versioninfo.rc)
endif()

add_arrow_lib(deephaven_flight_sql_odbc
              CMAKE_PACKAGE_NAME
              ArrowFlightSqlOdbc
              PKG_CONFIG_NAME
              arrow-flight-sql-odbc
              OUTPUTS
              ARROW_FLIGHT_SQL_ODBC_LIBRARIES
              SOURCES
              ${ARROW_FLIGHT_SQL_ODBC_SRCS}
              DEPENDENCIES
              arrow_flight_sql
              DEFINITIONS
              UNICODE
              SHARED_LINK_FLAGS
              ${ARROW_VERSION_SCRIPT_FLAGS} # Defined in cpp/arrow/CMakeLists.txt
              SHARED_LINK_LIBS
              arrow_flight_sql_shared
              SHARED_INSTALL_INTERFACE_LIBS
              ArrowFlight::arrow_flight_sql_shared
              STATIC_LINK_LIBS
              arrow_flight_sql_static
              STATIC_INSTALL_INTERFACE_LIBS
              ArrowFlight::arrow_flight_sql_static
              SHARED_PRIVATE_LINK_LIBS
              ODBC::ODBC
              ${ODBCINST}
              arrow_odbc_spi_impl
              deephaven::dhcore
              deephaven::dhclient
              deephaven_enterprise::dhe_client)

foreach(LIB_TARGET ${ARROW_FLIGHT_SQL_ODBC_LIBRARIES})
  target_compile_definitions(${LIB_TARGET} PRIVATE ARROW_FLIGHT_SQL_ODBC_EXPORTING)
endforeach()

# Construct ODBC Windows installer. Only Release installer is supported
if(ARROW_FLIGHT_SQL_ODBC_INSTALLER)

  include(InstallRequiredSystemLibraries)

  set(CPACK_RESOURCE_FILE_LICENSE
      "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../LICENSE.txt")

  set(CPACK_PACKAGE_VERSION_MAJOR ${ODBC_PACKAGE_VERSION_MAJOR})
  set(CPACK_PACKAGE_VERSION_MINOR ${ODBC_PACKAGE_VERSION_MINOR})
  set(CPACK_PACKAGE_VERSION_PATCH ${ODBC_PACKAGE_VERSION_PATCH})

  set(CPACK_PACKAGE_NAME ${ODBC_PACKAGE_NAME})
  # Make sure the MSI name contains only hyphens, not spaces
  string(REPLACE " " "-" CPACK_PACKAGE_NAME "${CPACK_PACKAGE_NAME}")
  set(CPACK_PACKAGE_VENDOR ${ODBC_PACKAGE_VENDOR})
  set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Deephaven Enterprise Flight SQL ODBC Driver")
  set(CPACK_PACKAGE_CONTACT "support@deephaven.io")

  # GH-47876 TODO: set up `arrow_flight_sql_odbc` component for macOS Installer
  # GH-47877 TODO: set up `arrow_flight_sql_odbc` component for Linux Installer
  if(WIN32)
    # Note: Library target and component name both use "deephaven_flight_sql_odbc"
    # WiX adds "CM_C_" prefix to component names and has a 38-character limit for
    # feature IDs. This name is used throughout to ensure CPack generates predictable
    # File IDs matching Arrow's pattern.

    # Install ODBC and its Arrow dependencies
    install(PROGRAMS ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS}
            DESTINATION bin
            COMPONENT deephaven_flight_sql_odbc)
    install(TARGETS arrow_shared
                    arrow_compute_shared
                    arrow_flight_shared
                    arrow_flight_sql_shared
                    deephaven_flight_sql_odbc_shared
            RUNTIME DESTINATION bin COMPONENT deephaven_flight_sql_odbc)

    # Find CURL package to get access to CURL::libcurl target
    find_package(CURL REQUIRED)

    # Manually install deephaven DLLs and their dependencies
    # vcpkg's RUNTIME_DEPENDENCIES doesn't work with its own toolchain, so we install manually
    foreach(CONFIG_TYPE Debug Release RelWithDebInfo MinSizeRel)
      string(TOUPPER ${CONFIG_TYPE} CONFIG_TYPE_UPPER)

      # Get deephaven DLL locations for this configuration
      get_target_property(DHCORE_DLL deephaven::dhcore IMPORTED_LOCATION_${CONFIG_TYPE_UPPER})
      get_target_property(DHCLIENT_DLL deephaven::dhclient IMPORTED_LOCATION_${CONFIG_TYPE_UPPER})
      get_target_property(DHE_CLIENT_DLL deephaven_enterprise::dhe_client IMPORTED_LOCATION_${CONFIG_TYPE_UPPER})

      # Install deephaven DLLs if they exist for this configuration
      if(DHCORE_DLL AND EXISTS "${DHCORE_DLL}")
        install(FILES ${DHCORE_DLL}
                DESTINATION bin
                COMPONENT deephaven_flight_sql_odbc
                CONFIGURATIONS ${CONFIG_TYPE})
      endif()
      if(DHCLIENT_DLL AND EXISTS "${DHCLIENT_DLL}")
        install(FILES ${DHCLIENT_DLL}
                DESTINATION bin
                COMPONENT deephaven_flight_sql_odbc
                CONFIGURATIONS ${CONFIG_TYPE})
      endif()
      if(DHE_CLIENT_DLL AND EXISTS "${DHE_CLIENT_DLL}")
        install(FILES ${DHE_CLIENT_DLL}
                DESTINATION bin
                COMPONENT deephaven_flight_sql_odbc
                CONFIGURATIONS ${CONFIG_TYPE})
      endif()

      # Install curl.dll (transitive dependency of deephaven)
      # Curl is in vcpkg but not auto-copied for external packages
      if(TARGET CURL::libcurl)
        get_target_property(CURL_DLL CURL::libcurl IMPORTED_LOCATION_${CONFIG_TYPE_UPPER})
        if(CURL_DLL AND EXISTS "${CURL_DLL}")
          install(FILES ${CURL_DLL}
                  DESTINATION bin
                  COMPONENT deephaven_flight_sql_odbc
                  CONFIGURATIONS ${CONFIG_TYPE})
        endif()
      endif()
    endforeach()

    set(CPACK_WIX_EXTRA_SOURCES
        "${CMAKE_CURRENT_SOURCE_DIR}/install/windows/arrow-flight-sql-odbc.wxs")
    set(CPACK_WIX_PATCH_FILE
        "${CMAKE_CURRENT_SOURCE_DIR}/install/windows/arrow-flight-sql-odbc-patch.xml")

    # Banner removed - using default WiX installer UI without custom branding
    # set(CPACK_WIX_UI_BANNER
    #     "${CMAKE_CURRENT_SOURCE_DIR}/install/windows/arrow-wix-banner.bmp")
  endif()

  get_cmake_property(CPACK_COMPONENTS_ALL COMPONENTS)
  set(CPACK_COMPONENTS_ALL "deephaven_flight_sql_odbc")

  if(WIN32)
    # WiX msi installer on Windows
    # CPack is compatible with WiX V.5 and V.6
    set(CPACK_GENERATOR "WIX")
    set(CPACK_WIX_VERSION 4)

    # Set installation directory without version suffix so registry entries remain valid across upgrades
    set(CPACK_PACKAGE_INSTALL_DIRECTORY "Deephaven Enterprise Flight SQL ODBC")

    # Upgrade GUID must remain unchanged across versions to allow proper upgrades
    # Product GUID should be unique for each product variant
    # These GUIDs are different from Apache Arrow's to ensure Windows treats this as a separate product
    set(CPACK_WIX_UPGRADE_GUID "A7C2E8F1-4D9B-4A3E-8F2C-1B5D7E9A3C6F")
    set(CPACK_WIX_PRODUCT_GUID "3F8E1D4A-9C7B-4E2F-A1D8-6B3E9C5A2F7D")
  endif()
  # GH-47876 TODO: create macOS Installer using cpack
  # GH-47877 TODO: create Linux Installer using cpack

  # Load CPack after all CPACK* variables are set
  include(CPack)
  cpack_add_component(deephaven_flight_sql_odbc
                      DISPLAY_NAME "Deephaven Enterprise Flight SQL ODBC Driver"
                      DESCRIPTION "Deephaven Enterprise Flight SQL ODBC Driver library, required to install"
                      REQUIRED)
endif()
