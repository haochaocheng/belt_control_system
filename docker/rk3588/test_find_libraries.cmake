# 测试脚本：验证find_library能否找到缺失符号链接的库
# 用法：docker run --rm -v "路径:/workspace" -v "sysroot:/opt/sysroot:ro" belt-control-rk3588:latest cmake -P /workspace/docker/rk3588/test_find_libraries.cmake

cmake_minimum_required(VERSION 3.16)

# 设置CMAKE_SYSROOT
set(CMAKE_SYSROOT "/opt/sysroot/pi-root")

message(STATUS "========================================")
message(STATUS "测试库查找功能")
message(STATUS "CMAKE_SYSROOT: ${CMAKE_SYSROOT}")
message(STATUS "========================================")

# 测试1: 查找 libX11-xcb
find_library(LIB_X11_XCB
    NAMES X11-xcb
    PATHS ${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu
    NO_DEFAULT_PATH
)
if(LIB_X11_XCB)
    message(STATUS "✅ 找到 libX11-xcb: ${LIB_X11_XCB}")
else()
    message(STATUS "❌ 未找到 libX11-xcb")
endif()

# 测试2: 查找 libmpg123
find_library(LIB_MPG123
    NAMES mpg123
    PATHS ${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu
    NO_DEFAULT_PATH
)
if(LIB_MPG123)
    message(STATUS "✅ 找到 libmpg123: ${LIB_MPG123}")
else()
    message(STATUS "❌ 未找到 libmpg123")
endif()

# 测试3: 查找 libcap
find_library(LIB_CAP
    NAMES cap
    PATHS ${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu
    NO_DEFAULT_PATH
)
if(LIB_CAP)
    message(STATUS "✅ 找到 libcap: ${LIB_CAP}")
else()
    message(STATUS "❌ 未找到 libcap")
endif()

# 测试4: 查找 liblz4
find_library(LIB_LZ4
    NAMES lz4
    PATHS ${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu
    NO_DEFAULT_PATH
)
if(LIB_LZ4)
    message(STATUS "✅ 找到 liblz4: ${LIB_LZ4}")
else()
    message(STATUS "❌ 未找到 liblz4")
endif()

message(STATUS "========================================")
message(STATUS "测试完成")
message(STATUS "========================================")
