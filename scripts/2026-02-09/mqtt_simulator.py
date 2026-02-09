#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MQTT 模块自动模拟器
自动模拟8个MQTT模块的行为，无需手动配置

日期: 2026-02-09
阶段: Phase 7.44
"""

import paho.mqtt.client as mqtt
import json
import time
import threading
import random
import math
import os
from datetime import datetime


# ========== 数据生成器 ==========

class DISimulatorRandom:
    """开关量模拟器 - 随机翻转模式"""

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


class DISimulatorPeriodic:
    """开关量模拟器 - 周期性变化模式"""

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

    def _bits_to_byte(self, bits):
        return sum(bit << i for i, bit in enumerate(bits))


class AISimulatorSine:
    """模拟量模拟器 - 正弦波模式"""

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


class AISimulatorSineNoise:
    """模拟量模拟器 - 正弦波+噪声模式"""

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


class CSSimulator:
    """CS模块模拟器 - 急停状态+通讯数据"""

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


class VoiceSimulator:
    """语音模块模拟器"""

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

    def generate_data(self):
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


class HeartbeatSimulator:
    """心跳模拟器"""

    def __init__(self, module_index):
        self.module_index = module_index
        self.start_time = time.time()

    def generate_data(self):
        """生成心跳数据"""
        uptime = int(time.time() - self.start_time)

        return {
            "module": self.module_index,
            "type": "heartbeat",
            "timestamp": int(time.time()),
            "data": {
                "uptime": uptime,
                "status": "online"
            },
            "quality": "good"
        }


# ========== 模拟模块 ==========

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
        self.client.on_disconnect = self._on_disconnect

        try:
            # 连接
            self.client.connect(broker["host"], broker["port"], 60)
            self.client.loop_start()
        except Exception as e:
            print(f"❌ [{self.config['name']}] 连接失败: {e}")

    def _on_connect(self, client, userdata, flags, rc):
        """连接成功回调"""
        if rc == 0:
            print(f"✅ [{self.config['name']}] 已连接到 Broker")

            # 订阅控制主题
            control_topic = self.config["topics"]["control"]
            client.subscribe(control_topic)
            print(f"✅ [{self.config['name']}] 订阅主题: {control_topic}")

            # 启动数据发布线程
            self.running = True
            threading.Thread(target=self._publish_loop, daemon=True).start()
        else:
            print(f"❌ [{self.config['name']}] 连接失败，返回码: {rc}")

    def _on_disconnect(self, client, userdata, rc):
        """断开连接回调"""
        if rc != 0:
            print(f"⚠️ [{self.config['name']}] 意外断开连接，返回码: {rc}")

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
        elif cmd_type == "voice" and isinstance(self.simulator, VoiceSimulator):
            # 语音命令
            data = self.simulator.handle_command(command)
            topic = self.config["topics"]["status"]
            payload = json.dumps(data)
            self.client.publish(topic, payload, qos=1)

    def _publish_loop(self):
        """周期性发布数据"""
        interval = self.config["polling"]["interval"] / 1000.0  # 转换为秒

        while self.running:
            self._publish_data()
            time.sleep(interval)

    def _publish_data(self):
        """发布模拟数据"""
        try:
            data = self.simulator.generate_data()
            topic = self.config["topics"]["status"]
            payload = json.dumps(data)

            self.client.publish(topic, payload, qos=1)

            # 简化日志输出，避免刷屏
            if random.random() < 0.1:  # 10%概率输出日志
                print(f"📤 [{self.config['name']}] 发布数据")
        except Exception as e:
            print(f"❌ [{self.config['name']}] 发布数据失败: {e}")

    def disconnect(self):
        """断开连接"""
        self.running = False
        if self.client:
            self.client.loop_stop()
            self.client.disconnect()


# ========== 模拟器管理器 ==========

class SimulatorManager:
    """模拟器管理器"""

    def __init__(self, config_file):
        self.config_file = config_file
        self.modules = []

    def load_config(self):
        """加载配置文件"""
        if not os.path.exists(self.config_file):
            print(f"❌ 配置文件不存在: {self.config_file}")
            print("请先运行启动脚本创建配置文件")
            return []

        with open(self.config_file, 'r', encoding='utf-8') as f:
            config = json.load(f)
        return config["modules"]

    def start(self):
        """启动所有模拟模块"""
        print("=" * 60)
        print("🚀 MQTT 模块模拟器")
        print("=" * 60)

        configs = self.load_config()
        if not configs:
            return

        for config in configs:
            if config.get("enabled", True):
                print(f"\n启动模块: {config['name']}")
                module = SimulatedModule(config)
                module.connect()
                self.modules.append(module)
                time.sleep(0.5)  # 避免同时连接

        print("\n" + "=" * 60)
        print(f"✅ 已启动 {len(self.modules)} 个模拟模块")
        print("=" * 60)

    def stop(self):
        """停止所有模拟模块"""
        print("\n🛑 停止模拟器...")
        for module in self.modules:
            module.disconnect()


def main():
    """主函数"""
    config_file = "config/mqtt_modules.json"

    manager = SimulatorManager(config_file)

    try:
        manager.start()

        if not manager.modules:
            print("❌ 没有启动任何模块")
            return

        print("\n✅ 模拟器运行中，按 Ctrl+C 停止...\n")

        # 保持运行
        while True:
            time.sleep(1)

    except KeyboardInterrupt:
        print("\n\n收到停止信号...")
        manager.stop()
        print("✅ 模拟器已停止")
    except Exception as e:
        print(f"\n❌ 发生错误: {e}")
        manager.stop()


if __name__ == "__main__":
    main()
