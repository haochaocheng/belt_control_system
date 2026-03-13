/**
 * @file MqttProtectionMonitor.h
 * @brief MQTT开关量保护监控器
 * @date 2026-02-27
 * @phase 7.47.35
 *
 * 功能：
 * - 监听MQTT开关量输入模块的位变化
 * - 检测保护触发（位从0→1）
 * - 生成对应的音频文件路径
 * - 触发音频播放
 *
 * 参考：docs/2026-02-26/08-音频文件路径映射设计方案.md
 */

#ifndef MQTTPROTECTIONMONITOR_H
#define MQTTPROTECTIONMONITOR_H

#include <QObject>
#include <QElapsedTimer>
#include "AudioPathMapper.h"
#include "../mqtt/AIDataManager.h"  // ✅ 2026-03-05 [Phase 7.48.5]: 包含 ChannelData 定义

// 前向声明
class DIDataManager;
class CommonControl;
class DeviceConfigManager;  // ✅ 2026-02-28 [Phase 7.47.49]
class AlarmPlaybackService; // ✅ 2026-03-04 [Phase 7.47.95]
class MQTTController;       // ✅ 2026-03-09 [Phase 7.48.26]: 洒水控制用MQTT发布

/**
 * @brief MQTT开关量保护监控器
 *
 * 监听MQTT DI模块的位变化，触发保护报警音频播放
 */
class MqttProtectionMonitor : public QObject
{
    Q_OBJECT

public:
    /**
     * @brief 构造函数
     * @param diManager DI数据管理器
     * @param commonControl 公共控制器（用于播放音频）
     * @param parent 父对象
     */
    explicit MqttProtectionMonitor(DIDataManager *diManager,
                                   CommonControl *commonControl,
                                   QObject *parent = nullptr);

    /**
     * @brief 析构函数
     */
    ~MqttProtectionMonitor();

    /**
     * @brief 启动保护监控
     */
    Q_INVOKABLE void start();

    /**
     * @brief 停止保护监控
     */
    Q_INVOKABLE void stop();

    /**
     * @brief 是否正在运行
     * @return true=运行中，false=已停止
     */
    Q_INVOKABLE bool isRunning() const { return m_isRunning; }

    // ✅ 2026-02-28 [Phase 7.47.49]: 新增 - 设置设备配置管理器（用于查询 use_text_to_speech）
    void setDeviceConfigManager(DeviceConfigManager *mgr) { m_deviceConfigMgr = mgr; }

    // ✅ 2026-03-04 [Phase 7.47.95]: 新增 - 设置报警播放服务（用于按次数/按时长播放）
    void setAlarmPlaybackService(AlarmPlaybackService *svc) { m_alarmPlaybackService = svc; }

    // ✅ 2026-03-05 [Phase 7.48.5]: 新增 - 设置AI数据管理器（用于模拟量保护监控）
    void setAIDataManager(AIDataManager *aiManager) { m_aiManager = aiManager; }

    // ✅ 2026-03-10 [Phase 7.48.31]: 电机控制 MQTT 命令发布（Q_INVOKABLE 供 QML 调用）
    /**
     * @brief 发布电机控制命令到 DO 模块
     * @param deviceId 设备ID
     * @param motorIndex 电机索引（0-7）
     * @param activate true=启动电机, false=停止电机
     */
    Q_INVOKABLE void publishMotorCommand(int deviceId, int motorIndex, bool activate);

    // ✅ 2026-03-09 [Phase 7.48.26]: 新增 - 设置MQTT控制器（用于洒水控制MQTT发布）
    void setMQTTController(MQTTController *ctrl) { m_mqttController = ctrl; }

    /**
     * @brief 设置AI模块的皮带编号映射
     * @param moduleIndex AI模块索引（0或1，对应模拟量模块1和2）
     * @param beltNumber 皮带编号（1-8）
     *
     * 说明：
     * - AI模块0（模拟量输入1）对应某条皮带
     * - AI模块1（模拟量输入2）对应另一条皮带
     * - 默认：AI模块0→1号皮带，AI模块1→2号皮带
     */
    Q_INVOKABLE void setAIBeltMapping(int moduleIndex, int beltNumber);

    /**
     * @brief 设置皮带编号映射
     * @param moduleIndex 模块索引（0或1）
     * @param beltNumber 皮带编号（1-8）
     *
     * 说明：
     * - 模块0（开关量输入1）对应某条皮带
     * - 模块1（开关量输入2）对应另一条皮带
     * - 默认：模块0→1号皮带，模块1→2号皮带
     */
    Q_INVOKABLE void setBeltMapping(int moduleIndex, int beltNumber);

    /**
     * @brief 获取皮带编号映射
     * @param moduleIndex 模块索引（0或1）
     * @return 皮带编号
     */
    Q_INVOKABLE int getBeltMapping(int moduleIndex) const;

public slots:
    // ✅ 2026-03-05 [Phase 7.48.5]: AI通道变化槽函数（移至 public slots）
    /**
     * @brief AI通道变化槽函数（模拟量保护监控）
     * @param moduleIndex AI模块索引（0或1）
     * @param channelIndex 通道索引（0-7）
     * @param data 通道数据（包含AD值、工程量等）
     *
     * 说明：
     * - 从AIDataManager接收channelChanged信号
     * - 查询该皮带的所有模拟量保护配置
     * - 从data中获取AD值和工程量
     * - 对比上下限阈值
     * - 超限时触发AlarmPlaybackService
     */
    void onAIChannelChanged(int moduleIndex, int channelIndex, const ChannelData &data);

    // ✅ 2026-03-13: 电机保护Modbus TCP数据接收槽函数
    /**
     * @brief 电机保护寄存器数据接收（来自NetworkTask）
     * @param motorIndex 电机索引（0-7）
     * @param tabIndex 保护Tab索引（1=电流, 2=前轴承温度, ..., 9=Y轴振动）
     * @param rawValue Modbus原始寄存器值（0-4095）
     *
     * 流程：
     * 1. 从 device_motor_config 加载该电机该Tab的保护配置
     * 2. 根据 input_type 选择 PT100 或 4-20mA 转换公式
     * 3. 转换为物理量（温度℃、电流A、振动mm/s）
     * 4. 对比上下限阈值
     * 5. 超限时触发 AlarmPlaybackService 播放报警语音
     */
    void onMotorRegisterReceived(int motorIndex, int tabIndex, quint16 rawValue);

    // ✅ 2026-03-05 [Phase 7.48.10]: 电机启动/停止通知（用于速度保护延时启动）
    /**
     * @brief 通知电机已启动（开始速度保护延时计时）
     * @param beltNumber 皮带编号（1-8）
     */
    void notifyMotorStarted(int beltNumber);

    /**
     * @brief 通知电机已停止（重置速度保护状态）
     * @param beltNumber 皮带编号（1-8）
     */
    void notifyMotorStopped(int beltNumber);

signals:
    /**
     * @brief 保护触发信号
     * @param moduleIndex 模块索引
     * @param bitIndex 位索引
     * @param beltNumber 皮带编号
     * @param protectionName 保护名称
     * @param audioPath 音频文件路径
     */
    void protectionTriggered(int moduleIndex, int bitIndex, int beltNumber,
                            const QString &protectionName, const QString &audioPath);

    // ✅ 2026-03-09 [Phase 7.48.24]: 模拟量保护触发/恢复信号（记录到报警历史数据库）
    /**
     * @brief 模拟量保护触发信号
     * @param beltNumber 皮带编号
     * @param protectionName 保护名称（如"温度一"、"甲烷"）
     * @param engineeringValue 触发时的工程量值
     * @param limitType 超限类型："超上限" 或 "低于下限"
     */
    void analogProtectionTriggered(int beltNumber, const QString &protectionName,
                                   double engineeringValue, const QString &limitType);

    /**
     * @brief 模拟量保护恢复信号
     * @param beltNumber 皮带编号
     * @param protectionName 保护名称
     * @param engineeringValue 恢复时的工程量值
     */
    void analogProtectionRestored(int beltNumber, const QString &protectionName,
                                  double engineeringValue);

private slots:
    /**
     * @brief DI位变化槽函数
     * @param moduleIndex 模块索引（0或1）
     * @param bitIndex 位索引（0-7）
     * @param value 位值（true=1, false=0）
     */
    void onBitChanged(int moduleIndex, int bitIndex, bool value);

private:
    DIDataManager *m_diManager;        ///< DI数据管理器
    AIDataManager *m_aiManager;        ///< AI数据管理器 ✅ Phase 7.48.5
    CommonControl *m_commonControl;    ///< 公共控制器
    AudioPathMapper *m_audioPathMapper; ///< 音频路径映射器
    DeviceConfigManager *m_deviceConfigMgr; ///< 设备配置管理器（查询use_text_to_speech）✅ Phase 7.47.49
    AlarmPlaybackService *m_alarmPlaybackService; ///< 报警播放服务（按次数/按时长播放）✅ Phase 7.47.95
    bool m_isRunning;                  ///< 是否正在运行

    /**
     * @brief 皮带编号映射表（模块索引 → 皮带编号）
     *
     * 说明：
     * - 键：模块索引（0或1）
     * - 值：皮带编号（1-8）
     * - 默认：{0: 1, 1: 2}
     */
    QMap<int, int> m_beltMapping;

    // ✅ 2026-03-05 [Phase 7.48.5]: AI模块皮带映射表
    /**
     * @brief AI模块皮带编号映射表（AI模块索引 → 皮带编号）
     *
     * 说明：
     * - 键：AI模块索引（0或1）
     * - 值：皮带编号（1-8）
     * - 默认：{0: 1, 1: 2}
     */
    QMap<int, int> m_aiBeltMapping;

    // ✅ 2026-03-05 [Phase 7.48.10]: 速度保护状态（延时启动 + 低速打滑计时）
    QMap<int, QElapsedTimer> m_motorStartTimers;  ///< 电机启动计时器（key=beltNumber）
    QMap<int, bool> m_motorRunning;               ///< 电机运行状态（key=beltNumber）
    QMap<int, QElapsedTimer> m_slipTimers;        ///< 低速打滑计时器（key=beltNumber）
    QMap<int, bool> m_slipTimerActive;            ///< 低速打滑计时器是否激活（key=beltNumber）

    // ✅ 2026-03-09 [Phase 7.48.23]: 模拟量保护报警状态追踪（边沿触发）
    // Key = "皮带编号:保护名称" (如 "1:温度一")
    // Value = true表示当前处于超限状态（已触发报警），false表示正常
    // 只在 false→true 转换时触发报警播放，避免持续超限时反复触发
    QMap<QString, bool> m_protectionAlarmActive;

    // ✅ 2026-03-09 [Phase 7.48.26]: 洒水控制相关成员
    // ✅ 2026-03-09 [Phase 7.48.28]: 改为多洒水支持（8个独立洒水装置）
    MQTTController *m_mqttController;     ///< MQTT控制器（用于发布洒水命令）
    QMap<int, QMap<QString, bool>> m_sprinklerTriggerSources;  ///< 洒水触发源（外层key=sprinkler_index 1-8, 内层key=皮带:保护名称）
    QMap<int, bool> m_sprinklerActive;    ///< 各洒水是否已激活（key=sprinkler_index 1-8）

    /**
     * @brief 检查洒水激活状态
     * @param beltNumber 皮带编号
     * @param protectionName 保护名称
     * @param exceeded 是否超限（true=触发, false=恢复）
     */
    void checkSprinklerActivation(int beltNumber, const QString &protectionName, bool exceeded);

    /**
     * @brief 发布洒水控制命令（多洒水版本）
     * @param sprinklerIndex 洒水索引（1-8）
     * @param activate true=启动洒水, false=停止洒水
     */
    void publishSprinklerCommand(int sprinklerIndex, bool activate);

    // ✅ 2026-03-13: PT100/4-20mA 转换函数
    /**
     * @brief PT100温度转换：rawValue(0-4095) → 温度(-50℃~+200℃)
     * 公式：temperature = rawValue × 250 / 4096 - 50
     */
    static double convertPT100(quint16 rawValue);

    /**
     * @brief 4-20mA电流型转换：rawValue(819-4096) → 物理量(0~Range)
     * 公式：value = (rawValue - 819) × Range / (4096 - 819)
     * rawValue < 819 表示欠量程（传感器断线）
     */
    static double convert420mA(quint16 rawValue, double range);

    // ✅ 2026-03-13: 电机保护报警状态追踪（边沿触发）
    // Key = "motor:电机索引:Tab索引" (如 "motor:0:2" = 电机1的前轴承温度)
    QMap<QString, bool> m_motorProtectionAlarmActive;

    // ✅ 2026-03-10 [Phase 7.48.31]: publishMotorCommand 已移至 public 区域（Q_INVOKABLE）
};

#endif // MQTTPROTECTIONMONITOR_H
