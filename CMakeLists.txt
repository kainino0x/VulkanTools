# The name of our project is "VULKAN". CMakeLists files in this project can
# refer to the root source directory of the project as ${VULKAN_SOURCE_DIR} and
# to the root binary directory of the project as ${VULKAN_BINARY_DIR}.
cmake_minimum_required(VERSION 2.8.11)
project (VULKAN_TOOLS)
# set (CMAKE_VERBOSE_MAKEFILE 1)

# The API_NAME allows renaming builds to avoid conflicts with installed SDKs
# The MAJOR number of the version we're building, used in naming
# <api-name>-<major>.dll (and other files).
set(API_NAME "Vulkan" CACHE STRING "API name to use when building")
set(MAJOR "1")
string(TOLOWER ${API_NAME} API_LOWERCASE)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
find_package(PythonInterp 3 REQUIRED)

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(FALLBACK_CONFIG_DIRS "/etc/xdg" CACHE STRING
        "Search path to use when XDG_CONFIG_DIRS is unset or empty or the current process is SUID/SGID. Default is freedesktop compliant.")
    set(FALLBACK_DATA_DIRS "/usr/local/share:/usr/share" CACHE STRING
        "Search path to use when XDG_DATA_DIRS is unset or empty or the current process is SUID/SGID. Default is freedesktop compliant.")

    include(FindPkgConfig)
    option(BUILD_WSI_XCB_SUPPORT "Build XCB WSI support" ON)
    option(BUILD_WSI_XLIB_SUPPORT "Build Xlib WSI support" ON)
    option(BUILD_WSI_WAYLAND_SUPPORT "Build Wayland WSI support" ON)
    option(BUILD_WSI_MIR_SUPPORT "Build Mir WSI support" OFF)
    set(DEMOS_WSI_SELECTION "XCB" CACHE STRING "Select WSI target for demos (XCB, XLIB, WAYLAND, MIR, DISPLAY)")
    set(VKREPLAY_WSI_SELECTION "XCB" CACHE STRING "Select WSI target for vkreplay (XCB, WAYLAND, DISPLAY)")

    # Need to turn WSI_SELECTION into boolean definitions for preprocessor directives
    if (VKREPLAY_WSI_SELECTION STREQUAL "XCB")
        add_definitions(-DVKREPLAY_USE_WSI_XCB)
    elseif (VKREPLAY_WSI_SELECTION STREQUAL "WAYLAND")
        add_definitions(-DVKREPLAY_USE_WSI_WAYLAND)
    endif()

    if (BUILD_WSI_XCB_SUPPORT)
        find_package(XCB REQUIRED)
    endif()

    if (BUILD_WSI_XLIB_SUPPORT)
        find_package(X11 REQUIRED)
    endif()

    if (BUILD_WSI_WAYLAND_SUPPORT)
        find_package(Wayland REQUIRED)
        include_directories(${WAYLAND_CLIENT_INCLUDE_DIR})
    endif()

    if(BUILD_WSI_MIR_SUPPORT)
        find_package(Mir REQUIRED)
    endif()

    # This option can be used to suppress the installation of artifacts from the
    # Vulkan-LoaderAndValidationLayers repo while running "make install" for the
    # VulkanTools and VulkanSamples repos.  This can be used to prevent the
    # overwriting of LVL artifacts when installing these downstream repos.
    option(INSTALL_LVL_FILES "Install content from LoaderAndValidationLayers repo" ON)
endif()

set(SCRIPTS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/scripts")

# Header file for CMake settings
include_directories("${PROJECT_SOURCE_DIR}/include")

if (CMAKE_COMPILER_IS_GNUCC OR CMAKE_C_COMPILER_ID MATCHES "Clang")
    set(COMMON_COMPILE_FLAGS "-Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers")
    set(COMMON_COMPILE_FLAGS "${COMMON_COMPILE_FLAGS} -fno-strict-aliasing -fno-builtin-memcmp")

    # For GCC version 7.1 or greater, we need to disable the implicit fallthrough warning since
    # there's no consistent way to satisfy all compilers until they all accept the C++17 standard
    if (CMAKE_COMPILER_IS_GNUCC AND NOT (CMAKE_CXX_COMPILER_VERSION LESS 7.1))
        set(COMMON_COMPILE_FLAGS "${COMMON_COMPILE_FLAGS} -Wimplicit-fallthrough=0")
    endif()

    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c99 ${COMMON_COMPILE_FLAGS}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${COMMON_COMPILE_FLAGS} -std=c++11 -fno-rtti")
    if (UNIX)
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fvisibility=hidden")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fvisibility=hidden")
    endif()
endif()

if(WIN32)
    # Treat warnings as errors
    #add_compile_options("$<$<CXX_COMPILER_ID:MSVC>:/WX>")
    # Disable RTTI
    add_compile_options("$<$<CXX_COMPILER_ID:MSVC>:/GR->")
    # Warn about nested declarations
    add_compile_options("$<$<CXX_COMPILER_ID:MSVC>:/w34456>")
    # Warn about potentially uninitialized variables
    add_compile_options("$<$<CXX_COMPILER_ID:MSVC>:/w34701>")
    add_compile_options("$<$<CXX_COMPILER_ID:MSVC>:/w34703>")
endif()

if(NOT WIN32)
    set (BUILDTGT_DIR build)
    set (BINDATA_DIR Bin)
    set (LIBSOURCE_DIR Lib)
else()
    # is WIN32
    option(DISABLE_BUILD_PATH_DECORATION "Disable the decoration of the gslang and SPIRV-Tools build path with MSVC build type info" OFF)
    option(DISABLE_BUILDTGT_DIR_DECORATION "Disable the decoration of the gslang and SPIRV-Tools build path with target info" OFF)
    # For Windows, since 32-bit and 64-bit items can co-exist, we build each in its own build directory.
    # 32-bit target data goes in build32, and 64-bit target data goes into build.  So, include/link the
    # appropriate data at build time.
    if (DISABLE_BUILDTGT_DIR_DECORATION)
        set (BUILDTGT_DIR "")
        set (BINDATA_DIR "")
        set (LIBSOURCE_DIR "")
    elseif (CMAKE_CL_64)
        set (BUILDTGT_DIR build)
        set (BINDATA_DIR Bin)
        set (LIBSOURCE_DIR Lib)
    else()
        set (BUILDTGT_DIR build32)
        set (BINDATA_DIR Bin32)
        set (LIBSOURCE_DIR Lib32)
    endif()
endif()

if (CMAKE_SYSTEM_NAME STREQUAL "Windows" OR
    CMAKE_SYSTEM_NAME STREQUAL "Linux")

    # These are unchanged from upstream file
    option(BUILD_LOADER "Build loader" ON)
    option(BUILD_TESTS "Build tests" ON)
    option(BUILD_LAYERS "Build layers" ON)
    option(BUILD_LAYERSVT "Build layersvt" ON)
    option(BUILD_DEMOS "Build demos" ON)
    option(BUILD_VKTRACE "Build VkTrace" ON)
    option(BUILD_VKJSON "Build vkjson" ON)
    option(BUILD_VIA "Build via" ON)
    option(CUSTOM_GLSLANG_BIN_ROOT "Use the user defined GLSLANG_BINARY_ROOT" OFF)
    option(CUSTOM_SPIRV_TOOLS_BIN_ROOT "Use the user defined SPIRV_TOOLS_BINARY_ROOT" OFF)
    if (CMAKE_SYSTEM_NAME STREQUAL "Linux" AND NOT (BUILD_WSI_XCB_SUPPORT OR BUILD_WSI_WAYLAND_SUPPORT))
        option(BUILD_VKTRACE_REPLAY "Build VkReplay" OFF)
    else()
        option(BUILD_VKTRACE_REPLAY "Build VkReplay" ON)
    endif()

elseif (CMAKE_SYSTEM_NAME STREQUAL "Darwin")

    # Only vktrace enable for macOS
    option(BUILD_VKTRACE ON)
    option(BUILD_LOADER OFF)
    option(BUILD_TESTS OFF)
    option(BUILD_LAYERS OFF)
    option(BUILD_LAYERSVT OFF)
    option(BUILD_VKTRACEVIEWER OFF)
    option(BUILD_DEMOS OFF)
    option(BUILD_VKJSON OFF)
    option(BUILD_VIA OFF)
    option(BUILD_VKTRACE_LAYER OFF)
    option(BUILD_VKTRACE_REPLAY OFF)

endif()

#Choose natural default paths for glslang and SPIRV-Tools binaries to support custom definition by the user on the CMake command line or in the GUI
set(GLSLANG_BINARY_ROOT "${CMAKE_BINARY_DIR}/../glslang" CACHE STRING "User defined path to the glslang binaries for this project")
set(SPIRV_TOOLS_BINARY_ROOT "${CMAKE_BINARY_DIR}/../SPIRV-Tools" CACHE STRING "User defined path to the SPIRV-Tools binaries for this project")
set(SPIRV_TOOLS_OPT_BINARY_ROOT "${CMAKE_BINARY_DIR}/../SPIRV-Tools/opt" CACHE STRING "User defined path to the SPIRV-Tools-opt binaries for this project")

# Define a variable for a default root location to the gslang, SPIRV-Tools and other external sources and cache it to allow the user to customize it as needed
set(EXTERNAL_SOURCE_ROOT "${CMAKE_SOURCE_DIR}/external" CACHE STRING "Root path to external sources such as glslang and SPIRV-Tools")


if (WIN32)
    if(CUSTOM_GLSLANG_BIN_ROOT)
        set(GSLANG_FINAL_BINARY_PATH ${GLSLANG_BINARY_ROOT}/${BUILDTGT_DIR})
    else()
        set(GSLANG_FINAL_BINARY_PATH "${EXTERNAL_SOURCE_ROOT}/glslang/${BUILDTGT_DIR}")
    endif()

    if(DISABLE_BUILD_PATH_DECORATION)
        set (DEBUG_DECORATION "")
        set (RELEASE_DECORATION "")
    else()
        set (DEBUG_DECORATION "Debug")
        set (RELEASE_DECORATION "Release")
    endif()

    # Take some steps to set up a variable pointing to the final glslang binaries given the variety of input options
    set (GLSLANG_SEARCH_PATH "${GSLANG_FINAL_BINARY_PATH}/glslang/${RELEASE_DECORATION}"
                             "${GSLANG_FINAL_BINARY_PATH}/glslang/OSDependent/Windows/${RELEASE_DECORATION}"
                             "${GSLANG_FINAL_BINARY_PATH}/hlsl/${RELEASE_DECORATION}"
                             "${GSLANG_FINAL_BINARY_PATH}/OGLCompilersDLL/${RELEASE_DECORATION}"
                             "${GSLANG_FINAL_BINARY_PATH}/SPIRV/${RELEASE_DECORATION}" )

    set (GLSLANG_DEBUG_SEARCH_PATH "${GSLANG_FINAL_BINARY_PATH}/glslang/${DEBUG_DECORATION}"
                                   "${GSLANG_FINAL_BINARY_PATH}/glslang/OSDependent/Windows/${DEBUG_DECORATION}"
                                   "${GSLANG_FINAL_BINARY_PATH}/hlsl/${DEBUG_DECORATION}"
                                   "${GSLANG_FINAL_BINARY_PATH}/OGLCompilersDLL/${DEBUG_DECORATION}"
                                   "${GSLANG_FINAL_BINARY_PATH}/SPIRV/${DEBUG_DECORATION}")

    if(CUSTOM_SPIRV_TOOLS_BIN_ROOT)
        set (SPIRV_TOOLS_SEARCH_PATH "${SPIRV_TOOLS_BINARY_ROOT}/${BUILDTGT_DIR}/source/${RELEASE_DECORATION}")
        set (SPIRV_TOOLS_DEBUG_SEARCH_PATH "${SPIRV_TOOLS_BINARY_ROOT}/${BUILDTGT_DIR}/source/${DEBUG_DECORATION}")
        set (SPIRV_TOOLS_OPT_SEARCH_PATH "${SPIRV_TOOLS_OPT_BINARY_ROOT}/${BUILDTGT_DIR}/source/opt/${RELEASE_DECORATION}")
        set (SPIRV_TOOLS_OPT_DEBUG_SEARCH_PATH "${SPIRV_TOOLS_OPT_BINARY_ROOT}/${BUILDTGT_DIR}/source/opt/${DEBUG_DECORATION}")
    else()
        set (SPIRV_TOOLS_SEARCH_PATH "${EXTERNAL_SOURCE_ROOT}/spirv-tools/${BUILDTGT_DIR}/source/${RELEASE_DECORATION}")
        set (SPIRV_TOOLS_DEBUG_SEARCH_PATH "${EXTERNAL_SOURCE_ROOT}/spirv-tools/${BUILDTGT_DIR}/source/${DEBUG_DECORATION}")
        set (SPIRV_TOOLS_OPT_SEARCH_PATH "${EXTERNAL_SOURCE_ROOT}/spirv-tools/${BUILDTGT_DIR}/source/opt/${RELEASE_DECORATION}")
        set (SPIRV_TOOLS_OPT_DEBUG_SEARCH_PATH "${EXTERNAL_SOURCE_ROOT}/spirv-tools/${BUILDTGT_DIR}/source/opt/${DEBUG_DECORATION}")
    endif()
else()
    # not WIN32
    if(CUSTOM_GLSLANG_BIN_ROOT)
        set (GLSLANG_SEARCH_PATH "${GLSLANG_BINARY_ROOT}/install/lib"
                                 "${GLSLANG_BINARY_ROOT}/glslang"
                                 "${GLSLANG_BINARY_ROOT}/glslang/OSDependent/Unix"
                                 "${GLSLANG_BINARY_ROOT}/OGLCompilersDLL"
                                 "${GLSLANG_BINARY_ROOT}/SPIRV"
                                 "${GLSLANG_BINARY_ROOT}/hlsl"
                                 "${GLSLANG_BINARY_ROOT}/StandAlone")
    else()
        set (GLSLANG_SEARCH_PATH "${EXTERNAL_SOURCE_ROOT}/glslang/${BUILDTGT_DIR}/install/lib" "${CMAKE_SOURCE_DIR}/../x86_64/lib/glslang" )
    endif()

    if(CUSTOM_SPIRV_TOOLS_BIN_ROOT)
        set (SPIRV_TOOLS_SEARCH_PATH "${SPIRV_TOOLS_BINARY_ROOT}/source" )
        set (SPIRV_TOOLS_OPT_SEARCH_PATH "${SPIRV_TOOLS_OPT_BINARY_ROOT}/source/opt" )
    else()
        set (SPIRV_TOOLS_SEARCH_PATH "${EXTERNAL_SOURCE_ROOT}/spirv-tools/${BUILDTGT_DIR}/source" "${CMAKE_SOURCE_DIR}/../x86_64/lib/spirv-tools" )
        set (SPIRV_TOOLS_OPT_SEARCH_PATH "${EXTERNAL_SOURCE_ROOT}/spirv-tools/${BUILDTGT_DIR}/source/opt" "${CMAKE_SOURCE_DIR}/../x86_64/lib/spirv-tools" )
    endif()
endif()

find_program(GLSLANG_VALIDATOR NAMES glslangValidator
             HINTS "${CMAKE_SOURCE_DIR}/external/glslang/${BUILDTGT_DIR}/install/bin"
                   "${GLSLANG_BINARY_ROOT}/StandAlone"
                   "${PROJECT_SOURCE_DIR}/external/${BINDATA_DIR}")

find_path(GLSLANG_SPIRV_INCLUDE_DIR SPIRV/spirv.hpp HINTS "${EXTERNAL_SOURCE_ROOT}/glslang"
                                                    "${CMAKE_SOURCE_DIR}/../glslang"
                                              DOC "Path to SPIRV/spirv.hpp")

find_path(SPIRV_TOOLS_INCLUDE_DIR spirv-tools/libspirv.h HINTS "${EXTERNAL_SOURCE_ROOT}/spirv-tools/include"
                                                   "${EXTERNAL_SOURCE_ROOT}/SPIRV-Tools/include"
                                                   "${CMAKE_SOURCE_DIR}/../spirv-tools/include"
                                                   "${CMAKE_SOURCE_DIR}/../SPIRV-Tools/include"
                                                   "${EXTERNAL_SOURCE_ROOT}/source/spirv-tools/external/include"
                                             DOC "Path to spirv-tools/libspirv.h")

find_path(JSONCPP_INCLUDE_DIR json/json.h HINTS "${EXTERNAL_SOURCE_ROOT}/jsoncpp/dist"
                                                   "${EXTERNAL_SOURCE_ROOT}/JsonCpp/dist"
                                                   "${EXTERNAL_SOURCE_ROOT}/JsonCPP/dist"
                                                   "${EXTERNAL_SOURCE_ROOT}/JSONCPP/dist"
                                                   "${CMAKE_SOURCE_DIR}/../jsoncpp/dist"
                                             DOC "Path to jsoncpp/dist/json/json.h")

find_path(JSONCPP_SOURCE_DIR jsoncpp.cpp HINTS "${EXTERNAL_SOURCE_ROOT}/jsoncpp/dist"
                                                   "${EXTERNAL_SOURCE_ROOT}/JsonCpp/dist"
                                                   "${EXTERNAL_SOURCE_ROOT}/JsonCPP/dist"
                                                   "${EXTERNAL_SOURCE_ROOT}/JSONCPP/dist"
                                                   "${CMAKE_SOURCE_DIR}/../jsoncpp/dist"
                                             DOC "Path to jsoncpp/dist/json.cpp")

    find_library(GLSLANG_LIB NAMES glslang
        HINTS ${GLSLANG_SEARCH_PATH} )

    find_library(OGLCompiler_LIB NAMES OGLCompiler
        HINTS ${GLSLANG_SEARCH_PATH} )

    find_library(OSDependent_LIB NAMES OSDependent
        HINTS ${GLSLANG_SEARCH_PATH} )

    find_library(HLSL_LIB NAMES HLSL
        HINTS ${GLSLANG_SEARCH_PATH} )

    find_library(SPIRV_LIB NAMES SPIRV
        HINTS ${GLSLANG_SEARCH_PATH} )

    find_library(SPIRV_REMAPPER_LIB NAMES SPVRemapper
             HINTS ${GLSLANG_SEARCH_PATH} )

    find_library(SPIRV_TOOLS_LIB NAMES SPIRV-Tools
             HINTS ${SPIRV_TOOLS_SEARCH_PATH} )

    find_library(JSONCPP_LIB NAMES jsoncpp
             HINTS ${JSONCPP_SEARCH_PATH} )

    find_library(SPIRV_TOOLS_OPT_LIB NAMES SPIRV-Tools-opt
             HINTS ${SPIRV_TOOLS_OPT_SEARCH_PATH} )

if (WIN32)
    add_library(glslang         STATIC IMPORTED)
    add_library(OGLCompiler     STATIC IMPORTED)
    add_library(OSDependent     STATIC IMPORTED)
    add_library(HLSL            STATIC IMPORTED)
    add_library(SPIRV           STATIC IMPORTED)
    add_library(SPVRemapper     STATIC IMPORTED)
    add_library(Loader          STATIC IMPORTED)
    add_library(SPIRV-Tools-opt STATIC IMPORTED)
    add_library(SPIRV-Tools     STATIC IMPORTED)
    add_library(jsoncpp         STATIC IMPORTED)

    find_library(GLSLANG_DLIB NAMES glslangd
                 HINTS ${GLSLANG_DEBUG_SEARCH_PATH} )
    find_library(OGLCompiler_DLIB NAMES OGLCompilerd
                 HINTS ${GLSLANG_DEBUG_SEARCH_PATH} )
    find_library(OSDependent_DLIB NAMES OSDependentd
                 HINTS ${GLSLANG_DEBUG_SEARCH_PATH} )
    find_library(HLSL_DLIB NAMES HLSLd
                 HINTS ${GLSLANG_DEBUG_SEARCH_PATH} )
    find_library(SPIRV_DLIB NAMES SPIRVd
                 HINTS ${GLSLANG_DEBUG_SEARCH_PATH} )
    find_library(SPIRV_REMAPPER_DLIB NAMES SPVRemapperd
                 HINTS ${GLSLANG_DEBUG_SEARCH_PATH} )
    find_library(SPIRV_TOOLS_DLIB NAMES SPIRV-Tools
                 HINTS ${SPIRV_TOOLS_DEBUG_SEARCH_PATH} )
    find_library(JSONCPP_DLIB NAMES jsoncpp
                 HINTS ${JSONCPP_DEBUG_SEARCH_PATH} )
    find_library(SPIRV_TOOLS_OPT_DLIB NAMES SPIRV-Tools-opt
                 HINTS ${SPIRV_TOOLS_OPT_DEBUG_SEARCH_PATH} )

    set_target_properties(glslang PROPERTIES
                          IMPORTED_LOCATION       "${GLSLANG_LIB}"
                          IMPORTED_LOCATION_DEBUG "${GLSLANG_DLIB}")
    set_target_properties(OGLCompiler PROPERTIES
                          IMPORTED_LOCATION       "${OGLCompiler_LIB}"
                          IMPORTED_LOCATION_DEBUG "${OGLCompiler_DLIB}")
    set_target_properties(OSDependent PROPERTIES
                          IMPORTED_LOCATION       "${OSDependent_LIB}"
                          IMPORTED_LOCATION_DEBUG "${OSDependent_DLIB}")
    set_target_properties(HLSL PROPERTIES
                          IMPORTED_LOCATION       "${HLSL_LIB}"
                          IMPORTED_LOCATION_DEBUG "${HLSL_DLIB}")
    set_target_properties(SPIRV PROPERTIES
                         IMPORTED_LOCATION       "${SPIRV_LIB}"
                         IMPORTED_LOCATION_DEBUG "${SPIRV_DLIB}")
    set_target_properties(SPVRemapper PROPERTIES
                         IMPORTED_LOCATION       "${SPIRV_REMAPPER_LIB}"
                         IMPORTED_LOCATION_DEBUG "${SPIRV_REMAPPER_DLIB}")
    set_target_properties(SPIRV-Tools PROPERTIES
                          IMPORTED_LOCATION       "${SPIRV_TOOLS_LIB}"
                          IMPORTED_LOCATION_DEBUG "${SPIRV_TOOLS_DLIB}")
    set_target_properties(jsoncpp PROPERTIES
                         IMPORTED_LOCATION       "${JSONCPP_LIB}"
                         IMPORTED_LOCATION_DEBUG "${JSONCPP_DLIB}")
    set_target_properties(SPIRV-Tools-opt PROPERTIES
                         IMPORTED_LOCATION       "${SPIRV_TOOLS_OPT_LIB}"
                         IMPORTED_LOCATION_DEBUG "${SPIRV_TOOLS_OPT_DLIB}")

    set (SPIRV_TOOLS_LIBRARIES SPIRV-Tools-opt SPIRV-Tools)
    set (GLSLANG_LIBRARIES glslang OGLCompiler OSDependent HLSL SPIRV SPVRemapper ${SPIRV_TOOLS_LIBRARIES})
else ()
    # not WIN32
    set (SPIRV_TOOLS_LIBRARIES ${SPIRV_TOOLS_OPT_LIB} ${SPIRV_TOOLS_LIB})
    set (GLSLANG_LIBRARIES ${GLSLANG_LIB} ${OGLCompiler_LIB} ${OSDependent_LIB} ${HLSL_LIB} ${SPIRV_LIB} ${SPIRV_REMAPPER_LIB} ${SPIRV_TOOLS_LIBRARIES})
endif()

set (PYTHON_CMD ${PYTHON_EXECUTABLE})

# Define macro used for building vkxml generated files
macro(run_vk_xml_generate dependency output)
    add_custom_command(OUTPUT ${output}
    COMMAND ${PYTHON_CMD} ${SCRIPTS_DIR}/lvl_genvk.py -registry ${SCRIPTS_DIR}/vk.xml ${output}
    DEPENDS ${SCRIPTS_DIR}/vk.xml ${SCRIPTS_DIR}/generator.py ${SCRIPTS_DIR}/${dependency} ${SCRIPTS_DIR}/lvl_genvk.py ${SCRIPTS_DIR}/reg.py
    )
endmacro()

# Custom target for generated vulkan helper file dependencies
add_custom_target(generate_helper_files DEPENDS
    vk_enum_string_helper.h
    vk_struct_size_helper.h
    vk_struct_size_helper.c
    vk_safe_struct.h
    vk_safe_struct.cpp
    vk_object_types.h
    vk_layer_dispatch_table.h
    vk_dispatch_table_helper.h
    vk_extension_helper.h
    )

# Rules to build generated helper files
run_vk_xml_generate(loader_extension_generator.py vk_layer_dispatch_table.h)
run_vk_xml_generate(dispatch_table_helper_generator.py vk_dispatch_table_helper.h)
run_vk_xml_generate(helper_file_generator.py vk_safe_struct.h)
run_vk_xml_generate(helper_file_generator.py vk_safe_struct.cpp)
run_vk_xml_generate(helper_file_generator.py vk_struct_size_helper.h)
run_vk_xml_generate(helper_file_generator.py vk_struct_size_helper.c)
run_vk_xml_generate(helper_file_generator.py vk_enum_string_helper.h)
run_vk_xml_generate(helper_file_generator.py vk_object_types.h)
run_vk_xml_generate(helper_file_generator.py vk_extension_helper.h)

if(NOT WIN32)
    include(GNUInstallDirs)

    add_definitions(-DFALLBACK_CONFIG_DIRS="${FALLBACK_CONFIG_DIRS}")
    add_definitions(-DFALLBACK_DATA_DIRS="${FALLBACK_DATA_DIRS}")
    add_definitions(-DSYSCONFDIR="${CMAKE_INSTALL_FULL_SYSCONFDIR}")

    # Make sure /etc is searched by the loader
    if(NOT (CMAKE_INSTALL_FULL_SYSCONFDIR STREQUAL "/etc"))
        add_definitions(-DEXTRASYSCONFDIR="/etc")
    endif()
endif()

if(UNIX)
    if(INSTALL_LVL_FILES)
        install(DIRECTORY "${PROJECT_SOURCE_DIR}/include/vulkan" DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
        install(FILES "${CMAKE_CURRENT_BINARY_DIR}/vk_layer_dispatch_table.h" DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/vulkan")
    endif()

# uninstall target
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/cmake_uninstall.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
    IMMEDIATE @ONLY)

add_custom_target(uninstall
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)
endif()

add_definitions(-DAPI_NAME="${API_NAME}")

# loader: Generic VULKAN ICD loader
# tests: VULKAN tests
if(BUILD_LOADER)
    add_subdirectory(loader)
endif()

if(BUILD_TESTS)
    add_subdirectory(tests)
endif()

if(BUILD_LAYERS)
    add_subdirectory(layers)
endif()

if(BUILD_LAYERSVT)
    add_subdirectory(layersvt)
endif()

if(BUILD_DEMOS)
    add_subdirectory(demos)
endif()

if(BUILD_VKTRACE)
    add_subdirectory(vktrace)
endif()

if(BUILD_VKJSON)
    add_subdirectory(libs/vkjson)
endif()

if(BUILD_VIA)
    add_subdirectory(via)
endif()

if(BUILD_ICD)
    add_subdirectory(icd)
endif()
