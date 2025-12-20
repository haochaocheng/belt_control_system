#ifndef PROTECTIONMONITORSERVICE_H
#define PROTECTIONMONITORSERVICE_H

#include <QObject>
#include <QMap>
#include <QTimer>
#include "ProtectionConfig.h"

class ProtectionConfigManager;
class NetworkTask;

/**
 * @brief 保护监控服务 - 监控寄存器值并检测保护触发条件
 *
 * 功能：
 * - 监听 NetworkTask 的寄存器值更新
 * - 从 ProtectionConfigManager 加载保护配置
 * - 检测数字保护触发条件（通道位从 0 到 1）
 * - 检测模拟量保护触发条件（值超过上/下限）
 * - 触发报警（语音报警 + 弹窗）
 * - 记录报警历史
 */
class ProtectionMonitorService : public QObject
{
    Q_OBJECT

public:
    explicit ProtectionMonitorService(QObject *parent = nullptr);
    ~ProtectionMonitorService();

    // 设置依赖的模块
    void setProtectionConfigManager(ProtectionConfigManager *manager);
    void setNetworkTask(NetworkTask *task);

    // 启动/停止监控
    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE bool isRunning() const { return m_isRunning; }

    // 手动触发保护检测（用于测试）
    Q_INVOKABLE void testProtection(const QString &protectionName);

    // 手动复位所有保护（F键） - 只复位外部信号已恢复的保护
    Q_INVOKABLE void manualReset();

signals:
    // 保护触发信号
    void protectionTriggered(const QString &protectionName, const QString &type, double value);

    // 保护恢复信号（值回到正常范围）
    void protectionRestored(const QString &protectionName);

    // 报警信号（用于播放语音）
    void alarmTriggered(const QString &protectionName, const QString &ttsText, const QString &audioFile,
                        bool useTextToSpeech, const QString &playMode, int playCount, double playDuration);

private slots:
    // 处理寄存器值更新
    void onRegisterValueReceived(int address, quint16 value);

    // 延时触发检查（用于保护延时）
    void onDelayedCheckTimeout();

private:
    // 加载所有保护配置
    void loadProtectionConfigs();

    // 检测数字保护（开关量）
    void checkDigitalProtection(int registerAddress, quint16 value);

    // 检测模拟量保护
    void checkAnalogProtection(int registerAddress, quint16 rawValue);

    // 将原始寄存器值转换为实际物理值
    double convertRawToPhysical(quint16 rawValue, double range, double lowerLimit);

    // 检查保护是否应该触发
    bool shouldTrigger(const QString &protectionName, bool isFault);

    // 触发保护
    void triggerProtection(const QString &protectionName, double value);

    // 恢复保护
    void restoreProtection(const QString &protectionName);

private:
    // 依赖模块
    ProtectionConfigManager *m_configManager;
    NetworkTask *m_networkTask;

    // 运行状态
    bool m_isRunning;

    // 保护配置缓存（保护名称 -> 配置）
    QMap<QString, ProtectionConfig> m_protectionConfigs;

    // 寄存器地址到保护名称的映射（用于快速查找）
    // 数字保护：registerAddress -> (channelNumber -> protectionName)
    QMap<int, QMap<int, QString>> m_digitalProtectionMap;

    // 模拟量保护：registerAddress -> protectionName
    QMap<int, QString> m_analogProtectionMap;

    // 上次寄存器值（用于检测变化）
    QMap<int, quint16> m_lastRegisterValues;

    // 保护触发状态（保护名称 -> 是否触发）
    QMap<QString, bool> m_protectionTriggered;

    // 保护延时定时器（保护名称 -> 定时器）
    QMap<QString, QTimer*> m_delayTimers;

    // 待检查的保护（保护名称 -> 故障状态）
    QMap<QString, bool> m_pendingChecks;
};

#endif // PROTECTIONMONITORSERVICE_H
