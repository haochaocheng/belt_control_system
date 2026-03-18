/**
 * @file CSDataManager.cpp
 * @brief CS模块（沿线点位保护）数据管理器实现
 * @date 2026-03-18
 * @phase 7.48.56
 */

#include "CSDataManager.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

CSDataManager::CSDataManager(QObject *parent)
    : QObject(parent)
    , m_pointCount(MAX_POINTS)
{
    // 初始化3种保护类型，每种64bit
    m_csData.resize(PROT_TYPE_COUNT);
    for (int i = 0; i < PROT_TYPE_COUNT; ++i) {
        m_csData[i].resize(MAX_POINTS);
        m_csData[i].fill(false);
    }

    qDebug() << "✅ [CSDataManager] 初始化CS模块数据管理器，点位数:" << m_pointCount;
}

void CSDataManager::setPointCount(int count)
{
    if (count < 1) count = 1;
    if (count > MAX_POINTS) count = MAX_POINTS;
    if (m_pointCount != count) {
        m_pointCount = count;
        emit pointCountChanged();
        qDebug() << "✅ [CSDataManager] 点位数量更新:" << m_pointCount;
    }
}

void CSDataManager::parseData(const QByteArray &payload)
{
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(payload, &error);

    if (error.error != QJsonParseError::NoError) {
        static bool warned = false;
        if (!warned) {
            qWarning() << "⚠️ [CSDataManager] JSON解析错误:" << error.errorString();
            warned = true;
        }
        emit parseError(error.errorString());
        return;
    }

    if (!doc.isObject()) {
        emit parseError("JSON不是对象");
        return;
    }

    QJsonObject obj = doc.object();

    // 解析3种保护类型
    static const QString keys[PROT_TYPE_COUNT] = {"estop", "deviation", "tear"};

    for (int i = 0; i < PROT_TYPE_COUNT; ++i) {
        if (obj.contains(keys[i]) && obj[keys[i]].isArray()) {
            parseByteArray(i, obj[keys[i]].toArray());
        }
    }
}

bool CSDataManager::getBit(int protType, int pointIndex) const
{
    if (protType < 0 || protType >= PROT_TYPE_COUNT) return false;
    if (pointIndex < 0 || pointIndex >= MAX_POINTS) return false;
    return m_csData[protType].testBit(pointIndex);
}

QVariantList CSDataManager::getProtectionData(int protType) const
{
    QVariantList list;
    if (protType < 0 || protType >= PROT_TYPE_COUNT) return list;

    for (int i = 0; i < m_pointCount; ++i) {
        list.append(m_csData[protType].testBit(i));
    }
    return list;
}

QVariantMap CSDataManager::getAllData() const
{
    QVariantMap data;
    data["estop"] = getProtectionData(Estop);
    data["deviation"] = getProtectionData(Deviation);
    data["tear"] = getProtectionData(Tear);
    data["pointCount"] = m_pointCount;
    return data;
}

void CSDataManager::reset()
{
    for (int t = 0; t < PROT_TYPE_COUNT; ++t) {
        QBitArray zeroData(MAX_POINTS);
        zeroData.fill(false);
        detectChanges(t, zeroData);
        m_csData[t] = zeroData;
        emit dataChanged(t);
    }
    qDebug() << "✅ [CSDataManager] 数据已重置（模块离线）";
}

QString CSDataManager::protectionTypeName(int protType)
{
    switch (protType) {
    case Estop:     return QStringLiteral("沿线急停");
    case Deviation: return QStringLiteral("沿线跑偏");
    case Tear:      return QStringLiteral("沿线撕裂");
    default:        return QStringLiteral("未知");
    }
}

// ========== 私有方法 ==========

void CSDataManager::parseByteArray(int protType, const QJsonArray &byteArray)
{
    if (byteArray.size() != 8) {
        static bool warned = false;
        if (!warned) {
            qWarning() << "⚠️ [CSDataManager] 字节数组长度不是8:" << byteArray.size()
                       << "保护类型:" << protectionTypeName(protType);
            warned = true;
        }
        return;
    }

    // 8字节 → 64bit
    QBitArray newData(MAX_POINTS);
    newData.fill(false);

    for (int byteIdx = 0; byteIdx < 8; ++byteIdx) {
        quint8 byte = static_cast<quint8>(byteArray[byteIdx].toInt());
        for (int bitIdx = 0; bitIdx < 8; ++bitIdx) {
            int pointIdx = byteIdx * 8 + bitIdx;
            if (pointIdx < MAX_POINTS) {
                newData.setBit(pointIdx, (byte & (1 << bitIdx)) != 0);
            }
        }
    }

    // 检测变化
    detectChanges(protType, newData);

    // 更新数据
    m_csData[protType] = newData;

    // 发送整体变化信号
    emit dataChanged(protType);
}

void CSDataManager::detectChanges(int protType, const QBitArray &newData)
{
    const QBitArray &oldData = m_csData[protType];

    for (int i = 0; i < qMin(m_pointCount, MAX_POINTS); ++i) {
        bool oldBit = oldData.testBit(i);
        bool newBit = newData.testBit(i);
        if (oldBit != newBit) {
            emit bitChanged(protType, i, newBit);
            qDebug() << "🔄 [CSDataManager]" << protectionTypeName(protType)
                     << "点位" << (i + 1) << "变化:" << oldBit << "→" << newBit;
        }
    }
}
