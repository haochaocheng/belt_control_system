# ✅ 2026-02-08 [Phase 7.43]: MQTT 通讯控制模块
# 功能：管理 8 个 MQTT 模块的连接、订阅、发布

# 检查 Qt MQTT 是否可用
find_package(Qt6 6.5 QUIET COMPONENTS Mqtt)

if(NOT Qt6Mqtt_FOUND)
    message(WARNING "Qt6::Mqtt not found - MQTT module will not be built")
    return()
endif()

message(STATUS "Building MQTT module with Qt6::Mqtt")

# 源文件
set(MQTT_SOURCES
    MQTTController.cpp
)

# 头文件
set(MQTT_HEADERS
    MQTTController.h
)

# 创建静态库
add_library(mqtt_module STATIC
    ${MQTT_SOURCES}
    ${MQTT_HEADERS}
)

# 链接 Qt 库
target_link_libraries(mqtt_module PUBLIC
    Qt6::Core
    Qt6::Network
    Qt6::Mqtt
    Qt6::Qml
)

# 包含目录
target_include_directories(mqtt_module PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# 导出编译定义
target_compile_definitions(mqtt_module PUBLIC MQTT_ENABLED)
