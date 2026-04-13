#!/usr/bin/env python3
# /root/mqtt_cs_publisher.py
# CS(测速)模块 - 临时功能：采集所有IO开关量输入
# 创建日期: 2026-03-10
# 用于 Luckfox Lyra RK3506 设备

import json
import time
import threading
import paho.mqtt.client as mqtt

# ===== 设备配置（部署时修改） =====
BROKER = '192.168.10.151'
PORT = 1883
CS_MODULE = 1
CLIENT_ID = 'luckfox-cs-module-' + str(CS_MODULE)
CS_TOPIC = 'belt_control/cs/module' + str(CS_MODULE) + '/status'

# GPIO 配置 - RK3506 GPIO0_A3~A7 + GPIO0_B0~B2 (编号 3~10)
# 2026-03-10: 避开 A0/A1/A2（内部上拉，上电默认高电平），统一使用下拉引脚（上电默认低电平，高电平触发）
# 旧配置: GPIO_PINS = [0, 1, 2, 3, 4, 5, 6, 7]  # GPIO0_A0~A7
GPIO_PINS = [3, 4, 5, 6, 7, 8, 9, 10]
CS_INTERVAL = 0.1  # 100ms


class CSPublisher:
    def __init__(self):
        self.client = None
        self.connected = False
        self.running = True
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

    def publish_cs(self):
        print('CS采集启动, 模块: ' + str(CS_MODULE) + ', 周期: ' + str(CS_INTERVAL) + 's')
        while self.running:
            if self.connected:
                bits, byte_val = self.read_gpio()
                payload = {
                    'module': CS_MODULE,
                    'type': 'cs',
                    'timestamp': int(time.time()),
                    'data': {'bits': bits, 'byte': byte_val},
                    'quality': 'good'
                }
                try:
                    self.client.publish(CS_TOPIC, json.dumps(payload))
                except Exception as e:
                    print('CS发布失败: ' + str(e))
            time.sleep(CS_INTERVAL)

    def run(self):
        self.connect_mqtt()
        cs_thread = threading.Thread(target=self.publish_cs, daemon=True)
        cs_thread.start()
        print('CS模块' + str(CS_MODULE) + ' 采集已启动')
        print('   主题: ' + CS_TOPIC)
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
    publisher = CSPublisher()
    publisher.run()
