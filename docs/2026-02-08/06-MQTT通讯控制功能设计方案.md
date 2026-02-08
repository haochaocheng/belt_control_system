# MQTT 通讯控制功能设计方案

## 文档信息
- **创建日期**: 2026-02-08
- **Phase**: 7.43
- **状态**: 规划中

---

## 1. 需求概述

### 1.1 使用场景
- 8个模块使用 MQTT 方式与工控机通讯
- 模块类型：输入输出模块、沿线急停数据模块等
- 工控机需要：
  - 读取各模块的状态数据（订阅）
  - 发送控制指令到各模块（发布）

### 1.2 功能需求
1. 支持 8 个 MQTT 模块的独立配置和管理
2. 每个模块可配置独立的连接参数
3. 支持订阅和发布主题配置
4. 实时数据监控和显示
5. 支持 QoS 0/1/2 三种服务质量级别
6. 支持用户名/密码认证

---

## 2. MQTT 协议简介

### 2.1 协议特点
- **轻量级**：协议头最小只有 2 字节
- **发布/订阅模式**：解耦消息发送者和接收者
- **QoS 支持**：三种服务质量级别
- **保留消息**：新订阅者可获取最后一条消息
- **遗嘱消息**：客户端异常断开时自动发布

### 2.2 QoS 级别说明
| QoS | 名称 | 说明 | 适用场景 |
|-----|------|------|----------|
| 0 | 最多一次 | 不保证送达，可能丢失 | 传感器数据（允许丢失） |
| 1 | 至少一次 | 保证送达，可能重复 | 状态更新（推荐） |
| 2 | 恰好一次 | 保证送达且不重复 | 控制指令（关键操作） |

### 2.3 主题设计建议
```
belt_control/                          # 根主题
├── module{1-8}/                       # 模块主题
│   ├── status                         # 状态数据（订阅）
│   │   ├── input                      # 输入状态
│   │   ├── output                     # 输出状态
│   │   └── emergency_stop             # 急停状态
│   ├── control                        # 控制指令（发布）
│   │   ├── output                     # 输出控制
│   │   └── reset                      # 复位指令
│   └── heartbeat                      # 心跳（双向）
└── system/                            # 系统主题
    ├── config                         # 配置下发
    └── alarm                          # 报警信息
```

---

## 3. 开源库选型分析

### 3.1 候选方案

#### 方案一：Qt MQTT 模块（推荐）
- **库名称**: Qt MQTT (QtMqtt)
- **官方支持**: Qt 5.10+ / Qt 6.2+
- **优点**:
  - Qt 官方模块，与项目完美集成
  - 信号槽机制，与 QML 无缝对接
  - 文档完善，社区活跃
  - 支持 MQTT 3.1.1 和 5.0
- **缺点**:
  - 需要额外安装 Qt MQTT 模块
  - 可能需要交叉编译
- **安装方式**:
  ```bash
  # Windows (Qt Maintenance Tool)
  选择 Qt MQTT 模块安装

  # Linux
  sudo apt install qt6-mqtt-dev
  ```

#### 方案二：Eclipse Paho MQTT C++
- **库名称**: Eclipse Paho MQTT C/C++
- **官方支持**: Eclipse Foundation
- **优点**:
  - 跨平台，成熟稳定
  - 支持同步和异步 API
  - 支持 SSL/TLS
- **缺点**:
  - 需要手动封装 Qt 信号槽
  - 需要单独编译和集成
- **GitHub**: https://github.com/eclipse/paho.mqtt.cpp

#### 方案三：mosquitto 客户端库
- **库名称**: libmosquitto
- **官方支持**: Eclipse Mosquitto 项目
- **优点**:
  - 轻量级，C 语言实现
  - 广泛使用，稳定可靠
- **缺点**:
  - C 语言 API，需要 C++ 封装
  - 与 Qt 集成需要额外工作

### 3.2 推荐方案

**推荐使用 Qt MQTT 模块**

理由：
1. 项目已使用 Qt6 6.5+，Qt MQTT 完全兼容
2. 信号槽机制与现有架构一致
3. 可直接暴露给 QML 使用
4. 减少第三方依赖管理复杂度
5. 官方维护，长期支持

### 3.3 Qt MQTT 安装验证

```cpp
// 检查 Qt MQTT 是否可用
#include <QtMqtt/QMqttClient>

// CMakeLists.txt 添加
find_package(Qt6 REQUIRED COMPONENTS Mqtt)
target_link_libraries(${PROJECT_NAME} PRIVATE Qt6::Mqtt)
```

---

## 4. 架构设计

### 4.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                      QML 界面层                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │MQTTListPanel│  │MQTTConfigPanel│ │MQTTControlPage│       │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    C++ 控制器层                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              MQTTController                          │   │
│  │  - 管理 8 个 MQTT 客户端实例                         │   │
│  │  - 处理连接/断开/订阅/发布                           │   │
│  │  - 暴露 Q_PROPERTY 和信号给 QML                      │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Qt MQTT 库层                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │QMqttClient 1│  │QMqttClient 2│  │  ... × 8    │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    MQTT Broker                               │
│              (Mosquitto / EMQX / 其他)                       │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    现场设备模块                              │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐              │
│  │ 模块1  │ │ 模块2  │ │ 模块3  │ │ ... ×8 │              │
│  │输入输出│ │输入输出│ │急停数据│ │        │              │
│  └────────┘ └────────┘ └────────┘ └────────┘              │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 类设计

#### MQTTController 类
```cpp
class MQTTController : public QObject
{
    Q_OBJECT

    // 模块配置属性
    Q_PROPERTY(QVariantList modules READ modules NOTIFY modulesChanged)
    Q_PROPERTY(int currentModuleIndex READ currentModuleIndex
               WRITE setCurrentModuleIndex NOTIFY currentModuleIndexChanged)

    // 当前模块状态
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(QVariantList receivedMessages READ receivedMessages
               NOTIFY receivedMessagesChanged)

public:
    // 连接管理
    Q_INVOKABLE bool connectToModule(int moduleIndex);
    Q_INVOKABLE void disconnectFromModule(int moduleIndex);
    Q_INVOKABLE void disconnectAll();

    // 订阅管理
    Q_INVOKABLE bool subscribe(int moduleIndex, const QString &topic, int qos = 1);
    Q_INVOKABLE void unsubscribe(int moduleIndex, const QString &topic);

    // 发布消息
    Q_INVOKABLE bool publish(int moduleIndex, const QString &topic,
                             const QByteArray &message, int qos = 1, bool retain = false);

    // 配置管理
    Q_INVOKABLE void saveModuleConfig(int moduleIndex);
    Q_INVOKABLE void loadModuleConfig(int moduleIndex);
    Q_INVOKABLE void resetModuleConfig(int moduleIndex);

signals:
    void modulesChanged();
    void currentModuleIndexChanged();
    void connectedChanged(int moduleIndex, bool connected);
    void lastErrorChanged();
    void receivedMessagesChanged();
    void messageReceived(int moduleIndex, const QString &topic, const QByteArray &payload);
    void connectionStateChanged(int moduleIndex, int state);

private:
    QVector<QMqttClient*> m_clients;  // 8 个客户端实例
    QVector<MQTTModuleConfig> m_configs;  // 8 个模块配置
};
```

#### MQTTModuleConfig 结构
```cpp
struct MQTTModuleConfig
{
    QString name;           // 模块名称（模块1-模块8）
    QString brokerHost;     // Broker 地址
    int brokerPort;         // Broker 端口（默认 1883）
    QString clientId;       // 客户端 ID
    QString username;       // 用户名
    QString password;       // 密码
    int keepAlive;          // 心跳间隔（秒）
    bool cleanSession;      // 清除会话
    int defaultQos;         // 默认 QoS

    // 订阅主题列表
    QStringList subscribeTopics;

    // 发布主题列表
    QStringList publishTopics;
};
```

---

## 5. 界面设计

### 5.1 界面结构（参考 TCP 控制）

```
┌─────────────────────────────────────────────────────────────┐
│                    MQTT 通讯控制                             │
├─────────────┬───────────────────────────────────────────────┤
│             │  ┌─────────────────────────────────────────┐  │
│  模块列表    │  │ 连接配置 │ 订阅主题 │ 发布主题 │ 数据监控 │  │
│             │  └─────────────────────────────────────────┘  │
│  ┌────────┐ │  ┌─────────────────────────────────────────┐  │
│  │ 模块1  │ │  │                                         │  │
│  ├────────┤ │  │         Tab 内容区域                     │  │
│  │ 模块2  │ │  │                                         │  │
│  ├────────┤ │  │  - 连接配置：Broker、端口、认证等        │  │
│  │ 模块3  │ │  │  - 订阅主题：主题列表、QoS 配置          │  │
│  ├────────┤ │  │  - 发布主题：主题列表、消息发送          │  │
│  │ 模块4  │ │  │  - 数据监控：实时消息显示                │  │
│  ├────────┤ │  │                                         │  │
│  │ 模块5  │ │  │                                         │  │
│  ├────────┤ │  └─────────────────────────────────────────┘  │
│  │ 模块6  │ │                                               │
│  ├────────┤ ├───────────────────────────────────────────────┤
│  │ 模块7  │ │  ┌────────┐ ┌────────┐                       │
│  ├────────┤ │  │  连接  │ │  断开  │                       │
│  │ 模块8  │ │  └────────┘ └────────┘                       │
│  └────────┘ │  ┌────────┐ ┌────────┐ ┌────────┐            │
│             │  │  保存  │ │  删除  │ │  重置  │            │
│             │  └────────┘ └────────┘ └────────┘            │
└─────────────┴───────────────────────────────────────────────┘
```

### 5.2 QML 文件结构

```
src/qml/components/device_info/pages/
├── MQTTControlPage.qml          # 主页面（参考 TCPControlPage.qml）
├── MQTTListPanel.qml            # 左侧模块列表
├── MQTTConfigPanel.qml          # 右侧配置面板（含 Tab）
├── MQTTConnectionTab.qml        # Tab 1: 连接配置
├── MQTTSubscribeTab.qml         # Tab 2: 订阅主题
├── MQTTPublishTab.qml           # Tab 3: 发布主题
└── MQTTMonitorTab.qml           # Tab 4: 数据监控
```

### 5.3 Tab 页面参数设计

#### Tab 1: 连接配置 (MQTTConnectionTab.qml)
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Broker 地址 | TextField | 192.168.10.1 | MQTT Broker IP/域名 |
| 端口 | SpinBox | 1883 | MQTT 端口 |
| 客户端 ID | TextField | module_1 | 唯一标识 |
| 用户名 | TextField | - | 认证用户名 |
| 密码 | TextField | - | 认证密码 |
| Keep Alive | SpinBox | 60 | 心跳间隔（秒） |
| Clean Session | ComboBox | 是 | 是否清除会话 |
| 默认 QoS | ComboBox | 1 | 默认服务质量 |
| 状态 | Label | 未连接 | 连接状态显示 |

#### Tab 2: 订阅主题 (MQTTSubscribeTab.qml)
| 参数 | 类型 | 说明 |
|------|------|------|
| 主题列表 | ListView | 已订阅的主题列表 |
| 新主题 | TextField | 输入新主题 |
| QoS | ComboBox | 0/1/2 |
| 添加按钮 | Button | 添加订阅 |
| 删除按钮 | Button | 删除选中订阅 |

#### Tab 3: 发布主题 (MQTTPublishTab.qml)
| 参数 | 类型 | 说明 |
|------|------|------|
| 主题 | TextField | 发布主题 |
| 消息内容 | TextArea | 消息内容（支持 JSON） |
| QoS | ComboBox | 0/1/2 |
| Retain | ComboBox | 是否保留 |
| 发布按钮 | Button | 发送消息 |
| 历史记录 | ListView | 发布历史 |

#### Tab 4: 数据监控 (MQTTMonitorTab.qml)
| 参数 | 类型 | 说明 |
|------|------|------|
| 消息列表 | ListView | 实时接收的消息 |
| 过滤主题 | TextField | 主题过滤 |
| 清空按钮 | Button | 清空消息列表 |
| 暂停按钮 | Button | 暂停/继续接收 |
| 导出按钮 | Button | 导出消息记录 |

---

## 6. 数据存储设计

### 6.1 配置存储（SQLite）

```sql
-- MQTT 模块配置表
CREATE TABLE mqtt_module_config (
    id INTEGER PRIMARY KEY,
    module_index INTEGER NOT NULL,      -- 模块索引 (0-7)
    module_name TEXT DEFAULT 'Module',  -- 模块名称
    broker_host TEXT DEFAULT '192.168.10.1',
    broker_port INTEGER DEFAULT 1883,
    client_id TEXT,
    username TEXT,
    password TEXT,
    keep_alive INTEGER DEFAULT 60,
    clean_session INTEGER DEFAULT 1,
    default_qos INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- MQTT 订阅主题表
CREATE TABLE mqtt_subscribe_topics (
    id INTEGER PRIMARY KEY,
    module_index INTEGER NOT NULL,
    topic TEXT NOT NULL,
    qos INTEGER DEFAULT 1,
    enabled INTEGER DEFAULT 1,
    FOREIGN KEY (module_index) REFERENCES mqtt_module_config(module_index)
);

-- MQTT 发布主题表
CREATE TABLE mqtt_publish_topics (
    id INTEGER PRIMARY KEY,
    module_index INTEGER NOT NULL,
    topic TEXT NOT NULL,
    qos INTEGER DEFAULT 1,
    retain INTEGER DEFAULT 0,
    FOREIGN KEY (module_index) REFERENCES mqtt_module_config(module_index)
);
```

---

## 7. 实施计划

### Phase 7.43.1: 环境准备
- [ ] 验证 Qt MQTT 模块是否已安装
- [ ] 如未安装，进行安装和交叉编译配置
- [ ] 更新 CMakeLists.txt 添加 Qt MQTT 依赖

### Phase 7.43.2: C++ 控制器实现
- [ ] 创建 MQTTController 类
- [ ] 实现连接/断开功能
- [ ] 实现订阅/发布功能
- [ ] 实现配置保存/加载功能
- [ ] 注册到 QML 引擎

### Phase 7.43.3: QML 界面实现
- [ ] 创建 MQTTControlPage.qml（主页面）
- [ ] 创建 MQTTListPanel.qml（模块列表）
- [ ] 创建 MQTTConfigPanel.qml（配置面板）
- [ ] 创建 4 个 Tab 页面
- [ ] 实现导航系统集成

### Phase 7.43.4: 集成和测试
- [ ] 添加到 DeviceSettingsDialog
- [ ] 添加到左侧类别列表
- [ ] 导航系统适配
- [ ] QDS 测试验证
- [ ] 实际设备测试

---

## 8. 风险和注意事项

### 8.1 技术风险
1. **Qt MQTT 模块可用性**
   - 风险：Qt MQTT 可能未安装或交叉编译困难
   - 缓解：准备 Paho MQTT 作为备选方案

2. **网络稳定性**
   - 风险：MQTT 连接可能因网络问题断开
   - 缓解：实现自动重连机制

3. **消息处理性能**
   - 风险：大量消息可能导致界面卡顿
   - 缓解：使用消息队列和异步处理

### 8.2 注意事项
1. 每个模块使用独立的 QMqttClient 实例
2. 客户端 ID 必须唯一，避免冲突
3. 敏感信息（密码）需要加密存储
4. 实现连接状态监控和自动重连
5. 消息监控需要限制缓存数量，避免内存溢出

---

## 9. 参考资料

1. [Qt MQTT 官方文档](https://doc.qt.io/qt-6/qtmqtt-index.html)
2. [MQTT 协议规范 3.1.1](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/mqtt-v3.1.1.html)
3. [Eclipse Paho MQTT](https://www.eclipse.org/paho/)
4. [EMQX MQTT Broker](https://www.emqx.io/)
