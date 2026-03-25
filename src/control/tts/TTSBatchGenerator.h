// ✅ 2026-02-25 11:00 [Phase 7.47.1]: TTS 批量生成器
// 用途：管理批量语音合成的后端逻辑
// 参考：docs/2026-02-24/03-语音管理界面批量合成功能实施计划.md

#ifndef TTSBATCHGENERATOR_H
#define TTSBATCHGENERATOR_H

#include <QObject>
#include <QThread>
#include <QMutex>
#include <QElapsedTimer>
#include "TTSBatchConfig.h"

class TTSBatchGenerator : public QObject
{
    Q_OBJECT

    // QML 可访问属性
    Q_PROPERTY(bool isRunning READ isRunning NOTIFY runningChanged)
    Q_PROPERTY(bool isPaused READ isPaused NOTIFY pausedChanged)
    Q_PROPERTY(int totalFiles READ totalFiles NOTIFY progressChanged)
    Q_PROPERTY(int completedFiles READ completedFiles NOTIFY progressChanged)
    Q_PROPERTY(int successFiles READ successFiles NOTIFY progressChanged)
    Q_PROPERTY(int failedFiles READ failedFiles NOTIFY progressChanged)
    Q_PROPERTY(int skippedFiles READ skippedFiles NOTIFY progressChanged)
    Q_PROPERTY(double progressPercent READ progressPercent NOTIFY progressChanged)
    Q_PROPERTY(QString currentFile READ currentFile NOTIFY currentFileChanged)
    Q_PROPERTY(QString currentText READ currentText NOTIFY currentFileChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusChanged)
    Q_PROPERTY(QString elapsedTime READ elapsedTime NOTIFY progressChanged)
    Q_PROPERTY(QString estimatedTime READ estimatedTime NOTIFY progressChanged)

public:
    explicit TTSBatchGenerator(QObject *parent = nullptr);
    ~TTSBatchGenerator();

    // 属性访问器
    bool isRunning() const { return m_progress.isRunning; }
    bool isPaused() const { return m_progress.isPaused; }
    int totalFiles() const { return m_progress.totalFiles; }
    int completedFiles() const { return m_progress.completedFiles; }
    int successFiles() const { return m_progress.successFiles; }
    int failedFiles() const { return m_progress.failedFiles; }
    int skippedFiles() const { return m_progress.skippedFiles; }
    double progressPercent() const { return m_progress.progressPercent(); }
    QString currentFile() const { return m_progress.currentFile; }
    QString currentText() const { return m_progress.currentText; }
    QString statusText() const { return m_statusText; }
    QString elapsedTime() const;
    QString estimatedTime() const;

    // 获取文件列表
    QVector<VoiceFileItem>& fileList() { return m_fileList; }
    const QVector<VoiceFileItem>& fileList() const { return m_fileList; }

public slots:
    // ========== QML 可调用方法 ==========

    // 设置配置
    Q_INVOKABLE void setConfig(const QVariantMap& config);

    // 生成文件清单（预览）
    Q_INVOKABLE int generateFileList();

    // 获取文件清单（用于 QML 显示）
    Q_INVOKABLE QVariantList getFileList() const;

    // 获取分类统计
    Q_INVOKABLE QVariantMap getCategoryStats() const;

    // 开始批量生成
    Q_INVOKABLE void start();

    // 暂停/继续
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();

    // 停止
    Q_INVOKABLE void stop();

    // 重试失败的文件
    Q_INVOKABLE void retryFailed();

signals:
    void runningChanged();
    void pausedChanged();
    void progressChanged();
    void currentFileChanged();
    void statusChanged();

    // 生成完成
    void finished(bool success, const QString& message);

    // 单个文件生成完成
    void fileGenerated(const QString& id, bool success, const QString& error);

    // 日志消息
    void logMessage(const QString& level, const QString& message);

private slots:
    void onGenerateNext();

private:
    // 生成单个文件
    bool generateSingleFile(VoiceFileItem& item, const TTSEngineConfig& engine);

    // 构建文件清单
    void buildSwitchInputList();      // 开关量输入保护
    void buildAnalogInputList();      // 模拟量输入保护
    void buildMotorList();            // 电机保护
    void buildBrakeList();            // 制动器保护
    void buildTensionList();          // 张紧控制保护
    void buildLinePositionList();     // 沿线点位保护
    void buildSystemSoundList();      // 系统提示音
    // ✅ 2026-03-25 [Phase 7.48.88.10]: 新增皮带操作状态
    void buildBeltOperationList();    // 皮带操作状态（启车/停车预警）

    // 辅助方法
    QString formatTime(double seconds) const;
    void updateEstimatedTime();
    void emitLog(const QString& level, const QString& message);

private:
    TTSBatchConfig m_config;
    TTSBatchProgress m_progress;
    QVector<VoiceFileItem> m_fileList;

    QString m_statusText;
    QElapsedTimer m_elapsedTimer;
    QMutex m_mutex;

    int m_currentIndex;
    int m_currentEngineIndex;
};

#endif // TTSBATCHGENERATOR_H
