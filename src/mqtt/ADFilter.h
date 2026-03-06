/**
 * @file ADFilter.h
 * @brief AD值滤波器
 * @date 2026-03-06
 * @phase 7.48.17
 *
 * 功能：
 * - 中值滤波：去除脉冲干扰
 * - 滑动平均滤波：平滑数据
 * - 限幅滤波：去除异常值
 * - 一阶滞后滤波：平滑慢变化量
 */

#ifndef ADFILTER_H
#define ADFILTER_H

#include <QVector>
#include <QtMath>
#include <algorithm>

/**
 * @brief AD值滤波器基类
 */
class ADFilterBase
{
public:
    virtual ~ADFilterBase() = default;
    virtual quint16 filter(quint16 newValue) = 0;
    virtual void reset() = 0;
};

/**
 * @brief 中值滤波器
 *
 * 原理：取最近N个采样值的中值
 * 优点：去除脉冲干扰效果好
 * 缺点：计算量较大
 * 适用：偶然出现的脉冲干扰
 */
class MedianFilter : public ADFilterBase
{
public:
    explicit MedianFilter(int windowSize = 5)
        : m_windowSize(windowSize)
    {
        m_buffer.reserve(windowSize);
    }

    quint16 filter(quint16 newValue) override
    {
        // 添加新值
        m_buffer.append(newValue);

        // 保持窗口大小
        if (m_buffer.size() > m_windowSize) {
            m_buffer.removeFirst();
        }

        // 计算中值
        if (m_buffer.isEmpty()) {
            return newValue;
        }

        QVector<quint16> sorted = m_buffer;
        std::sort(sorted.begin(), sorted.end());

        int mid = sorted.size() / 2;
        if (sorted.size() % 2 == 0) {
            return (sorted[mid - 1] + sorted[mid]) / 2;
        } else {
            return sorted[mid];
        }
    }

    void reset() override
    {
        m_buffer.clear();
    }

private:
    int m_windowSize;
    QVector<quint16> m_buffer;
};

/**
 * @brief 滑动平均滤波器
 *
 * 原理：取最近N个采样值的算术平均
 * 优点：简单高效，平滑效果好
 * 缺点：响应慢，占用内存
 * 适用：周期性干扰
 */
class MovingAverageFilter : public ADFilterBase
{
public:
    explicit MovingAverageFilter(int windowSize = 10)
        : m_windowSize(windowSize)
        , m_sum(0)
    {
        m_buffer.reserve(windowSize);
    }

    quint16 filter(quint16 newValue) override
    {
        // 添加新值
        m_buffer.append(newValue);
        m_sum += newValue;

        // 保持窗口大小
        if (m_buffer.size() > m_windowSize) {
            m_sum -= m_buffer.first();
            m_buffer.removeFirst();
        }

        // 计算平均值
        if (m_buffer.isEmpty()) {
            return newValue;
        }

        return static_cast<quint16>(m_sum / m_buffer.size());
    }

    void reset() override
    {
        m_buffer.clear();
        m_sum = 0;
    }

private:
    int m_windowSize;
    QVector<quint16> m_buffer;
    quint64 m_sum;
};

/**
 * @brief 限幅滤波器
 *
 * 原理：相邻两次采样值差值超过阈值则认为异常，使用上次值
 * 优点：简单快速
 * 缺点：无法抑制周期性干扰
 * 适用：慢变化信号
 */
class LimitFilter : public ADFilterBase
{
public:
    explicit LimitFilter(quint16 maxDelta = 1000)
        : m_maxDelta(maxDelta)
        , m_lastValue(0)
        , m_initialized(false)
    {
    }

    quint16 filter(quint16 newValue) override
    {
        if (!m_initialized) {
            m_lastValue = newValue;
            m_initialized = true;
            return newValue;
        }

        // 检查变化是否超过阈值
        quint16 delta = qAbs(static_cast<int>(newValue) - static_cast<int>(m_lastValue));

        if (delta > m_maxDelta) {
            // 变化过大，认为是干扰，使用上次值
            return m_lastValue;
        } else {
            // 正常变化，更新并返回
            m_lastValue = newValue;
            return newValue;
        }
    }

    void reset() override
    {
        m_initialized = false;
        m_lastValue = 0;
    }

private:
    quint16 m_maxDelta;
    quint16 m_lastValue;
    bool m_initialized;
};

/**
 * @brief 一阶滞后滤波器（指数移动平均）
 *
 * 原理：Y(n) = α * X(n) + (1-α) * Y(n-1)
 * 优点：平滑效果好，占用内存少
 * 缺点：相位滞后
 * 适用：温度、液位等慢变化量
 *
 * @param alpha 滤波系数（0-1），越大响应越快，越小越平滑
 *              推荐值：0.1-0.3
 */
class FirstOrderLagFilter : public ADFilterBase
{
public:
    explicit FirstOrderLagFilter(double alpha = 0.2)
        : m_alpha(alpha)
        , m_lastValue(0.0)
        , m_initialized(false)
    {
        if (alpha < 0.0) m_alpha = 0.0;
        if (alpha > 1.0) m_alpha = 1.0;
    }

    quint16 filter(quint16 newValue) override
    {
        if (!m_initialized) {
            m_lastValue = newValue;
            m_initialized = true;
            return newValue;
        }

        // Y(n) = α * X(n) + (1-α) * Y(n-1)
        m_lastValue = m_alpha * newValue + (1.0 - m_alpha) * m_lastValue;

        return static_cast<quint16>(qRound(m_lastValue));
    }

    void reset() override
    {
        m_initialized = false;
        m_lastValue = 0.0;
    }

private:
    double m_alpha;
    double m_lastValue;
    bool m_initialized;
};

/**
 * @brief 组合滤波器：中值滤波 + 滑动平均
 *
 * 原理：先用中值滤波去除脉冲干扰，再用滑动平均平滑数据
 * 优点：综合效果好，适合工业场景
 * 缺点：计算量较大
 */
class CombinedFilter : public ADFilterBase
{
public:
    explicit CombinedFilter(int medianWindow = 5, int avgWindow = 10)
        : m_medianFilter(medianWindow)
        , m_avgFilter(avgWindow)
    {
    }

    quint16 filter(quint16 newValue) override
    {
        // 先中值滤波
        quint16 medianValue = m_medianFilter.filter(newValue);

        // 再滑动平均
        quint16 avgValue = m_avgFilter.filter(medianValue);

        return avgValue;
    }

    void reset() override
    {
        m_medianFilter.reset();
        m_avgFilter.reset();
    }

private:
    MedianFilter m_medianFilter;
    MovingAverageFilter m_avgFilter;
};

/**
 * @brief 组合滤波器：限幅 + 一阶滞后
 *
 * 原理：先用限幅滤波去除异常值，再用一阶滞后平滑数据
 * 优点：轻量级，响应快
 * 缺点：对周期性干扰效果一般
 */
class LightweightFilter : public ADFilterBase
{
public:
    explicit LightweightFilter(quint16 maxDelta = 1000, double alpha = 0.2)
        : m_limitFilter(maxDelta)
        , m_lagFilter(alpha)
    {
    }

    quint16 filter(quint16 newValue) override
    {
        // 先限幅滤波
        quint16 limitValue = m_limitFilter.filter(newValue);

        // 再一阶滞后
        quint16 lagValue = m_lagFilter.filter(limitValue);

        return lagValue;
    }

    void reset() override
    {
        m_limitFilter.reset();
        m_lagFilter.reset();
    }

private:
    LimitFilter m_limitFilter;
    FirstOrderLagFilter m_lagFilter;
};

#endif // ADFILTER_H
