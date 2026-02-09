# 使用 MQTTX 可视化模拟 8 个 MQTT 模块

**日期**: 2026-02-09
**阶段**: Phase 7.44
**作者**: Claude

---

## 一、方案概述

使用 **MQTTX** 可视化工具模拟 8 个 MQTT 模块，无需编程，通过图形界面：
- ✅ 创建 8 个模块连接
- ✅ 可视化修改发送数据
- ✅ 自动周期性发送数据（脚本功能）
- ✅ 接收主机控制命令
- ✅ 验证主机 MQTT 功能

---

## 二、MQTTX 介绍

### 2.1 什么是 MQTTX

**MQTTX** 是 EMQ 官方出品的跨平台 MQTT 5.0 桌面客户端工具，提供：
- 🎨 优雅的图形界面
- 🔌 多连接管理
- 📝 消息发布/订阅
- 🤖 脚本自动化
- 💾 配置导入/导出

### 2.2 下载和安装

**官网**: https://mqttx.app/zh

**Windows 安装**:
1. 下载 MQTTX-Setup-x.x.x.exe
2. 双击安装
3. 启动 MQTTX

**或使用 Chocolatey**:
```powershell
choco install mqttx
```

---

## 三、配置 8 个模块连接

### 3.1 模块连接配置表

| 模块编号 | 模块名称 | Client ID | 订阅主题 | 发布主题 |
|---------|---------|-----------|---------|---------|
| 模块1 | 开关量输入1 | belt_control_di1 | belt_control/di/module1/control | belt_control/di/module1/status |
| 模块2 | 开关量输入2 | belt_control_di2 | belt_control/di/module2/control | belt_control/di/module2/status |
| 模块3 | 模拟量输入1 | belt_control_ai1 | belt_control/ai/module3/control | belt_control/ai/module3/status |
| 模块4 | 模拟量输入2 | belt_control_ai2 | belt_control/ai/module4/control | belt_control/ai/module4/status |
| 模块5 | CS1 | belt_control_cs1 | belt_control/cs/module5/control | belt_control/cs/module5/status |
| 模块6 | CS2 | belt_control_cs2 | belt_control/cs/module6/control | belt_control/cs/module6/status |
| 模块7 | 语音模块 | belt_control_voice | belt_control/voice/module7/control | belt_control/voice/module7/status |
| 模块8 | 预留模块 | belt_control_module8 | belt_control/module8/control | belt_control/module8/status |

### 3.2 创建连接步骤

#### 步骤 1：创建第一个连接（开关量输入1）

1. 点击左上角 **"+"** 按钮
2. 填写连接信息：
   - **Name**: 开关量输入1
   - **Client ID**: belt_control_di1
   - **Host**: mqtt://
   - **Host**: 192.168.10.142
   - **Port**: 1883
   - **Username**: (留空)
   - **Password**: (留空)
3. 点击右上角 **"Connect"** 连接

#### 步骤 2：订阅控制主题

1. 连接成功后，在底部 **"New Subscription"** 区域
2. **Topic**: belt_control/di/module1/control
3. **QoS**: 1
4. 点击 **"Subscribe"**

#### 步骤 3：发布状态数据

1. 在右侧消息发送区域
2. **Topic**: belt_control/di/module1/status
3. **Payload** (JSON格式):
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
4. **QoS**: 1
5. 点击 **"Send"** 发送

#### 步骤 4：重复创建其他 7 个连接

按照上述步骤，创建其他 7 个模块的连接。

---

## 四、使用脚本自动发送数据

### 4.1 开关量模块脚本（模块1）

MQTTX 支持 JavaScript 脚本自动发送数据。

#### 创建脚本步骤：

1. 点击右侧消息发送区域的 **"脚本"** 图标
2. 选择 **"新建脚本"**
3. **脚本名称**: DI_Module1_Auto
4. **脚本内容**:

```javascript
/**
 * 开关量输入1 - 自动发送脚本
 * 每100ms发送一次，随机翻转位
 */

// 初始化8位开关量状态
let bits = [0, 0, 0, 0, 0, 0, 0, 0];

function generator(faker, options) {
  // 10%概率随机翻转一位
  if (Math.random() < 0.1) {
    const bitIndex = Math.floor(Math.random() * 8);
    bits[bitIndex] = 1 - bits[bitIndex];
  }

  // 计算字节值
  const byteValue = bits.reduce((sum, bit, i) => sum + (bit << i), 0);

  // 生成消息
  return JSON.stringify({
    module: 1,
    type: "di",
    timestamp: Math.floor(Date.now() / 1000),
    data: {
      bits: bits,
      byte: byteValue
    },
    quality: "good"
  });
}

// 导出
module.exports = {
  name: 'DI_Module1_Auto',
  generator,
};
```

5. **发送间隔**: 100ms
6. 点击 **"保存"**
7. 启用脚本，点击 **"开始"**

### 4.2 模拟量模块脚本（模块3）

```javascript
/**
 * 模拟量输入1 - 自动发送脚本
 * 每500ms发送一次，正弦波数据
 */

let timeOffset = 0;
const frequency = 0.1; // 0.1Hz

function generator(faker, options) {
  timeOffset += 0.5; // 每次增加0.5秒

  const channels = [];
  for (let ch = 0; ch < 8; ch++) {
    // 每个通道相位不同
    const phase = ch * Math.PI / 4;

    // 正弦波：幅值32768，偏移32768
    let value = Math.floor(
      32768 + 32768 * Math.sin(2 * Math.PI * frequency * timeOffset + phase)
    );

    // 限制范围 0-65535
    value = Math.max(0, Math.min(65535, value));

    // 转换为电压（0-20V）
    const voltage = (value * 20.0 / 65535).toFixed(2);

    channels.push({
      ch: ch,
      value: value,
      voltage: parseFloat(voltage)
    });
  }

  return JSON.stringify({
    module: 3,
    type: "ai",
    timestamp: Math.floor(Date.now() / 1000),
    data: {
      channels: channels
    },
    quality: "good"
  });
}

module.exports = {
  name: 'AI_Module3_Auto',
  generator,
};
```

### 4.3 CS模块脚本（模块5）

```javascript
/**
 * CS1 - 自动发送脚本
 * 每1000ms发送一次，随机触发急停
 */

let emergencyStop = false;

function generator(faker, options) {
  // 5%概率触发/解除急停
  if (Math.random() < 0.05) {
    emergencyStop = !emergencyStop;
  }

  return JSON.stringify({
    module: 5,
    type: "cs",
    timestamp: Math.floor(Date.now() / 1000),
    data: {
      emergency_stop: emergencyStop,
      stop_positions: [
        { id: 1, status: emergencyStop },
        { id: 2, status: false },
        { id: 3, status: false }
      ],
      comm_status: "online",
      signal_strength: Math.floor(Math.random() * 30) + 70
    },
    quality: "good"
  });
}

module.exports = {
  name: 'CS_Module5_Auto',
  generator,
};
```

---

## 五、手动修改参数测试

### 5.1 修改开关量状态

在 MQTTX 消息发送区域，直接修改 JSON 数据：

```json
{
  "module": 1,
  "type": "di",
  "timestamp": 1707456789,
  "data": {
    "bits": [1, 1, 1, 1, 0, 0, 0, 0],  // 修改这里
    "byte": 15
  },
  "quality": "good"
}
```

点击 **"Send"** 立即发送。

### 5.2 修改模拟量数值

```json
{
  "module": 3,
  "type": "ai",
  "timestamp": 1707456789,
  "data": {
    "channels": [
      {"ch": 0, "value": 10000, "voltage": 3.05},  // 修改这里
      {"ch": 1, "value": 20000, "voltage": 6.10},
      // ... 其他通道
    ]
  },
  "quality": "good"
}
```

### 5.3 触发急停测试

```json
{
  "module": 5,
  "type": "cs",
  "timestamp": 1707456789,
  "data": {
    "emergency_stop": true,  // 修改为 true 触发急停
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

## 六、验证主机 MQTT 功能

### 6.1 测试主机订阅功能

**步骤**：
1. 在主机应用中订阅模块状态主题
2. 在 MQTTX 中发送状态数据
3. 检查主机是否收到数据

**预期结果**：
- 主机应用显示收到的数据
- 数据解析正确
- UI 更新正确

### 6.2 测试主机发布功能

**步骤**：
1. 在 MQTTX 中订阅控制主题（已完成）
2. 在主机应用中发送控制命令
3. 在 MQTTX 中查看收到的命令

**预期结果**：
- MQTTX 收到控制命令
- 命令格式正确
- 主题正确

### 6.3 测试数据解析

**测试用例**：

| 测试项 | 发送数据 | 预期结果 |
|-------|---------|---------|
| 开关量全0 | bits: [0,0,0,0,0,0,0,0] | 主机显示全部关闭 |
| 开关量全1 | bits: [1,1,1,1,1,1,1,1] | 主机显示全部开启 |
| 模拟量最小值 | value: 0 | 主机显示 0V |
| 模拟量最大值 | value: 65535 | 主机显示 20V |
| 急停触发 | emergency_stop: true | 主机显示急停告警 |

---

## 七、MQTTX 配置导入/导出

### 7.1 导出配置

1. 点击左上角 **"设置"** 图标
2. 选择 **"导出数据"**
3. 选择导出路径
4. 保存为 `mqttx_8modules_config.json`

### 7.2 导入配置

1. 点击左上角 **"设置"** 图标
2. 选择 **"导入数据"**
3. 选择配置文件
4. 所有连接自动创建

### 7.3 配置文件模板

我已经为您准备了一个配置文件模板，包含 8 个模块的完整配置。

**文件位置**: `config/mqttx_8modules_config.json`

---

## 八、备选方案：MQTT Explorer

如果您更喜欢树形结构的可视化工具，可以使用 **MQTT Explorer**。

### 8.1 下载地址

- 官网：https://mqtt-explorer.com/
- GitHub：https://github.com/thomasnordquist/MQTT-Explorer

### 8.2 优势

- 📊 树形主题结构，一目了然
- 📈 数据可视化图表
- 🔍 强大的搜索功能
- 💾 历史数据记录

### 8.3 劣势

- ❌ 不支持多连接（只能连接一个 Broker）
- ❌ 不支持脚本自动发送
- ❌ 需要手动发送每条消息

**适用场景**：查看和调试 MQTT 主题结构，不适合模拟多个模块。

---

## 九、使用建议

### 9.1 推荐工作流程

1. **开发阶段**：使用 MQTTX 模拟 8 个模块
   - 创建 8 个连接
   - 使用脚本自动发送数据
   - 手动修改参数测试边界情况

2. **调试阶段**：使用 MQTT Explorer 查看主题树
   - 查看所有主题和消息
   - 验证主题命名是否正确
   - 检查消息格式

3. **测试阶段**：结合使用
   - MQTTX 模拟模块
   - MQTT Explorer 监控消息
   - 主机应用运行测试

### 9.2 常见问题

**Q1: MQTTX 连接失败？**
- 检查 EMQX 是否运行：`docker ps | grep emqx`
- 检查 IP 地址是否正确：192.168.10.142
- 检查端口是否正确：1883

**Q2: 脚本不工作？**
- 检查脚本语法是否正确
- 检查发送间隔是否设置
- 查看 MQTTX 控制台错误信息

**Q3: 主机收不到数据？**
- 检查主机是否订阅了正确的主题
- 检查 QoS 设置是否匹配
- 使用 MQTT Explorer 验证消息是否发送成功

---

## 十、总结

使用 **MQTTX** 可视化工具模拟 8 个 MQTT 模块，具有以下优势：

✅ **零编程** - 图形界面操作，无需编写代码
✅ **实时调试** - 立即看到发送和接收的消息
✅ **参数可调** - 随时修改数据测试不同场景
✅ **自动化** - 脚本功能支持周期性自动发送
✅ **配置复用** - 导出配置文件，团队共享

**下一步行动**：
1. 下载安装 MQTTX
2. 创建 8 个模块连接
3. 配置脚本自动发送数据
4. 启动主机应用测试 MQTT 功能
5. 验证数据收发正确性

---

**文档版本**: v1.0
**最后更新**: 2026-02-09
