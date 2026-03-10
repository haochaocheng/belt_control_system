/**
 * @file DODataManager.cpp
 * @brief DO模块数据管理器实现
 * @date 2026-03-10
 * @phase 7.48.36
 */

#include "DODataManager.h"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

DODataManager::DODataManager(QObject *parent)
    : QObject(parent)
    , m_doStates(8, false)
    , m_diFeedback(8, false)
    , m_estop(false)
{
    qDebug() << "✅ [DODataManager] 初始化DO模块数据管理器";
}

// ========== 属性访问器 ==========

QVariantList DODataManager::doStates() const
{
    QVariantList list;
    for (bool bit : m_doStates) {
        list.append(bit);
    }
    return list;
}

QVariantList DODataManager::diFeedback() const
{
    QVariantList list;
    for (bool bit : m_diFeedback) {
        list.append(bit);
    }
    return list;
}

bool DODataManager::estop() const
{
    return m_estop;
}

// ========== 公共方法 ==========

void DODataManager::parseData(const QByteArray &payload)
{
    if (!parseJsonData(payload)) {
        emit parseError("JSON解析失败");
    }
}

bool DODataManager::getDoState(int channel) const
{
    if (channel < 0 || channel >= 8) return false;
    return m_doStates[channel];
}

bool DODataManager::getFeedback(int channel) const
{
    if (channel < 0 || channel >= 8) return false;
    return m_diFeedback[channel];
}

bool DODataManager::getEstop() const
{
    return m_estop;
}

void DODataManager::reset()
{
    bool changed = false;
    for (int i = 0; i < 8; ++i) {
        if (m_doStates[i]) { m_doStates[i] = false; changed = true; }
        if (m_diFeedback[i]) { m_diFeedback[i] = false; changed = true; }
    }
    if (m_estop) { m_estop = false; emit estopChanged(); }
    if (changed) {
        emit doStatesChanged();
        emit diFeedbackChanged();
    }
    qDebug() << "✅ [DODataManager] 数据已重置";
}

bool DODataManager::parseJsonData(const QByteArray &payload)
{
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(payload, &error);
    if (error.error != QJsonParseError::NoError) {
        return false;
    }

    QJsonObject root = doc.object();
    QJsonObject data = root["data"].toObject();
    if (data.isEmpty()) {
        return false;
    }

    // 解析 do_states
    QJsonArray doArr = data["do_states"].toArray();
    if (doArr.size() == 8) {
        bool doChanged = false;
        for (int i = 0; i < 8; ++i) {
            bool newVal = (doArr[i].toInt() != 0);
            if (m_doStates[i] != newVal) {
                m_doStates[i] = newVal;
                doChanged = true;
                emit doStateChanged(i, newVal);
            }
        }
        if (doChanged) emit doStatesChanged();
    }

    // 解析 di_feedback
    QJsonArray diArr = data["di_feedback"].toArray();
    if (diArr.size() == 8) {
        bool diChanged = false;
        for (int i = 0; i < 8; ++i) {
            bool newVal = (diArr[i].toInt() != 0);
            if (m_diFeedback[i] != newVal) {
                m_diFeedback[i] = newVal;
                diChanged = true;
                emit feedbackChanged(i, newVal);
            }
        }
        if (diChanged) emit diFeedbackChanged();
    }

    // 解析 estop
    bool newEstop = (data["estop"].toInt() != 0);
    if (m_estop != newEstop) {
        m_estop = newEstop;
        emit estopChanged();
    }

    return true;
}
