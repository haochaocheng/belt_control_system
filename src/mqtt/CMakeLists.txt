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
    MQTTAutoManager.cpp      # ✅ 2026-02-09 [Phase 7.44]: MQTT自动管理器
    DIDataManager.cpp        # ✅ 2026-02-09 [Phase 7.44]: 开关量数据管理器
    AIDataManager.cpp        # ✅ 2026-02-09 [Phase 7.44]: 模拟量数据管理器
    DODataManager.cpp        # ✅ 2026-03-10 [Phase 7.48.36]: DO模块数据管理器
    CSDataManager.cpp        # ✅ 2026-03-18 [Phase 7.48.56]: CS模块数据管理器（沿线点位保护）
)

# 头文件
set(MQTT_HEADERS
    MQTTController.h
    MQTTAutoManager.h        # ✅ 2026-02-09 [Phase 7.44]: MQTT自动管理器
    DIDataManager.h          # ✅ 2026-02-09 [Phase 7.44]: 开关量数据管理器
    AIDataManager.h          # ✅ 2026-02-09 [Phase 7.44]: 模拟量数据管理器
    DODataManager.h          # ✅ 2026-03-10 [Phase 7.48.36]: DO模块数据管理器
    CSDataManager.h          # ✅ 2026-03-18 [Phase 7.48.56]: CS模块数据管理器（沿线点位保护）
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
