/**
 * @file DIDataManager.h
 * @brief 开关量数据管理器
 * @date 2026-02-09
 * @phase 7.44.3
 *
 * 功能：
 * - 解析开关量数据（8位布尔值）
 * - 数据存储和缓存
 * - 变化检测（逐位检测）
 * - 信号通知
 */

#ifndef DIDATAMANAGER_H
#define DIDATAMANAGER_H

#include <QObject>
#include <QVector>
#include <QVariantMap>
#include <QVariantList>

/**
 * @brief 开关量数据管理器
 *
 * 管理2个开关量输入模块的数据：
 * - 模块0（模块1）：开关量输入1
 * - 模块1（模块2）：开关量输入2
 * 每个模块8位开关量状态
 */
class DIDataManager : public QObject
{
    Q_OBJECT

    // ========== 属性 ==========
    Q_PROPERTY(QVariantList module1Data READ module1Data NOTIFY module1DataChanged)
    Q_PROPERTY(QVariantList module2Data READ module2Data NOTIFY module2DataChanged)

public:
    explicit DIDataManager(QObject *parent = nullptr);

    // ========== 属性访问器 ==========
    QVariantList module1Data() const;
    QVariantList module2Data() const;

    // ========== 公共方法 ==========
    Q_INVOKABLE void parseData(int moduleIndex, const QByteArray &payload);
    Q_INVOKABLE bool getBit(int moduleIndex, int bitIndex) const;
    Q_INVOKABLE quint8 getByte(int moduleIndex) const;
    Q_INVOKABLE QVariantMap getModuleData(int moduleIndex) const;

signals:
    // 数据变化信号
    void module1DataChanged();
    void module2DataChanged();
    void dataChanged(int moduleIndex, const QVector<bool> &data);
    void bitChanged(int moduleIndex, int bitIndex, bool value);

    // 解析错误信号
    void parseError(int moduleIndex, const QString &error);

private:
    // 解析 JSON 数据
    bool parseJsonData(int moduleIndex, const QByteArray &payload);

    // 检测变化
    void detectChanges(int moduleIndex, const QVector<bool> &newData);

    // 字节转位数组
    QVector<bool> byteToBits(quint8 byte) const;

    // 位数组转字节
    quint8 bitsToByte(const QVector<bool> &bits) const;

private:
    // 数据存储：2个模块，每个8位
    QVector<QVector<bool>> m_diData;
};

#endif // DIDATAMANAGER_H
