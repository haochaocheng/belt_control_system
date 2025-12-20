# CMake配置验证脚本
# 用法：在Docker容器中运行cmake配置阶段，验证所有库路径正确
# docker run --rm -v "路径:/workspace" -v "sysroot:/opt/sysroot:ro" -v "qt-raspi:/opt/qt-raspi:ro" -v "rk3588-libs:/opt/rk3588-libs:ro" -w /workspace/belt_control_system/build_rk3588 belt-control-rk3588:latest cmake -DCMAKE_TOOLCHAIN_FILE=/opt/qt-raspi/lib/cmake/Qt6/qt.toolchain.cmake -DQT_CHAINLOAD_TOOLCHAIN_FILE=/workspace/belt_control_system/docker/rk3588/toolchain-rk3588.cmake -DCMAKE_BUILD_TYPE=Release ..

cmake_minimum_required(VERSION 3.16)

message(STATUS "========================================")
message(STATUS "CMake配置验证脚本")
message(STATUS "========================================")

# 模拟真实配置环境
set(CMAKE_SYSROOT "/opt/sysroot/pi-root")
set(RK3588_LIBS_PATH "/opt/rk3588-libs")

# 验证所有版本化库文件路径
set(LIB_X11_XCB "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libX11-xcb.so.1.0.0")
set(LIB_MPG123 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libmpg123.so.0.48.2")
set(LIB_CAP "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libcap.so.2.66")
set(LIB_LZ4 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/liblz4.so.1.9.4")
set(LIB_V4L2 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libv4l2.so.0.0.0")
set(LIB_SDL2 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0")
set(LIB_PNG16 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libpng16.so.16.43.0")

message(STATUS "")
message(STATUS "=== 验证所有7个库的路径 ===")

set(ALL_LIBS_VALID TRUE)

if(EXISTS ${LIB_X11_XCB})
    message(STATUS "✅ libX11-xcb: ${LIB_X11_XCB}")
else()
    message(STATUS "❌ libX11-xcb 不存在")
    set(ALL_LIBS_VALID FALSE)
endif()

if(EXISTS ${LIB_MPG123})
    message(STATUS "✅ libmpg123: ${LIB_MPG123}")
else()
    message(STATUS "❌ libmpg123 不存在")
    set(ALL_LIBS_VALID FALSE)
endif()

if(EXISTS ${LIB_CAP})
    message(STATUS "✅ libcap: ${LIB_CAP}")
else()
    message(STATUS "❌ libcap 不存在")
    set(ALL_LIBS_VALID FALSE)
endif()

if(EXISTS ${LIB_LZ4})
    message(STATUS "✅ liblz4: ${LIB_LZ4}")
else()
    message(STATUS "❌ liblz4 不存在")
    set(ALL_LIBS_VALID FALSE)
endif()

if(EXISTS ${LIB_V4L2})
    message(STATUS "✅ libv4l2: ${LIB_V4L2}")
else()
    message(STATUS "❌ libv4l2 不存在")
    set(ALL_LIBS_VALID FALSE)
endif()

if(EXISTS ${LIB_SDL2})
    message(STATUS "✅ libSDL2: ${LIB_SDL2}")
else()
    message(STATUS "❌ libSDL2 不存在")
    set(ALL_LIBS_VALID FALSE)
endif()

if(EXISTS ${LIB_PNG16})
    message(STATUS "✅ libpng16: ${LIB_PNG16}")
else()
    message(STATUS "❌ libpng16 不存在")
    set(ALL_LIBS_VALID FALSE)
endif()

message(STATUS "")
message(STATUS "========================================")
if(ALL_LIBS_VALID)
    message(STATUS "✅ 验证通过：所有7个库路径正确")
    message(STATUS "")
    message(STATUS "下一步：执行完整编译")
    message(STATUS "命令：在build_rk3588目录中运行 cmake --build .")
else()
    message(STATUS "❌ 验证失败：部分库路径不正确")
    message(FATAL_ERROR "请检查库路径配置")
endif()
message(STATUS "========================================")
