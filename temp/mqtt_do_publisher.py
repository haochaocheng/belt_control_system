#!/usr/bin/env python3
# /root/mqtt_do_publisher.py
# DO(继电器输出)模块 - 订阅MQTT控制命令，输出GPIO控制继电器
# 同时采集反馈输入和急停按钮状态
# 创建日期: 2026-03-10
# 用于 Luckfox Lyra RK3506 设备5

import json
import time
import threading
import paho.mqtt.client as mqtt

# ===== 设备配置 =====
BROKER = '192.168.10.151'
PORT = 1883
DO_MODULE = 1
CLIENT_ID = 'luckfox-do-module-' + str(DO_MODULE)

# MQTT 主题
DO_CMD_TOPIC = 'belt_control/do/module' + str(DO_MODULE) + '/cmd'        # 订阅：控制命令
DO_STATUS_TOPIC = 'belt_control/do/module' + str(DO_MODULE) + '/status'  # 发布：状态反馈

# GPIO 引脚配置 - 全部使用下拉引脚（上电默认低电平）
# 继电器输出: GPIO 3~10 (GPIO0_A3~B2), 8路
DO_PINS = [3, 4, 5, 6, 7, 8, 9, 10]
# 反馈输入: GPIO 11~18 (GPIO0_B3~C2), 8路
DI_PINS = [11, 12, 13, 14, 15, 16, 17, 18]
# 急停按钮: GPIO 19 (GPIO0_C3), 1路, 高电平=急停触发
ESTOP_PIN = 19

STATUS_INTERVAL = 0.1  # 100ms 状态上报周期
ESTOP_CHECK_INTERVAL = 0.02  # 20ms 急停检测周期


class DOPublisher:
    def __init__(self):
        self.client = None
        self.connected = False
        self.running = True
        self.estop_active = False
        self.do_states = [0] * len(DO_PINS)  # 当前输出状态
        self.init_gpio()

    def init_gpio(self):
        # 初始化输出引脚
        for pin in DO_PINS:
            self._export_gpio(pin, 'out')
            self._write_gpio(pin, 0)  # 上电全部关闭
        print('DO GPIO 初始化完成 (输出): ' + str(DO_PINS))

        # 初始化反馈输入引脚
        for pin in DI_PINS:
            self._export_gpio(pin, 'in')
        print('DI GPIO 初始化完成 (输入): ' + str(DI_PINS))

        # 初始化急停引脚
        self._export_gpio(ESTOP_PIN, 'in')
        print('急停 GPIO 初始化完成: GPIO' + str(ESTOP_PIN))

    def _export_gpio(self, pin, direction):
        try:
            with open('/sys/class/gpio/export', 'w') as f:
                f.write(str(pin))
        except:
            pass
        try:
            with open('/sys/class/gpio/gpio' + str(pin) + '/direction', 'w') as f:
                f.write(direction)
        except:
            pass

    def _write_gpio(self, pin, value):
        try:
            with open('/sys/class/gpio/gpio' + str(pin) + '/value', 'w') as f:
                f.write(str(value))
        except Exception as e:
            print('GPIO' + str(pin) + ' 写入失败: ' + str(e))

    def _read_gpio(self, pin):
        try:
            with open('/sys/class/gpio/gpio' + str(pin) + '/value', 'r') as f:
                return int(f.read().strip())
        except:
            return 0

    def _create_client(self):
        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, CLIENT_ID)
        client.on_connect = self._on_connect
        client.on_disconnect = self._on_disconnect
        client.on_message = self._on_message
        client.reconnect_delay_set(min_delay=1, max_delay=30)
        return client

    def _on_connect(self, client, userdata, flags, rc, properties=None):
        if rc == 0:
            self.connected = True
            print('[MQTT] 连接成功: ' + BROKER)
            # 订阅控制命令
            client.subscribe(DO_CMD_TOPIC)
            print('[MQTT] 已订阅: ' + DO_CMD_TOPIC)
        else:
            self.connected = False
            print('[MQTT] 连接失败, rc=' + str(rc))

    def _on_disconnect(self, client, userdata, flags, rc, properties=None):
        self.connected = False
        print('[MQTT] 断开连接, rc=' + str(rc))

    def _on_message(self, client, userdata, msg):
        """处理控制命令"""
        try:
            payload = json.loads(msg.payload.decode())
            action = payload.get('action', '')

            if action == 'set':
                # 设置单个继电器: {"action": "set", "channel": 0, "value": 1}
                ch = payload.get('channel', -1)
                val = payload.get('value', 0)
                if 0 <= ch < len(DO_PINS):
                    if self.estop_active:
                        print('[急停] 急停激活中，拒绝输出命令')
                    else:
                        self._write_gpio(DO_PINS[ch], val)
                        self.do_states[ch] = val
                        print('[DO] 通道' + str(ch) + ' = ' + str(val))

            elif action == 'set_all':
                # 设置所有继电器: {"action": "set_all", "values": [1,0,1,0,0,0,0,0]}
                values = payload.get('values', [])
                if self.estop_active:
                    print('[急停] 急停激活中，拒绝输出命令')
                else:
                    for i, val in enumerate(values):
                        if i < len(DO_PINS):
                            self._write_gpio(DO_PINS[i], val)
                            self.do_states[i] = val
                    print('[DO] 全部设置: ' + str(self.do_states))

            elif action == 'all_off':
                # 全部关闭: {"action": "all_off"}
                self._all_off()
                print('[DO] 全部关闭')

            elif action == 'estop_reset':
                # 急停复位: {"action": "estop_reset"}
                if self._read_gpio(ESTOP_PIN) == 0:
                    self.estop_active = False
                    print('[急停] 急停已复位')
                else:
                    print('[急停] 急停按钮仍按下，无法复位')

        except Exception as e:
            print('[DO] 命令解析失败: ' + str(e))

    def _all_off(self):
        """关闭所有继电器输出"""
        for i, pin in enumerate(DO_PINS):
            self._write_gpio(pin, 0)
            self.do_states[i] = 0

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

    def estop_monitor(self):
        """急停按钮监控线程 - 高优先级，20ms检测"""
        print('[急停] 监控启动, GPIO' + str(ESTOP_PIN) + ', 周期: ' + str(ESTOP_CHECK_INTERVAL) + 's')
        while self.running:
            estop_val = self._read_gpio(ESTOP_PIN)
            if estop_val == 1 and not self.estop_active:
                # 急停触发！立即关闭所有输出
                self.estop_active = True
                self._all_off()
                print('[急停] *** 急停触发！所有继电器已断开 ***')
            time.sleep(ESTOP_CHECK_INTERVAL)

    def publish_status(self):
        """状态上报线程"""
        print('[状态] 上报启动, 周期: ' + str(STATUS_INTERVAL) + 's')
        while self.running:
            if self.connected:
                # 读取反馈输入
                di_bits = []
                di_byte = 0
                for i, pin in enumerate(DI_PINS):
                    val = self._read_gpio(pin)
                    di_bits.append(val)
                    di_byte |= (val << i)

                payload = {
                    'module': DO_MODULE,
                    'type': 'do',
                    'timestamp': int(time.time()),
                    'data': {
                        'do_states': self.do_states[:],
                        'do_byte': sum(v << i for i, v in enumerate(self.do_states)),
                        'di_feedback': di_bits,
                        'di_byte': di_byte,
                        'estop': 1 if self.estop_active else 0,
                        'estop_raw': self._read_gpio(ESTOP_PIN)
                    },
                    'quality': 'good'
                }
                try:
                    self.client.publish(DO_STATUS_TOPIC, json.dumps(payload))
                except Exception as e:
                    print('[状态] 发布失败: ' + str(e))
            time.sleep(STATUS_INTERVAL)

    def run(self):
        self.connect_mqtt()

        # 急停监控线程（最高优先级）
        estop_thread = threading.Thread(target=self.estop_monitor, daemon=True)
        estop_thread.start()

        # 状态上报线程
        status_thread = threading.Thread(target=self.publish_status, daemon=True)
        status_thread.start()

        print('DO模块' + str(DO_MODULE) + ' 已启动')
        print('   控制命令: ' + DO_CMD_TOPIC)
        print('   状态反馈: ' + DO_STATUS_TOPIC)
        print('   输出GPIO: ' + str(DO_PINS))
        print('   反馈GPIO: ' + str(DI_PINS))
        print('   急停GPIO: ' + str(ESTOP_PIN))
        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            print('\n停止...')
            self.running = False
            self._all_off()
            if self.client:
                self.client.loop_stop()
                self.client.disconnect()


if __name__ == '__main__':
    publisher = DOPublisher()
    publisher.run()
