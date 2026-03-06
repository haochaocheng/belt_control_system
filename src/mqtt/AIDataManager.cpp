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
    , m_filterType("combined")  // ✅ 2026-03-06 [Phase 7.48.17]: 默认使用组合滤波器
    , m_filterEnabled(true)     // ✅ 2026-03-06 [Phase 7.48.17]: 默认启用滤波
{
    // 初始化2个模块，每个8通道
    m_aiData.resize(2);
    for (int i = 0; i < 2; ++i) {
        m_aiData[i].resize(8);
    }

    // ✅ 2026-03-06 [Phase 7.48.17]: 初始化滤波器
    initFilters();

    qDebug() << "✅ [AIDataManager] 初始化模拟量数据管理器（滤波器:" << m_filterType << "）";
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

// ✅ 2026-03-06 [Phase 7.48.17]: 设置滤波器类型
void AIDataManager::setFilterType(const QString &type)
{
    if (m_filterType != type) {
        m_filterType = type;
        initFilters();  // 重新初始化滤波器
        qDebug() << "✅ [AIDataManager] 滤波器类型:" << type;
        emit filterTypeChanged();
    }
}

// ✅ 2026-03-06 [Phase 7.48.17]: 设置滤波器启用状态
void AIDataManager::setFilterEnabled(bool enabled)
{
    if (m_filterEnabled != enabled) {
        m_filterEnabled = enabled;
        qDebug() << "✅ [AIDataManager] 滤波器" << (enabled ? "启用" : "禁用");
        emit filterEnabledChanged();
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
        // ✅ 2026-03-06 [Phase 7.48.17]: 应用滤波器
        quint16 rawValue = static_cast<quint16>(chObj["value"].toInt());
        ch.adValue = applyFilter(dataIndex, i, rawValue);
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

    // ✅ 2026-02-26 19:55 [Phase 7.47.16.2]: 移除高频数据更新日志
    // 原因：每秒多次打印，日志文件中重复3,176次
    // qDebug() << "✅ [AIDataManager] 模块" << (dataIndex + 2) << "数据更新";

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

            // ✅ 2026-02-26 19:55 [Phase 7.47.16.2]: 移除高频通道变化日志
            // 原因：模拟量变化频繁，日志文件中重复10,000+次
            // qDebug() << "🔄 [AIDataManager] 模块" << (dataIndex + 2)
            //          << "通道" << i << "变化:"
            //          << oldData[i].adValue << "→" << newData[i].adValue
            //          << "(" << newData[i].voltage << "V)";
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

// ✅ 2026-03-06 [Phase 7.48.17]: 初始化滤波器
void AIDataManager::initFilters()
{
    // 清理旧滤波器
    for (auto &moduleFilters : m_filters) {
        for (auto *filter : moduleFilters) {
            delete filter;
        }
    }
    m_filters.clear();

    // 创建新滤波器（2个模块×8通道）
    m_filters.resize(2);
    for (int i = 0; i < 2; ++i) {
        m_filters[i].resize(8);
        for (int j = 0; j < 8; ++j) {
            if (m_filterType == "median") {
                m_filters[i][j] = new MedianFilter(5);  // 5点中值滤波
            } else if (m_filterType == "average") {
                m_filters[i][j] = new MovingAverageFilter(8);  // 8点滑动平均
            } else if (m_filterType == "limit") {
                m_filters[i][j] = new LimitFilter(100);  // 限幅100
            } else if (m_filterType == "lag") {
                m_filters[i][j] = new FirstOrderLagFilter(0.3);  // 滞后系数0.3
            } else if (m_filterType == "combined") {
                m_filters[i][j] = new CombinedFilter(5, 8);  // 中值5点+平均8点
            } else if (m_filterType == "lightweight") {
                m_filters[i][j] = new LightweightFilter(100, 0.3);  // 限幅100+滞后0.3
            } else {
                m_filters[i][j] = nullptr;  // 无滤波
            }
        }
    }

    qDebug() << "✅ [AIDataManager] 滤波器初始化完成，类型:" << m_filterType;
}

// ✅ 2026-03-06 [Phase 7.48.17]: 应用滤波
quint16 AIDataManager::applyFilter(int moduleIndex, int channelIndex, quint16 rawValue)
{
    // 滤波器未启用，直接返回原始值
    if (!m_filterEnabled) {
        return rawValue;
    }

    // 检查索引有效性
    if (moduleIndex < 0 || moduleIndex >= 2 || channelIndex < 0 || channelIndex >= 8) {
        return rawValue;
    }

    // 获取滤波器
    ADFilterBase *filter = m_filters[moduleIndex][channelIndex];
    if (!filter) {
        return rawValue;  // 无滤波器，返回原始值
    }

    // 应用滤波
    return filter->filter(rawValue);
}
