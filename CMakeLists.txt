cmake_minimum_required(VERSION 3.21)
project(belt_control_system VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 查找QT依赖（必须包含Qml模块）
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
    Test            # 单元测试（可选）
)
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
add_subdirectory(src/risip)  # Risip VoIP SDK (PJSIP wrapper)
add_subdirectory(src/sip_phone)  # SIP Phone module
add_subdirectory(src/qml)  # QML模块需在控制模块之后（依赖C++逻辑）
add_subdirectory(src/main)

# 单元测试
option(BUILD_TESTS "Build unit tests" ON)
if(BUILD_TESTS)
    add_subdirectory(tests)
endif()