/**
 * @file AIDataManager.cpp
 * @brief 模拟量数据管理器实现
 * @date 2026-02-09
 * @phase 7.44.4
 */

#include "AIDataManager.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QtMath>

AIDataManager::AIDataManager(QObject *parent)
    : QObject(parent)
    , m_changeThreshold(10)  // 默认阈值：AD值变化>10
{
    // 初始化2个模块，每个8通道
    m_aiData.resize(2);
    for (int i = 0; i < 2; ++i) {
        m_aiData[i].resize(8);
    }

    qDebug() << "✅ [AIDataManager] 初始化模拟量数据管理器";
}

// ========== 属性访问器 ==========

QVariantList AIDataManager::module3Data() const
{
    QVariantList list;
    if (m_aiData.size() > 0) {
        for (const ChannelData &ch : m_aiData[0]) {
            list.append(channelDataToVariant(ch));
        }
    }
    return list;
}

QVariantList AIDataManager::module4Data() const
{
    QVariantList list;
    if (m_aiData.size() > 1) {
        for (const ChannelData &ch : m_aiData[1]) {
            list.append(channelDataToVariant(ch));
        }
    }
    return list;
}

void AIDataManager::setChangeThreshold(int threshold)
{
    if (threshold < 0 || threshold > 1000) {
        qWarning() << "⚠️ [AIDataManager] 无效的变化阈值:" << threshold;
        return;
    }

    if (m_changeThreshold != threshold) {
        m_changeThreshold = threshold;
        qDebug() << "✅ [AIDataManager] 变化阈值:" << threshold;
        emit changeThresholdChanged();
    }
}

// ========== 公共方法 ==========

void AIDataManager::parseData(int moduleIndex, const QByteArray &payload)
{
    // 模块索引转换：模块2→索引0，模块3→索引1
    int dataIndex = moduleIndex - 2;

    if (dataIndex < 0 || dataIndex >= 2) {
        qWarning() << "⚠️ [AIDataManager] 无效的模块索引:" << moduleIndex;
        return;
    }

    if (!parseJsonData(dataIndex, payload)) {
        emit parseError(moduleIndex, "JSON解析失败");
    }
}

QVariantMap AIDataManager::getChannel(int moduleIndex, int channelIndex) const
{
    int dataIndex = moduleIndex - 2;

    if (dataIndex < 0 || dataIndex >= 2) {
        return QVariantMap();
    }
    if (channelIndex < 0 || channelIndex >= 8) {
        return QVariantMap();
    }

    return channelDataToVariant(m_aiData[dataIndex][channelIndex]);
}

QVariantMap AIDataManager::getModuleData(int moduleIndex) const
{
    int dataIndex = moduleIndex - 2;

    QVariantMap data;

    if (dataIndex >= 0 && dataIndex < 2) {
        QVariantList channels;
        for (const ChannelData &ch : m_aiData[dataIndex]) {
            channels.append(channelDataToVariant(ch));
        }

        data["moduleIndex"] = moduleIndex;
        data["channels"] = channels;
    }

    return data;
}

// ========== 私有方法 ==========

bool AIDataManager::parseJsonData(int dataIndex, const QByteArray &payload)
{
    // 解析 JSON
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(payload, &error);

    if (error.error != QJsonParseError::NoError) {
        qWarning() << "⚠️ [AIDataManager] JSON解析错误:" << error.errorString();
        return false;
    }

    if (!doc.isObject()) {
        qWarning() << "⚠️ [AIDataManager] JSON不是对象";
        return false;
    }

    QJsonObject obj = doc.object();

    // 检查必要字段
    if (!obj.contains("data") || !obj["data"].isObject()) {
        qWarning() << "⚠️ [AIDataManager] 缺少data字段";
        return false;
    }

    QJsonObject dataObj = obj["data"].toObject();

    if (!dataObj.contains("channels") || !dataObj["channels"].isArray()) {
        qWarning() << "⚠️ [AIDataManager] 缺少channels字段";
        return false;
    }

    QJsonArray channelsArray = dataObj["channels"].toArray();

    if (channelsArray.size() != 8) {
        qWarning() << "⚠️ [AIDataManager] channels数组长度不是8:" << channelsArray.size();
        return false;
    }

    // 解析通道数据
    QVector<ChannelData> newData(8);
    qint64 timestamp = obj["timestamp"].toVariant().toLongLong();

    for (int i = 0; i < 8; ++i) {
        QJsonObject chObj = channelsArray[i].toObject();

        ChannelData &ch = newData[i];
        ch.adValue = static_cast<quint16>(chObj["value"].toInt());
        ch.voltage = chObj["voltage"].toDouble();
        ch.timestamp = timestamp;
        ch.valid = true;
    }

    // 检测变化
    detectChanges(dataIndex, newData);

    // 更新数据
    m_aiData[dataIndex] = newData;

    // 发送信号
    if (dataIndex == 0) {
        emit module3DataChanged();
    } else {
        emit module4DataChanged();
    }

    qDebug() << "✅ [AIDataManager] 模块" << (dataIndex + 2) << "数据更新";

    return true;
}

void AIDataManager::detectChanges(int dataIndex, const QVector<ChannelData> &newData)
{
    if (newData.size() != 8) {
        return;
    }

    const QVector<ChannelData> &oldData = m_aiData[dataIndex];

    bool hasChange = false;

    for (int i = 0; i < 8; ++i) {
        // 计算AD值变化
        int diff = qAbs(static_cast<int>(oldData[i].adValue) - static_cast<int>(newData[i].adValue));

        if (diff > m_changeThreshold) {
            hasChange = true;

            // 发送单个通道变化信号
            emit channelChanged(dataIndex + 2, i, newData[i]);

            qDebug() << "🔄 [AIDataManager] 模块" << (dataIndex + 2)
                     << "通道" << i << "变化:"
                     << oldData[i].adValue << "→" << newData[i].adValue
                     << "(" << newData[i].voltage << "V)";
        }
    }

    // 发送整体变化信号
    if (hasChange) {
        emit dataChanged(dataIndex + 2, newData);
    }
}

QVariantMap AIDataManager::channelDataToVariant(const ChannelData &data) const
{
    QVariantMap map;
    map["adValue"] = data.adValue;
    map["voltage"] = data.voltage;
    map["timestamp"] = data.timestamp;
    map["valid"] = data.valid;
    return map;
}
