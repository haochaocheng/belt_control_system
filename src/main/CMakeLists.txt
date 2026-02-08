qt_add_executable(belt_control_system
    main.cpp
)

target_link_libraries(belt_control_system PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Quick3D
    qml_module
    control_module
    hal_module
    simulated_hal_module
    real_hal_module
    utils_module
    sip_phone_module
    # ✅ 2026-01-21 19:50 [音频网络传输] 添加音频网络发送模块
    audio_network
)

# ✅ 2026-02-08 [Phase 7.43]: 链接MQTT模块（如果可用）
if(TARGET mqtt_module)
    target_link_libraries(belt_control_system PRIVATE mqtt_module)
    message(STATUS "MQTT module linked to belt_control_system")
endif()

# Link risip_sdk with whole-archive to force inclusion of stub symbols
target_link_libraries(belt_control_system PRIVATE
    -Wl,--whole-archive
    risip_sdk
    -Wl,--no-whole-archive
)

target_include_directories(belt_control_system PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
    F:/0/pjproject-2.15.1/pjproject-2.15.1/pjlib/include
)

# Link system libraries for ARM64 cross-compilation
if(NOT WIN32)
    # 直接指定版本化库文件路径（sysroot缺少符号链接）
    set(LIB_X11_XCB "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libX11-xcb.so.1.0.0")
    set(LIB_MPG123 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libmpg123.so.0.48.2")
    set(LIB_CAP "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libcap.so.2.66")
    set(LIB_LZ4 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/liblz4.so.1.9.4")
    set(LIB_PNG16 "${CMAKE_SYSROOT}/usr/lib/aarch64-linux-gnu/libpng16.so.16.43.0")

    # v4l2和SDL2已经在risip_sdk模块中链接了（pjmedia-videodev的依赖）
    # 不需要在这里重复链接

    # Use Docker container's Ubuntu 24.04 system libraries instead of external sysroot
    target_link_libraries(belt_control_system PRIVATE
        # ICU libraries (Qt6Core dependencies)
        icuuc icui18n icudata

        # Font and text rendering
        fontconfig freetype harfbuzz

        # GLib (required by many libraries)
        glib-2.0

        # X11 and OpenGL
        Xau GLdispatch GLESv2 drm

        # Video4Linux (PJSIP video dependencies) - v4l2使用直接路径
        v4lconvert

        # SDL2 (PJSIP video dependencies) - SDL2-2.0使用直接路径

        # Audio/Video codecs - 已预编译，不从系统库链接
        # FFmpeg、PJSIP、x264等库已在外部编译并链接
        # 这里注释掉，避免链接冲突
        # x264 x265 vpx opus speex theora
        # avcodec avformat avutil avdevice swresample swscale
        # FLAC vorbisenc vorbis ogg

        # XML parsing, Cryptography, Compression
        expat pcre2-8 gcrypt gpg-error z

        # System libraries - png16使用直接路径
        udev systemd sndfile ffi md
    )

    # 链接版本化的库文件
    if(EXISTS ${LIB_X11_XCB})
        target_link_libraries(belt_control_system PRIVATE ${LIB_X11_XCB})
        message(STATUS "Using libX11-xcb: ${LIB_X11_XCB}")
    else()
        message(WARNING "libX11-xcb not found at ${LIB_X11_XCB}")
    endif()

    if(EXISTS ${LIB_MPG123})
        target_link_libraries(belt_control_system PRIVATE ${LIB_MPG123})
        message(STATUS "Using libmpg123: ${LIB_MPG123}")
    else()
        message(WARNING "libmpg123 not found at ${LIB_MPG123}")
    endif()

    if(EXISTS ${LIB_CAP})
        target_link_libraries(belt_control_system PRIVATE ${LIB_CAP})
        message(STATUS "Using libcap: ${LIB_CAP}")
    else()
        message(WARNING "libcap not found at ${LIB_CAP}")
    endif()

    if(EXISTS ${LIB_LZ4})
        target_link_libraries(belt_control_system PRIVATE ${LIB_LZ4})
        message(STATUS "Using liblz4: ${LIB_LZ4}")
    else()
        message(WARNING "liblz4 not found at ${LIB_LZ4}")
    endif()

    # v4l2和SDL2已经在前面紧跟PJSIP之后链接了，这里不再重复链接

    if(EXISTS ${LIB_PNG16})
        target_link_libraries(belt_control_system PRIVATE ${LIB_PNG16})
        message(STATUS "Using libpng16: ${LIB_PNG16}")
    else()
        message(WARNING "libpng16 not found at ${LIB_PNG16}")
    endif()

    # RK3588 hardware acceleration libraries (from rk3588-libs)
    find_library(ROCKCHIP_MPP_LIB NAMES rockchip_mpp mpp PATHS ${RK3588_LIBS_PATH}/lib NO_DEFAULT_PATH)
    find_library(ROCKCHIP_RGA_LIB NAMES rga PATHS ${RK3588_LIBS_PATH}/lib NO_DEFAULT_PATH)

    if(ROCKCHIP_MPP_LIB)
        target_link_libraries(belt_control_system PRIVATE ${ROCKCHIP_MPP_LIB})
        message(STATUS "Using Rockchip MPP: ${ROCKCHIP_MPP_LIB}")
    endif()

    if(ROCKCHIP_RGA_LIB)
        target_link_libraries(belt_control_system PRIVATE ${ROCKCHIP_RGA_LIB})
        message(STATUS "Using Rockchip RGA: ${ROCKCHIP_RGA_LIB}")
    endif()

    message(STATUS "Using Docker container's Ubuntu 24.04 system libraries with video codec support")
    message(STATUS "  H.264/H.265: x264/x265 (software) + MPP (hardware if available)")
    message(STATUS "  VP8/VP9: libvpx (software) + MPP (hardware if available)")
    message(STATUS "  Audio: Opus, Speex, FLAC, Vorbis")
endif()

set_target_properties(belt_control_system PROPERTIES
    WIN32_EXECUTABLE FALSE
    MACOSX_BUNDLE TRUE
)
