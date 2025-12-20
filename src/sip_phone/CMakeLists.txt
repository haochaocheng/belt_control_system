# SIP Phone Module - Based on risip/PJSIP
cmake_minimum_required(VERSION 3.16)

# SIP Phone module library
add_library(sip_phone_module STATIC
    SipPhoneManager.h
    SipPhoneManager.cpp
    VideoCallManager.h
    VideoCallManager.cpp
    VideoPreviewWidget.h
    VideoPreviewWidget.cpp
    QtVideoPreview.h
    QtVideoPreview.cpp
    VideoSinkItem.h
    VideoSinkItem.cpp
    LocalVideoManager.h
    LocalVideoManager.cpp
    RemoteVideoManager.h
    RemoteVideoManager.cpp
)

# Define RISIP_VOIPSDK_LIBRARY to tell risip headers this is a static library build
target_compile_definitions(sip_phone_module PRIVATE
    RISIP_VOIPSDK_LIBRARY
)

# PJSIP does not support UNICODE - undefine it explicitly
# Windows platform specific definitions - MUST match PJSIP compilation
if(WIN32)
    target_compile_options(sip_phone_module PRIVATE -UPJSIP_HAS_UNICODE_STRING -UUNICODE -U_UNICODE)
    # Set FD_SETSIZE to 512 BEFORE including any Windows headers
    # This MUST match the value used in PJSIP config_site.h
    target_compile_definitions(sip_phone_module PRIVATE FD_SETSIZE=512 _WIN32_WINNT=0x0601)
endif()

# ARM64/AARCH64 platform specific definitions for PJSIP
# For cross-compilation, CMAKE_SYSTEM_PROCESSOR may not be set correctly
# Define endianness unconditionally for Linux ARM64 builds
if(UNIX AND NOT WIN32)
    # ARM64 is little-endian - define PJSIP endianness macros
    target_compile_definitions(sip_phone_module PRIVATE
        PJ_IS_LITTLE_ENDIAN=1
        PJ_IS_BIG_ENDIAN=0
        PJ_AUTOCONF=1
    )
endif()

# Link Qt libraries
target_link_libraries(sip_phone_module PUBLIC
    Qt6::Core
    Qt6::Qml
    Qt6::Quick
    Qt6::Network
)

# 条件性链接可选Qt组件
if(TARGET Qt6::Widgets)
    target_link_libraries(sip_phone_module PUBLIC Qt6::Widgets)
endif()

if(TARGET Qt6::Multimedia)
    target_link_libraries(sip_phone_module PUBLIC Qt6::Multimedia)
endif()

# Link risip SDK
target_link_libraries(sip_phone_module PUBLIC
    risip_sdk
)

# Platform specific libraries
if(WIN32)
    target_link_libraries(sip_phone_module PRIVATE
        ws2_32
        wsock32
        ole32
    )
endif()

# Expose headers to other modules
target_include_directories(sip_phone_module PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Installation (if needed)
# install(TARGETS sip_phone_module
#     LIBRARY DESTINATION lib
#     ARCHIVE DESTINATION lib
# )
