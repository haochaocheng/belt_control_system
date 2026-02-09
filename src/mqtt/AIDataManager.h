/**
 * @file AIDataManager.h
 * @brief 模拟量数据管理器
 * @date 2026-02-09
 * @phase 7.44.4
 *
 * 功能：
 * - 解析模拟量数据（8通道×16位AD值）
 * - 数据存储和缓存
 * - 变化检测（阈值检测）
 * - 信号通知
 */

#ifndef AIDATAMANAGER_H
#define AIDATAMANAGER_H

#include <QObject>
#include <QVector>
#include <QVariantMap>
#include <QVariantList>

/**
 * @brief 模拟量通道数据
 */
struct ChannelData
{
    quint16 adValue;      // AD转换值（0-65535）
    double voltage;       // 电压值（V）
    qint64 timestamp;     // 时间戳
    bool valid;           // 数据有效性

    ChannelData()
        : adValue(0)
        , voltage(0.0)
        , timestamp(0)
        , valid(false)
    {}
};

/**
 * @brief 模拟量数据管理器
 *
 * 管理2个模拟量输入模块的数据：
 * - 模块2（模块3）：模拟量输入1
 * - 模块3（模块4）：模拟量输入2
 * 每个模块8通道，每通道16位AD值
 */
class AIDataManager : public QObject
{
    Q_OBJECT

    // ========== 属性 ==========
    Q_PROPERTY(QVariantList module3Data READ module3Data NOTIFY module3DataChanged)
    Q_PROPERTY(QVariantList module4Data READ module4Data NOTIFY module4DataChanged)
    Q_PROPERTY(int changeThreshold READ changeThreshold
               WRITE setChangeThreshold NOTIFY changeThresholdChanged)

public:
    explicit AIDataManager(QObject *parent = nullptr);

    // ========== 属性访问器 ==========
    QVariantList module3Data() const;
    QVariantList module4Data() const;

    int changeThreshold() const { return m_changeThreshold; }
    void setChangeThreshold(int threshold);

    // ========== 公共方法 ==========
    Q_INVOKABLE void parseData(int moduleIndex, const QByteArray &payload);
    Q_INVOKABLE QVariantMap getChannel(int moduleIndex, int channelIndex) const;
    Q_INVOKABLE QVariantMap getModuleData(int moduleIndex) const;

signals:
    // 数据变化信号
    void module3DataChanged();
    void module4DataChanged();
    void dataChanged(int moduleIndex, const QVector<ChannelData> &data);
    void channelChanged(int moduleIndex, int channelIndex, const ChannelData &data);
    void changeThresholdChanged();

    // 解析错误信号
    void parseError(int moduleIndex, const QString &error);

private:
    // 解析 JSON 数据
    bool parseJsonData(int moduleIndex, const QByteArray &payload);

    // 检测变化
    void detectChanges(int moduleIndex, const QVector<ChannelData> &newData);

    // 转换为 QVariantMap
    QVariantMap channelDataToVariant(const ChannelData &data) const;

private:
    // 数据存储：2个模块，每个8通道
    QVector<QVector<ChannelData>> m_aiData;

    // 变化检测阈值（AD值变化超过此值才认为变化）
    int m_changeThreshold;
};

#endif // AIDATAMANAGER_H
