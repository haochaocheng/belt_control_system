# MQTT 主动上报模式测试指南

**日期**: 2026-02-09
**阶段**: Phase 7.44.18
**类型**: 测试指南

---

## 一、工作模式说明

### 模式对比

| 特性 | 轮询模式 | 主动上报模式 ✅ |
|------|---------|----------------|
| 主机发送命令 | ✅ 每100ms发送读取命令 | ❌ 不发送命令 |
| 模块发送数据 | 收到命令后响应 | 主动定期发送 |
| 适用场景 | 模块支持命令控制 | 纯输入模块 |
| 网络流量 | 较大（命令+数据） | 较小（仅数据） |

### 当前需求

开关量输入模块（DI）和模拟量输入模块（AI）都是**纯输入模块**，应该使用**主动上报模式**。

---

## 二、主机应用配置

### 2.1 关闭数据采集（轮询）

1. 打开主机应用
2. 进入"设备信息" → "MQTT"
3. 选择任意模块
4. 切换到"自动控制"Tab
5. **关闭"数据采集"开关**

**效果**：
- ❌ 主机不再发送读取命令
- ✅ 主机继续订阅状态主题
- ✅ 主机可以接收模块主动发送的数据

### 2.2 保持自动连接

确保"自动连接"开关是**开启**的，这样主机会：
- ✅ 自动连接到 EMQX
- ✅ 自动订阅状态主题
- ✅ 自动重连（如果断开）

---

## 三、MQTTX 模拟器配置

### 3.1 模块1（开关量输入1）

**连接配置**：
- Name: `belt_control_di1`
- Client ID: `belt_control_di1`
- Host: `localhost`
- Port: `1883`

**不需要订阅任何主题**（因为不接收命令）

**定期发布数据**：

**主题**：`belt_control/di/module1/status`

**数据**（每100ms发送一次）：
```json
{
  "module_id": 1,
  "type": "di",
  "timestamp": 1707956785,
  "data": {
    "bits": [true, false, true, true, false, false, true, false],
    "byte": 178
  }
}
```

### 3.2 模块2（开关量输入2）

**连接配置**：
- Name: `belt_control_di2`
- Client ID: `belt_control_di2`
- Host: `localhost`
- Port: `1883`

**不需要订阅任何主题**

**定期发布数据**：

**主题**：`belt_control/di/module2/status`

**数据**（每100ms发送一次）：
```json
{
  "module_id": 2,
  "type": "di",
  "timestamp": 1707956785,
  "data": {
    "bits": [false, true, false, true, false, true, false, true],
    "byte": 85
  }
}
```

---

## 四、MQTTX 定时发送配置

### 4.1 使用 MQTTX 的脚本功能

MQTTX 支持脚本功能，可以定时发送消息。

**步骤**：
1. 在 MQTTX 中，点击连接的"脚本"按钮
2. 选择"定时发送"
3. 设置间隔：100ms
4. 设置主题：`belt_control/di/module1/status`
5. 设置消息内容（JSON格式）
6. 启动定时发送

### 4.2 手动定时发送

如果 MQTTX 不支持定时发送，可以手动每隔一段时间点击"发送"按钮。

或者使用 Python 脚本自动发送（参考之前的 `mqtt_simulator.py`）。

---

## 五、测试步骤

### 5.1 启动 EMQX

```powershell
docker start emqx
```

### 5.2 启动主机应用

在设备上运行主机应用。

### 5.3 配置主机应用

1. 进入"设备信息" → "MQTT"
2. 切换到"自动控制"Tab
3. **关闭"数据采集"开关**
4. 确认"自动连接"开关是**开启**的

### 5.4 连接 MQTTX

1. 打开 MQTTX
2. 连接 `belt_control_di1`
3. 连接 `belt_control_di2`

### 5.5 MQTTX 发送数据

在 `belt_control_di1` 中，发布消息到 `belt_control/di/module1/status`：

```json
{
  "module_id": 1,
  "type": "di",
  "timestamp": 1707956785,
  "data": {
    "bits": [true, false, true, true, false, false, true, false],
    "byte": 178
  }
}
```

**重复发送**：每隔1-2秒手动点击"发送"按钮，模拟模块主动上报。

### 5.6 观察主机应用

1. 在模块列表中选择"模块1"
2. 切换到"自动控制"Tab
3. 观察 LED 指示灯是否更新

---

## 六、预期结果

### 6.1 主机应用日志

```
✅ [MQTTAutoManager] 自动管理器已启动
🔌 [MQTTAutoManager] 连接所有模块（前4个）
✅ [MQTTAutoManager] 模块 0 订阅主题: belt_control/di/module1/status
✅ [MQTTAutoManager] 模块 1 订阅主题: belt_control/di/module2/status
📩 [MQTTAutoManager] 模块 0 收到数据 - 主题: belt_control/di/module1/status
✅ [DIDataManager] 模块 0 数据更新: byte=178
```

**注意**：
- ✅ 有"订阅主题"的日志
- ✅ 有"收到数据"的日志
- ❌ **没有**"发送读取命令"的日志（因为关闭了数据采集）

### 6.2 EMQX Dashboard

访问 http://localhost:18083

**连接列表**：
- `belt_control_module_1`（主机）
- `belt_control_module_2`（主机）
- `belt_control_di1`（MQTTX 模拟器）
- `belt_control_di2`（MQTTX 模拟器）

**订阅列表**：
- `belt_control_module_1` 订阅 `belt_control/di/module1/status`
- `belt_control_module_2` 订阅 `belt_control/di/module2/status`

**消息流**：
- `belt_control_di1` 发布到 `belt_control/di/module1/status`
- `belt_control_module_1` 接收消息

### 6.3 主机应用界面

1. 选择"模块1"
2. 切换到"自动控制"Tab
3. 看到 LED 指示灯实时更新
4. 字节值显示：`B2h (178)`
5. 二进制显示：`1011 0010`

---

## 七、主题总结

### 7.1 开关量模块（模块1-2）

| 模块 | 状态主题（模块→主机） | 控制主题（主机→模块） |
|------|----------------------|----------------------|
| 模块1 | `belt_control/di/module1/status` | ❌ 不使用 |
| 模块2 | `belt_control/di/module2/status` | ❌ 不使用 |

### 7.2 模拟量模块（模块3-4）

| 模块 | 状态主题（模块→主机） | 控制主题（主机→模块） |
|------|----------------------|----------------------|
| 模块3 | `belt_control/ai/module1/status` | ❌ 不使用 |
| 模块4 | `belt_control/ai/module2/status` | ❌ 不使用 |

---

## 八、优势

### 8.1 简化通信

- ❌ 不需要主机发送读取命令
- ✅ 模块主动发送数据
- ✅ 减少网络流量

### 8.2 降低延迟

- ❌ 不需要等待命令
- ✅ 模块可以立即发送数据
- ✅ 实时性更好

### 8.3 更符合输入模块特性

- ✅ 输入模块只需要上报数据
- ✅ 不需要接收控制命令
- ✅ 架构更清晰

---

## 九、常见问题

### 9.1 关闭数据采集后，主机还能收到数据吗？

**答**：可以！关闭数据采集只是停止发送读取命令，但主机仍然会：
- ✅ 订阅状态主题
- ✅ 接收模块发送的数据
- ✅ 解析和显示数据

### 9.2 如果需要轮询模式怎么办？

**答**：打开"数据采集"开关即可。主机会：
- ✅ 定期发送读取命令
- ✅ 接收模块响应的数据

### 9.3 模块应该多久发送一次数据？

**答**：根据实际需求：
- 开关量模块：建议 100-500ms
- 模拟量模块：建议 500-1000ms
- 可以根据数据变化频率调整

---

## 十、下一步

1. ✅ 关闭主机应用的"数据采集"开关
2. ✅ 使用 MQTTX 定期发送数据
3. ✅ 观察主机应用是否正常接收和显示

如果还有问题，请提供：
- 主机应用的日志
- EMQX Dashboard 的截图
- MQTTX 的发送记录

---

**文档版本**: v1.0
**最后更新**: 2026-02-09
