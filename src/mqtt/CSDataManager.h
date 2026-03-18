/**
 * @file CSDataManager.h
 * @brief CS模块（沿线点位保护）数据管理器
 * @date 2026-03-18
 * @phase 7.48.56
 *
 * 功能：
 * - 解析CS模块数据（3种保护类型×64点位）
 * - 数据存储和缓存
 * - 变化检测（逐位检测，边沿触发）
 * - 信号通知
 *
 * CS模块MQTT数据格式：
 * {
 *   "estop": [byte0, byte1, ..., byte7],      // 沿线急停 64bit
 *   "deviation": [byte0, byte1, ..., byte7],   // 沿线跑偏 64bit
 *   "tear": [byte0, byte1, ..., byte7],        // 沿线撕裂 64bit
 *   "timestamp": 1234567890
 * }
 * 每个字段8字节=64bit，data[0] bit0=1号点位
 */

#ifndef CSDATAMANAGER_H
#define CSDATAMANAGER_H

#include <QObject>
#include <QVector>
#include <QBitArray>
#include <QVariantMap>
#include <QVariantList>

class CSDataManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int pointCount READ pointCount WRITE setPointCount NOTIFY pointCountChanged)

public:
    // 保护类型枚举
    enum ProtectionType {
        Estop = 0,      // 沿线急停
        Deviation = 1,  // 沿线跑偏
        Tear = 2        // 沿线撕裂
    };
    Q_ENUM(ProtectionType)

    static const int MAX_POINTS = 64;
    static const int PROT_TYPE_COUNT = 3;

    explicit CSDataManager(QObject *parent = nullptr);

    // ========== 属性 ==========
    int pointCount() const { return m_pointCount; }
    void setPointCount(int count);

    // ========== 公共方法 ==========
    Q_INVOKABLE void parseData(const QByteArray &payload);
    Q_INVOKABLE bool getBit(int protType, int pointIndex) const;
    Q_INVOKABLE QVariantList getProtectionData(int protType) const;
    Q_INVOKABLE QVariantMap getAllData() const;
    Q_INVOKABLE void reset();

    // 保护类型名称
    Q_INVOKABLE static QString protectionTypeName(int protType);

signals:
    void pointCountChanged();
    void bitChanged(int protType, int pointIndex, bool value);
    void dataChanged(int protType);
    void parseError(const QString &error);

private:
    // 解析8字节数组为64bit
    void parseByteArray(int protType, const QJsonArray &byteArray);

    // 检测变化并发信号
    void detectChanges(int protType, const QBitArray &newData);

private:
    // 3种保护类型 × 64 bit
    QVector<QBitArray> m_csData;
    int m_pointCount;
};

#endif // CSDATAMANAGER_H
