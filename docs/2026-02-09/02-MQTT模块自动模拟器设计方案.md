# MQTT 模块自动模拟器设计方案

**日期**: 2026-02-09
**阶段**: Phase 7.44
**作者**: Claude

---

## 一、方案概述

### 1.1 设计目标

在硬件模块未完成生产之前，提供一个**全自动化的MQTT模块模拟器**，用于：
- ✅ 模拟8个MQTT模块的行为
- ✅ 自动连接到MQTT Broker
- ✅ 自动生成合理的模拟数据
- ✅ 响应控制命令
- ✅ 一键启动，无需手动配置

### 1.2 技术选型

**实现语言**: Python 3.x
- 优势：跨平台、易于开发、丰富的MQTT库
- 库：`paho-mqtt`（MQTT客户端）、`json`（配置解析）

**部署方式**: 单个Python脚本 + PowerShell启动脚本
- 自动读取配置文件
- 自动启动8个模拟客户端（多线程）
- 自动生成模拟数据

---

## 二、模拟器架构

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                  MQTT Module Simulator                      │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  配置加载器（ConfigLoader）                           │  │
│  │  - 读取 mqtt_modules.json                            │  │
│  │  - 解析模块配置                                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                           ↓                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  模拟器管理器（SimulatorManager）                     │  │
│  │  - 创建8个模拟客户端                                  │  │
│  │  - 管理客户端生命周期                                 │  │
│  └──────────────────────────────────────────────────────┘  │
│                           ↓                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  模拟客户端（SimulatedModule）× 8                    │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  开关量模拟器（DISimulator）× 2                │  │  │
│  │  │  - 随机变化 + 周期性变化                       │  │  │
│  │  │  - 响应读取命令                                │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  模拟量模拟器（AISimulator）× 2                │  │  │
│  │  │  - 正弦波 + 随机噪声                           │  │  │
│  │  │  - 响应读取命令                                │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  CS模拟器（CSSimulator）× 2                    │  │  │
│  │  │  - 急停状态模拟                                │  │  │
│  │  │  - 通讯数据模拟                                │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  语音模拟器（VoiceSimulator）× 1               │  │  │
│  │  │  - 播报命令响应                                │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
│                           ↓                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  MQTT Broker（EMQX）                                  │  │
│  │  - 192.168.10.142:1883                               │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 模块类型和数据生成策略

| 模块编号 | 模块类型 | 数据生成策略 | 更新频率 |
|---------|---------|-------------|---------|
| 模块1 | 开关量输入1 | 随机翻转（10%概率） | 100ms |
| 模块2 | 开关量输入2 | 周期性变化（方波） | 100ms |
| 模块3 | 模拟量输入1 | 正弦波（频率0.1Hz） | 500ms |
| 模块4 | 模拟量输入2 | 正弦波+随机噪声 | 500ms |
| 模块5 | CS1 | 急停状态（随机触发） | 1000ms |
| 模块6 | CS2 | 急停状态（随机触发） | 1000ms |
| 模块7 | 语音模块 | 命令响应 | 按需 |
| 模块8 | 预留 | 心跳 | 5000ms |

---

## 三、数据生成算法

### 3.1 开关量模拟器（DISimulator）

#### 3.1.1 模块1：随机翻转模式

```python
class DISimulatorRandom:
    def __init__(self):
        self.bits = [0] * 8  # 初始全为0
        self.flip_probability = 0.1  # 10%概率翻转

    def generate_data(self):
        """生成随机变化的开关量数据"""
        for i in range(8):
            if random.random() < self.flip_probability:
                self.bits[i] = 1 - self.bits[i]  # 翻转

        return {
            "module": 1,
            "type": "di",
            "timestamp": int(time.time()),
            "data": {
                "bits": self.bits,
                "byte": self._bits_to_byte(self.bits)
            },
            "quality": "good"
        }

    def _bits_to_byte(self, bits):
        """将8位转换为字节"""
        return sum(bit << i for i, bit in enumerate(bits))
```

#### 3.1.2 模块2：周期性变化模式

```python
class DISimulatorPeriodic:
    def __init__(self):
        self.counter = 0
        self.period = 20  # 20次更新为一个周期（2秒）

    def generate_data(self):
        """生成周期性变化的开关量数据"""
        self.counter += 1

        # 方波模式：前半周期全1，后半周期全0
        if self.counter % self.period < self.period // 2:
            bits = [1] * 8
        else:
            bits = [0] * 8

        return {
            "module": 2,
            "type": "di",
            "timestamp": int(time.time()),
            "data": {
                "bits": bits,
                "byte": self._bits_to_byte(bits)
            },
            "quality": "good"
        }
```

### 3.2 模拟量模拟器（AISimulator）

#### 3.2.1 模块3：正弦波模式

```python
class AISimulatorSine:
    def __init__(self, module_index):
        self.module_index = module_index
        self.time_offset = 0
        self.frequency = 0.1  # 0.1Hz（10秒一个周期）

    def generate_data(self):
        """生成正弦波模拟量数据"""
        self.time_offset += 0.5  # 每次增加0.5秒

        channels = []
        for ch in range(8):
            # 每个通道相位不同
            phase = ch * math.pi / 4

            # 正弦波：幅值32768（半量程），偏移32768（中心）
            value = int(32768 + 32768 * math.sin(
                2 * math.pi * self.frequency * self.time_offset + phase
            ))

            # 限制范围 0-65535
            value = max(0, min(65535, value))

            # 转换为电压（假设0-20V）
            voltage = value * 20.0 / 65535

            channels.append({
                "ch": ch,
                "value": value,
                "voltage": round(voltage, 2)
            })

        return {
            "module": self.module_index,
            "type": "ai",
            "timestamp": int(time.time()),
            "data": {
                "channels": channels
            },
            "quality": "good"
        }
```

#### 3.2.2 模块4：正弦波+噪声模式

```python
class AISimulatorSineNoise:
    def __init__(self, module_index):
        self.module_index = module_index
        self.time_offset = 0
        self.frequency = 0.1
        self.noise_amplitude = 1000  # 噪声幅度

    def generate_data(self):
        """生成正弦波+噪声模拟量数据"""
        self.time_offset += 0.5

        channels = []
        for ch in range(8):
            phase = ch * math.pi / 4

            # 正弦波
            sine_value = 32768 + 32768 * math.sin(
                2 * math.pi * self.frequency * self.time_offset + phase
            )

            # 添加随机噪声
            noise = random.uniform(-self.noise_amplitude, self.noise_amplitude)
            value = int(sine_value + noise)

            # 限制范围
            value = max(0, min(65535, value))
            voltage = value * 20.0 / 65535

            channels.append({
                "ch": ch,
                "value": value,
                "voltage": round(voltage, 2)
            })

        return {
            "module": self.module_index,
            "type": "ai",
            "timestamp": int(time.time()),
            "data": {
                "channels": channels
            },
            "quality": "good"
        }
```

### 3.3 CS模拟器（CSSimulator）

```python
class CSSimulator:
    def __init__(self, module_index):
        self.module_index = module_index
        self.emergency_stop = False
        self.trigger_probability = 0.05  # 5%概率触发急停

    def generate_data(self):
        """生成CS模块数据（急停状态+通讯数据）"""
        # 随机触发/解除急停
        if random.random() < self.trigger_probability:
            self.emergency_stop = not self.emergency_stop

        return {
            "module": self.module_index,
            "type": "cs",
            "timestamp": int(time.time()),
            "data": {
                "emergency_stop": self.emergency_stop,
                "stop_positions": [
                    {"id": 1, "status": self.emergency_stop},
                    {"id": 2, "status": False},
                    {"id": 3, "status": False}
                ],
                "comm_status": "online",
                "signal_strength": random.randint(70, 100)
            },
            "quality": "good"
        }
```

### 3.4 语音模拟器（VoiceSimulator）

```python
class VoiceSimulator:
    def __init__(self):
        self.last_command = None

    def handle_command(self, command):
        """处理语音播报命令"""
        self.last_command = command

        return {
            "module": 7,
            "type": "voice",
            "timestamp": int(time.time()),
            "data": {
                "command": command.get("text", ""),
                "status": "playing",
                "duration": command.get("duration", 3)
            },
            "quality": "good"
        }

    def generate_status(self):
        """生成语音模块状态"""
        return {
            "module": 7,
            "type": "voice",
            "timestamp": int(time.time()),
            "data": {
                "status": "idle",
                "last_command": self.last_command
            },
            "quality": "good"
        }
```

---

## 四、模拟器实现

### 4.1 核心代码结构

**文件**: `scripts/2026-02-09/mqtt_simulator.py`

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MQTT 模块自动模拟器
自动模拟8个MQTT模块的行为，无需手动配置
"""

import paho.mqtt.client as mqtt
import json
import time
import threading
import random
import math
from datetime import datetime

class SimulatedModule:
    """模拟MQTT模块"""

    def __init__(self, config):
        self.config = config
        self.client = None
        self.running = False
        self.simulator = self._create_simulator()

    def _create_simulator(self):
        """根据模块类型创建对应的模拟器"""
        module_type = self.config.get("type")
        index = self.config.get("index")

        if module_type == "di":
            if index == 0:
                return DISimulatorRandom()
            else:
                return DISimulatorPeriodic()
        elif module_type == "ai":
            if index == 2:
                return AISimulatorSine(index + 1)
            else:
                return AISimulatorSineNoise(index + 1)
        elif module_type == "cs":
            return CSSimulator(index + 1)
        elif module_type == "voice":
            return VoiceSimulator()
        else:
            return HeartbeatSimulator(index + 1)

    def connect(self):
        """连接到MQTT Broker"""
        broker = self.config["broker"]
        self.client = mqtt.Client(broker["clientId"])

        # 设置回调
        self.client.on_connect = self._on_connect
        self.client.on_message = self._on_message

        # 连接
        self.client.connect(broker["host"], broker["port"], 60)
        self.client.loop_start()

    def _on_connect(self, client, userdata, flags, rc):
        """连接成功回调"""
        print(f"✅ [{self.config['name']}] 已连接到 Broker")

        # 订阅控制主题
        control_topic = self.config["topics"]["control"]
        client.subscribe(control_topic)
        print(f"✅ [{self.config['name']}] 订阅主题: {control_topic}")

        # 启动数据发布线程
        self.running = True
        threading.Thread(target=self._publish_loop, daemon=True).start()

    def _on_message(self, client, userdata, msg):
        """接收消息回调"""
        print(f"📩 [{self.config['name']}] 收到命令: {msg.topic}")

        try:
            command = json.loads(msg.payload.decode())
            self._handle_command(command)
        except Exception as e:
            print(f"❌ [{self.config['name']}] 解析命令失败: {e}")

    def _handle_command(self, command):
        """处理控制命令"""
        cmd_type = command.get("cmd")

        if cmd_type == "read":
            # 立即发布一次数据
            self._publish_data()

    def _publish_loop(self):
        """周期性发布数据"""
        interval = self.config["polling"]["interval"] / 1000.0  # 转换为秒

        while self.running:
            self._publish_data()
            time.sleep(interval)

    def _publish_data(self):
        """发布模拟数据"""
        data = self.simulator.generate_data()
        topic = self.config["topics"]["status"]
        payload = json.dumps(data)

        self.client.publish(topic, payload, qos=1)
        print(f"📤 [{self.config['name']}] 发布数据到: {topic}")

    def disconnect(self):
        """断开连接"""
        self.running = False
        if self.client:
            self.client.loop_stop()
            self.client.disconnect()

# ... (数据生成器类的实现见上文)

class SimulatorManager:
    """模拟器管理器"""

    def __init__(self, config_file):
        self.config_file = config_file
        self.modules = []

    def load_config(self):
        """加载配置文件"""
        with open(self.config_file, 'r', encoding='utf-8') as f:
            config = json.load(f)
        return config["modules"]

    def start(self):
        """启动所有模拟模块"""
        print("🚀 启动 MQTT 模块模拟器...")

        configs = self.load_config()

        for config in configs:
            if config.get("enabled", True):
                module = SimulatedModule(config)
                module.connect()
                self.modules.append(module)
                time.sleep(0.5)  # 避免同时连接

        print(f"✅ 已启动 {len(self.modules)} 个模拟模块")

    def stop(self):
        """停止所有模拟模块"""
        print("🛑 停止模拟器...")
        for module in self.modules:
            module.disconnect()

def main():
    """主函数"""
    config_file = "config/mqtt_modules.json"

    manager = SimulatorManager(config_file)

    try:
        manager.start()

        print("\n✅ 模拟器运行中，按 Ctrl+C 停止...\n")

        # 保持运行
        while True:
            time.sleep(1)

    except KeyboardInterrupt:
        print("\n\n收到停止信号...")
        manager.stop()
        print("✅ 模拟器已停止")

if __name__ == "__main__":
    main()
```

### 4.2 PowerShell 启动脚本

**文件**: `scripts/2026-02-09/01-start-mqtt-simulator.ps1`

```powershell
# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "🚀 启动 MQTT 模块模拟器" -ForegroundColor Green

# 检查 Python 是否安装
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    Write-Host "❌ 未找到 Python，请先安装 Python 3.x" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Python 版本: $((python --version))" -ForegroundColor Green

# 检查 paho-mqtt 是否安装
$pahoInstalled = python -c "import paho.mqtt.client" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "📦 安装 paho-mqtt 库..." -ForegroundColor Yellow
    pip install paho-mqtt
}

# 检查配置文件是否存在
$configFile = "config/mqtt_modules.json"
if (-not (Test-Path $configFile)) {
    Write-Host "❌ 配置文件不存在: $configFile" -ForegroundColor Red
    Write-Host "正在创建默认配置文件..." -ForegroundColor Yellow

    # 创建配置目录
    New-Item -ItemType Directory -Force -Path "config" | Out-Null

    # 复制默认配置（从设计方案中的配置）
    # ... (配置文件内容)
}

# 启动模拟器
Write-Host "`n🎯 启动模拟器..." -ForegroundColor Cyan
python scripts/2026-02-09/mqtt_simulator.py
```

---

## 五、使用方法

### 5.1 一键启动

```powershell
# 在项目根目录执行
.\scripts\2026-02-09\01-start-mqtt-simulator.ps1
```

### 5.2 预期输出

```
🚀 启动 MQTT 模块模拟器
✅ Python 版本: Python 3.11.0
✅ paho-mqtt 已安装

🎯 启动模拟器...
✅ [开关量输入1] 已连接到 Broker
✅ [开关量输入1] 订阅主题: belt_control/di/module1/control
📤 [开关量输入1] 发布数据到: belt_control/di/module1/status
✅ [开关量输入2] 已连接到 Broker
✅ [开关量输入2] 订阅主题: belt_control/di/module2/control
📤 [开关量输入2] 发布数据到: belt_control/di/module2/status
...
✅ 已启动 8 个模拟模块

✅ 模拟器运行中，按 Ctrl+C 停止...
```

### 5.3 在EMQX Web界面查看

1. 打开 http://localhost:18083
2. 进入 **Clients** 页面，应该看到8个客户端连接
3. 进入 **WebSocket** 工具，订阅主题查看数据

---

## 六、测试验证

### 6.1 连接测试

```bash
# 查看EMQX客户端列表
# 应该看到8个客户端：
# - belt_control_di1
# - belt_control_di2
# - belt_control_ai1
# - belt_control_ai2
# - belt_control_cs1
# - belt_control_cs2
# - belt_control_voice
# - belt_control_module8
```

### 6.2 数据测试

在EMQX WebSocket工具中订阅：
```
belt_control/di/module1/status
belt_control/ai/module3/status
```

应该看到周期性的数据更新。

### 6.3 命令测试

在EMQX WebSocket工具中发布：
```json
主题: belt_control/di/module1/control
消息: {"cmd": "read", "timestamp": 1707456789}
```

应该立即收到一条状态数据。

---

## 七、优势和特点

✅ **零配置启动**：一键启动，自动读取配置
✅ **真实模拟**：数据生成算法模拟真实硬件行为
✅ **多样化数据**：随机、周期、正弦波、噪声等多种模式
✅ **命令响应**：支持读取命令，模拟真实交互
✅ **易于调试**：清晰的日志输出，便于问题定位
✅ **可扩展**：易于添加新的模块类型和数据模式

---

## 八、总结

本模拟器方案提供了一个完整的自动化测试环境，无需等待硬件模块生产即可开始MQTT通讯功能的开发和测试。

**下一步行动**：
1. 创建 `mqtt_simulator.py` 脚本
2. 创建 `01-start-mqtt-simulator.ps1` 启动脚本
3. 创建默认配置文件 `config/mqtt_modules.json`
4. 测试模拟器运行
5. 结合真实应用进行集成测试

---

**文档版本**: v1.0
**最后更新**: 2026-02-09
