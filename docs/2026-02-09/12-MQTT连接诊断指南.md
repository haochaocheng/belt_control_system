# MQTT 连接诊断指南

**日期**: 2026-02-09
**阶段**: Phase 7.44.17
**类型**: 诊断指南

---

## 问题描述

MQTTX 已经正确发送数据到 `belt_control/di/module1/status`，但设备上没有收到数据。

---

## 诊断步骤

### 步骤 1：检查设备日志

在设备的控制台输出中，查找以下关键信息：

#### 1.1 MQTT 初始化

```
✅ [MQTTController] 初始化 MQTT 控制器
✅ [MQTTController] 初始化 8 个模块配置完成
✅ [MQTTAutoManager] 自动管理器已启动
```

#### 1.2 连接状态

```
🔌 [MQTTAutoManager] 连接所有模块（前4个）
🔌 [MQTTAutoManager] 连接模块: 0
✅ [MQTTController] 连接模块: 0
✅ [MQTTController] 创建客户端: 0
```

**如果看到**：
```
⚠️ [MQTTController] "模块1: 传输层无效"
```

**说明**：无法连接到 Broker（192.168.10.142:1883）

**原因**：
1. EMQX 没有运行
2. 防火墙阻止了连接
3. 网络不通

#### 1.3 订阅状态

```
✅ [MQTTAutoManager] 模块 0 订阅主题: belt_control/di/module1/status
```

**如果没有看到这条消息**，说明订阅失败。

#### 1.4 数据接收

```
📩 [MQTTAutoManager] 模块 0 收到数据 - 主题: belt_control/di/module1/status
✅ [DIDataManager] 模块 0 数据更新: byte=178
```

**如果没有看到这条消息**，说明没有收到数据。

---

### 步骤 2：检查 EMQX 连接

#### 2.1 访问 EMQX Dashboard

1. 打开浏览器，访问 http://localhost:18083
2. 登录（admin/public）
3. 点击"连接"菜单

#### 2.2 查看连接列表

您应该看到以下连接：

| Client ID | IP 地址 | 状态 |
|-----------|---------|------|
| belt_control_module_1 | 192.168.10.188 | 已连接 |
| belt_control_module_2 | 192.168.10.188 | 已连接 |
| belt_control_module_3 | 192.168.10.188 | 已连接 |
| belt_control_module_4 | 192.168.10.188 | 已连接 |
| belt_control_di1 | 127.0.0.1 | 已连接 |
| belt_control_di2 | 127.0.0.1 | 已连接 |

**如果没有看到 belt_control_module_1**，说明设备没有连接到 EMQX。

#### 2.3 查看订阅列表

点击"订阅"菜单，您应该看到：

| Client ID | 主题 | QoS |
|-----------|------|-----|
| belt_control_module_1 | belt_control/di/module1/status | 1 |
| belt_control_module_2 | belt_control/di/module2/status | 1 |
| belt_control_di1 | belt_control/di/module1/control | 0 |
| belt_control_di2 | belt_control/di/module2/control | 0 |

**如果没有看到 belt_control_module_1 的订阅**，说明订阅失败。

---

### 步骤 3：网络连通性测试

#### 3.1 从设备 ping 开发电脑

在设备上运行：

```bash
ping 192.168.10.142
```

**预期结果**：
```
PING 192.168.10.142 (192.168.10.142) 56(84) bytes of data.
64 bytes from 192.168.10.142: icmp_seq=1 ttl=64 time=0.5 ms
64 bytes from 192.168.10.142: icmp_seq=2 ttl=64 time=0.4 ms
```

**如果 ping 不通**，说明网络有问题。

#### 3.2 从设备测试 EMQX 端口

在设备上运行：

```bash
telnet 192.168.10.142 1883
```

或者：

```bash
nc -zv 192.168.10.142 1883
```

**预期结果**：
```
Connection to 192.168.10.142 1883 port [tcp/*] succeeded!
```

**如果连接失败**，说明：
1. EMQX 没有运行
2. 防火墙阻止了 1883 端口

---

### 步骤 4：检查防火墙

#### 4.1 Windows 防火墙（开发电脑）

在开发电脑上运行：

```powershell
# 检查 1883 端口是否开放
netstat -ano | findstr 1883

# 添加防火墙规则（如果需要）
New-NetFirewallRule -DisplayName "EMQX MQTT" -Direction Inbound -Protocol TCP -LocalPort 1883 -Action Allow
```

#### 4.2 Docker 端口映射

检查 EMQX 容器的端口映射：

```powershell
docker ps | findstr emqx
```

**预期结果**：
```
CONTAINER ID   IMAGE          PORTS
abc123def456   emqx/emqx      0.0.0.0:1883->1883/tcp, ...
```

**如果没有看到 1883 端口映射**，重新启动 EMQX：

```powershell
docker stop emqx
docker rm emqx
docker run -d --name emqx -p 1883:1883 -p 8083:8083 -p 8084:8084 -p 8883:8883 -p 18083:18083 emqx/emqx:latest
```

---

### 步骤 5：临时解决方案

如果网络连接有问题，可以临时修改 Broker 地址：

#### 5.1 在设备上修改配置

1. 打开设备上的主机应用
2. 进入"设备信息" → "MQTT"
3. 选择"模块1"
4. 切换到"连接配置"Tab
5. 修改"Broker 地址"为开发电脑的实际 IP
6. 点击"保存"
7. 点击"重新连接"

#### 5.2 检查开发电脑的 IP 地址

在开发电脑上运行：

```powershell
ipconfig | findstr IPv4
```

确认 IP 地址是 192.168.10.142。

---

### 步骤 6：使用 MQTTX 测试设备连接

#### 6.1 创建测试客户端

在 MQTTX 中创建一个新的连接：

- Name: `test_device`
- Client ID: `test_device`
- Host: `192.168.10.142`（从设备的角度）
- Port: `1883`

#### 6.2 订阅主题

订阅：`belt_control/di/module1/control`

#### 6.3 发布测试消息

发布到：`belt_control/di/module1/status`

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

**如果这个测试客户端可以连接**，说明网络是通的，问题在设备应用。

**如果这个测试客户端也无法连接**，说明网络或 EMQX 有问题。

---

## 常见问题和解决方案

### 问题 1：设备无法连接到 EMQX

**症状**：
```
⚠️ [MQTTController] "模块1: 传输层无效"
```

**原因**：
1. EMQX 没有运行
2. 防火墙阻止
3. IP 地址错误
4. 网络不通

**解决**：
1. 确认 EMQX 运行：`docker ps | findstr emqx`
2. 检查防火墙规则
3. 确认 IP 地址：`ipconfig`
4. 测试网络连通性：`ping 192.168.10.142`

### 问题 2：订阅失败

**症状**：没有看到"订阅主题"的日志

**原因**：
1. 连接建立太慢，500ms 延迟不够
2. 连接后立即断开

**解决**：
1. 增加订阅延迟到 1000ms
2. 检查 EMQX 日志

### 问题 3：数据格式错误

**症状**：
```
⚠️ [DIDataManager] JSON解析错误
```

**原因**：JSON 格式不正确

**解决**：
1. 使用 JSON 验证工具检查格式
2. 确认字段名称正确（`module_id`，不是 `module`）
3. 确认 `bits` 使用布尔值（`true`/`false`，不是 `1`/`0`）

### 问题 4：主题不匹配

**症状**：MQTTX 发送了数据，但设备没有收到

**原因**：发布主题和订阅主题不匹配

**解决**：
1. 确认 MQTTX 发布到：`belt_control/di/module1/status`
2. 确认设备订阅了：`belt_control/di/module1/status`
3. 在 EMQX Dashboard 中查看订阅列表

---

## 调试清单

- [ ] EMQX 正在运行（`docker ps | findstr emqx`）
- [ ] 设备可以 ping 通开发电脑（`ping 192.168.10.142`）
- [ ] 1883 端口可以连接（`telnet 192.168.10.142 1883`）
- [ ] 防火墙允许 1883 端口
- [ ] 设备日志显示"连接模块"
- [ ] 设备日志显示"订阅主题"
- [ ] EMQX Dashboard 显示设备已连接
- [ ] EMQX Dashboard 显示设备已订阅
- [ ] MQTTX 发布主题正确（`belt_control/di/module1/status`）
- [ ] 数据格式正确（`module_id`，布尔值）

---

## 下一步

如果以上步骤都检查过了，还是无法接收数据，请提供：

1. 设备的完整日志（从启动到发送数据）
2. EMQX Dashboard 的连接列表截图
3. EMQX Dashboard 的订阅列表截图
4. MQTTX 的发送记录截图

这样我可以更准确地诊断问题。

---

**文档版本**: v1.0
**最后更新**: 2026-02-09
