# 测试脚本2：直接查找版本化的库文件
# 用法：docker run --rm -v "路径:/workspace" -v "sysroot:/opt/sysroot:ro" belt-control-rk3588:latest cmake -P /workspace/docker/rk3588/test_find_libraries2.cmake

cmake_minimum_required(VERSION 3.16)

set(CMAKE_SYSROOT "/opt/sysroot/pi-root")

message(STATUS "========================================")
message(STATUS "测试库查找功能 - 方法2：查找版本化文件")
message(STATUS "========================================")

# 方法1: 直接指定.so.1等版本号
find_library(LIB_X11_XCB
    NAMES X11-xcb.1 X11-xcb
    PATHS ${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu
    NO_DEFAULT_PATH
)
if(LIB_X11_XCB)
    message(STATUS "✅ 找到 libX11-xcb: ${LIB_X11_XCB}")
else()
    message(STATUS "❌ 未找到 libX11-xcb")
endif()

find_library(LIB_MPG123
    NAMES mpg123.0 mpg123
    PATHS ${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu
    NO_DEFAULT_PATH
)
if(LIB_MPG123)
    message(STATUS "✅ 找到 libmpg123: ${LIB_MPG123}")
else()
    message(STATUS "❌ 未找到 libmpg123")
endif()

find_library(LIB_CAP
    NAMES cap.2 cap
    PATHS ${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu
    NO_DEFAULT_PATH
)
if(LIB_CAP)
    message(STATUS "✅ 找到 libcap: ${LIB_CAP}")
else()
    message(STATUS "❌ 未找到 libcap")
endif()

find_library(LIB_LZ4
    NAMES lz4.1 lz4
    PATHS ${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu
    NO_DEFAULT_PATH
)
if(LIB_LZ4)
    message(STATUS "✅ 找到 liblz4: ${LIB_LZ4}")
else()
    message(STATUS "❌ 未找到 liblz4")
endif()

message(STATUS "========================================")

# 方法2: 直接使用完整路径
set(FULL_LIB_X11_XCB "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libX11-xcb.so.1.0.0")
set(FULL_LIB_MPG123 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libmpg123.so.0.48.2")
set(FULL_LIB_CAP "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libcap.so.2.66")
set(FULL_LIB_LZ4 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/liblz4.so.1.9.4")

if(EXISTS ${FULL_LIB_X11_XCB})
    message(STATUS "✅ 直接路径存在 libX11-xcb: ${FULL_LIB_X11_XCB}")
else()
    message(STATUS "❌ 直接路径不存在 libX11-xcb")
endif()

if(EXISTS ${FULL_LIB_MPG123})
    message(STATUS "✅ 直接路径存在 libmpg123: ${FULL_LIB_MPG123}")
else()
    message(STATUS "❌ 直接路径不存在 libmpg123")
endif()

if(EXISTS ${FULL_LIB_CAP})
    message(STATUS "✅ 直接路径存在 libcap: ${FULL_LIB_CAP}")
else()
    message(STATUS "❌ 直接路径不存在 libcap")
endif()

if(EXISTS ${FULL_LIB_LZ4})
    message(STATUS "✅ 直接路径存在 liblz4: ${FULL_LIB_LZ4}")
else()
    message(STATUS "❌ 直接路径不存在 liblz4")
endif()

message(STATUS "========================================")
