cmake_minimum_required(VERSION 3.10)
set(CMAKE_ALLOW_LOOSE_LOOP_CONSTRUCTS ON)

set(VERSION "1.2.13")

if (CMAKE_VERSION VERSION_LESS "3.0")
    project(ZLIB C)
else()
    cmake_policy(SET CMP0048 NEW)
    project(ZLIB VERSION ${VERSION} LANGUAGES C)
endif()

include(EasePackageHelper REQUIRED)
add_package(ZLIB VERSION "${VERSION}")

set(INSTALL_BIN_DIR "${CMAKE_INSTALL_PREFIX}/bin" CACHE PATH "Installation directory for executables")
set(INSTALL_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib" CACHE PATH "Installation directory for libraries")
set(INSTALL_INC_DIR "${CMAKE_INSTALL_PREFIX}/include" CACHE PATH "Installation directory for headers")
set(INSTALL_MAN_DIR "${CMAKE_INSTALL_PREFIX}/share/man" CACHE PATH "Installation directory for manual pages")
set(INSTALL_PKGCONFIG_DIR "${CMAKE_INSTALL_PREFIX}/share/pkgconfig" CACHE PATH "Installation directory for pkgconfig (.pc) files")

include(CheckTypeSize)
include(CheckFunctionExists)
include(CheckIncludeFile)
include(CheckCSourceCompiles)
enable_testing()

check_include_file(sys/types.h HAVE_SYS_TYPES_H)
check_include_file(stdint.h    HAVE_STDINT_H)
check_include_file(stddef.h    HAVE_STDDEF_H)

#
# Check to see if we have large file support
#
set(CMAKE_REQUIRED_DEFINITIONS -D_LARGEFILE64_SOURCE=1)
# We add these other definitions here because CheckTypeSize.cmake
# in CMake 2.4.x does not automatically do so and we want
# compatibility with CMake 2.4.x.
if(HAVE_SYS_TYPES_H)
    list(APPEND CMAKE_REQUIRED_DEFINITIONS -DHAVE_SYS_TYPES_H)
endif()
if(HAVE_STDINT_H)
    list(APPEND CMAKE_REQUIRED_DEFINITIONS -DHAVE_STDINT_H)
endif()
if(HAVE_STDDEF_H)
    list(APPEND CMAKE_REQUIRED_DEFINITIONS -DHAVE_STDDEF_H)
endif()
check_type_size(off64_t OFF64_T)
if(HAVE_OFF64_T)
   add_definitions(-D_LARGEFILE64_SOURCE=1)
endif()
set(CMAKE_REQUIRED_DEFINITIONS) # clear variable

#
# Check for fseeko
#
check_function_exists(fseeko HAVE_FSEEKO)
if(NOT HAVE_FSEEKO)
    add_definitions(-DNO_FSEEKO)
endif()

#
# Check for unistd.h
#
check_include_file(unistd.h Z_HAVE_UNISTD_H)

set(ZLIB_PC ${CMAKE_CURRENT_BINARY_DIR}/zlib.pc)
configure_file( ${CMAKE_CURRENT_SOURCE_DIR}/zlib.pc.cmakein
        ${ZLIB_PC} @ONLY)
configure_file( ${CMAKE_CURRENT_SOURCE_DIR}/zconf.h.cmakein
        ${CMAKE_CURRENT_BINARY_DIR}/zconf.h @ONLY)


#============================================================================
# zlib
#============================================================================

set(ZLIB_PUBLIC_HDRS
    ${CMAKE_CURRENT_BINARY_DIR}/zconf.h
    zlib.h
)
set(ZLIB_PRIVATE_HDRS
    crc32.h
    deflate.h
    gzguts.h
    inffast.h
    inffixed.h
    inflate.h
    inftrees.h
    trees.h
    zutil.h
)
set(ZLIB_SRCS
    adler32.c
    compress.c
    crc32.c
    deflate.c
    gzclose.c
    gzlib.c
    gzread.c
    gzwrite.c
    inflate.c
    infback.c
    inftrees.c
    inffast.c
    trees.c
    uncompr.c
    zutil.c
)

# parse the full version number from zlib.h and include in ZLIB_FULL_VERSION
file(READ ${CMAKE_CURRENT_SOURCE_DIR}/zlib.h _zlib_h_contents)
string(REGEX REPLACE ".*#define[ \t]+ZLIB_VERSION[ \t]+\"([-0-9A-Za-z.]+)\".*"
    "\\1" ZLIB_FULL_VERSION ${_zlib_h_contents})

if(MINGW)
    # This gets us DLL resource information when compiling on MinGW.
    if(NOT CMAKE_RC_COMPILER)
        set(CMAKE_RC_COMPILER windres.exe)
    endif()

    add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/zlib1rc.obj
                       COMMAND ${CMAKE_RC_COMPILER}
                            -D GCC_WINDRES
                            -I ${CMAKE_CURRENT_SOURCE_DIR}
                            -I ${CMAKE_CURRENT_BINARY_DIR}
                            -o ${CMAKE_CURRENT_BINARY_DIR}/zlib1rc.obj
                            -i ${CMAKE_CURRENT_SOURCE_DIR}/win32/zlib1.rc)
    set(ZLIB_DLL_SRCS ${CMAKE_CURRENT_BINARY_DIR}/zlib1rc.obj)
endif(MINGW)

add_library(ZLIB ${ZLIB_SRCS} ${ZLIB_DLL_SRCS} ${ZLIB_PUBLIC_HDRS} ${ZLIB_PRIVATE_HDRS})
set_target_properties(ZLIB PROPERTIES SOVERSION 1)

# Disable warnings
if(MSVC)
    set(CMAKE_DEBUG_POSTFIX "d")
    target_compile_definitions(ZLIB PRIVATE _CRT_SECURE_NO_DEPRECATE)
    target_compile_definitions(ZLIB PRIVATE _CRT_NONSTDC_NO_DEPRECATE)
    target_compile_options(ZLIB PRIVATE /wd4127 /wd4131 /wd4244 /wd4245 /wd4267)
    include_directories(${CMAKE_CURRENT_SOURCE_DIR})
endif()
if (CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(ZLIB PRIVATE -Wno-implicit-function-declaration)
    target_compile_options(ZLIB PRIVATE -Wno-deprecated-non-prototype)
endif()



include(GenerateExportHeader)
generate_export_header(ZLIB)
list(APPEND ZLIB_PUBLIC_HDRS "${CMAKE_CURRENT_BINARY_DIR}/zlib_export.h")

if(NOT CYGWIN)
    # This property causes shared libraries on Linux to have the full version
    # encoded into their final filename.  We disable this on Cygwin because
    # it causes cygz-${ZLIB_FULL_VERSION}.dll to be created when cygz.dll
    # seems to be the default.
    #
    # This has no effect with MSVC, on that platform the version info for
    # the DLL comes from the resource file win32/zlib1.rc
    set_target_properties(ZLIB PROPERTIES VERSION ${ZLIB_FULL_VERSION})
endif()

if(UNIX)
   if(NOT APPLE)
     set_target_properties(ZLIB PROPERTIES LINK_FLAGS "-Wl,--version-script,\"${CMAKE_CURRENT_SOURCE_DIR}/zlib.map\"")
   endif()
endif()

target_include_directories(ZLIB PUBLIC
  "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>"
  "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>")

package_library(ZLIB)
install(FILES ${ZLIB_PUBLIC_HDRS} DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")
install(FILES zlib.3 DESTINATION "${CMAKE_INSTALL_DATADIR}/man/man3")
install(FILES ${ZLIB_PC} DESTINATION "${CMAKE_INSTALL_DATADIR}/pkgconfig")
return()

#============================================================================
# Example binaries
#============================================================================

add_executable(example test/example.c)
target_link_libraries(example ZLIB)
add_test(example example)

add_executable(minigzip test/minigzip.c)
target_link_libraries(minigzip ZLIB)

if(HAVE_OFF64_T)
    add_executable(example64 test/example.c)
    target_link_libraries(example64 ZLIB)
    set_target_properties(example64 PROPERTIES COMPILE_FLAGS "-D_FILE_OFFSET_BITS=64")
    add_test(example64 example64)

    add_executable(minigzip64 test/minigzip.c)
    target_link_libraries(minigzip64 ZLIB)
    set_target_properties(minigzip64 PROPERTIES COMPILE_FLAGS "-D_FILE_OFFSET_BITS=64")
endif()
