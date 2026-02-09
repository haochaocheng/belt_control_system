# MQTT 模拟测试指南

**日期**: 2026-02-09
**阶段**: Phase 7.44.10
**类型**: 测试指南

---

## 一、测试准备

### 1.1 启动 EMQX

```powershell
# 启动 EMQX 容器
docker start emqx

# 验证 EMQX 运行状态
docker ps | grep emqx

# 访问 EMQX Web 管理界面
# http://localhost:18083
# 用户名: admin
# 密码: public
```

### 1.2 启动主机应用

```powershell
# 编译并运行（如果需要）
cd e:\2025\3_gongkongji\belt_control_system
.\build-ubuntu24-apt.ps1 188

# 或者直接运行已编译的程序
cd build_rk3588\bin_arm64
.\belt_control_system.exe
```

### 1.3 打开 MQTTX

- 下载地址：https://mqttx.app/zh/downloads
- 或使用已安装的 MQTTX

---

## 二、配置 MQTTX 模拟器

### 2.1 创建 8 个连接

按照以下配置创建 8 个 MQTT 连接：

| 连接名称 | Client ID | 主题前缀 | 模块类型 |
|---------|-----------|---------|---------|
| 模块1-DI1 | module_1 | module/1 | 开关量输入1 |
| 模块2-DI2 | module_2 | module/2 | 开关量输入2 |
| 模块3-AI1 | module_3 | module/3 | 模拟量输入1 |
| 模块4-AI2 | module_4 | module/4 | 模拟量输入2 |
| 模块5-CS1 | module_5 | module/5 | CS1 |
| 模块6-CS2 | module_6 | module/6 | CS2 |
| 模块7-Voice | module_7 | module/7 | 语音模块 |
| 模块8-Reserved | module_8 | module/8 | 预留模块 |

**连接参数**：
- Host: `localhost`
- Port: `1883`
- Protocol: `MQTT 3.1.1`
- Clean Session: `true`
- Keep Alive: `60`

### 2.2 订阅主题

每个连接需要订阅对应的命令主题：

```
module/1/cmd    # 模块1订阅
module/2/cmd    # 模块2订阅
module/3/cmd    # 模块3订阅
module/4/cmd    # 模块4订阅
module/5/cmd    # 模块5订阅
module/6/cmd    # 模块6订阅
module/7/cmd    # 模块7订阅
module/8/cmd    # 模块8订阅
```

---

## 三、测试场景

### 3.1 测试开关量模块（模块1-2）

#### 3.1.1 主机发送读取命令

主机应用会自动发送读取命令到 `module/1/cmd`：

```json
{
  "cmd": "read",
  "timestamp": 1707456789
}
```

#### 3.1.2 模块1 响应数据

在 MQTTX 中，模块1 发布消息到 `module/1/data`：

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

**说明**：
- `bits`: 8位开关量状态（true=ON, false=OFF）
- `byte`: 字节值（0-255）
- 示例：`[true, false, true, true, false, false, true, false]` = `1011 0010` = `0xB2` = `178`

#### 3.1.3 预期结果

在主机应用中：
1. 选择"模块1"
2. 切换到"自动控制"Tab
3. 看到 8 个 LED 指示灯：
   - 位0: 绿色闪烁（ON）
   - 位1: 灰色（OFF）
   - 位2: 绿色闪烁（ON）
   - 位3: 绿色闪烁（ON）
   - 位4: 灰色（OFF）
   - 位5: 灰色（OFF）
   - 位6: 绿色闪烁（ON）
   - 位7: 灰色（OFF）
4. 字节值显示：`B2h (178)`
5. 二进制显示：`1011 0010`

#### 3.1.4 调试日志

在控制台应该看到：

```
✅ [MQTTAutoManager] 自动管理器已启动
🔌 [MQTTAutoManager] 连接所有模块（前4个）
📤 [MQTTAutoManager] 发送读取命令到模块 0
📩 [MQTTAutoManager] 模块 0 收到数据 - 主题: module/1/data
✅ [DIDataManager] 模块 0 数据更新: byte=178
```

---

### 3.2 测试模拟量模块（模块3-4）

#### 3.2.1 主机发送读取命令

主机应用会自动发送读取命令到 `module/3/cmd`：

```json
{
  "cmd": "read",
  "timestamp": 1707456789
}
```

#### 3.2.2 模块3 响应数据

在 MQTTX 中，模块3 发布消息到 `module/3/data`：

```json
{
  "module_id": 3,
  "type": "ai",
  "timestamp": 1707456789,
  "data": {
    "channels": [
      {"channel": 0, "ad_value": 32768, "voltage": 10.00},
      {"channel": 1, "ad_value": 40000, "voltage": 12.21},
      {"channel": 2, "ad_value": 50000, "voltage": 15.26},
      {"channel": 3, "ad_value": 55000, "voltage": 16.79},
      {"channel": 4, "ad_value": 45000, "voltage": 13.73},
      {"channel": 5, "ad_value": 35000, "voltage": 10.68},
      {"channel": 6, "ad_value": 25000, "voltage": 7.63},
      {"channel": 7, "ad_value": 20000, "voltage": 6.10}
    ]
  }
}
```

**说明**：
- `ad_value`: AD值（0-65535，16位）
- `voltage`: 电压值（0-20V）
- 转换公式：`voltage = (ad_value / 65535.0) * 20.0`

#### 3.2.3 预期结果

在主机应用中：
1. 选择"模块3"
2. 切换到"自动控制"Tab
3. 看到 8 个通道的数据：
   - 通道0: `32768 / 10.00V` （绿色）
   - 通道1: `40000 / 12.21V` （橙色）
   - 通道2: `50000 / 15.26V` （橙色）
   - 通道3: `55000 / 16.79V` （红色）
   - 通道4: `45000 / 13.73V` （橙色）
   - 通道5: `35000 / 10.68V` （橙色）
   - 通道6: `25000 / 7.63V` （绿色）
   - 通道7: `20000 / 6.10V` （绿色）
4. 统计信息：
   - 最小值: `6.10V`
   - 最大值: `16.79V`
   - 平均值: `11.29V`

#### 3.2.4 调试日志

在控制台应该看到：

```
📤 [MQTTAutoManager] 发送读取命令到模块 2
📩 [MQTTAutoManager] 模块 2 收到数据 - 主题: module/3/data
✅ [AIDataManager] 模块 2 数据更新
```

---

### 3.3 测试自动连接和重连

#### 3.3.1 测试自动连接

1. 启动主机应用
2. 观察日志，应该看到：
   ```
   ✅ [MQTTAutoManager] 自动管理器已启动
   🔌 [MQTTAutoManager] 连接所有模块（前4个）
   ```
3. 前4个模块（模块1-4）应该自动连接

#### 3.3.2 测试自动重连

1. 在 MQTTX 中断开模块1的连接
2. 等待 5 秒
3. 观察日志，应该看到：
   ```
   🔄 [MQTTAutoManager] 重连模块: 0
   ```
4. 模块1 应该自动重连

#### 3.3.3 测试手动重连

1. 在主机应用中，选择模块1
2. 切换到"自动控制"Tab
3. 点击"重新连接"按钮
4. 观察日志，应该看到：
   ```
   🔄 [MQTTAutoManager] 重连模块: 0
   ```

---

### 3.4 测试轮询机制

#### 3.4.1 开关量轮询（100ms）

1. 启动主机应用
2. 观察日志，应该每 100ms 看到：
   ```
   📤 [MQTTAutoManager] 发送读取命令到模块 0
   📤 [MQTTAutoManager] 发送读取命令到模块 1
   ```

#### 3.4.2 模拟量轮询（500ms）

1. 启动主机应用
2. 观察日志，应该每 500ms 看到：
   ```
   📤 [MQTTAutoManager] 发送读取命令到模块 2
   📤 [MQTTAutoManager] 发送读取命令到模块 3
   ```

#### 3.4.3 停止轮询

1. 在主机应用中，关闭"数据采集"开关
2. 观察日志，应该看到：
   ```
   🛑 [MQTTAutoManager] 停止轮询
   ```
3. 不再发送读取命令

---

### 3.5 测试健康监控

#### 3.5.1 数据超时检测

1. 启动主机应用，连接模块1
2. 在 MQTTX 中，模块1 停止响应数据
3. 等待 5 秒
4. 观察日志，应该看到：
   ```
   ⚠️ [MQTTAutoManager] 模块 0 数据超时
   ```
5. 在主机应用中，模块1 的状态应该显示"数据超时"

#### 3.5.2 恢复正常

1. 在 MQTTX 中，模块1 恢复响应数据
2. 观察日志，应该看到：
   ```
   ✅ [MQTTAutoManager] 模块 0 数据恢复正常
   ```
3. 在主机应用中，模块1 的状态应该显示"正常"

---

## 四、测试数据示例

### 4.1 开关量数据（模块1-2）

**模块1 - 全部 ON**：
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

**模块1 - 全部 OFF**：
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

**模块1 - 交替 ON/OFF**：
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

### 4.2 模拟量数据（模块3-4）

**模块3 - 低电压（0-5V）**：
```json
{
  "module_id": 3,
  "type": "ai",
  "timestamp": 1707456789,
  "data": {
    "channels": [
      {"channel": 0, "ad_value": 0, "voltage": 0.00},
      {"channel": 1, "ad_value": 8192, "voltage": 2.50},
      {"channel": 2, "ad_value": 16384, "voltage": 5.00},
      {"channel": 3, "ad_value": 8192, "voltage": 2.50},
      {"channel": 4, "ad_value": 0, "voltage": 0.00},
      {"channel": 5, "ad_value": 16384, "voltage": 5.00},
      {"channel": 6, "ad_value": 8192, "voltage": 2.50},
      {"channel": 7, "ad_value": 0, "voltage": 0.00}
    ]
  }
}
```

**模块3 - 高电压（15-20V）**：
```json
{
  "module_id": 3,
  "type": "ai",
  "timestamp": 1707456789,
  "data": {
    "channels": [
      {"channel": 0, "ad_value": 49152, "voltage": 15.00},
      {"channel": 1, "ad_value": 57344, "voltage": 17.50},
      {"channel": 2, "ad_value": 65535, "voltage": 20.00},
      {"channel": 3, "ad_value": 57344, "voltage": 17.50},
      {"channel": 4, "ad_value": 49152, "voltage": 15.00},
      {"channel": 5, "ad_value": 65535, "voltage": 20.00},
      {"channel": 6, "ad_value": 57344, "voltage": 17.50},
      {"channel": 7, "ad_value": 49152, "voltage": 15.00}
    ]
  }
}
```

---

## 五、常见问题

### 5.1 EMQX 无法启动

**问题**：`docker start emqx` 失败

**解决**：
```powershell
# 检查容器状态
docker ps -a | grep emqx

# 查看日志
docker logs emqx

# 重新创建容器
docker rm emqx
docker run -d --name emqx -p 1883:1883 -p 8083:8083 -p 8084:8084 -p 8883:8883 -p 18083:18083 emqx/emqx:latest
```

### 5.2 MQTTX 连接失败

**问题**：`Error: connect ECONNREFUSED 127.0.0.1:1883`

**解决**：
1. 确认 EMQX 已启动：`docker ps | grep emqx`
2. 确认端口 1883 未被占用：`netstat -ano | findstr 1883`
3. 检查防火墙设置

### 5.3 主机应用收不到数据

**问题**：主机应用连接成功，但收不到数据

**解决**：
1. 检查 MQTTX 是否订阅了正确的主题（`module/X/cmd`）
2. 检查 MQTTX 是否发布到正确的主题（`module/X/data`）
3. 检查 JSON 格式是否正确
4. 查看主机应用的调试日志

### 5.4 数据格式错误

**问题**：`⚠️ [DIDataManager] JSON解析错误`

**解决**：
1. 检查 JSON 格式是否正确（使用 JSON 验证工具）
2. 确认字段名称正确（`module_id`, `type`, `timestamp`, `data`）
3. 确认数据类型正确（`bits` 是布尔数组，`byte` 是整数）

---

## 六、调试技巧

### 6.1 启用详细日志

在 `main.cpp` 中添加：

```cpp
// 启用 Qt 调试输出
qSetMessagePattern("[%{time yyyy-MM-dd HH:mm:ss.zzz}] %{if-category}%{category}: %{endif}%{message}");
```

### 6.2 使用 EMQX Dashboard

1. 访问 http://localhost:18083
2. 登录（admin/public）
3. 查看"连接"页面，确认所有模块已连接
4. 查看"订阅"页面，确认主题订阅正确
5. 查看"消息"页面，监控消息流

### 6.3 使用 MQTTX 日志

在 MQTTX 中：
1. 点击"设置" → "日志"
2. 启用"显示详细日志"
3. 查看发送/接收的消息

---

## 七、测试检查清单

### 7.1 基本功能

- [ ] EMQX 启动成功
- [ ] 主机应用启动成功
- [ ] MQTTX 创建 8 个连接
- [ ] 前4个模块自动连接

### 7.2 开关量模块（模块1-2）

- [ ] 模块1 接收读取命令
- [ ] 模块1 响应数据
- [ ] 主机应用显示 LED 指示灯
- [ ] LED 状态正确（ON=绿色闪烁，OFF=灰色）
- [ ] 字节值显示正确
- [ ] 二进制显示正确

### 7.3 模拟量模块（模块3-4）

- [ ] 模块3 接收读取命令
- [ ] 模块3 响应数据
- [ ] 主机应用显示通道数据
- [ ] AD 值显示正确
- [ ] 电压值显示正确
- [ ] 颜色编码正确（蓝<5V，绿5-10V，橙10-15V，红>15V）
- [ ] 统计信息正确（最小值、最大值、平均值）

### 7.4 自动管理功能

- [ ] 自动连接前4个模块
- [ ] 自动重连（5秒间隔）
- [ ] 开关量轮询（100ms）
- [ ] 模拟量轮询（500ms）
- [ ] 健康监控（数据超时检测）
- [ ] 手动重连按钮工作

### 7.5 界面切换

- [ ] 选择模块1 → 显示开关量输入1
- [ ] 选择模块2 → 显示开关量输入2
- [ ] 选择模块3 → 显示模拟量输入1
- [ ] 选择模块4 → 显示模拟量输入2
- [ ] 选择模块5 → 显示 CS1 占位界面
- [ ] 选择模块6 → 显示 CS2 占位界面
- [ ] 选择模块7 → 显示语音模块占位界面
- [ ] 选择模块8 → 显示预留模块占位界面

---

**文档版本**: v1.0
**最后更新**: 2026-02-09
