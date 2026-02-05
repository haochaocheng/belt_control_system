#ifndef AUDIOMANAGEMENTCONTROLLER_H
#define AUDIOMANAGEMENTCONTROLLER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVector>
#include "SherpaOnnxTTS.h"
#include "TTSConfigManager.h"

/**
 * @brief 音频管理控制器
 *
 * 功能：
 * 1. 管理音频文件扫描
 * 2. 协调TTS和STT功能
 * 3. 批量生成控制
 * 4. 进度管理
 *
 * ✅ 2026-01-23 10:00 [FIX 100.299] 语音管理功能核心控制器
 */
class AudioManagementController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int totalFiles READ totalFiles NOTIFY totalFilesChanged)
    Q_PROPERTY(int processedFiles READ processedFiles NOTIFY processedFilesChanged)
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString currentFile READ currentFile NOTIFY currentFileChanged)
    Q_PROPERTY(bool isProcessing READ isProcessing NOTIFY isProcessingChanged)

public:
    // 音频文件信息结构
    struct AudioFileInfo {
        QString filePath;           // 文件路径
        QString fileName;           // 文件名
        QString recognizedText;     // 识别的文本
        QString generatedPath;      // 生成的TTS文件路径
        enum Status {
            Pending,                // 待处理
            Recognizing,            // 识别中
            Recognized,             // 已识别
            Generating,             // 生成中
            Generated,              // 已生成
            Failed                  // 失败
        };
        Status status;
        QString errorMessage;       // 错误信息
    };

    explicit AudioManagementController(QObject *parent = nullptr);
    ~AudioManagementController();

    // 设置TTS引擎
    void setTtsEngine(SherpaOnnxTTS* tts);

    // 扫描音频文件
    Q_INVOKABLE void scanDirectory(const QString &dirPath);

    // 获取文件列表
    Q_INVOKABLE QVariantList getFileList() const;

    // 识别单个文件
    Q_INVOKABLE void recognizeFile(int index);

    // 批量识别
    Q_INVOKABLE void recognizeAll();

    // 生成单个TTS
    Q_INVOKABLE void generateTts(int index, const QString &text);

    // 批量生成TTS
    Q_INVOKABLE void generateAllTts();

    // 停止处理
    Q_INVOKABLE void stopProcessing();

    // 清除文件列表
    Q_INVOKABLE void clearFileList();

    // 属性访问器
    int totalFiles() const { return m_audioFiles.size(); }
    int processedFiles() const { return m_processedFiles; }
    int progress() const;
    QString currentFile() const { return m_currentFile; }
    bool isProcessing() const { return m_isProcessing; }

signals:
    // 文件列表更新
    void fileListUpdated();

    // 进度信号
    void totalFilesChanged();
    void processedFilesChanged();
    void progressChanged();
    void currentFileChanged();
    void isProcessingChanged();

    // 状态信号
    void fileStatusChanged(int index, int status, const QString &message);
    void recognitionCompleted(int index, const QString &text);
    void generationCompleted(int index, const QString &path);
    void processingFinished(bool success, const QString &message);

    // 错误信号
    void errorOccurred(const QString &message);

private slots:
    void onRecognitionFinished();
    void onGenerationFinished();

private:
    // 处理下一个文件
    void processNextFile();

    // 更新进度
    void updateProgress();

    SherpaOnnxTTS* m_tts;
    TTSConfigManager* m_config;

    QVector<AudioFileInfo> m_audioFiles;
    int m_processedFiles;
    int m_currentIndex;
    QString m_currentFile;
    bool m_isProcessing;

    enum ProcessMode {
        None,
        RecognizeAll,
        GenerateAll
    };
    ProcessMode m_processMode;
};

#endif // AUDIOMANAGEMENTCONTROLLER_H
