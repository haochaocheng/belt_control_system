/**
 * @file DODataManager.h
 * @brief DO模块数据管理器（继电器输出状态+反馈输入+急停）
 * @date 2026-03-10
 * @phase 7.48.36
 *
 * 功能：
 * - 解析DO模块状态数据（do_states, di_feedback, estop）
 * - 数据存储和缓存
 * - 变化检测（逐位检测）
 * - 信号通知
 *
 * DO模块MQTT消息格式（belt_control/do/module1/status）：
 * {
 *   "module": 1, "type": "do", "timestamp": ...,
 *   "data": {
 *     "do_states": [1,0,1,0,0,0,0,0], "do_byte": 5,
 *     "di_feedback": [1,0,1,0,0,0,0,0], "di_byte": 5,
 *     "estop": 0, "estop_raw": 0
 *   },
 *   "quality": "good"
 * }
 */

#ifndef DODATAMANAGER_H
#define DODATAMANAGER_H

#include <QObject>
#include <QVector>
#include <QVariantMap>
#include <QVariantList>

class DODataManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList doStates READ doStates NOTIFY doStatesChanged)
    Q_PROPERTY(QVariantList diFeedback READ diFeedback NOTIFY diFeedbackChanged)
    Q_PROPERTY(bool estop READ estop NOTIFY estopChanged)

public:
    explicit DODataManager(QObject *parent = nullptr);

    // ========== 属性访问器 ==========
    QVariantList doStates() const;
    QVariantList diFeedback() const;
    bool estop() const;

    // ========== 公共方法 ==========
    Q_INVOKABLE void parseData(const QByteArray &payload);
    Q_INVOKABLE bool getDoState(int channel) const;
    Q_INVOKABLE bool getFeedback(int channel) const;
    Q_INVOKABLE bool getEstop() const;
    Q_INVOKABLE void reset();

signals:
    void doStatesChanged();
    void diFeedbackChanged();
    void estopChanged();
    void doStateChanged(int channel, bool value);
    void feedbackChanged(int channel, bool value);
    void parseError(const QString &error);

private:
    bool parseJsonData(const QByteArray &payload);

    QVector<bool> m_doStates;    // 8路继电器输出状态
    QVector<bool> m_diFeedback;  // 8路反馈输入状态
    bool m_estop;                // 急停状态
};

#endif // DODATAMANAGER_H
