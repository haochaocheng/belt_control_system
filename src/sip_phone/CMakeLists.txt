# SIP Phone Module - Based on risip/PJSIP
cmake_minimum_required(VERSION 3.16)

# SIP Phone module library
add_library(sip_phone_module STATIC
    SipPhoneManager.h
    SipPhoneManager.cpp
)

# Define RISIP_VOIPSDK_LIBRARY to tell risip headers this is a static library build
target_compile_definitions(sip_phone_module PRIVATE
    RISIP_VOIPSDK_LIBRARY
)

# Link Qt libraries
target_link_libraries(sip_phone_module PUBLIC
    Qt6::Core
    Qt6::Qml
    Qt6::Network
)

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
