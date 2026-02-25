#ifndef MELOTTSADAPTER_H
#define MELOTTSADAPTER_H

#include "TTSEngineAdapter.h"
#include <QProcess>
#include <QMutex>
#include <QJsonObject>

/**
 * @brief MeloTTS 适配器
 *
 * 通过 Python 进程通信实现 MeloTTS 语音合成
 *
 * ✅ 2026-02-13 [Phase 7.46.2]: 创建 MeloTTS 适配器
 */
class MeloTTSAdapter : public TTSEngineAdapter
{
    Q_OBJECT

public:
    explicit MeloTTSAdapter(QObject *parent = nullptr);
    ~MeloTTSAdapter() override;

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

private:
    QProcess *m_process;            // Python 服务进程
    QString m_serviceScript;        // 服务脚本路径
    QString m_responseBuffer;       // 响应缓冲区
    QMutex m_mutex;                 // 线程锁

    // 模型信息
    static const QMap<QString, int> MODEL_SPEAKER_COUNTS;
};

#endif // MELOTTSADAPTER_H
