# MQTTX 快速测试步骤

**日期**: 2026-02-09
**阶段**: Phase 7.44.16
**类型**: 测试指南

---

## 一、MQTTX 客户端配置

### 1.1 模块1（开关量输入1）

**连接配置**：
- Name: `belt_control_di1`
- Client ID: `belt_control_di1`
- Host: `localhost`
- Port: `1883`
- Protocol: `MQTT 3.1.1`

**订阅主题**：
```
belt_control/di/module1/control
```

**发布主题**：
```
belt_control/di/module1/status
```

### 1.2 模块2（开关量输入2）

**连接配置**：
- Name: `belt_control_di2`
- Client ID: `belt_control_di2`
- Host: `localhost`
- Port: `1883`
- Protocol: `MQTT 3.1.1`

**订阅主题**：
```
belt_control/di/module2/control
```

**发布主题**：
```
belt_control/di/module2/status
```

---

## 二、测试步骤

### 2.1 启动 EMQX

```powershell
docker start emqx
```

### 2.2 启动主机应用

在设备上运行主机应用，或者在本地运行。

### 2.3 连接 MQTTX 客户端

1. 打开 MQTTX
2. 连接 `belt_control_di1`
3. 连接 `belt_control_di2`

### 2.4 验证主机发送的读取命令

在 MQTTX 中，您应该看到主机应用每 100ms 发送一次读取命令：

**模块1 收到**（主题：`belt_control/di/module1/control`）：
```json
{
  "cmd": "read",
  "timestamp": 1770614338
}
```

**模块2 收到**（主题：`belt_control/di/module2/control`）：
```json
{
  "cmd": "read",
  "timestamp": 1770614338
}
```

### 2.5 模块1 响应数据

在 MQTTX 的 `belt_control_di1` 客户端中，发布消息到 `belt_control/di/module1/status`：

**正确格式**：
```json
{
  "module_id": 1,
  "type": "di",
  "timestamp": 1707456789,
  "data": {
    "bits": [true, false, true, true, false, false, true, false],
    "byte": 178
  }
}
```

**注意**：
- ✅ `module_id`（不是 `module`）
- ✅ `bits` 数组使用布尔值 `true`/`false`（不是数字 `1`/`0`）
- ✅ 不需要 `quality` 字段

### 2.6 模块2 响应数据

在 MQTTX 的 `belt_control_di2` 客户端中，发布消息到 `belt_control/di/module2/status`：

```json
{
  "module_id": 2,
  "type": "di",
  "timestamp": 1707456789,
  "data": {
    "bits": [false, true, false, true, false, true, false, true],
    "byte": 85
  }
}
```

---

## 三、预期结果

### 3.1 主机应用日志

在主机应用的控制台中，您应该看到：

```
✅ [MQTTAutoManager] 自动管理器已启动
🔌 [MQTTAutoManager] 连接所有模块（前4个）
🔌 [MQTTAutoManager] 连接模块: 0
🔌 [MQTTAutoManager] 连接模块: 1
✅ [MQTTAutoManager] 启动开关量采集定时器
📤 [MQTTAutoManager] 发送读取命令到模块 0
📤 [MQTTAutoManager] 发送读取命令到模块 1
📩 [MQTTAutoManager] 模块 0 收到数据 - 主题: belt_control/di/module1/status
✅ [DIDataManager] 模块 0 数据更新: byte=178
📩 [MQTTAutoManager] 模块 1 收到数据 - 主题: belt_control/di/module2/status
✅ [DIDataManager] 模块 1 数据更新: byte=85
```

### 3.2 主机应用界面

1. 打开"设备信息"对话框
2. 选择"MQTT"类别
3. 在模块列表中选择"模块1"
4. 切换到"自动控制"Tab
5. 看到 8 个 LED 指示灯：
   - 位0: 绿色闪烁（ON）
   - 位1: 灰色（OFF）
   - 位2: 绿色闪烁（ON）
   - 位3: 绿色闪烁（ON）
   - 位4: 灰色（OFF）
   - 位5: 灰色（OFF）
   - 位6: 绿色闪烁（ON）
   - 位7: 灰色（OFF）
6. 字节值显示：`B2h (178)`
7. 二进制显示：`1011 0010`

---

## 四、常见问题

### 4.1 模块1没有收到读取命令

**问题**：MQTTX 的 `belt_control_di1` 客户端没有收到消息

**原因**：订阅主题错误

**解决**：
1. 检查订阅主题是否为 `belt_control/di/module1/control`
2. 确认 QoS 设置为 0 或 1
3. 重新订阅主题

### 4.2 主机应用收不到数据

**问题**：主机应用日志中没有"收到数据"的消息

**原因**：发布主题错误或数据格式错误

**解决**：
1. 检查发布主题是否为 `belt_control/di/module1/status`
2. 检查 JSON 格式是否正确（使用 JSON 验证工具）
3. 确认字段名称：
   - ✅ `module_id`（不是 `module`）
   - ✅ `bits` 使用布尔值（不是数字）

### 4.3 数据格式错误

**错误的格式**：
```json
{
  "module": 1,  // ❌ 应该是 "module_id"
  "type": "di",
  "timestamp": 1707456789,
  "data": {
    "bits": [1, 0, 1, 1, 0, 0, 1, 0],  // ❌ 应该是布尔值
    "byte": 178
  },
  "quality": "good"  // ❌ 不需要这个字段
}
```

**正确的格式**：
```json
{
  "module_id": 1,
  "type": "di",
  "timestamp": 1707456789,
  "data": {
    "bits": [true, false, true, true, false, false, true, false],
    "byte": 178
  }
}
```

### 4.4 界面不显示数据

**问题**：界面上的 LED 不亮

**原因**：
1. 数据格式错误，解析失败
2. 模块索引不匹配
3. 界面没有切换到正确的模块

**解决**：
1. 检查主机应用日志，确认数据解析成功
2. 确认在模块列表中选择了正确的模块
3. 确认切换到了"自动控制"Tab

---

## 五、测试数据示例

### 5.1 模块1 - 全部 ON

```json
{
  "module_id": 1,
  "type": "di",
  "timestamp": 1707456789,
  "data": {
    "bits": [true, true, true, true, true, true, true, true],
    "byte": 255
  }
}
```

### 5.2 模块1 - 全部 OFF

```json
{
  "module_id": 1,
  "type": "di",
  "timestamp": 1707456789,
  "data": {
    "bits": [false, false, false, false, false, false, false, false],
    "byte": 0
  }
}
```

### 5.3 模块1 - 交替 ON/OFF

```json
{
  "module_id": 1,
  "type": "di",
  "timestamp": 1707456789,
  "data": {
    "bits": [true, false, true, false, true, false, true, false],
    "byte": 170
  }
}
```

### 5.4 模块2 - 示例数据

```json
{
  "module_id": 2,
  "type": "di",
  "timestamp": 1707456789,
  "data": {
    "bits": [false, true, false, true, false, true, false, true],
    "byte": 85
  }
}
```

---

## 六、主题总结

### 6.1 开关量模块（模块1-2）

| 模块 | 控制主题（主机→模块） | 状态主题（模块→主机） |
|------|----------------------|----------------------|
| 模块1 | `belt_control/di/module1/control` | `belt_control/di/module1/status` |
| 模块2 | `belt_control/di/module2/control` | `belt_control/di/module2/status` |

### 6.2 模拟量模块（模块3-4）

| 模块 | 控制主题（主机→模块） | 状态主题（模块→主机） |
|------|----------------------|----------------------|
| 模块3 | `belt_control/ai/module1/control` | `belt_control/ai/module1/status` |
| 模块4 | `belt_control/ai/module2/control` | `belt_control/ai/module2/status` |

---

## 七、调试技巧

### 7.1 使用 EMQX Dashboard

1. 访问 http://localhost:18083
2. 登录（admin/public）
3. 查看"连接"页面，确认所有客户端已连接
4. 查看"订阅"页面，确认主题订阅正确
5. 查看"消息"页面，监控消息流

### 7.2 使用 MQTTX 日志

在 MQTTX 中：
1. 点击"设置" → "日志"
2. 启用"显示详细日志"
3. 查看发送/接收的消息

### 7.3 主机应用日志

在主机应用中，查看控制台输出：
- `📤` 表示发送消息
- `📩` 表示接收消息
- `✅` 表示操作成功
- `⚠️` 表示警告
- `❌` 表示错误

---

**文档版本**: v1.0
**最后更新**: 2026-02-09
