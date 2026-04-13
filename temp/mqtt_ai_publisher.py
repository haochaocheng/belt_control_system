#!/usr/bin/env python3
# /root/mqtt_ai_publisher.py
# AI(模拟量输入)模块 - MQTT发布器
# 创建日期: 2026-03-10
# 基于 mqtt_io_publisher.py 拆分，仅保留AI模块功能
# 修改日期: 2026-03-10 从 mqtt_io_publisher.py 拆分，去除DI功能
# 修改日期: 2026-03-10 电压计算改用 in_voltage_scale（Wiki标准方式）
# 用于 Luckfox Nova (RK3308b) 设备 192.168.10.154

import json
import time
import threading
import paho.mqtt.client as mqtt
from collections import deque

# MQTT 配置
BROKER = '192.168.10.151'
PORT = 1883
AI_MODULE = 1
CLIENT_ID = 'luckfox-ai-module-' + str(AI_MODULE)
AI_TOPIC = 'belt_control/ai/module' + str(AI_MODULE) + '/status'

# ADC 配置
ADC_PATH = '/sys/bus/iio/devices/iio:device0'
ADC_CHANNELS = 5
AI_INTERVAL = 0.5  # 500ms 发布间隔
# 2026-03-10: 去掉硬编码 VREF/ADC_MAX，改用 in_voltage_scale 动态读取
# VREF = 1.8
# ADC_MAX = 1023
ADC_MAX = 1023  # 仅用于滤波阈值计算和16位值转换

# 2026-03-09 [Phase 7.48.25]: ADC滤波配置
FILTER_SAMPLE_INTERVAL = 0.05
FILTER_WINDOW_SIZE = 10
FILTER_SPIKE_THRESHOLD = 0.3


class ADCFilter:
    """
    2026-03-09 [Phase 7.48.25]: ADC滤波器
    """

    def __init__(self, num_channels, window_size=FILTER_WINDOW_SIZE):
        self.num_channels = num_channels
        self.window_size = window_size
        self.buffers = [deque(maxlen=window_size) for _ in range(num_channels)]
        self.lock = threading.Lock()
        self.running = True
        # 2026-03-10: 从 in_voltage_scale 读取比例因子
        self.voltage_scale = self._read_scale()

    def _read_scale(self):
        """读取 ADC 比例因子 in_voltage_scale"""
        try:
            with open(ADC_PATH + '/in_voltage_scale', 'r') as f:
                scale = float(f.read().strip())
                print('[ADCFilter] in_voltage_scale = ' + str(scale))
                return scale
        except:
            print('[ADCFilter] 无法读取 in_voltage_scale，使用默认值 1.757812500')
            return 1.757812500

    def _read_raw(self, channel):
        try:
            with open(ADC_PATH + '/in_voltage' + str(channel) + '_raw', 'r') as f:
                return int(f.read().strip())
        except:
            return 0

    def sample_once(self):
        with self.lock:
            for ch in range(self.num_channels):
                raw = self._read_raw(ch)
                self.buffers[ch].append(raw)

    def get_filtered(self, channel):
        with self.lock:
            buf = list(self.buffers[channel])

        if not buf:
            return 0, 0.0

        if len(buf) < 3:
            avg_raw = sum(buf) / len(buf)
        else:
            sorted_buf = sorted(buf)
            n = len(sorted_buf)
            if n % 2 == 0:
                median = (sorted_buf[n // 2 - 1] + sorted_buf[n // 2]) / 2
            else:
                median = sorted_buf[n // 2]

            if median > 0:
                threshold = median * FILTER_SPIKE_THRESHOLD
            else:
                threshold = ADC_MAX * FILTER_SPIKE_THRESHOLD

            filtered = [v for v in buf if abs(v - median) <= threshold]

            if filtered:
                avg_raw = sum(filtered) / len(filtered)
            else:
                avg_raw = median

        # 2026-03-10: 使用 in_voltage_scale 计算电压（Wiki标准方式）
        # voltage = raw * scale / 1000
        voltage = round(avg_raw * self.voltage_scale / 1000, 4)
        value16 = int(avg_raw * 65535 / ADC_MAX)

        return value16, voltage

    def sampling_loop(self):
        print('[ADCFilter] 高频采样启动: 间隔=' + str(FILTER_SAMPLE_INTERVAL) + 's, 窗口=' + str(self.window_size))
        while self.running:
            self.sample_once()
            time.sleep(FILTER_SAMPLE_INTERVAL)
        print('[ADCFilter] 采样循环已停止')


class AIPublisher:
    def __init__(self):
        self.client = None
        self.connected = False
        self.running = True
        self._loop_thread = None
        self.adc_filter = ADCFilter(num_channels=ADC_CHANNELS + 1)

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

    def publish_ai(self):
        print('模拟量采集启动, 模块: ' + str(AI_MODULE) + ', 周期: ' + str(AI_INTERVAL) + 's')
        time.sleep(FILTER_SAMPLE_INTERVAL * 3)
        while self.running:
            if self.connected:
                channels = []
                for ch in range(8):
                    if ch < ADC_CHANNELS:
                        value, voltage = self.adc_filter.get_filtered(ch)
                    else:
                        value, voltage = 0, 0.0
                    channels.append({'value': value, 'voltage': voltage})
                payload = {
                    'module': AI_MODULE,
                    'type': 'ai',
                    'timestamp': int(time.time()),
                    'data': {'channels': channels},
                    'quality': 'good'
                }
                try:
                    self.client.publish(AI_TOPIC, json.dumps(payload))
                except Exception as e:
                    print('AI发布失败: ' + str(e))
            time.sleep(AI_INTERVAL)

    def run(self):
        self.connect_mqtt()

        adc_sample_thread = threading.Thread(
            target=self.adc_filter.sampling_loop,
            name='adc-filter-sampler',
            daemon=True
        )
        adc_sample_thread.start()

        ai_thread = threading.Thread(target=self.publish_ai, daemon=True)
        ai_thread.start()

        print('AI模块' + str(AI_MODULE) + ' 采集已启动')
        print('   主题: ' + AI_TOPIC)
        print('   ADC滤波: 采样间隔=' + str(FILTER_SAMPLE_INTERVAL) + 's, 窗口=' + str(FILTER_WINDOW_SIZE) + ', 尖峰阈值=' + str(FILTER_SPIKE_THRESHOLD))

        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            print('\n停止采集...')
            self.running = False
            self.adc_filter.running = False
            if self.client:
                self.client.loop_stop()
                self.client.disconnect()


if __name__ == '__main__':
    publisher = AIPublisher()
    publisher.run()
