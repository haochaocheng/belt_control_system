// ✅ 2026-01-22 20:30 [FIX 100.295] 独立音频发送线程
// 文件: src/audio_network/AudioSenderWorker.h
// 功能: 在独立线程中发送 Opus 音频帧，不受主线程干扰
// 作者: Claude AI
// 日期: 2026-01-22

#ifndef AUDIOSENDERWORKER_H
#define AUDIOSENDERWORKER_H

#include <QObject>
#include <QTimer>
#include <QElapsedTimer>
#include <QByteArray>
#include <QList>
#include "WebSocketClient.h"

/**
 * @brief 音频发送工作类（运行在独立线程）
 *
 * 功能：
 * - 接收主线程编码好的 Opus 帧列表
 * - 在独立线程中精确控制发送节奏（20ms 间隔）
 * - 不受主线程 UI/数据库/键盘事件干扰
 * - 适应恶劣网络环境
 *
 * 工作流程：
 * 1. 主线程调用 startSending(opusFrames)
 * 2. 信号跨线程传递到独立线程（Qt::QueuedConnection）
 * 3. 独立线程启动定时发送（20ms 精确间隔）
 * 4. 发送完成后通知主线程
 *
 * 线程安全：
 * - 所有公共方法都通过信号槽调用（Qt 自动处理线程安全）
 * - QByteArray 是隐式共享的（线程安全）
 */
class AudioSenderWorker : public QObject
{
    Q_OBJECT

public:
    /**
     * @brief 构造函数
     * @param wsClient WebSocket 客户端（必须在构造时传入）
     * @param parent 父对象
     *
     * 注意：
     * - wsClient 将被移动到独立线程（moveToThread）
     * - 必须在主线程构造，然后移动到独立线程
     */
    explicit AudioSenderWorker(WebSocketClient* wsClient, QObject *parent = nullptr);

    /**
     * @brief 析构函数
     */
    ~AudioSenderWorker();

signals:
    // ========== 发送进度信号 ==========

    /**
     * @brief 发送开始信号
     * @param totalFrames 总帧数
     */
    void sendingStarted(int totalFrames);

    /**
     * @brief 发送进度信号
     * @param framesSent 已发送帧数
     * @param totalFrames 总帧数
     */
    void sendingProgress(int framesSent, int totalFrames);

    /**
     * @brief 发送完成信号
     */
    void sendingFinished();

    /**
     * @brief 发送错误信号
     * @param error 错误描述
     */
    void sendingError(const QString& error);

public slots:
    // ========== 控制接口（跨线程调用）==========

    /**
     * @brief 开始发送 Opus 帧
     * @param frames Opus 帧列表
     *
     * 说明：
     * - 此方法由主线程调用
     * - 通过 Qt::QueuedConnection 跨线程传递
     * - 在独立线程中执行实际发送
     */
    void startSending(const QList<QByteArray>& frames);

    /**
     * @brief 停止发送
     *
     * 说明：
     * - 立即停止当前发送任务
     * - 清空发送队列
     */
    void stopSending();

private slots:
    /**
     * @brief 发送下一帧（定时器触发）
     */
    void sendNextFrame();

private:
    // WebSocket 客户端
    WebSocketClient* m_wsClient;       ///< WebSocket 客户端（已移到独立线程）

    // 发送状态
    QList<QByteArray> m_frames;        ///< 当前发送的 Opus 帧列表
    int m_currentFrameIndex;           ///< 当前发送帧索引
    int m_totalFrames;                 ///< 总帧数
    bool m_isSending;                  ///< 是否正在发送

    // 定时器
    QTimer* m_sendTimer;               ///< 发送定时器（20ms 精确定时）
    QElapsedTimer m_elapsedTimer;      ///< 时间计数器（用于绝对时间戳控制）
    qint64 m_sendStartTime;            ///< 发送开始时间戳
};

#endif // AUDIOSENDERWORKER_H
