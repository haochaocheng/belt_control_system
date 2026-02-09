# MQTTX 快速启动指南

**日期**: 2026-02-09

---

## 🚀 5分钟快速开始

### 步骤 1：下载安装 MQTTX

**Windows 用户**：
1. 访问：https://mqttx.app/zh
2. 点击 "下载" 按钮
3. 选择 Windows 版本下载
4. 双击安装包安装
5. 启动 MQTTX

### 步骤 2：确保 EMQX 运行

```powershell
# 检查 EMQX 是否运行
docker ps | grep emqx

# 如果没有运行，启动 EMQX
docker start emqx

# 如果没有安装，运行以下命令
docker run -d --name emqx -p 1883:1883 -p 8083:8083 -p 8084:8084 -p 8883:8883 -p 18083:18083 emqx/emqx:latest
```

### 步骤 3：创建第一个连接（开关量输入1）

1. 点击左上角 **"+"** 按钮
2. 填写连接信息：
   - **Name**: `开关量输入1`
   - **Client ID**: `belt_control_di1`
   - **Host**: `mqtt://`
   - **Host**: `192.168.10.142`
   - **Port**: `1883`
3. 点击右上角 **"Connect"** 连接

### 步骤 4：订阅控制主题

1. 连接成功后，在底部 **"New Subscription"** 区域
2. **Topic**: `belt_control/di/module1/control`
3. **QoS**: `1`
4. 点击 **"Subscribe"**

### 步骤 5：发布状态数据

1. 在右侧消息发送区域
2. **Topic**: `belt_control/di/module1/status`
3. **Payload**:
```json
{
  "module": 1,
  "type": "di",
  "timestamp": 1707456789,
  "data": {
    "bits": [1, 0, 1, 1, 0, 0, 1, 0],
    "byte": 178
  },
  "quality": "good"
}
```
4. **QoS**: `1`
5. 点击 **"Send"** 发送

### 步骤 6：创建自动发送脚本

1. 点击右侧消息发送区域的 **"脚本"** 图标（闪电图标）
2. 点击 **"新建脚本"**
3. **脚本名称**: `DI_Module1_Auto`
4. **脚本内容**:
```javascript
let bits = [0, 0, 0, 0, 0, 0, 0, 0];

function generator(faker, options) {
  if (Math.random() < 0.1) {
    const bitIndex = Math.floor(Math.random() * 8);
    bits[bitIndex] = 1 - bits[bitIndex];
  }
  const byteValue = bits.reduce((sum, bit, i) => sum + (bit << i), 0);
  return JSON.stringify({
    module: 1,
    type: 'di',
    timestamp: Math.floor(Date.now() / 1000),
    data: {
      bits: bits,
      byte: byteValue
    },
    quality: 'good'
  });
}

module.exports = { name: 'DI_Module1_Auto', generator };
```
5. **发送间隔**: `100` (毫秒)
6. 点击 **"保存"**
7. 启用脚本，点击 **"开始"**

---

## 📋 8个模块配置清单

按照上述步骤，依次创建以下 8 个连接：

| 序号 | 模块名称 | Client ID | 控制主题 | 状态主题 | 间隔 |
|-----|---------|-----------|---------|---------|------|
| 1 | 开关量输入1 | belt_control_di1 | belt_control/di/module1/control | belt_control/di/module1/status | 100ms |
| 2 | 开关量输入2 | belt_control_di2 | belt_control/di/module2/control | belt_control/di/module2/status | 100ms |
| 3 | 模拟量输入1 | belt_control_ai1 | belt_control/ai/module3/control | belt_control/ai/module3/status | 500ms |
| 4 | 模拟量输入2 | belt_control_ai2 | belt_control/ai/module4/control | belt_control/ai/module4/status | 500ms |
| 5 | CS1 | belt_control_cs1 | belt_control/cs/module5/control | belt_control/cs/module5/status | 1000ms |
| 6 | CS2 | belt_control_cs2 | belt_control/cs/module6/control | belt_control/cs/module6/status | 1000ms |
| 7 | 语音模块 | belt_control_voice | belt_control/voice/module7/control | belt_control/voice/module7/status | 5000ms |
| 8 | 预留模块 | belt_control_module8 | belt_control/module8/control | belt_control/module8/status | 5000ms |

---

## 🎯 测试验证

### 测试 1：手动发送数据

1. 在 MQTTX 中选择 "开关量输入1" 连接
2. 修改 Payload 中的 `bits` 数组
3. 点击 "Send" 发送
4. 在主机应用中查看是否收到数据

### 测试 2：自动发送数据

1. 启用脚本自动发送
2. 观察 MQTTX 中的发送日志
3. 在主机应用中查看数据是否持续更新

### 测试 3：接收控制命令

1. 在主机应用中发送控制命令
2. 在 MQTTX 的订阅区域查看收到的命令
3. 验证命令格式是否正确

---

## 💡 常用操作

### 修改开关量状态
```json
{
  "module": 1,
  "type": "di",
  "timestamp": 1707456789,
  "data": {
    "bits": [1, 1, 1, 1, 0, 0, 0, 0],  // 前4位开启，后4位关闭
    "byte": 15
  },
  "quality": "good"
}
```

### 修改模拟量数值
```json
{
  "module": 3,
  "type": "ai",
  "timestamp": 1707456789,
  "data": {
    "channels": [
      {"ch": 0, "value": 65535, "voltage": 20.0},  // 最大值
      {"ch": 1, "value": 0, "voltage": 0.0},       // 最小值
      {"ch": 2, "value": 32768, "voltage": 10.0}   // 中间值
    ]
  },
  "quality": "good"
}
```

### 触发急停
```json
{
  "module": 5,
  "type": "cs",
  "timestamp": 1707456789,
  "data": {
    "emergency_stop": true,  // 触发急停
    "stop_positions": [
      {"id": 1, "status": true},
      {"id": 2, "status": false},
      {"id": 3, "status": false}
    ],
    "comm_status": "online",
    "signal_strength": 85
  },
  "quality": "good"
}
```

---

## 🔧 故障排查

### 问题 1：连接失败

**症状**：MQTTX 显示 "连接失败"

**解决方法**：
1. 检查 EMQX 是否运行：`docker ps | grep emqx`
2. 检查 IP 地址是否正确：`192.168.10.142`
3. 检查端口是否正确：`1883`
4. 检查防火墙是否阻止连接

### 问题 2：主机收不到数据

**症状**：MQTTX 发送成功，但主机应用没有收到

**解决方法**：
1. 检查主机是否订阅了正确的主题
2. 检查主题名称是否完全匹配（区分大小写）
3. 检查 QoS 设置是否匹配
4. 使用 EMQX Web 界面（http://localhost:18083）查看消息是否到达 Broker

### 问题 3：脚本不工作

**症状**：启用脚本后没有自动发送数据

**解决方法**：
1. 检查脚本语法是否正确
2. 检查发送间隔是否设置
3. 查看 MQTTX 控制台是否有错误信息
4. 重启 MQTTX 重新加载脚本

---

## 📚 更多资源

- **完整文档**：[docs/2026-02-09/03-使用MQTTX可视化模拟8个模块.md](../docs/2026-02-09/03-使用MQTTX可视化模拟8个模块.md)
- **配置文件**：[config/mqttx_8modules_config.json](mqttx_8modules_config.json)
- **MQTTX 官网**：https://mqttx.app/zh
- **EMQX 文档**：https://www.emqx.io/docs/zh/latest/

---

## ✅ 完成检查清单

- [ ] 下载安装 MQTTX
- [ ] 启动 EMQX Broker
- [ ] 创建 8 个模块连接
- [ ] 配置订阅主题
- [ ] 测试手动发送数据
- [ ] 创建自动发送脚本
- [ ] 测试主机接收数据
- [ ] 测试主机发送控制命令
- [ ] 验证数据格式正确

---

**祝您测试顺利！** 🎉
