# Sherpa-ONNX TTS 独立服务进程（跨平台）
# Windows: 使用 MSVC 编译
# Linux ARM64: 使用 GCC/Clang 交叉编译

cmake_minimum_required(VERSION 3.16)

project(sherpa_tts_service)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# MSVC 特定设置
if(MSVC)
    add_compile_options(/utf-8)
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
endif()

# 根据平台选择 Sherpa-ONNX 库路径
if(WIN32)
    # Windows x64
    set(SHERPA_ONNX_ROOT "${CMAKE_SOURCE_DIR}/../../libs/sherpa-onnx-v1.12.9-win-x64-shared")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    # ARM64 Linux (RK3588 with RKNN acceleration)
    set(SHERPA_ONNX_ROOT "${CMAKE_SOURCE_DIR}/../../libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared")
else()
    message(FATAL_ERROR "Unsupported platform: ${CMAKE_SYSTEM_NAME} ${CMAKE_SYSTEM_PROCESSOR}")
endif()

message(STATUS "Using Sherpa-ONNX from: ${SHERPA_ONNX_ROOT}")

# 直接指定库路径（绕过find_library在交叉编译中的问题）
if(WIN32)
    set(SHERPA_ONNX_CXX_LIB "${SHERPA_ONNX_ROOT}/lib/sherpa-onnx-cxx-api.lib")
    set(SHERPA_ONNX_C_LIB "${SHERPA_ONNX_ROOT}/lib/sherpa-onnx-c-api.lib")
else()
    set(SHERPA_ONNX_CXX_LIB "${SHERPA_ONNX_ROOT}/lib/libsherpa-onnx-cxx-api.so")
    set(SHERPA_ONNX_C_LIB "${SHERPA_ONNX_ROOT}/lib/libsherpa-onnx-c-api.so")
endif()

# 验证库文件存在
if(NOT EXISTS "${SHERPA_ONNX_CXX_LIB}")
    message(FATAL_ERROR "❌ Sherpa-ONNX CXX API not found: ${SHERPA_ONNX_CXX_LIB}")
endif()

if(NOT EXISTS "${SHERPA_ONNX_C_LIB}")
    message(FATAL_ERROR "❌ Sherpa-ONNX C API not found: ${SHERPA_ONNX_C_LIB}")
endif()

message(STATUS "✅ Found Sherpa-ONNX CXX API: ${SHERPA_ONNX_CXX_LIB}")
message(STATUS "✅ Found Sherpa-ONNX C API: ${SHERPA_ONNX_C_LIB}")

# 创建可执行文件
add_executable(sherpa_tts_service
    sherpa_tts_service.cpp
)

# 添加头文件路径
target_include_directories(sherpa_tts_service PRIVATE
    "${SHERPA_ONNX_ROOT}/include"
)

# 链接库
target_link_libraries(sherpa_tts_service
    ${SHERPA_ONNX_CXX_LIB}
    ${SHERPA_ONNX_C_LIB}
)

# 复制 DLL 到输出目录
if(WIN32)
    file(GLOB SHERPA_DLLS
        "${SHERPA_ONNX_ROOT}/lib/*.dll"
        "${SHERPA_ONNX_ROOT}/bin/*.dll"
    )
    foreach(dll ${SHERPA_DLLS})
        add_custom_command(TARGET sherpa_tts_service POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${dll}"
                "$<TARGET_FILE_DIR:sherpa_tts_service>"
            COMMENT "Copying ${dll} to output directory"
        )
    endforeach()
endif()

# 安装规则
install(TARGETS sherpa_tts_service
    RUNTIME DESTINATION bin
)

if(WIN32)
    install(FILES ${SHERPA_DLLS}
        DESTINATION bin
    )
endif()
