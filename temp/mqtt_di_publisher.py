#!/usr/bin/env python3
# /root/mqtt_di_publisher.py
# DI(开关量输入)模块 - MQTT发布器
# 创建日期: 2026-03-10
# 用于 Luckfox Lyra RK3506 设备
# 基于 154 设备 mqtt_io_publisher.py 拆分

import json
import time
import threading
import paho.mqtt.client as mqtt

# ===== 设备配置（部署时修改） =====
BROKER = '192.168.10.151'
PORT = 1883
DI_MODULE = 1          # 模块编号: 1 或 2
CLIENT_ID = 'luckfox-di-module-' + str(DI_MODULE)
DI_TOPIC = 'belt_control/di/module' + str(DI_MODULE) + '/status'

# GPIO 配置 - RK3506 GPIO0_A3~A7 + GPIO0_B0~B2 (编号 3~10)
# 2026-03-10: 避开 A0/A1/A2（内部上拉，上电默认高电平），统一使用下拉引脚（上电默认低���平，高电平触发）
# 旧配置: GPIO_PINS = [0, 1, 2, 3, 4, 5, 6, 7]  # GPIO0_A0~A7
GPIO_PINS = [3, 4, 5, 6, 7, 8, 9, 10]
# 2026-03-10: 改为1秒定时发送 + 变化立即发送
# 旧配置: DI_INTERVAL = 0.1  # 100ms 固定周期
DI_POLL_INTERVAL = 0.05  # 50ms 轮询检测变化
DI_HEARTBEAT = 1.0       # 1秒定时上报


class DIPublisher:
    def __init__(self):
        self.client = None
        self.connected = False
        self.running = True
        self.last_byte = -1  # 上次发送的值，-1表示首次
        self.last_send_time = 0
        self.init_gpio()

    def init_gpio(self):
        for pin in GPIO_PINS:
            try:
                with open('/sys/class/gpio/export', 'w') as f:
                    f.write(str(pin))
            except:
                pass
            try:
                with open('/sys/class/gpio/gpio' + str(pin) + '/direction', 'w') as f:
                    f.write('in')
            except:
                pass
        print('GPIO 初始化完成: ' + str(GPIO_PINS))

    def _create_client(self):
        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, CLIENT_ID)
        client.on_connect = self._on_connect
        client.on_disconnect = self._on_disconnect
        client.reconnect_delay_set(min_delay=1, max_delay=30)
        return client

    def _on_connect(self, client, userdata, flags, rc, properties=None):
        if rc == 0:
            self.connected = True
            print('[MQTT] 连接成功: ' + BROKER)
        else:
            self.connected = False
            print('[MQTT] 连接失败, rc=' + str(rc))

    def _on_disconnect(self, client, userdata, flags, rc, properties=None):
        self.connected = False
        print('[MQTT] 断开连接, rc=' + str(rc))

    def connect_mqtt(self):
        self.client = self._create_client()
        while self.running:
            try:
                self.client.connect(BROKER, PORT)
                break
            except Exception as e:
                print('[MQTT] 连接失败: ' + str(e) + ', 5秒后重试...')
                time.sleep(5)
        self._loop_thread = threading.Thread(target=self._mqtt_loop, daemon=True)
        self._loop_thread.start()

    def _mqtt_loop(self):
        while self.running:
            try:
                self.client.loop_forever(retry_first_connection=False)
            except AttributeError as e:
                # paho-mqtt 2.1.0 bug: ssl=None
                print('[MQTT] 捕获 paho-mqtt SSL bug: ' + str(e))
                self.connected = False
            except Exception as e:
                print('[MQTT] 网络循环异常: ' + str(e))
                self.connected = False
            if not self.running:
                break
            time.sleep(3)
            try:
                self.client.reconnect()
            except Exception:
                self.client = self._create_client()
                while self.running:
                    try:
                        self.client.connect(BROKER, PORT)
                        break
                    except:
                        time.sleep(5)

    def read_gpio(self):
        bits = []
        byte_val = 0
        for i, pin in enumerate(GPIO_PINS):
            try:
                with open('/sys/class/gpio/gpio' + str(pin) + '/value', 'r') as f:
                    val = int(f.read().strip())
            except:
                val = 0
            bits.append(val)
            byte_val |= (val << i)
        return bits, byte_val

    def publish_di(self):
        print('开关量采集启动, 模块: ' + str(DI_MODULE) + ', 轮询: ' + str(DI_POLL_INTERVAL) + 's, 心跳: ' + str(DI_HEARTBEAT) + 's')
        while self.running:
            if self.connected:
                bits, byte_val = self.read_gpio()
                now = time.time()
                changed = (byte_val != self.last_byte)
                heartbeat = (now - self.last_send_time >= DI_HEARTBEAT)

                if changed or heartbeat:
                    payload = {
                        'module': DI_MODULE,
                        'type': 'di',
                        'timestamp': int(now),
                        'data': {'bits': bits, 'byte': byte_val},
                        'quality': 'good',
                        'trigger': 'change' if changed else 'heartbeat'
                    }
                    try:
                        self.client.publish(DI_TOPIC, json.dumps(payload))
                        if changed:
                            print('[DI] 变化: ' + str(self.last_byte) + ' -> ' + str(byte_val) + ' bits=' + str(bits))
                    except Exception as e:
                        print('DI发布失败: ' + str(e))
                    self.last_byte = byte_val
                    self.last_send_time = now
            time.sleep(DI_POLL_INTERVAL)

    def run(self):
        self.connect_mqtt()
        di_thread = threading.Thread(target=self.publish_di, daemon=True)
        di_thread.start()
        print('DI模块' + str(DI_MODULE) + ' 采集已启动')
        print('   主题: ' + DI_TOPIC)
        print('   GPIO: ' + str(GPIO_PINS))
        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            print('\n停止采集...')
            self.running = False
            if self.client:
                self.client.loop_stop()
                self.client.disconnect()


if __name__ == '__main__':
    publisher = DIPublisher()
    publisher.run()
