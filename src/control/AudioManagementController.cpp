#include "AudioManagementController.h"
#include <QDebug>
#include <QDir>
#include <QFileInfo>

// ✅ 2026-01-23 10:00 [FIX 100.299] 音频管理控制器实现

AudioManagementController::AudioManagementController(QObject *parent)
    : QObject(parent)
    , m_tts(nullptr)
    , m_config(TTSConfigManager::instance())
    , m_processedFiles(0)
    , m_currentIndex(-1)
    , m_isProcessing(false)
    , m_processMode(None)
{
    qDebug() << "🎵 [AudioMgmt] 初始化音频管理控制器";
}

AudioManagementController::~AudioManagementController()
{
    qDebug() << "🎵 [AudioMgmt] 销毁音频管理控制器";
}

void AudioManagementController::setTtsEngine(SherpaOnnxTTS* tts)
{
    m_tts = tts;
    qDebug() << "🎵 [AudioMgmt] 设置TTS引擎:" << (m_tts ? "成功" : "失败");
}

void AudioManagementController::scanDirectory(const QString &dirPath)
{
    qDebug() << "🎵 [AudioMgmt] 扫描目录:" << dirPath;

    // 清空现有列表
    m_audioFiles.clear();
    m_processedFiles = 0;
    m_currentIndex = -1;

    // 检查目录是否存在
    QDir dir(dirPath);
    if (!dir.exists()) {
        qWarning() << "❌ [AudioMgmt] 目录不存在:" << dirPath;
        emit errorOccurred("目录不存在: " + dirPath);
        return;
    }

    // 扫描音频文件（支持 .wav, .mp3, .ogg 等格式）
    QStringList filters;
    filters << "*.wav" << "*.mp3" << "*.ogg" << "*.flac";
    QFileInfoList fileList = dir.entryInfoList(filters, QDir::Files | QDir::Readable, QDir::Name);

    qDebug() << "  找到" << fileList.size() << "个音频文件";

    // 添加到文件列表
    for (const QFileInfo &fileInfo : fileList) {
        AudioFileInfo info;
        info.filePath = fileInfo.absoluteFilePath();
        info.fileName = fileInfo.fileName();
        info.recognizedText = "";
        info.generatedPath = "";
        info.status = AudioFileInfo::Pending;
        info.errorMessage = "";

        m_audioFiles.append(info);
    }

    emit totalFilesChanged();
    emit fileListUpdated();

    qDebug() << "✅ [AudioMgmt] 扫描完成，共" << m_audioFiles.size() << "个文件";
}

QVariantList AudioManagementController::getFileList() const
{
    QVariantList list;

    for (const AudioFileInfo &info : m_audioFiles) {
        QVariantMap map;
        map["filePath"] = info.filePath;
        map["fileName"] = info.fileName;
        map["recognizedText"] = info.recognizedText;
        map["generatedPath"] = info.generatedPath;
        map["status"] = static_cast<int>(info.status);
        map["errorMessage"] = info.errorMessage;

        list.append(map);
    }

    return list;
}

void AudioManagementController::recognizeFile(int index)
{
    if (index < 0 || index >= m_audioFiles.size()) {
        qWarning() << "❌ [AudioMgmt] 无效的文件索引:" << index;
        return;
    }

    qDebug() << "🎵 [AudioMgmt] 识别文件:" << m_audioFiles[index].fileName;

    // TODO: 实施STT识别
    // 当前占位实现：使用文件名作为识别文本
    m_audioFiles[index].status = AudioFileInfo::Recognizing;
    emit fileStatusChanged(index, AudioFileInfo::Recognizing, "识别中...");

    // 模拟识别（实际应调用STT引擎）
    QString recognizedText = m_audioFiles[index].fileName;
    recognizedText.replace(".wav", "");
    recognizedText.replace(".mp3", "");
    recognizedText.replace(".ogg", "");
    recognizedText.replace(".flac", "");

    m_audioFiles[index].recognizedText = recognizedText;
    m_audioFiles[index].status = AudioFileInfo::Recognized;

    emit fileStatusChanged(index, AudioFileInfo::Recognized, "识别完成");
    emit recognitionCompleted(index, recognizedText);

    qDebug() << "  识别结果:" << recognizedText;
}

void AudioManagementController::recognizeAll()
{
    if (m_audioFiles.isEmpty()) {
        qWarning() << "❌ [AudioMgmt] 没有文件可识别";
        emit errorOccurred("没有文件可识别");
        return;
    }

    qDebug() << "🎵 [AudioMgmt] 开始批量识别，共" << m_audioFiles.size() << "个文件";

    m_isProcessing = true;
    m_processMode = RecognizeAll;
    m_processedFiles = 0;
    m_currentIndex = 0;

    emit isProcessingChanged();
    emit processedFilesChanged();

    processNextFile();
}

void AudioManagementController::generateTts(int index, const QString &text)
{
    if (index < 0 || index >= m_audioFiles.size()) {
        qWarning() << "❌ [AudioMgmt] 无效的文件索引:" << index;
        return;
    }

    if (!m_tts) {
        qWarning() << "❌ [AudioMgmt] TTS引擎未设置";
        emit errorOccurred("TTS引擎未设置");
        return;
    }

    qDebug() << "🎵 [AudioMgmt] 生成TTS:" << text;

    m_audioFiles[index].status = AudioFileInfo::Generating;
    emit fileStatusChanged(index, AudioFileInfo::Generating, "生成中...");

    // 生成输出文件路径
    QString outputDir = QDir::currentPath() + "/generated_tts";
    QDir().mkpath(outputDir);

    QString outputPath = outputDir + "/" + m_audioFiles[index].fileName;

    // 调用TTS合成
    bool success = m_tts->synthesizeToFile(text, outputPath);

    if (success) {
        m_audioFiles[index].generatedPath = outputPath;
        m_audioFiles[index].status = AudioFileInfo::Generated;
        emit fileStatusChanged(index, AudioFileInfo::Generated, "生成完成");
        emit generationCompleted(index, outputPath);
        qDebug() << "  生成成功:" << outputPath;
    } else {
        m_audioFiles[index].status = AudioFileInfo::Failed;
        m_audioFiles[index].errorMessage = "TTS生成失败";
        emit fileStatusChanged(index, AudioFileInfo::Failed, "生成失败");
        qWarning() << "  生成失败";
    }
}

void AudioManagementController::generateAllTts()
{
    if (m_audioFiles.isEmpty()) {
        qWarning() << "❌ [AudioMgmt] 没有文件可生成";
        emit errorOccurred("没有文件可生成");
        return;
    }

    // 检查是否有已识别的文件
    int recognizedCount = 0;
    for (const AudioFileInfo &info : m_audioFiles) {
        if (info.status == AudioFileInfo::Recognized ||
            info.status == AudioFileInfo::Generated) {
            recognizedCount++;
        }
    }

    if (recognizedCount == 0) {
        qWarning() << "❌ [AudioMgmt] 没有已识别的文件";
        emit errorOccurred("请先识别音频文件");
        return;
    }

    qDebug() << "🎵 [AudioMgmt] 开始批量生成TTS，共" << recognizedCount << "个文件";

    m_isProcessing = true;
    m_processMode = GenerateAll;
    m_processedFiles = 0;
    m_currentIndex = 0;

    emit isProcessingChanged();
    emit processedFilesChanged();

    processNextFile();
}

void AudioManagementController::stopProcessing()
{
    qDebug() << "🎵 [AudioMgmt] 停止处理";

    m_isProcessing = false;
    m_processMode = None;
    m_currentIndex = -1;
    m_currentFile = "";

    emit isProcessingChanged();
    emit currentFileChanged();
    emit processingFinished(false, "用户取消");
}

void AudioManagementController::clearFileList()
{
    qDebug() << "🎵 [AudioMgmt] 清空文件列表";

    m_audioFiles.clear();
    m_processedFiles = 0;
    m_currentIndex = -1;
    m_currentFile = "";

    emit totalFilesChanged();
    emit processedFilesChanged();
    emit currentFileChanged();
    emit fileListUpdated();
}

int AudioManagementController::progress() const
{
    if (m_audioFiles.isEmpty()) {
        return 0;
    }
    return (m_processedFiles * 100) / m_audioFiles.size();
}

void AudioManagementController::processNextFile()
{
    // 检查是否完成
    if (m_currentIndex >= m_audioFiles.size()) {
        qDebug() << "✅ [AudioMgmt] 批量处理完成";
        m_isProcessing = false;
        m_processMode = None;
        m_currentIndex = -1;
        m_currentFile = "";

        emit isProcessingChanged();
        emit currentFileChanged();
        emit processingFinished(true, "处理完成");
        return;
    }

    // 更新当前文件
    m_currentFile = m_audioFiles[m_currentIndex].fileName;
    emit currentFileChanged();

    // 根据处理模式执行操作
    if (m_processMode == RecognizeAll) {
        recognizeFile(m_currentIndex);
        m_processedFiles++;
        m_currentIndex++;
        emit processedFilesChanged();
        emit progressChanged();

        // 继续处理下一个文件（延迟100ms避免阻塞）
        QTimer::singleShot(100, this, &AudioManagementController::processNextFile);

    } else if (m_processMode == GenerateAll) {
        // 只处理已识别的文件
        if (m_audioFiles[m_currentIndex].status == AudioFileInfo::Recognized ||
            m_audioFiles[m_currentIndex].status == AudioFileInfo::Generated) {

            QString text = m_audioFiles[m_currentIndex].recognizedText;
            generateTts(m_currentIndex, text);
            m_processedFiles++;
            emit processedFilesChanged();
            emit progressChanged();
        }

        m_currentIndex++;

        // 继续处理下一个文件（延迟200ms等待TTS完成）
        QTimer::singleShot(200, this, &AudioManagementController::processNextFile);
    }
}

void AudioManagementController::updateProgress()
{
    emit progressChanged();
}

void AudioManagementController::onRecognitionFinished()
{
    // STT识别完成回调（预留）
}

void AudioManagementController::onGenerationFinished()
{
    // TTS生成完成回调（预留）
}
