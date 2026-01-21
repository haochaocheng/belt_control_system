# ========================================
# audio_network CMakeLists.txt
# ========================================
# 日期: 2026-01-21 19:45
# 作者: Claude AI
# 目的: 音频网络传输模块编译配置
# 参考: docs/2026-01-21/12-音频网络传输实施计划-最终版.md
# ========================================

# 查找依赖库
find_package(PkgConfig REQUIRED)

# FFmpeg 库
pkg_check_modules(FFMPEG REQUIRED
    libavcodec
    libavformat
    libavutil
    libswresample
)

# Opus 库
pkg_check_modules(OPUS REQUIRED opus)

# 创建静态库
add_library(audio_network STATIC
    AudioNetworkSender.cpp
)

# 包含目录
target_include_directories(audio_network PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${FFMPEG_INCLUDE_DIRS}
    ${OPUS_INCLUDE_DIRS}
)

# 链接库
target_link_libraries(audio_network PUBLIC
    Qt6::Core
    Qt6::Network
    ${FFMPEG_LIBRARIES}
    ${OPUS_LIBRARIES}
)

# 编译选项
target_compile_features(audio_network PUBLIC cxx_std_17)

# 调试输出
message(STATUS "✅ audio_network 模块配置完成")
message(STATUS "   FFmpeg 包含目录: ${FFMPEG_INCLUDE_DIRS}")
message(STATUS "   FFmpeg 库: ${FFMPEG_LIBRARIES}")
message(STATUS "   Opus 包含目录: ${OPUS_INCLUDE_DIRS}")
message(STATUS "   Opus 库: ${OPUS_LIBRARIES}")
