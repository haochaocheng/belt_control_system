# 完整测试脚本：验证所有链接错误中缺失的库
# 根据编译错误，需要验证以下库：
# 1. libX11-xcb (已添加) - X11相关
# 2. libmpg123 (已添加) - 音频解码
# 3. libcap (已添加) - Linux capabilities
# 4. liblz4 (已添加) - 压缩
# 5. libv4l2 - Video4Linux2（v4l2_ioctl等函数）
# 6. libSDL2 - SDL2视频库（SDL_UpdateTexture等函数）
# 7. libpng16 - PNG图像库（png_xxx@PNG16_0函数）

cmake_minimum_required(VERSION 3.16)

set(CMAKE_SYSROOT "/opt/sysroot/pi-root")
set(RK3588_LIBS_PATH "/opt/rk3588-libs")

message(STATUS "========================================")
message(STATUS "完整库验证测试")
message(STATUS "CMAKE_SYSROOT: ${CMAKE_SYSROOT}")
message(STATUS "RK3588_LIBS_PATH: ${RK3588_LIBS_PATH}")
message(STATUS "========================================")

# 1. 已添加的4个库
set(LIB_X11_XCB "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libX11-xcb.so.1.0.0")
set(LIB_MPG123 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libmpg123.so.0.48.2")
set(LIB_CAP "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libcap.so.2.66")
set(LIB_LZ4 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/liblz4.so.1.9.4")

message(STATUS "")
message(STATUS "=== 第1组：已添加的库（版本化路径） ===")

if(EXISTS ${LIB_X11_XCB})
    message(STATUS "✅ libX11-xcb 存在: ${LIB_X11_XCB}")
else()
    message(STATUS "❌ libX11-xcb 不存在")
endif()

if(EXISTS ${LIB_MPG123})
    message(STATUS "✅ libmpg123 存在: ${LIB_MPG123}")
else()
    message(STATUS "❌ libmpg123 不存在")
endif()

if(EXISTS ${LIB_CAP})
    message(STATUS "✅ libcap 存在: ${LIB_CAP}")
else()
    message(STATUS "❌ libcap 不存在")
endif()

if(EXISTS ${LIB_LZ4})
    message(STATUS "✅ liblz4 存在: ${LIB_LZ4}")
else()
    message(STATUS "❌ liblz4 不存在")
endif()

# 2. 查找缺失的库文件
message(STATUS "")
message(STATUS "=== 第2组：检查v4l2, SDL2, png16库 ===")

# 查找libv4l2（提供v4l2_ioctl等函数）
execute_process(
    COMMAND find ${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -name "libv4l2.so*"
    OUTPUT_VARIABLE V4L2_FILES
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
message(STATUS "libv4l2文件: ${V4L2_FILES}")

# 查找libSDL2
execute_process(
    COMMAND find ${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -name "libSDL2*.so*"
    OUTPUT_VARIABLE SDL2_FILES
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
message(STATUS "libSDL2文件: ${SDL2_FILES}")

# 查找libpng16
execute_process(
    COMMAND find ${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu -name "libpng16.so*"
    OUTPUT_VARIABLE PNG16_FILES
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
message(STATUS "libpng16文件: ${PNG16_FILES}")

# 3. 测试这些库的具体版本文件是否存在
message(STATUS "")
message(STATUS "=== 第3组：测试具体版本文件 ===")

set(LIB_V4L2 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libv4l2.so.0.0.0")
set(LIB_SDL2 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0")
set(LIB_PNG16 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libpng16.so.16.43.0")

if(EXISTS ${LIB_V4L2})
    message(STATUS "✅ libv4l2 版本文件存在: ${LIB_V4L2}")
else()
    message(STATUS "❌ libv4l2 版本文件不存在")
endif()

if(EXISTS ${LIB_SDL2})
    message(STATUS "✅ libSDL2 版本文件存在: ${LIB_SDL2}")
else()
    message(STATUS "❌ libSDL2 版本文件不存在")
endif()

if(EXISTS ${LIB_PNG16})
    message(STATUS "✅ libpng16 版本文件存在: ${LIB_PNG16}")
else()
    message(STATUS "❌ libpng16 版本文件不存在")
endif()

# 4. 检查CMakeLists.txt中已链接的库
message(STATUS "")
message(STATUS "=== 第4组：检查CMakeLists.txt中已声明的库 ===")

# 这些库应该已经在target_link_libraries中了
set(ALREADY_LINKED_LIBS "v4l2;SDL2-2.0;png16")
message(STATUS "CMakeLists.txt中已声明的库: ${ALREADY_LINKED_LIBS}")
message(STATUS "问题：这些库名没有符号链接，链接器找不到")

# 5. 总结
message(STATUS "")
message(STATUS "========================================")
message(STATUS "测试总结")
message(STATUS "========================================")
message(STATUS "")
message(STATUS "【问题诊断】：")
message(STATUS "1. CMakeLists.txt中已声明：v4l2, SDL2-2.0, png16")
message(STATUS "2. 但链接器需要：libv4l2.so, libSDL2-2.0.so, libpng16.so")
message(STATUS "3. sysroot中只有：libv4l2.so.0.0.0, libSDL2-2.0.so.0, libpng16.so.16.43.0")
message(STATUS "4. 缺少符号链接：libXXX.so -> libXXX.so.X.X.X")
message(STATUS "")
message(STATUS "【解决方案】：")
message(STATUS "需要像X11-xcb一样，使用完整版本路径")
message(STATUS "========================================")
