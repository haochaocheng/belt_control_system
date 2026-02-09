# MQTT 模块自动通讯设计方案

**日期**: 2026-02-09
**阶段**: Phase 7.44
**作者**: Claude

---

## 一、系统概述

### 1.1 模块架构

系统共有 **8 个 MQTT 模块**，当前优先实施前 4 个模块：

| 模块编号 | 模块名称 | 功能描述 | 数据类型 | 数据量 |
|---------|---------|---------|---------|--------|
| 模块1 | 开关量输入1 | 检测8位开关量状态 | 8位布尔值 | 1字节 |
| 模块2 | 开关量输入2 | 检测8位开关量状态 | 8位布尔值 | 1字节 |
| 模块3 | 模拟量输入1 | 8通道16位AD转换 | 8×16位整数 | 16字节 |
| 模块4 | 模拟量输入2 | 8通道16位AD转换 | 8×16位整数 | 16字节 |
| 模块5 | CS1 | 沿线急停状态+主机通讯 | 待定 | 待定 |
| 模块6 | CS2 | 沿线急停状态+主机通讯 | 待定 | 待定 |
| 模块7 | 语音模块 | 语音播报控制 | 待定 | 待定 |
| 模块8 | 预留 | 待规划 | 待定 | 待定 |

### 1.2 现有技术基础

**已实现功能**（Phase 7.43）：
- ✅ MQTTController 支持 8 个独立客户端
- ✅ 连接管理（connect/disconnect）
- ✅ 订阅/发布功能
- ✅ QoS 0/1/2 支持
- ✅ 用户名/密码认证
- ✅ QML 界面集成
- ✅ 消息接收和显示

**待实现功能**（Phase 7.44）：
- ❌ 自动连接和重连机制
- ❌ 周期性数据采集
- ❌ 数据解析和存储
- ❌ 模块状态监控
- ❌ 数据变化通知

---

## 二、MQTT 主题设计

### 2.1 主题命名规范

采用分层主题结构：`belt_control/{模块类型}/{模块编号}/{数据类型}`

### 2.2 开关量输入模块（模块1、模块2）

#### 2.2.1 订阅主题（设备订阅，接收控制命令）

```
belt_control/di/module1/control    # 开关量输入1控制
belt_control/di/module2/control    # 开关量输入2控制
```

**控制命令格式**（JSON）：
```json
{
  "cmd": "read",           // 命令类型：read（读取）、config（配置）
  "timestamp": 1707456789  // 时间戳
}
```

#### 2.2.2 发布主题（设备发布，上报数据）

```
belt_control/di/module1/status     # 开关量输入1状态
belt_control/di/module2/status     # 开关量输入2状态
```

**状态数据格式**（JSON）：
```json
{
  "module": 1,                    // 模块编号
  "type": "di",                   // 模块类型：di（开关量输入）
  "timestamp": 1707456789,        // 时间戳
  "data": {
    "bits": [1, 0, 1, 1, 0, 0, 1, 0],  // 8位开关量状态（0/1）
    "byte": 0xB2                        // 字节表示（可选）
  },
  "quality": "good"               // 数据质量：good/bad/uncertain
}
```

### 2.3 模拟量输入模块（模块3、模块4）

#### 2.3.1 订阅主题（设备订阅，接收控制命令）

```
belt_control/ai/module3/control    # 模拟量输入1控制
belt_control/ai/module4/control    # 模拟量输入2控制
```

**控制命令格式**（JSON）：
```json
{
  "cmd": "read",                  // 命令类型：read（读取）、config（配置）
  "channels": [0, 1, 2, 3, 4, 5, 6, 7],  // 要读取的通道（可选，默认全部）
  "timestamp": 1707456789
}
```

#### 2.3.2 发布主题（设备发布，上报数据）

```
belt_control/ai/module3/status     # 模拟量输入1状态
belt_control/ai/module4/status     # 模拟量输入2状态
```

**状态数据格式**（JSON）：
```json
{
  "module": 3,                    // 模块编号
  "type": "ai",                   // 模块类型：ai（模拟量输入）
  "timestamp": 1707456789,        // 时间戳
  "data": {
    "channels": [
      {"ch": 0, "value": 1234, "voltage": 2.45},  // 通道0：AD值+电压
      {"ch": 1, "value": 2345, "voltage": 4.67},
      {"ch": 2, "value": 3456, "voltage": 6.89},
      {"ch": 3, "value": 4567, "voltage": 9.12},
      {"ch": 4, "value": 5678, "voltage": 11.34},
      {"ch": 5, "value": 6789, "voltage": 13.56},
      {"ch": 6, "value": 7890, "voltage": 15.78},
      {"ch": 7, "value": 8901, "voltage": 17.90}
    ]
  },
  "quality": "good"               // 数据质量
}
```

### 2.4 心跳主题（所有模块）

```
belt_control/heartbeat/module{N}   # 模块心跳
```

**心跳数据格式**（JSON）：
```json
{
  "module": 1,
  "timestamp": 1707456789,
  "uptime": 3600,                 // 运行时间（秒）
  "status": "online"              // 状态：online/offline
}
```

---

## 三、自动通讯机制设计

### 3.1 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    MQTTController                           │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  8个独立MQTT客户端（已实现）                          │  │
│  └──────────────────────────────────────────────────────┘  │
│                           ↓                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  MQTTAutoManager（新增）                              │  │
│  │  - 自动连接管理                                       │  │
│  │  - 周期性数据采集                                     │  │
│  │  - 数据解析和存储                                     │  │
│  │  - 状态监控和告警                                     │  │
│  └──────────────────────────────────────────────────────┘  │
│                           ↓                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  ModuleDataManager（新增）                            │  │
│  │  - 开关量数据管理（DIDataManager）                    │  │
│  │  - 模拟量数据管理（AIDataManager）                    │  │
│  │  - 数据缓存和历史记录                                 │  │
│  │  - 数据变化检测和通知                                 │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 自动连接管理

#### 3.2.1 启动时自动连接

```cpp
// 启动时自动连接前4个模块
void MQTTAutoManager::autoConnectModules()
{
    // 模块1-4：开关量和模拟量输入
    for (int i = 0; i < 4; ++i) {
        connectModule(i);
    }
}
```

#### 3.2.2 断线重连机制

```cpp
// 每5秒检查连接状态，断线自动重连
void MQTTAutoManager::checkConnectionStatus()
{
    for (int i = 0; i < 4; ++i) {
        if (!m_mqttController->isModuleConnected(i)) {
            qWarning() << "模块" << i << "断线，尝试重连...";
            reconnectModule(i);
        }
    }
}
```

**重连策略**：
- 检查周期：5秒
- 重连延迟：指数退避（1s, 2s, 4s, 8s, 最大30s）
- 最大重试次数：无限制（持续重连）

### 3.3 周期性数据采集

#### 3.3.1 采集周期配置

| 模块类型 | 默认周期 | 可配置范围 | 说明 |
|---------|---------|-----------|------|
| 开关量输入 | 100ms | 50ms-1000ms | 快速响应开关变化 |
| 模拟量输入 | 500ms | 100ms-5000ms | 平衡精度和性能 |

#### 3.3.2 采集实现

```cpp
// 开关量采集定时器
void MQTTAutoManager::startDIPolling()
{
    m_diTimer = new QTimer(this);
    m_diTimer->setInterval(100);  // 100ms
    connect(m_diTimer, &QTimer::timeout, this, &MQTTAutoManager::pollDIModules);
    m_diTimer->start();
}

// 模拟量采集定时器
void MQTTAutoManager::startAIPolling()
{
    m_aiTimer = new QTimer(this);
    m_aiTimer->setInterval(500);  // 500ms
    connect(m_aiTimer, &QTimer::timeout, this, &MQTTAutoManager::pollAIModules);
    m_aiTimer->start();
}

// 轮询开关量模块
void MQTTAutoManager::pollDIModules()
{
    // 发送读取命令到模块1和模块2
    for (int i = 0; i < 2; ++i) {
        QString topic = QString("belt_control/di/module%1/control").arg(i + 1);
        QJsonObject cmd;
        cmd["cmd"] = "read";
        cmd["timestamp"] = QDateTime::currentSecsSinceEpoch();

        m_mqttController->publish(topic,
            QJsonDocument(cmd).toJson(QJsonDocument::Compact),
            1, false, i);
    }
}

// 轮询模拟量模块
void MQTTAutoManager::pollAIModules()
{
    // 发送读取命令到模块3和模块4
    for (int i = 2; i < 4; ++i) {
        QString topic = QString("belt_control/ai/module%1/control").arg(i + 1);
        QJsonObject cmd;
        cmd["cmd"] = "read";
        cmd["timestamp"] = QDateTime::currentSecsSinceEpoch();

        m_mqttController->publish(topic,
            QJsonDocument(cmd).toJson(QJsonDocument::Compact),
            1, false, i);
    }
}
```

### 3.4 数据解析和存储

#### 3.4.1 开关量数据管理

```cpp
class DIDataManager : public QObject
{
    Q_OBJECT
public:
    // 解析开关量数据
    void parseData(int moduleIndex, const QByteArray &payload)
    {
        QJsonDocument doc = QJsonDocument::fromJson(payload);
        QJsonObject obj = doc.object();

        int module = obj["module"].toInt();
        QJsonArray bits = obj["data"].toObject()["bits"].toArray();

        // 存储数据
        QVector<bool> newData;
        for (int i = 0; i < 8; ++i) {
            newData.append(bits[i].toInt() == 1);
        }

        // 检测变化
        if (m_diData[moduleIndex] != newData) {
            m_diData[moduleIndex] = newData;
            emit dataChanged(moduleIndex, newData);

            // 检测每一位的变化
            for (int i = 0; i < 8; ++i) {
                if (m_diData[moduleIndex][i] != newData[i]) {
                    emit bitChanged(moduleIndex, i, newData[i]);
                }
            }
        }
    }

    // 获取指定位的状态
    bool getBit(int moduleIndex, int bitIndex) const
    {
        if (moduleIndex < 0 || moduleIndex >= 2) return false;
        if (bitIndex < 0 || bitIndex >= 8) return false;
        return m_diData[moduleIndex][bitIndex];
    }

signals:
    void dataChanged(int moduleIndex, const QVector<bool> &data);
    void bitChanged(int moduleIndex, int bitIndex, bool value);

private:
    QVector<QVector<bool>> m_diData;  // 2个模块，每个8位
};
```

#### 3.4.2 模拟量数据管理

```cpp
class AIDataManager : public QObject
{
    Q_OBJECT
public:
    struct ChannelData {
        quint16 adValue;      // AD转换值（0-65535）
        double voltage;       // 电压值（V）
        qint64 timestamp;     // 时间戳
        bool valid;           // 数据有效性
    };

    // 解析模拟量数据
    void parseData(int moduleIndex, const QByteArray &payload)
    {
        QJsonDocument doc = QJsonDocument::fromJson(payload);
        QJsonObject obj = doc.object();

        int module = obj["module"].toInt();
        QJsonArray channels = obj["data"].toObject()["channels"].toArray();

        // 存储数据
        QVector<ChannelData> newData;
        for (int i = 0; i < 8; ++i) {
            QJsonObject ch = channels[i].toObject();
            ChannelData data;
            data.adValue = ch["value"].toInt();
            data.voltage = ch["voltage"].toDouble();
            data.timestamp = obj["timestamp"].toVariant().toLongLong();
            data.valid = true;
            newData.append(data);
        }

        // 检测变化（阈值：AD值变化>10）
        bool changed = false;
        for (int i = 0; i < 8; ++i) {
            int diff = qAbs(m_aiData[moduleIndex][i].adValue - newData[i].adValue);
            if (diff > 10) {
                changed = true;
                emit channelChanged(moduleIndex, i, newData[i]);
            }
        }

        m_aiData[moduleIndex] = newData;
        if (changed) {
            emit dataChanged(moduleIndex, newData);
        }
    }

    // 获取指定通道的数据
    ChannelData getChannel(int moduleIndex, int channelIndex) const
    {
        if (moduleIndex < 2 || moduleIndex >= 4) return ChannelData();
        if (channelIndex < 0 || channelIndex >= 8) return ChannelData();
        return m_aiData[moduleIndex - 2][channelIndex];
    }

signals:
    void dataChanged(int moduleIndex, const QVector<ChannelData> &data);
    void channelChanged(int moduleIndex, int channelIndex, const ChannelData &data);

private:
    QVector<QVector<ChannelData>> m_aiData;  // 2个模块，每个8通道
};
```

### 3.5 状态监控和告警

#### 3.5.1 模块健康监控

```cpp
class ModuleHealthMonitor : public QObject
{
    Q_OBJECT
public:
    struct HealthStatus {
        bool connected;           // 连接状态
        qint64 lastDataTime;      // 最后数据时间
        int dataTimeout;          // 数据超时次数
        int reconnectCount;       // 重连次数
        QString status;           // 状态描述
    };

    // 检查模块健康状态
    void checkHealth()
    {
        qint64 now = QDateTime::currentSecsSinceEpoch();

        for (int i = 0; i < 4; ++i) {
            HealthStatus &health = m_health[i];

            // 检查连接状态
            health.connected = m_mqttController->isModuleConnected(i);

            // 检查数据超时（5秒无数据）
            if (now - health.lastDataTime > 5) {
                health.dataTimeout++;
                if (health.dataTimeout > 3) {
                    health.status = "数据超时";
                    emit healthWarning(i, "数据超时");
                }
            } else {
                health.dataTimeout = 0;
                health.status = "正常";
            }
        }
    }

signals:
    void healthWarning(int moduleIndex, const QString &message);
    void healthRecovered(int moduleIndex);

private:
    QVector<HealthStatus> m_health;  // 4个模块的健康状态
};
```

---

## 四、实施步骤

### Phase 7.44.1：创建自动管理器基础框架

**文件**：
- `src/mqtt/MQTTAutoManager.h`
- `src/mqtt/MQTTAutoManager.cpp`

**功能**：
- 自动连接管理
- 断线重连机制
- 连接状态监控

**预计工作量**：2-3小时

### Phase 7.44.2：实现周期性数据采集

**文件**：
- 修改 `MQTTAutoManager.cpp`

**功能**：
- 开关量采集定时器（100ms）
- 模拟量采集定时器（500ms）
- 发送读取命令

**预计工作量**：1-2小时

### Phase 7.44.3：实现开关量数据管理

**文件**：
- `src/mqtt/DIDataManager.h`
- `src/mqtt/DIDataManager.cpp`

**功能**：
- 数据解析
- 数据存储
- 变化检测
- 信号通知

**预计工作量**：2-3小时

### Phase 7.44.4：实现模拟量数据管理

**文件**：
- `src/mqtt/AIDataManager.h`
- `src/mqtt/AIDataManager.cpp`

**功能**：
- 数据解析
- 数据存储
- 变化检测（阈值）
- 信号通知

**预计工作量**：2-3小时

### Phase 7.44.5：实现健康监控

**文件**：
- `src/mqtt/ModuleHealthMonitor.h`
- `src/mqtt/ModuleHealthMonitor.cpp`

**功能**：
- 连接状态监控
- 数据超时检测
- 告警通知

**预计工作量**：1-2小时

### Phase 7.44.6：QML界面集成

**文件**：
- `src/qml/components/device_info/pages/MQTTAutoControlTab.qml`（新增）

**功能**：
- 显示4个模块的实时数据
- 开关量状态指示灯
- 模拟量数值显示
- 健康状态显示

**预计工作量**：3-4小时

### Phase 7.44.7：测试和优化

**测试内容**：
- 自动连接测试
- 断线重连测试
- 数据采集测试
- 数据解析测试
- 性能测试

**预计工作量**：2-3小时

---

## 五、配置文件设计

### 5.1 模块配置文件

**文件路径**：`config/mqtt_modules.json`

```json
{
  "modules": [
    {
      "index": 0,
      "name": "开关量输入1",
      "type": "di",
      "enabled": true,
      "broker": {
        "host": "192.168.10.142",
        "port": 1883,
        "clientId": "belt_control_di1"
      },
      "topics": {
        "control": "belt_control/di/module1/control",
        "status": "belt_control/di/module1/status",
        "heartbeat": "belt_control/heartbeat/module1"
      },
      "polling": {
        "enabled": true,
        "interval": 100
      }
    },
    {
      "index": 1,
      "name": "开关量输入2",
      "type": "di",
      "enabled": true,
      "broker": {
        "host": "192.168.10.142",
        "port": 1883,
        "clientId": "belt_control_di2"
      },
      "topics": {
        "control": "belt_control/di/module2/control",
        "status": "belt_control/di/module2/status",
        "heartbeat": "belt_control/heartbeat/module2"
      },
      "polling": {
        "enabled": true,
        "interval": 100
      }
    },
    {
      "index": 2,
      "name": "模拟量输入1",
      "type": "ai",
      "enabled": true,
      "broker": {
        "host": "192.168.10.142",
        "port": 1883,
        "clientId": "belt_control_ai1"
      },
      "topics": {
        "control": "belt_control/ai/module3/control",
        "status": "belt_control/ai/module3/status",
        "heartbeat": "belt_control/heartbeat/module3"
      },
      "polling": {
        "enabled": true,
        "interval": 500
      },
      "channels": {
        "count": 8,
        "changeThreshold": 10
      }
    },
    {
      "index": 3,
      "name": "模拟量输入2",
      "type": "ai",
      "enabled": true,
      "broker": {
        "host": "192.168.10.142",
        "port": 1883,
        "clientId": "belt_control_ai2"
      },
      "topics": {
        "control": "belt_control/ai/module4/control",
        "status": "belt_control/ai/module4/status",
        "heartbeat": "belt_control/heartbeat/module4"
      },
      "polling": {
        "enabled": true,
        "interval": 500
      },
      "channels": {
        "count": 8,
        "changeThreshold": 10
      }
    }
  ],
  "reconnect": {
    "enabled": true,
    "checkInterval": 5000,
    "maxDelay": 30000
  },
  "health": {
    "dataTimeout": 5000,
    "maxTimeoutCount": 3
  }
}
```

---

## 六、性能和资源评估

### 6.1 网络流量

| 模块类型 | 采集周期 | 单次数据量 | 每秒流量 |
|---------|---------|-----------|---------|
| 开关量×2 | 100ms | ~150字节 | ~3KB/s |
| 模拟量×2 | 500ms | ~500字节 | ~2KB/s |
| **总计** | - | - | **~5KB/s** |

### 6.2 CPU占用

- 定时器开销：<1%
- JSON解析：<2%
- 数据处理：<1%
- **总计**：<5%

### 6.3 内存占用

- 数据缓存：~10KB
- 历史记录（100条）：~50KB
- **总计**：<100KB

---

## 七、扩展性设计

### 7.1 新增模块类型

添加新模块类型只需：
1. 定义新的主题结构
2. 创建对应的 DataManager
3. 在配置文件中添加模块定义

### 7.2 支持更多模块

当前设计支持 8 个模块，扩展到更多模块只需：
1. 修改 `MQTTController` 的模块数量
2. 更新配置文件
3. 调整 UI 布局

### 7.3 支持其他协议

架构设计支持未来扩展：
- Modbus TCP/RTU
- OPC UA
- S7 通讯

只需实现对应的 DataManager 接口即可。

---

## 八、安全性考虑

### 8.1 认证和授权

- 支持 MQTT 用户名/密码认证
- 建议使用 TLS/SSL 加密（端口 8883）
- 配置文件中的密码应加密存储

### 8.2 数据完整性

- 使用 QoS 1 确保消息至少送达一次
- 添加时间戳和序列号检测重复消息
- 数据校验和（CRC/MD5）

### 8.3 异常处理

- 网络断线自动重连
- 数据超时告警
- 异常数据过滤

---

## 九、测试计划

### 9.1 单元测试

- MQTTAutoManager 连接管理测试
- DIDataManager 数据解析测试
- AIDataManager 数据解析测试
- ModuleHealthMonitor 健康检测测试

### 9.2 集成测试

- 4个模块同时连接测试
- 数据采集和解析测试
- 断线重连测试
- 性能压力测试

### 9.3 现场测试

- 实际硬件模块连接测试
- 长时间稳定性测试
- 异常场景测试

---

## 十、总结

本设计方案提供了一个完整的 MQTT 模块自动通讯解决方案，具有以下特点：

✅ **模块化设计**：各组件职责清晰，易于维护和扩展
✅ **自动化管理**：自动连接、重连、采集，无需人工干预
✅ **实时性**：开关量 100ms、模拟量 500ms 采集周期
✅ **可靠性**：断线重连、数据校验、健康监控
✅ **可扩展性**：支持新增模块类型和通讯协议
✅ **低资源占用**：网络流量 <5KB/s，CPU <5%，内存 <100KB

**下一步行动**：
1. 确认设计方案
2. 开始实施 Phase 7.44.1（创建自动管理器基础框架）
3. 逐步完成各个阶段的开发和测试

---

**文档版本**: v1.0
**最后更新**: 2026-02-09
