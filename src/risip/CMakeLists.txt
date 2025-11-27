cmake_minimum_required(VERSION 3.21)

# Risip VoIP SDK - PJSIP Wrapper for Qt/QML
project(risip_sdk VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# 查找 Qt 依赖
find_package(Qt6 REQUIRED COMPONENTS Core Gui Network Qml Quick)

# PJSIP 编译定义
add_definitions(
    -DRISIP_SDK
    -DRISIP_VOIPSDK_LIBRARY    # Tell risipsdkglobal.h to export symbols
    -DPJ_IS_LITTLE_ENDIAN=1
    -DPJ_IS_BIG_ENDIAN=0
    -DPJ_AUTOCONF
)

# 头文件包含路径
set(RISIP_INCLUDE_DIRS
    ${CMAKE_CURRENT_SOURCE_DIR}             # For "pjsipwrapper/..." includes
    ${CMAKE_CURRENT_SOURCE_DIR}/core
    ${CMAKE_CURRENT_SOURCE_DIR}/core/models
    ${CMAKE_CURRENT_SOURCE_DIR}/core/apploader
    ${CMAKE_CURRENT_SOURCE_DIR}/core/utils
    ${CMAKE_CURRENT_SOURCE_DIR}/pjsipwrapper
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
)

# PJSIP Wrapper 源文件
set(RISIP_PJSIP_SOURCES
    pjsipwrapper/pjsipaccount.cpp
    pjsipwrapper/pjsipbuddy.cpp
    pjsipwrapper/pjsipcall.cpp
    pjsipwrapper/pjsipendpoint.cpp
    pjsip_stub/pjmedia_vid_dev_stub.c  # PJSIP 视频设备子系统 stub (当视频被禁用时)
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
)

# Windows 平台特定配置
if(WIN32)
    # PJSIP 库路径 - 使用 F:/0/pjproject-2.15.1/pjproject-2.15.1
    set(PJSIP_ROOT "F:/0/pjproject-2.15.1/pjproject-2.15.1" CACHE PATH "PJSIP root directory")

    if(EXISTS ${PJSIP_ROOT})
        # PJSIP 头文件路径
        target_include_directories(risip_sdk PUBLIC
            ${PJSIP_ROOT}/pjsip/include
            ${PJSIP_ROOT}/pjlib/include
            ${PJSIP_ROOT}/pjlib-util/include
            ${PJSIP_ROOT}/pjmedia/include
            ${PJSIP_ROOT}/pjnath/include
            ${PJSIP_ROOT}/pjsip/include
        )

        # PJSIP 库文件路径
        target_link_directories(risip_sdk PUBLIC
            ${PJSIP_ROOT}/pjsip/lib
            ${PJSIP_ROOT}/pjlib/lib
            ${PJSIP_ROOT}/pjlib-util/lib
            ${PJSIP_ROOT}/pjmedia/lib
            ${PJSIP_ROOT}/pjnath/lib
            ${PJSIP_ROOT}/third_party/lib
        )

        # PJSIP 库链接
        # 按依赖顺序链接: 高层 -> 底层
        target_link_libraries(risip_sdk PUBLIC
            # PJSIP 核心库 (从高层到低层)
            pjsua2-x86_64-pc-mingw32          # PJSUA2 C++ API
            pjsua-x86_64-pc-mingw32           # PJSUA API
            pjsip-ua-x86_64-pc-mingw32        # SIP User Agent
            pjsip-simple-x86_64-pc-mingw32    # SIP SIMPLE
            pjsip-x86_64-pc-mingw32           # SIP Core

            # 媒体库
            pjmedia-codec-x86_64-pc-mingw32   # Media Codecs
            pjmedia-x86_64-pc-mingw32         # Media
            pjmedia-audiodev-x86_64-pc-mingw32 # Audio Device
            pjsdp-x86_64-pc-mingw32           # SDP

            # NAT穿越和工具库
            pjnath-x86_64-pc-mingw32          # NAT Helper
            pjlib-util-x86_64-pc-mingw32      # Utilities

            # 第三方编解码器库
            g7221codec-x86_64-pc-mingw32      # G.722.1 codec
            speex-x86_64-pc-mingw32           # Speex codec
            ilbccodec-x86_64-pc-mingw32       # iLBC codec
            gsmcodec-x86_64-pc-mingw32        # GSM codec
            srtp-x86_64-pc-mingw32            # SRTP
            resample-x86_64-pc-mingw32        # Resample
            webrtc-x86_64-pc-mingw32          # WebRTC

            # 基础库
            pj-x86_64-pc-mingw32              # PJ Base Library

            # Windows 系统库 (最后链接)
            winmm
            ole32
            ws2_32
            wsock32
            gdi32
            iphlpapi
            dxguid
            uuid
        )

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
endif()

# 导出包含目录供其他模块使用
set(RISIP_SDK_INCLUDE_DIRS ${RISIP_INCLUDE_DIRS} PARENT_SCOPE)
