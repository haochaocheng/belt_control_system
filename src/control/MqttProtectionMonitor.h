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
#include "AudioPathMapper.h"
#include "../mqtt/AIDataManager.h"  // ✅ 2026-03-05 [Phase 7.48.5]: 包含 ChannelData 定义

// 前向声明
class DIDataManager;
class CommonControl;
class DeviceConfigManager;  // ✅ 2026-02-28 [Phase 7.47.49]
class AlarmPlaybackService; // ✅ 2026-03-04 [Phase 7.47.95]

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
};

#endif // MQTTPROTECTIONMONITOR_H
