# 验证脚本：检查正确的库路径（rk3588-libs vs sysroot）
# 用法：docker run --rm -v "路径:/workspace" -v "sysroot:/opt/sysroot:ro" -v "rk3588-libs:/opt/rk3588-libs:ro" belt-control-rk3588:latest cmake -P /workspace/docker/rk3588/test_correct_libraries.cmake

cmake_minimum_required(VERSION 3.16)

set(CMAKE_SYSROOT "/opt/sysroot/pi-root")
set(RK3588_LIBS_PATH "/opt/rk3588-libs")

message(STATUS "========================================")
message(STATUS "验证正确的库路径")
message(STATUS "========================================")

# 1. sysroot里的库（系统基础库）
set(LIB_X11_XCB "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libX11-xcb.so.1.0.0")
set(LIB_MPG123 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libmpg123.so.0.48.2")
set(LIB_CAP "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libcap.so.2.66")
set(LIB_LZ4 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/liblz4.so.1.9.4")
set(LIB_PNG16 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libpng16.so.16.43.0")

message(STATUS "")
message(STATUS "=== sysroot系统库（5个） ===")

if(EXISTS ${LIB_X11_XCB})
    message(STATUS "✅ libX11-xcb: ${LIB_X11_XCB}")
else()
    message(STATUS "❌ libX11-xcb 不存在")
endif()

if(EXISTS ${LIB_MPG123})
    message(STATUS "✅ libmpg123: ${LIB_MPG123}")
else()
    message(STATUS "❌ libmpg123 不存在")
endif()

if(EXISTS ${LIB_CAP})
    message(STATUS "✅ libcap: ${LIB_CAP}")
else()
    message(STATUS "❌ libcap 不存在")
endif()

if(EXISTS ${LIB_LZ4})
    message(STATUS "✅ liblz4: ${LIB_LZ4}")
else()
    message(STATUS "❌ liblz4 不存在")
endif()

if(EXISTS ${LIB_PNG16})
    message(STATUS "✅ libpng16: ${LIB_PNG16}")
else()
    message(STATUS "❌ libpng16 不存在")
endif()

# 2. rk3588-libs里的库（PJSIP视频依赖）
set(LIB_V4L2 "${RK3588_LIBS_PATH}/lib/libv4l2.so")
set(LIB_SDL2 "${RK3588_LIBS_PATH}/lib/libSDL2-2.0.so")

message(STATUS "")
message(STATUS "=== rk3588-libs预编译库（2个） ===")

if(EXISTS ${LIB_V4L2})
    message(STATUS "✅ libv4l2: ${LIB_V4L2}")
else()
    message(STATUS "❌ libv4l2 不存在")
endif()

if(EXISTS ${LIB_SDL2})
    message(STATUS "✅ libSDL2: ${LIB_SDL2}")
else()
    message(STATUS "❌ libSDL2 不存在")
endif()

# 3. 对比sysroot里的SDL2和v4l2（应该不使用）
set(SYSROOT_V4L2 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libv4l2.so.0.0.0")
set(SYSROOT_SDL2 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0")

message(STATUS "")
message(STATUS "=== sysroot里的v4l2/SDL2（不应使用） ===")

if(EXISTS ${SYSROOT_V4L2})
    message(STATUS "⚠️  sysroot libv4l2存在但不应使用: ${SYSROOT_V4L2}")
else()
    message(STATUS "❌ sysroot libv4l2 不存在")
endif()

if(EXISTS ${SYSROOT_SDL2})
    message(STATUS "⚠️  sysroot libSDL2存在但不应使用: ${SYSROOT_SDL2}")
else()
    message(STATUS "❌ sysroot libSDL2 不存在")
endif()

# 4. 总结
message(STATUS "")
message(STATUS "========================================")
message(STATUS "【关键发现】")
message(STATUS "========================================")
message(STATUS "")
message(STATUS "1. PJSIP编译时链接的是rk3588-libs里的v4l2和SDL2")
message(STATUS "2. rk3588-libs里的库有完整符号链接（libv4l2.so, libSDL2-2.0.so）")
message(STATUS "3. sysroot里的库只有版本号文件，没有符号链接")
message(STATUS "4. 必须使用rk3588-libs里的v4l2和SDL2才能正确链接")
message(STATUS "")
message(STATUS "【修复方案】")
message(STATUS "set(LIB_V4L2 \"\${RK3588_LIBS_PATH}/lib/libv4l2.so\")")
message(STATUS "set(LIB_SDL2 \"\${RK3588_LIBS_PATH}/lib/libSDL2-2.0.so\")")
message(STATUS "========================================")
