cmake_minimum_required(VERSION 3.21)

# Risip VoIP SDK - PJSIP Wrapper for Qt/QML
project(risip_sdk VERSION 1.0 LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# 查找 Qt 依赖
find_package(Qt6 REQUIRED COMPONENTS Core Gui Network Qml Quick Sql)

# PJSIP 编译定义
add_definitions(
    -DRISIP_SDK
    -DRISIP_VOIPSDK_LIBRARY    # Tell risipsdkglobal.h to export symbols
    -DPJ_IS_LITTLE_ENDIAN=1
    -DPJ_IS_BIG_ENDIAN=0
    -DPJ_AUTOCONF
)

# Windows platform specific definitions - MUST match PJSIP compilation
if(WIN32)
    # Set FD_SETSIZE to 512 BEFORE including any Windows headers
    # This MUST match the value used in PJSIP config_site.h
    add_definitions(-DFD_SETSIZE=512)
    add_definitions(-D_WIN32_WINNT=0x0601)  # Windows 7 or later

    # PJSIP does not support UNICODE - undefine it
    add_compile_options(-UUNICODE -U_UNICODE)
endif()

# 头文件包含路径
set(RISIP_INCLUDE_DIRS
    ${CMAKE_CURRENT_SOURCE_DIR}             # For "pjsipwrapper/..." includes
    ${CMAKE_CURRENT_SOURCE_DIR}/core
    ${CMAKE_CURRENT_SOURCE_DIR}/core/models
    ${CMAKE_CURRENT_SOURCE_DIR}/core/apploader
    ${CMAKE_CURRENT_SOURCE_DIR}/core/utils
    ${CMAKE_CURRENT_SOURCE_DIR}/pjsipwrapper
    ${CMAKE_CURRENT_SOURCE_DIR}/../         # For "control/..." includes (DataPathConfig.h)
)

# 核心源文件
set(RISIP_CORE_SOURCES
    core/risip.cpp
    core/risipaccount.cpp
    core/risipaccountconfiguration.cpp
    core/risipbuddy.cpp
    core/risipcall.cpp
    core/risipcallmanager.cpp
    core/risipcontactimageprovider.cpp
    core/risipcontactmanager.cpp        # Qt6 兼容性已修复 - 条件编译处理平台依赖
    core/risipcountryflagimageprovider.cpp
    core/risipendpoint.cpp
    core/risipglobals.cpp
    core/risipmedia.cpp
    core/risipmessage.cpp
    core/risipphonecontact.cpp
    core/risipphonenumber.cpp
    core/risipratemanager.cpp
    core/apploader/risipapplicationsettings.cpp  # 新增 - 应用程序设置管理
    core/CallHistoryDatabase.cpp         # 新增 - SQLite 通话历史数据库
    core/ContactDatabase.cpp             # 新增 - 联系人数据库
)

# 核心头文件
set(RISIP_CORE_HEADERS
    core/risip.h
    core/risipaccount.h
    core/risipaccountconfiguration.h
    core/risipbuddy.h
    core/risipcall.h
    core/risipcallmanager.h
    core/risipcontactimageprovider.h
    core/risipcontactmanager.h
    core/risipcountryflagimageprovider.h
    core/risipendpoint.h
    core/risipglobals.h
    core/risipmedia.h
    core/risipmessage.h
    core/risipphonecontact.h
    core/risipphonenumber.h
    core/risipratemanager.h
    core/risipsdkglobal.h
    core/apploader/risipapplicationsettings.h  # 新增 - 应用程序设置管理
    core/CallHistoryDatabase.h           # 新增 - SQLite 通话历史数据库
    core/ContactDatabase.h               # 新增 - 联系人数据库
)

# PJSIP Wrapper 源文件
set(RISIP_PJSIP_SOURCES
    pjsipwrapper/pjsipaccount.cpp
    pjsipwrapper/pjsipbuddy.cpp
    pjsipwrapper/pjsipcall.cpp
    pjsipwrapper/pjsipendpoint.cpp
    # pjsip_stub/pjmedia_vid_dev_stub.c  # REMOVED: Video support now enabled via PJSIP recompilation
    timezone_stub.c  # REQUIRED: OpenSSL static lib needs __imp___timezone symbol
)

set(RISIP_PJSIP_HEADERS
    pjsipwrapper/pjsipaccount.h
    pjsipwrapper/pjsipbuddy.h
    pjsipwrapper/pjsipcall.h
    pjsipwrapper/pjsipendpoint.h
)

# 模型源文件
set(RISIP_MODEL_SOURCES
    models/risipabstractbuddymodel.cpp
    models/risipaccountlistmodel.cpp
    models/risipcallhistorymodel.cpp
    models/risipcountryratesmodel.cpp
    models/risipmodels.cpp
    models/risipphonecontactsmodel.cpp
    models/risipphonenumbersmodel.cpp
)

set(RISIP_MODEL_HEADERS
    core/models/risipabstractbuddymodel.h
    core/models/risipaccountlistmodel.h
    core/models/risipcallhistorymodel.h
    core/models/risipcountryratesmodel.h
    core/models/risipmodels.h
    core/models/risipphonecontactsmodel.h
    core/models/risipphonenumbersmodel.h
)

# 工具类源文件
set(RISIP_UTIL_SOURCES
    utils/qqmlsortfilterproxymodel.cpp  # Qt6 兼容性已修复
    utils/filter.cpp                     # Qt6 兼容性已修复
    utils/sorter.cpp                     # Qt6 兼容性已修复
    utils/stopwatch.cpp
)

set(RISIP_UTIL_HEADERS
    core/utils/qqmlsortfilterproxymodel.h
    core/utils/filter.h
    core/utils/sorter.h
    core/utils/stopwatch.h
)

# 合并所有源文件
set(RISIP_ALL_SOURCES
    ${RISIP_CORE_SOURCES}
    ${RISIP_PJSIP_SOURCES}
    ${RISIP_MODEL_SOURCES}
    ${RISIP_UTIL_SOURCES}
)

set(RISIP_ALL_HEADERS
    ${RISIP_CORE_HEADERS}
    ${RISIP_PJSIP_HEADERS}
    ${RISIP_MODEL_HEADERS}
    ${RISIP_UTIL_HEADERS}
)

# 创建静态库
add_library(risip_sdk STATIC
    ${RISIP_ALL_SOURCES}
    ${RISIP_ALL_HEADERS}
)

# 目标属性
target_include_directories(risip_sdk PUBLIC
    ${RISIP_INCLUDE_DIRS}
)

# 链接 Qt 库
target_link_libraries(risip_sdk PUBLIC
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    Qt6::Qml
    Qt6::Quick
    Qt6::Sql
)

# Windows 平台特定配置
if(WIN32)
    # PJSIP 库路径 - 优先使用项目本地 libs, 回退到源码目录
    set(PJSIP_ROOT "F:/0/pjproject-2.15.1/pjproject-2.15.1" CACHE PATH "PJSIP root directory")
    set(PROJECT_LIBS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../libs/pjsip")

    if(EXISTS ${PJSIP_ROOT})
        # PJSIP 头文件路径 (从源码目录)
        target_include_directories(risip_sdk PUBLIC
            ${PJSIP_ROOT}/pjsip/include
            ${PJSIP_ROOT}/pjlib/include
            ${PJSIP_ROOT}/pjlib-util/include
            ${PJSIP_ROOT}/pjmedia/include
            ${PJSIP_ROOT}/pjnath/include
            ${PJSIP_ROOT}/pjsip/include
        )

        # PJSIP 库文件路径 (使用项目本地 libs - 包含 IOCP 重编译的库)
        target_link_directories(risip_sdk PUBLIC
            ${PROJECT_LIBS_DIR}
            C:/openssl3/lib64  # OpenSSL library directory for SSL/TLS support
        )

        # PJSIP 库链接
        # 按依赖顺序链接: 高层 -> 底层
        # 所有模块使用 -w64-mingw32 后缀 (FD_SETSIZE=512 + 48000 pool size fix)
        target_link_libraries(risip_sdk PUBLIC
            # PJSIP 核心库 (从高层到低层) - 使用 -w64-mingw32 后缀
            pjsua2-x86_64-w64-mingw32          # PJSUA2 C++ API
            pjsua-x86_64-w64-mingw32           # PJSUA API
            pjsip-ua-x86_64-w64-mingw32        # SIP User Agent
            pjsip-simple-x86_64-w64-mingw32    # SIP SIMPLE
            pjsip-x86_64-w64-mingw32           # SIP Core

            # 媒体库 (包括视频支持) - 使用 -w64-mingw32 后缀 (FD_SETSIZE=512)
            pjmedia-codec-x86_64-w64-mingw32   # Media Codecs
            pjmedia-x86_64-w64-mingw32         # Media
            pjmedia-videodev-x86_64-w64-mingw32 # Video Device (NEW - video support with FD_SETSIZE=512)
            pjmedia-audiodev-x86_64-w64-mingw32 # Audio Device
            pjsdp-x86_64-w64-mingw32           # SDP

            # NAT穿越和工具库 - 使用 -w64-mingw32 后缀
            pjnath-x86_64-w64-mingw32          # NAT Helper
            pjlib-util-x86_64-w64-mingw32      # Utilities

            # 第三方编解码器库 - 使用 -w64-mingw32 后缀
            speex-x86_64-w64-mingw32           # Speex codec
            ilbccodec-x86_64-w64-mingw32       # iLBC codec
            gsmcodec-x86_64-w64-mingw32        # GSM codec
            srtp-x86_64-w64-mingw32            # SRTP
            resample-x86_64-w64-mingw32        # Resample
            webrtc-x86_64-w64-mingw32          # WebRTC

            # 第三方库 (DirectShow)
            baseclasses-x86_64-w64-mingw32     # DirectShow base classes (for video)

            # 基础库 - 使用 -w64-mingw32 后缀
            pj-x86_64-w64-mingw32              # PJ Base Library
            # OpenSSL libraries (SSL wrapper implementation)
            ssl
            crypto

            # ✅ CRITICAL: Duplicate pj library AFTER OpenSSL to resolve circular dependencies
            # SSL functions in libpj depend on OpenSSL symbols, which depend on Windows crypto APIs
            # Static linker resolves symbols left-to-right, so we need pj again after OpenSSL
            pj-x86_64-w64-mingw32              # PJ Base Library (again for SSL symbol resolution)

            # Windows 系统库 (最后链接)
            winmm
            ole32
            ws2_32
            wsock32
            gdi32
            iphlpapi
            dxguid
            uuid
            crypt32        # Windows Crypto API (needed by OpenSSL static lib)
            strmiids       # DirectShow (needed by video device)
            quartz         # DirectShow quartz (needed by AMGetErrorText)
        )

        # FFmpeg and x264 video libraries (for H.264 video calling)
        set(FFMPEG_ROOT "C:/ffmpeg" CACHE PATH "FFmpeg installation directory")
        set(X264_ROOT "C:/x264" CACHE PATH "x264 installation directory")

        if(EXISTS ${FFMPEG_ROOT})
            # FFmpeg 头文件路径
            target_include_directories(risip_sdk PUBLIC
                ${FFMPEG_ROOT}/include
            )

            # FFmpeg 库文件路径
            target_link_directories(risip_sdk PUBLIC
                ${FFMPEG_ROOT}/lib
            )

            # 链接 FFmpeg 库 (用于 H.264 视频编解码)
            target_link_libraries(risip_sdk PUBLIC
                avcodec      # FFmpeg codec library
                avformat     # FFmpeg format library
                avutil       # FFmpeg utility library
                swscale      # FFmpeg video scaling library
                swresample   # FFmpeg audio resampling library
            )

            message(STATUS "FFmpeg found at: ${FFMPEG_ROOT}")
        else()
            message(WARNING "FFmpeg not found at ${FFMPEG_ROOT}")
            message(WARNING "Video calling will not be available")
        endif()

        if(EXISTS ${X264_ROOT})
            # x264 头文件路径
            target_include_directories(risip_sdk PUBLIC
                ${X264_ROOT}/include
            )

            # x264 库文件路径
            target_link_directories(risip_sdk PUBLIC
                ${X264_ROOT}/lib
            )

            # 链接 x264 库
            target_link_libraries(risip_sdk PUBLIC
                x264         # x264 H.264 encoder
            )

            message(STATUS "x264 found at: ${X264_ROOT}")
        else()
            message(WARNING "x264 not found at ${X264_ROOT}")
        endif()

        # OpenSSL 3.3 libraries (required by PJSIP SSL support)
        # Use independently compiled OpenSSL 3.3.5 for portability
        set(OPENSSL_ROOT "C:/openssl3" CACHE PATH "OpenSSL installation directory")
        if(EXISTS ${OPENSSL_ROOT}/lib64)
            # OpenSSL 3.x uses lib64 on 64-bit systems
            target_include_directories(risip_sdk PUBLIC
                ${OPENSSL_ROOT}/include
            )
            target_link_directories(risip_sdk PUBLIC
                ${OPENSSL_ROOT}/lib64
            )
            target_link_libraries(risip_sdk PUBLIC
                # Windows system libraries required by OpenSSL static linking
                crypt32        # Windows Crypto API
                rpcrt4         # RPC runtime (UuidCompare)
            )
            message(STATUS "OpenSSL 3.3 found at: ${OPENSSL_ROOT}")
        else()
            message(WARNING "OpenSSL not found at ${OPENSSL_ROOT}/lib64")
        endif()

        # SDL2 video library (required by PJSIP video device)
        set(SDL2_ROOT "C:/video_deps/SDL2-2.28.5" CACHE PATH "SDL2 installation directory")
        if(EXISTS ${SDL2_ROOT})
            # SDL2 header files
            target_include_directories(risip_sdk PUBLIC
                ${SDL2_ROOT}/include
            )

            # SDL2 library files
            target_link_directories(risip_sdk PUBLIC
                ${SDL2_ROOT}/lib/x64
            )

            # Link SDL2 libraries
            target_link_libraries(risip_sdk PUBLIC
                SDL2       # SDL2 core library
                SDL2main   # SDL2 main wrapper
            )

            message(STATUS "SDL2 found at: ${SDL2_ROOT}")
        else()
            message(WARNING "SDL2 not found at ${SDL2_ROOT}")
            message(WARNING "Video calling will not be available")
        endif()

        message(STATUS "PJSIP found at: ${PJSIP_ROOT}")
        message(STATUS "Please ensure PJSIP is compiled for your platform")
    else()
        message(WARNING "PJSIP not found at ${PJSIP_ROOT}.")
        message(WARNING "Please:")
        message(WARNING "  1. Download PJSIP from https://www.pjsip.org/")
        message(WARNING "  2. Compile PJSIP for Windows")
        message(WARNING "  3. Update PJSIP_ROOT in CMakeLists.txt")
        message(WARNING "Continuing build without PJSIP - linking may fail")
    endif()
else()
    # Linux/ARM64 平台特定配置 (RK3588)
    # PJSIP 库路径 - 从 RK3588 预编译库目录
    set(RK3588_LIBS_PATH "/opt/rk3588-libs" CACHE PATH "RK3588 libraries directory")

    if(EXISTS ${RK3588_LIBS_PATH})
        # PJSIP 头文件路径
        target_include_directories(risip_sdk PUBLIC
            ${RK3588_LIBS_PATH}/include
        )

        # PJSIP 库文件路径
        target_link_directories(risip_sdk PUBLIC
            ${RK3588_LIBS_PATH}/lib
        )

        # PJSIP 库链接 - Linux 静态库版本
        # 按依赖顺序链接: 高层 -> 底层
        # 使用完整库文件名（包含平台后缀）
        target_link_libraries(risip_sdk PUBLIC
            # PJSIP 核心库 (从高层到低层)
            pjsua2-aarch64-unknown-linux-gnu          # PJSUA2 C++ API
            pjsua-aarch64-unknown-linux-gnu           # PJSUA API
            pjsip-ua-aarch64-unknown-linux-gnu        # SIP User Agent
            pjsip-simple-aarch64-unknown-linux-gnu    # SIP SIMPLE
            pjsip-aarch64-unknown-linux-gnu           # SIP Core

            # 媒体库
            pjmedia-codec-aarch64-unknown-linux-gnu   # Media Codecs
            pjmedia-aarch64-unknown-linux-gnu         # Media
            pjmedia-videodev-aarch64-unknown-linux-gnu # Video Device
            pjmedia-audiodev-aarch64-unknown-linux-gnu # Audio Device

            # PJSIP 编解码器支持库 (必须在媒体库之后)
            gsmcodec-aarch64-unknown-linux-gnu        # GSM codec
            ilbccodec-aarch64-unknown-linux-gnu       # iLBC codec
            speex-aarch64-unknown-linux-gnu           # Speex codec (PJSIP built-in)
            resample-aarch64-unknown-linux-gnu        # Resample library
            srtp-aarch64-unknown-linux-gnu            # SRTP library
            webrtc-aarch64-unknown-linux-gnu          # WebRTC AEC/NS

            # NAT穿越和工具库
            pjnath-aarch64-unknown-linux-gnu          # NAT Helper
            pjlib-util-aarch64-unknown-linux-gnu      # Utilities

            # 基础库
            pj-aarch64-unknown-linux-gnu              # PJ Base Library

            # 系统库 (Linux) - PJSIP 媒体库依赖
            pthread
            m
            rt
           asound                      # ALSA audio library

            # FFmpeg 库 (视频编解码)
            avcodec                     # FFmpeg codec library (for video codecs)
            avformat                    # FFmpeg format library
            avutil                      # FFmpeg utilities (av_strerror, etc)
            swscale                     # FFmpeg video scaling/conversion

            # 音频编解码器
            opus                        # Opus codec (for opus_strerror)
            # gsm                       # GSM codec (built into PJSIP libgsmcodec)
            speex                       # Speex codec

            # 视频处理
            yuv                         # libyuv (video format conversion)

            # 其他 PJSIP 依赖
            # srtp2                     # Secure RTP (built into PJSIP libsrtp)

            # Video device dependencies (REQUIRED for pjmedia-videodev)
            v4l2                        # Video4Linux2 (for video capture)
            SDL2-2.0                    # SDL2 (for video rendering)
            # webrtc-aec                # WebRTC AEC (built into PJSIP libwebrtc)
            # sndfile                   # libsndfile (PulseAudio) - missing dev symlink
            png16                       # libpng16 (for Qt6Gui)
        )

        message(STATUS "RK3588 PJSIP libraries found at: ${RK3588_LIBS_PATH}")
    else()
        message(WARNING "RK3588 libraries not found at ${RK3588_LIBS_PATH}")
        message(WARNING "Please ensure PJSIP is compiled for ARM64/Linux")
        message(WARNING "Continuing build without PJSIP - linking may fail")
    endif()
endif()

# 导出包含目录供其他模块使用
set(RISIP_SDK_INCLUDE_DIRS ${RISIP_INCLUDE_DIRS} PARENT_SCOPE)
