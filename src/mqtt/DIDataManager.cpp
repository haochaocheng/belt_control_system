/**
 * @file DIDataManager.cpp
 * @brief 开关量数据管理器实现
 * @date 2026-02-09
 * @phase 7.44.3
 */

#include "DIDataManager.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

DIDataManager::DIDataManager(QObject *parent)
    : QObject(parent)
{
    // 初始化2个模块，每个8位，初始值为0
    m_diData.resize(2);
    for (int i = 0; i < 2; ++i) {
        m_diData[i].resize(8, false);
    }

    qDebug() << "✅ [DIDataManager] 初始化开关量数据管理器";
}

// ========== 属性访问器 ==========

QVariantList DIDataManager::module1Data() const
{
    QVariantList list;
    if (m_diData.size() > 0) {
        for (bool bit : m_diData[0]) {
            list.append(bit);
        }
    }
    return list;
}

QVariantList DIDataManager::module2Data() const
{
    QVariantList list;
    if (m_diData.size() > 1) {
        for (bool bit : m_diData[1]) {
            list.append(bit);
        }
    }
    return list;
}

// ========== 公共方法 ==========

void DIDataManager::parseData(int moduleIndex, const QByteArray &payload)
{
    if (moduleIndex < 0 || moduleIndex >= 2) {
        qWarning() << "⚠️ [DIDataManager] 无效的模块索引:" << moduleIndex;
        return;
    }

    if (!parseJsonData(moduleIndex, payload)) {
        emit parseError(moduleIndex, "JSON解析失败");
    }
}

bool DIDataManager::getBit(int moduleIndex, int bitIndex) const
{
    if (moduleIndex < 0 || moduleIndex >= 2) {
        return false;
    }
    if (bitIndex < 0 || bitIndex >= 8) {
        return false;
    }
    return m_diData[moduleIndex][bitIndex];
}

quint8 DIDataManager::getByte(int moduleIndex) const
{
    if (moduleIndex < 0 || moduleIndex >= 2) {
        return 0;
    }
    return bitsToByte(m_diData[moduleIndex]);
}

QVariantMap DIDataManager::getModuleData(int moduleIndex) const
{
    QVariantMap data;

    if (moduleIndex >= 0 && moduleIndex < 2) {
        QVariantList bits;
        for (bool bit : m_diData[moduleIndex]) {
            bits.append(bit);
        }

        data["moduleIndex"] = moduleIndex;
        data["bits"] = bits;
        data["byte"] = getByte(moduleIndex);
    }

    return data;
}

// ========== 私有方法 ==========

bool DIDataManager::parseJsonData(int moduleIndex, const QByteArray &payload)
{
    // 解析 JSON
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(payload, &error);

    if (error.error != QJsonParseError::NoError) {
        qWarning() << "⚠️ [DIDataManager] JSON解析错误:" << error.errorString();
        return false;
    }

    if (!doc.isObject()) {
        qWarning() << "⚠️ [DIDataManager] JSON不是对象";
        return false;
    }

    QJsonObject obj = doc.object();

    // 检查必要字段
    if (!obj.contains("data") || !obj["data"].isObject()) {
        qWarning() << "⚠️ [DIDataManager] 缺少data字段";
        return false;
    }

    QJsonObject dataObj = obj["data"].toObject();

    // 解析位数组
    QVector<bool> newData;

    if (dataObj.contains("bits") && dataObj["bits"].isArray()) {
        // 从bits数组解析
        QJsonArray bitsArray = dataObj["bits"].toArray();

        if (bitsArray.size() != 8) {
            qWarning() << "⚠️ [DIDataManager] bits数组长度不是8:" << bitsArray.size();
            return false;
        }

        for (int i = 0; i < 8; ++i) {
            newData.append(bitsArray[i].toInt() != 0);
        }
    } else if (dataObj.contains("byte")) {
        // 从byte解析
        quint8 byte = static_cast<quint8>(dataObj["byte"].toInt());
        newData = byteToBits(byte);
    } else {
        qWarning() << "⚠️ [DIDataManager] 缺少bits或byte字段";
        return false;
    }

    // 检测变化
    detectChanges(moduleIndex, newData);

    // 更新数据
    m_diData[moduleIndex] = newData;

    // 发送信号
    if (moduleIndex == 0) {
        emit module1DataChanged();
    } else {
        emit module2DataChanged();
    }

    qDebug() << "✅ [DIDataManager] 模块" << moduleIndex << "数据更新:"
             << "byte=" << getByte(moduleIndex);

    return true;
}

void DIDataManager::detectChanges(int moduleIndex, const QVector<bool> &newData)
{
    if (newData.size() != 8) {
        return;
    }

    const QVector<bool> &oldData = m_diData[moduleIndex];

    // 检查整体是否变化
    bool hasChange = false;
    for (int i = 0; i < 8; ++i) {
        if (oldData[i] != newData[i]) {
            hasChange = true;
            // 发送单个位变化信号
            emit bitChanged(moduleIndex, i, newData[i]);
            qDebug() << "🔄 [DIDataManager] 模块" << moduleIndex
                     << "位" << i << "变化:" << oldData[i] << "→" << newData[i];
        }
    }

    // 发送整体变化信号
    if (hasChange) {
        emit dataChanged(moduleIndex, newData);
    }
}

QVector<bool> DIDataManager::byteToBits(quint8 byte) const
{
    QVector<bool> bits(8);
    for (int i = 0; i < 8; ++i) {
        bits[i] = (byte & (1 << i)) != 0;
    }
    return bits;
}

quint8 DIDataManager::bitsToByte(const QVector<bool> &bits) const
{
    if (bits.size() != 8) {
        return 0;
    }

    quint8 byte = 0;
    for (int i = 0; i < 8; ++i) {
        if (bits[i]) {
            byte |= (1 << i);
        }
    }
    return byte;
}
