#ifndef PADDLESPEECHADAPTER_H
#define PADDLESPEECHADAPTER_H

#include "TTSEngineAdapter.h"
#include <QProcess>
#include <QMutex>
#include <QJsonObject>
#include <atomic>

/**
 * @brief PaddleSpeech 适配器
 *
 * 通过 Python 进程通信实现 PaddleSpeech 语音合成
 *
 * ✅ 2026-02-13 [Phase 7.46.3]: 创建 PaddleSpeech 适配器
 */
class PaddleSpeechAdapter : public TTSEngineAdapter
{
    Q_OBJECT

public:
    explicit PaddleSpeechAdapter(QObject *parent = nullptr);
    ~PaddleSpeechAdapter() override;

    // 实现基类接口
    bool initialize(const QString &modelPath) override;
    bool synthesize(const QString &text, const QString &outputPath, const TTSParameters &params) override;
    QStringList getModelList() const override;
    int getMaxSpeakerId(int modelIndex) const override;
    void stop() override;

private slots:
    void onProcessReadyRead();
    void onProcessError(QProcess::ProcessError error);
    void onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);

private:
    /**
     * @brief 启动 Python 服务进程
     * @return 是否成功
     */
    bool startService();

    /**
     * @brief 停止 Python 服务进程
     */
    void stopService();

    /**
     * @brief 发送命令到 Python 服务
     * @param command JSON 命令
     * @param response JSON 响应
     * @param timeoutMs 超时时间（毫秒）
     * @return 是否成功
     */
    bool sendCommand(const QJsonObject &command, QJsonObject &response, int timeoutMs = 30000);

    /**
     * @brief 排空 Python 进程的 stdout 残留数据，防止协议错位
     * ✅ 2026-02-27 09:00 [Phase 7.47.33]
     */
    void drainStdout();

public:
    /**
     * @brief 请求取消当前正在等待的 sendCommand
     * ✅ 2026-02-27 09:00 [Phase 7.47.33]: 不走 mutex，直接设标志
     */
    void cancelPending();

private:
    QProcess *m_process;            // Python 服务进程
    QString m_serviceScript;        // 服务脚本路径
    QString m_responseBuffer;       // 响应缓冲区
    QMutex m_mutex;                 // 线程锁
    // ✅ 2026-02-27 08:00 [Phase 7.47.33]: 添加取消标志，让sendCommand可被中断
    // ✅ 2026-02-27 09:00 [Phase 7.47.33]: 改用 atomic 保证线程安全（cancelPending 不走 mutex）
    std::atomic<bool> m_cancelRequested{false};

    // 模型信息
    static const QMap<QString, int> MODEL_SPEAKER_COUNTS;
};

#endif // PADDLESPEECHADAPTER_H
