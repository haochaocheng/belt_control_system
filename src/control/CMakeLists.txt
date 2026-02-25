# 公共控制模块

set(CONTROL_SOURCES
    CommonControl.cpp
    SystemConfig.cpp
    DeviceDatabase.cpp
    DeviceConfigManager.cpp  # ✅ 2026-02-02 [FIX 100.300.112.8.20]: 添加设备配置管理器源文件
    DeviceRoleManager.cpp  # ✅ 2026-02-10 [Phase 7.45.1]: 添加设备角色管理器源文件
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
    ModbusTCPMasterController.cpp  # ✅ 2026-02-08 [Phase 7.42]: 添加Modbus TCP主站控制器源文件
    ModbusTCPSlaveController.cpp  # ✅ 2026-02-08 [Phase 7.42]: 添加Modbus TCP从站控制器源文件
    S7ClientController.cpp  # ✅ 2026-02-08 [Phase 7.42]: 添加S7客户端控制器源文件
    S7ServerController.cpp  # ✅ 2026-02-08 [Phase 7.42]: 添加S7服务器控制器源文件
    TTSConfigManager.cpp  # ✅ 2026-02-11 [Phase 7.45.24]: 添加TTS配置管理器源文件
    # ✅ 2026-02-25 00:20 [Phase 7.46.54]: 添加 TTS 引擎模块源文件
    tts/TTSEngineManager.cpp
    tts/TTSEngineAdapter.cpp
    tts/PaddleSpeechAdapter.cpp
    # ❌ 2026-02-25 00:20 [禁用 MeloTTS]: tts/MeloTTSAdapter.cpp
)

set(CONTROL_HEADERS
    CommonControl.h
    SystemConfig.h
    DeviceDatabase.h
    DeviceConfigManager.h  # ✅ 2026-02-02 [FIX 100.300.112.8.20]: 添加设备配置管理器头文件
    DeviceRoleManager.h  # ✅ 2026-02-10 [Phase 7.45.1]: 添加设备角色管理器头文件
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
    ModbusTCPMasterController.h  # ✅ 2026-02-08 [Phase 7.42]: 添加Modbus TCP主站控制器头文件
    ModbusTCPSlaveController.h  # ✅ 2026-02-08 [Phase 7.42]: 添加Modbus TCP从站控制器头文件
    S7ClientController.h  # ✅ 2026-02-08 [Phase 7.42]: 添加S7客户端控制器头文件
    S7ServerController.h  # ✅ 2026-02-08 [Phase 7.42]: 添加S7服务器控制器头文件
    TTSConfigManager.h  # ✅ 2026-02-11 [Phase 7.45.24]: 添加TTS配置管理器头文件
    # ✅ 2026-02-25 00:20 [Phase 7.46.54]: 添加 TTS 引擎模块头文件
    tts/TTSEngineManager.h
    tts/TTSEngineAdapter.h
    tts/PaddleSpeechAdapter.h
    # ❌ 2026-02-25 00:20 [禁用 MeloTTS]: tts/MeloTTSAdapter.h
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

# ========== Snap7 库集成（可选） ==========
option(ENABLE_SNAP7 "Enable Snap7 S7 protocol support" OFF)

if(ENABLE_SNAP7)
    message(STATUS "🔧 Snap7 S7 protocol support: ENABLED")

    # 定义平台相关的库路径
    if(WIN32)
        set(SNAP7_ROOT "${CMAKE_SOURCE_DIR}/libs/snap7-windows")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64" OR CMAKE_SYSTEM_PROCESSOR MATCHES "arm64")
        # 检查是否在RK3588交叉编译环境中
        if(EXISTS "/opt/rk3588-libs/lib")
            set(SNAP7_ROOT "/opt/rk3588-libs")
            message(STATUS "  🎯 Using RK3588 cross-compile environment")
        else()
            set(SNAP7_ROOT "${CMAKE_SOURCE_DIR}/libs/snap7-rk3588")
        endif()
    else()
        set(SNAP7_ROOT "${CMAKE_SOURCE_DIR}/libs/snap7-linux")
    endif()

    message(STATUS "  Looking for Snap7 in: ${SNAP7_ROOT}")

    # 查找Snap7库
    find_library(SNAP7_LIB
        NAMES snap7 libsnap7
        PATHS "${SNAP7_ROOT}/lib"
        NO_DEFAULT_PATH
    )

    if(SNAP7_LIB)
        message(STATUS "  ✅ Found Snap7: ${SNAP7_LIB}")
        set(SNAP7_FOUND TRUE)
    else()
        message(WARNING "❌ Snap7 library not found in ${SNAP7_ROOT}, S7 protocol will not be available")
        message(WARNING "   To enable Snap7:")
        message(WARNING "   1. Download: https://github.com/SCADACS/snap7")
        message(WARNING "   2. Compile and install to: ${SNAP7_ROOT}")
        set(ENABLE_SNAP7 OFF)
    endif()
else()
    message(STATUS "🔧 Snap7 S7 protocol support: DISABLED")
    message(STATUS "   To enable: cmake -DENABLE_SNAP7=ON ..")
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

# ========== Snap7 后处理（链接库和包含目录）==========
if(ENABLE_SNAP7 AND SNAP7_FOUND)
    # 添加头文件路径
    target_include_directories(control_module PRIVATE
        "${SNAP7_ROOT}/include"
        "${CMAKE_SOURCE_DIR}/libs/snap7/src/core"
        "${CMAKE_SOURCE_DIR}/libs/snap7/src/lib"
    )

    # 链接Snap7库
    target_link_libraries(control_module
        ${SNAP7_LIB}
    )

    # 添加编译定义
    target_compile_definitions(control_module PUBLIC
        ENABLE_SNAP7
    )

    # Windows: 复制DLL到输出目录
    if(WIN32)
        file(GLOB SNAP7_DLLS "${SNAP7_ROOT}/lib/*.dll")
        foreach(dll ${SNAP7_DLLS})
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
