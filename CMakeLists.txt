cmake_minimum_required(VERSION 3.21)
project(belt_control_system VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 查找QT依赖（必须包含Qml模块）
# 核心组件（必须）
find_package(Qt6 6.5 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2  # Qt Quick Controls
    Quick3D         # Qt Quick 3D for digital twin
    VirtualKeyboard # Qt Virtual Keyboard for input
    SerialPort      # 硬件通信
    Network         # 网络（如需）
    SerialBus       # Modbus TCP/RTU support
)

# 可选组件（某些ARM预编译Qt可能不包含）
find_package(Qt6 6.5 QUIET COMPONENTS
    Widgets         # Qt Widgets for video preview embedding
    Multimedia      # Qt Multimedia for camera access
    TextToSpeech    # Qt TextToSpeech for voice alerts
    Sql             # Qt SQL for database support
    Test            # 单元测试（可选）
    Mqtt            # ✅ 2026-02-08 [Phase 7.43]: Qt MQTT for MQTT communication
)

# 报告可选组件的可用性
if(Qt6Widgets_FOUND)
    message(STATUS "Qt6::Widgets available")
else()
    message(WARNING "Qt6::Widgets not found - video preview may be limited")
endif()

if(Qt6Multimedia_FOUND)
    message(STATUS "Qt6::Multimedia available")
else()
    message(WARNING "Qt6::Multimedia not found - audio features may be limited")
endif()

if(Qt6TextToSpeech_FOUND)
    message(STATUS "Qt6::TextToSpeech available")
else()
    message(WARNING "Qt6::TextToSpeech not found - TTS features may be limited")
endif()

if(Qt6Sql_FOUND)
    message(STATUS "Qt6::Sql available")
else()
    message(WARNING "Qt6::Sql not found - database features may be limited")
endif()

# ✅ 2026-02-08 [Phase 7.43]: 检查 Qt MQTT 可用性
if(Qt6Mqtt_FOUND)
    message(STATUS "Qt6::Mqtt available - MQTT features enabled")
    add_compile_definitions(MQTT_ENABLED)
else()
    message(WARNING "Qt6::Mqtt not found - MQTT features disabled")
endif()

qt_standard_project_setup(REQUIRES 6.5)

# 配置输出目录
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin_arm64)
else()
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin_windows)
endif()

# 添加子模块（按依赖顺序）
add_subdirectory(src/utils)
add_subdirectory(src/hardware/hal)
add_subdirectory(src/hardware/simulated)
add_subdirectory(src/hardware/real)
add_subdirectory(src/control)
add_subdirectory(src/network)  # Network module (Modbus TCP)
# ✅ 2026-02-08 [Phase 7.43]: MQTT 通讯控制模块
# 功能：管理 8 个 MQTT 模块的连接、订阅、发布
add_subdirectory(src/mqtt)  # MQTT communication module
add_subdirectory(src/risip)  # Risip VoIP SDK (PJSIP wrapper)
add_subdirectory(src/sip_phone)  # SIP Phone module
# ✅ 2026-01-21 19:50 [音频网络传输] 添加音频网络发送模块
# 功能：MP3/WAV → Opus → UDP 组播（224.1.1.1:8800）
# 参考：docs/2026-01-21/12-音频网络传输实施计划-最终版.md
add_subdirectory(src/audio_network)  # Audio network transmission module
add_subdirectory(src/qml)  # QML模块需在控制模块之后（依赖C++逻辑）
add_subdirectory(src/main)

# 单元测试
# ❌ 2026-02-26 09:50 [Phase 7.47.5]: 完全禁用单元测试
# 原因：tests目录已被用户删除，测试功能不需要
# 用户确认："我把tests文件夹移除了，测试功能，不需要"
# option(BUILD_TESTS "Build unit tests" OFF)
# if(BUILD_TESTS)
#     add_subdirectory(tests)
# endif()