#!/usr/bin/env python3
# /root/mqtt_io_publisher.py
# GPIO/ADC 采集并发布到 MQTT
# 创建日期: 2026-02-26
# 修改日期: 2026-03-02 修复 paho-mqtt 2.1.0 SSL-None bug 导致线程崩溃后无法重连的问题
# 修改日期: 2026-03-09 [Phase 7.48.25] 新增模拟量ADC滤波功能
#   - 内部高频采样（50ms间隔）
#   - 中值滤波（去除尖峰噪声）
#   - 移动平均（平滑输出）
#   - 滤波窗口大小: 10个采样点
# 用于 Luckfox Nova 设备

import json
import time
import threading
import paho.mqtt.client as mqtt
from collections import deque

# MQTT 配置
BROKER = '192.168.10.142'  # EMQX 服务器地址
PORT = 1883
CLIENT_ID = 'luckfox-io-module'

# GPIO 配置 - 根据 Luckfox Nova 原理图 P1 连接器
GPIO_PINS = [68, 69, 70, 71, 72, 73, 74, 75]
DI_MODULE = 1
DI_TOPIC = 'belt_control/di/module' + str(1) + '/status'
DI_INTERVAL = 0.1  # 100ms

# ADC 配置
ADC_PATH = '/sys/bus/iio/devices/iio:device0'
ADC_CHANNELS = 5
AI_MODULE = 3
AI_TOPIC = 'belt_control/ai/module1/status'
AI_INTERVAL = 0.5  # 500ms 发布间隔
VREF = 1.8
ADC_MAX = 1023

# 2026-03-09 [Phase 7.48.25]: ADC滤波配置
FILTER_SAMPLE_INTERVAL = 0.05   # 内部采样间隔 50ms
FILTER_WINDOW_SIZE = 10         # 滑动窗口大小（10个采样 = 500ms）
FILTER_SPIKE_THRESHOLD = 0.3    # 尖峰剔除阈值：偏离中值超过30%则剔除


class ADCFilter:
    """
    2026-03-09 [Phase 7.48.25]: ADC滤波器

    滤波策略：
    1. 高频采样：每50ms采样一次（比发布频率快10倍）
    2. 中值滤波：取窗口中值，有效去除尖峰噪声
    3. 移动平均：对去除尖峰后的数据取平均值，平滑输出
    4. 尖峰剔除：偏离中值超过阈值的采样点被排除
    """

    def __init__(self, num_channels, window_size=FILTER_WINDOW_SIZE):
        self.num_channels = num_channels
        self.window_size = window_size
        # 每个通道一个采样缓冲区
        self.buffers = [deque(maxlen=window_size) for _ in range(num_channels)]
        self.lock = threading.Lock()
        self.running = True

    def _read_raw(self, channel):
        """读取单个ADC通道原始值"""
        try:
            with open(ADC_PATH + '/in_voltage' + str(channel) + '_raw', 'r') as f:
                return int(f.read().strip())
        except:
            return 0

    def sample_once(self):
        """执行一次全通道采样，存入缓冲区"""
        with self.lock:
            for ch in range(self.num_channels):
                raw = self._read_raw(ch)
                self.buffers[ch].append(raw)

    def get_filtered(self, channel):
        """
        获取滤波后的值（中值滤波 + 尖峰剔除后求平均）

        返回: (value16, voltage)
        """
        with self.lock:
            buf = list(self.buffers[channel])

        if not buf:
            return 0, 0.0

        if len(buf) < 3:
            # 采样不足3个，直接取平均
            avg_raw = sum(buf) / len(buf)
        else:
            # 步骤1: 计算中值
            sorted_buf = sorted(buf)
            n = len(sorted_buf)
            if n % 2 == 0:
                median = (sorted_buf[n // 2 - 1] + sorted_buf[n // 2]) / 2
            else:
                median = sorted_buf[n // 2]

            # 步骤2: 尖峰剔除 - 排除偏离中值超过阈值的采样点
            if median > 0:
                threshold = median * FILTER_SPIKE_THRESHOLD
            else:
                threshold = ADC_MAX * FILTER_SPIKE_THRESHOLD

            filtered = [v for v in buf if abs(v - median) <= threshold]

            # 步骤3: 对剔除后的数据求平均
            if filtered:
                avg_raw = sum(filtered) / len(filtered)
            else:
                # 全部被剔除（不太可能），回退到中值
                avg_raw = median

        # 转换为16位值和电压
        voltage = round(avg_raw * VREF / ADC_MAX, 2)
        value16 = int(avg_raw * 65535 / ADC_MAX)

        return value16, voltage

    def sampling_loop(self):
        """高频采样循环（独立线程运行）"""
        print('[ADCFilter] 高频采样启动: 间隔=' + str(FILTER_SAMPLE_INTERVAL) + 's, 窗口=' + str(self.window_size))
        while self.running:
            self.sample_once()
            time.sleep(FILTER_SAMPLE_INTERVAL)
        print('[ADCFilter] 采样循环已停止')


class IOPublisher:
    def __init__(self):
        self.client = None
        self.connected = False
        self.running = True
        self._loop_thread = None
        # 2026-03-09 [Phase 7.48.25]: 初始化ADC滤波器（CH0-CH5, 6个通道）
        self.adc_filter = ADCFilter(num_channels=ADC_CHANNELS + 1)
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
        client.on_connect = self.on_connect
        client.on_disconnect = self.on_disconnect
        return client

    def _mqtt_loop(self):
        # 修复: 用 while 循环包裹 loop_forever，捕获 paho-mqtt 2.1.0 的 ssl=None bug
        # 导致的未捕获 AttributeError，防止线程意外退出后无法重连
        while self.running:
            try:
                print('[MQTT] 网络循环启动')
                self.client.loop_forever(retry_first_connection=False)
                print('[MQTT] loop_forever 正常退出')
            except AttributeError as e:
                # paho-mqtt 2.1.0 bug: ssl=None 时报 AttributeError
                print('[MQTT] 捕获 paho-mqtt SSL bug: ' + str(e) + '，尝试重连...')
                self.connected = False
            except Exception as e:
                print('[MQTT] 网络循环异常: ' + str(e) + '，尝试重连...')
                self.connected = False

            if not self.running:
                break

            # 等待后重新建立连接
            time.sleep(3)
            print('[MQTT] 重新连接 ' + BROKER + ':' + str(PORT) + '...')
            try:
                # 重用同一个 client 对象，调用 reconnect
                self.client.reconnect()
            except Exception as e:
                print('[MQTT] reconnect() 失败: ' + str(e) + '，重建 client...')
                # reconnect 失败时重建 client 对象
                try:
                    self.client.loop_stop()
                    self.client.disconnect()
                except:
                    pass
                self.client = self._create_client()
                while self.running:
                    try:
                        self.client.connect(BROKER, PORT)
                        break
                    except Exception as ce:
                        print('[MQTT] connect 失败: ' + str(ce) + '，5秒后重试...')
                        time.sleep(5)

    def connect_mqtt(self):
        self.client = self._create_client()
        while self.running:
            try:
                print('正在连接 MQTT Broker: ' + BROKER + ':' + str(PORT))
                self.client.connect(BROKER, PORT)
                break
            except Exception as e:
                print('连接失败: ' + str(e) + ', 5秒后重试...')
                time.sleep(5)

        # 用自定义线程替代 loop_start()，加入崩溃保护
        self._loop_thread = threading.Thread(
            target=self._mqtt_loop,
            name='mqtt-loop-watchdog',
            daemon=True
        )
        self._loop_thread.start()

    def on_connect(self, client, userdata, flags, rc, properties=None):
        if rc == 0:
            print('MQTT 连接成功')
            self.connected = True
        else:
            print('MQTT 连接失败: rc=' + str(rc))

    def on_disconnect(self, client, userdata, rc, properties=None, reason=None):
        print('MQTT 断开连接 (rc=' + str(rc) + ')')
        self.connected = False

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
            if val:
                byte_val |= (1 << i)
        return bits, byte_val

    # 2026-03-09 [Phase 7.48.25]: 原始read_adc注释保留，改用ADCFilter
    # def read_adc(self, channel):
    #     try:
    #         with open(ADC_PATH + '/in_voltage' + str(channel) + '_raw', 'r') as f:
    #             raw = int(f.read().strip())
    #     except:
    #         raw = 0
    #     voltage = round(raw * VREF / ADC_MAX, 2)
    #     value16 = int(raw * 65535 / ADC_MAX)
    #     return value16, voltage

    def publish_di(self):
        print('开关量采集线程启动, 周期: ' + str(DI_INTERVAL) + 's')
        while self.running:
            if self.connected:
                bits, byte_val = self.read_gpio()
                payload = {
                    'module': DI_MODULE,
                    'type': 'di',
                    'timestamp': int(time.time()),
                    'data': {'bits': bits, 'byte': byte_val},
                    'quality': 'good'
                }
                try:
                    self.client.publish(DI_TOPIC, json.dumps(payload))
                except Exception as e:
                    print('DI发布失败: ' + str(e))
            time.sleep(DI_INTERVAL)

    def publish_ai(self):
        print('模拟量采集线程启动, 周期: ' + str(AI_INTERVAL) + 's')
        # 2026-03-09 [Phase 7.48.25]: 等待滤波器积累足够采样（至少3个）
        time.sleep(FILTER_SAMPLE_INTERVAL * 3)
        while self.running:
            if self.connected:
                channels = []
                for ch in range(8):
                    if ch < ADC_CHANNELS:
                        # 2026-03-09 [Phase 7.48.25]: 使用滤波后的值替代原始单次采样
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

        # 2026-03-09 [Phase 7.48.25]: 启动ADC高频采样线程
        adc_sample_thread = threading.Thread(
            target=self.adc_filter.sampling_loop,
            name='adc-filter-sampler',
            daemon=True
        )
        adc_sample_thread.start()

        di_thread = threading.Thread(target=self.publish_di, daemon=True)
        di_thread.start()

        ai_thread = threading.Thread(target=self.publish_ai, daemon=True)
        ai_thread.start()

        print('IO 采集已启动')
        print('   DI主题: ' + DI_TOPIC)
        print('   AI主题: ' + AI_TOPIC)
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
    publisher = IOPublisher()
    publisher.run()
