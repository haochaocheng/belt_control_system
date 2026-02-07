# 公共控制模块

set(CONTROL_SOURCES
    CommonControl.cpp
    SystemConfig.cpp
    DeviceDatabase.cpp
    DeviceConfigManager.cpp  # ✅ 2026-02-02 [FIX 100.300.112.8.20]: 添加设备配置管理器源文件
    belt_controller.cpp
    MaintenanceControl.cpp
    LocalControl.cpp
    OperationLogDatabase.cpp
    DeviceRuntimeTracker.cpp
    ProtectionConfigManager.cpp
    ProtectionMonitorService.cpp
    AlarmPlaybackService.cpp
    AlarmHistoryDatabase.cpp
    SerialPortController.cpp  # ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.1]: 添加串口控制器源文件
    ModbusController.cpp  # ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.4]: 添加MODBUS控制器源文件
    ModbusSlaveController.cpp  # ✅ 2026-02-06 [FIX 100.300.113 Phase 7.40]: 添加MODBUS从站控制器源文件
    CANController.cpp  # ✅ 2026-02-07 [Phase 7.39.1]: 添加CAN控制器源文件
)

set(CONTROL_HEADERS
    CommonControl.h
    SystemConfig.h
    DeviceDatabase.h
    DeviceConfigManager.h  # ✅ 2026-02-02 [FIX 100.300.112.8.20]: 添加设备配置管理器头文件
    belt_controller.h
    MaintenanceControl.h
    LocalControl.h
    OperationLogDatabase.h
    DeviceRuntimeTracker.h
    ProtectionConfig.h
    ProtectionConfigManager.h
    ProtectionMonitorService.h
    AlarmPlaybackService.h
    AlarmHistoryDatabase.h
    SerialPortController.h  # ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.1]: 添加串口控制器头文件
    ModbusController.h  # ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.4]: 添加MODBUS控制器头文件
    ModbusSlaveController.h  # ✅ 2026-02-06 [FIX 100.300.113 Phase 7.40]: 添加MODBUS从站控制器头文件
    CANController.h  # ✅ 2026-02-07 [Phase 7.39.1]: 添加CAN控制器头文件
)

# ========== Sherpa-ONNX TTS 集成（可选） ==========
option(ENABLE_SHERPA_ONNX "Enable Sherpa-ONNX TTS support" OFF)

if(ENABLE_SHERPA_ONNX)
    message(STATUS "🎙️ Sherpa-ONNX TTS support: ENABLED")

    # 添加 Sherpa-ONNX 封装类到源文件
    list(APPEND CONTROL_SOURCES SherpaOnnxTTS.cpp)
    list(APPEND CONTROL_HEADERS SherpaOnnxTTS.h)

    # 定义平台相关的库路径
    if(WIN32)
        set(SHERPA_ONNX_ROOT "${CMAKE_SOURCE_DIR}/libs/sherpa-onnx/windows-x64")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64" OR CMAKE_SYSTEM_PROCESSOR MATCHES "arm64")
        # 检查是否在RK3588交叉编译环境中（docker容器）
        if(EXISTS "/opt/rk3588-libs/lib")
            set(SHERPA_ONNX_ROOT "/opt/rk3588-libs")
            message(STATUS "  🎯 Using RK3588 cross-compile environment")
        else()
            set(SHERPA_ONNX_ROOT "${CMAKE_SOURCE_DIR}/libs/sherpa-onnx/linux-arm64")
        endif()
    else()
        set(SHERPA_ONNX_ROOT "${CMAKE_SOURCE_DIR}/libs/sherpa-onnx/linux-x64")
    endif()

    message(STATUS "  Looking for sherpa-onnx in: ${SHERPA_ONNX_ROOT}")

    # 查找sherpa-onnx C++ API库
    # MinGW: 查找 .dll.a 导入库
    # MSVC: 查找 .lib 导入库
    find_library(SHERPA_ONNX_CXX_LIB
        NAMES sherpa-onnx-cxx-api libsherpa-onnx-cxx-api.dll
        PATHS "${SHERPA_ONNX_ROOT}/lib"
        NO_DEFAULT_PATH
    )

    find_library(SHERPA_ONNX_C_LIB
        NAMES sherpa-onnx-c-api libsherpa-onnx-c-api.dll
        PATHS "${SHERPA_ONNX_ROOT}/lib"
        NO_DEFAULT_PATH
    )

    if(SHERPA_ONNX_CXX_LIB AND SHERPA_ONNX_C_LIB)
        message(STATUS "  ✅ Found sherpa-onnx CXX API: ${SHERPA_ONNX_CXX_LIB}")
        message(STATUS "  ✅ Found sherpa-onnx C API: ${SHERPA_ONNX_C_LIB}")

        # 保存库路径，稍后在 add_library 之后使用
        set(SHERPA_ONNX_FOUND TRUE)

    else()
        message(WARNING "❌ sherpa-onnx libraries not found in ${SHERPA_ONNX_ROOT}, TTS will use fallback (QTextToSpeech)")
        message(WARNING "   CXX LIB: ${SHERPA_ONNX_CXX_LIB}")
        message(WARNING "   C LIB: ${SHERPA_ONNX_C_LIB}")
        message(WARNING "   To enable sherpa-onnx:")
        message(WARNING "   1. Download: https://github.com/k2-fsa/sherpa-onnx/releases")
        message(WARNING "   2. Extract to: ${SHERPA_ONNX_ROOT}")
        set(ENABLE_SHERPA_ONNX OFF)
    endif()
else()
    message(STATUS "🎙️ Sherpa-ONNX TTS support: DISABLED (using QTextToSpeech)")
    message(STATUS "   To enable: cmake -DENABLE_SHERPA_ONNX=ON ..")
endif()

# ========== 创建控制模块库 ==========
add_library(control_module STATIC
    ${CONTROL_SOURCES}
    ${CONTROL_HEADERS}
)

target_link_libraries(control_module
    Qt6::Core
    Qt6::SerialPort  # ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.1]: 添加串口支持
    Qt6::SerialBus  # ✅ 2026-02-06 [FIX 100.300.113 Phase 7.38.4]: 添加MODBUS支持
    hal_module
    network_module
)

# 条件性链接可选Qt组件
if(TARGET Qt6::Multimedia)
    target_link_libraries(control_module Qt6::Multimedia)
endif()

if(TARGET Qt6::TextToSpeech)
    target_link_libraries(control_module Qt6::TextToSpeech)
endif()

if(TARGET Qt6::Sql)
    target_link_libraries(control_module Qt6::Sql)
endif()

target_include_directories(control_module PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/src
)

# ========== Sherpa-ONNX 后处理（链接库和包含目录）==========
if(ENABLE_SHERPA_ONNX AND SHERPA_ONNX_FOUND)
    # 添加头文件路径
    target_include_directories(control_module PRIVATE
        "${SHERPA_ONNX_ROOT}/include"
    )

    # 链接sherpa-onnx库（CXX API需要C API）
    target_link_libraries(control_module
        ${SHERPA_ONNX_CXX_LIB}
        ${SHERPA_ONNX_C_LIB}
    )

    # 添加编译定义（PUBLIC确保MOC也能看到这个宏）
    target_compile_definitions(control_module PUBLIC
        ENABLE_SHERPA_ONNX
    )

    # Windows: 复制DLL到输出目录
    if(WIN32)
        file(GLOB SHERPA_DLLS "${SHERPA_ONNX_ROOT}/lib/*.dll" "${SHERPA_ONNX_ROOT}/bin/*.dll")
        foreach(dll ${SHERPA_DLLS})
            add_custom_command(TARGET control_module POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${dll}"
                    "$<TARGET_FILE_DIR:belt_control_system>"
                COMMENT "Copying ${dll} to output directory"
            )
        endforeach()
    endif()
endif()

# ========== 智能复制TTS模型到输出目录（如果存在）==========
# 使用增量复制，只复制修改的文件
if(EXISTS "${CMAKE_SOURCE_DIR}/libs/tts_models")
    add_custom_command(TARGET control_module POST_BUILD
        COMMAND ${CMAKE_COMMAND}
            -DSOURCE_DIR=${CMAKE_SOURCE_DIR}/libs/tts_models
            -DDEST_DIR=$<TARGET_FILE_DIR:belt_control_system>/tts_models
            -DLABEL="TTS model files"
            -P ${CMAKE_SOURCE_DIR}/cmake/smart_copy.cmake
        COMMENT "Smart copying TTS model files (incremental)..."
    )
endif()
