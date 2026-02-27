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

// 前向声明
class DIDataManager;
class CommonControl;

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
    CommonControl *m_commonControl;    ///< 公共控制器
    AudioPathMapper *m_audioPathMapper; ///< 音频路径映射器
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
};

#endif // MQTTPROTECTIONMONITOR_H
