// 2026-02-26 08:00 [Phase 7.47.3]: 批量音频生成器
// 用途：批量生成语音文件，支持多分类、多引擎、进度统计

#ifndef BATCHAUDIOGENERATOR_H
#define BATCHAUDIOGENERATOR_H

#include <QObject>
#include <QVariantMap>
#include <QStringList>
#include <QThread>
#include <QMutex>
#include <QDateTime>

// ✅ 2026-02-26 08:35 [Phase 7.47.3]: 添加 TTS 引擎管理器
class TTSEngineManager;

/**
 * @brief 批量音频生成器
 *
 * 功能：
 * 1. 根据配置生成文件清单
 * 2. 批量调用 TTS 引擎生成音频
 * 3. 实时统计进度和耗时
 * 4. 支持跳过已存在文件
 * 5. 生成详细报告
 */
class BatchAudioGenerator : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isRunning READ isRunning NOTIFY isRunningChanged)
    Q_PROPERTY(int totalFiles READ totalFiles NOTIFY totalFilesChanged)
    Q_PROPERTY(int completedFiles READ completedFiles NOTIFY completedFilesChanged)
    Q_PROPERTY(int failedFiles READ failedFiles NOTIFY failedFilesChanged)
    Q_PROPERTY(QString currentFile READ currentFile NOTIFY currentFileChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)
    // ✅ 2026-02-26 23:30 [Phase 7.47.21]: 添加时间统计属性
    Q_PROPERTY(QString elapsedTime READ elapsedTime NOTIFY elapsedTimeChanged)
    Q_PROPERTY(QString estimatedTime READ estimatedTime NOTIFY estimatedTimeChanged)

public:
    // ✅ 2026-02-26 08:35 [Phase 7.47.3]: 添加 TTSEngineManager 参数
    explicit BatchAudioGenerator(TTSEngineManager *ttsManager, QObject *parent = nullptr);
    ~BatchAudioGenerator();

    // 属性访问器
    bool isRunning() const { return m_isRunning; }
    int totalFiles() const { return m_totalFiles; }
    int completedFiles() const { return m_completedFiles; }
    int failedFiles() const { return m_failedFiles; }
    QString currentFile() const { return m_currentFile; }
    double progress() const;
    // ✅ 2026-02-26 23:30 [Phase 7.47.21]: 时间统计访问器
    QString elapsedTime() const;
    QString estimatedTime() const;

public slots:
    /**
     * @brief 设置配置
     * @param config 配置对象，包含：
     *   - categories: 分类列表 ["switchInput", "analogInput", ...]
     *   - beltNumbers: 皮带编号列表 [1, 2, 3, ...]
     *   - motorNumbers: 电机编号列表 [1, 2, 3, ...]
     *   - brakeNumbers: 制动器编号列表 [1, 2, 3, ...]
     *   - tensionNumbers: 张紧器编号列表 [1, 2, 3, ...]
     *   - linePositionStart: 线位起始值
     *   - linePositionEnd: 线位结束值
     *   - skipExisting: 是否跳过已存在文件
     *   - generateReport: 是否生成报告
     *   - outputBaseDir: 输出基础目录
     *   - engines: 引擎配置列表 [{engineName, modelName, speakerId, outputFolder}, ...]
     */
    void setConfig(const QVariantMap &config);

    /**
     * @brief 生成文件清单（预览）
     * @return 文件总数
     */
    int generateFileList();

    /**
     * @brief 开始批量生成
     */
    void start();

    /**
     * @brief 停止生成
     */
    void stop();

    /**
     * @brief 导出日志
     * @param filePath 日志文件路径
     */
    void exportLog(const QString &filePath);

    // ✅ 2026-03-25 [Phase 7.48.88.14]: 清除指定分类的已生成语音文件（用于皮带名称变更后重新生成）
    Q_INVOKABLE int clearCategoryFiles(const QStringList &categories);

    /**
     * @brief 生成所有说话人ID测试语音
     * ✅ 2026-02-27 00:25 [Phase 7.47.23]: 新增功能
     * 为 fastspeech2_aishell3 模型的所有 174 个说话人生成测试语音
     * 测试文本：1108顺槽皮带沿线急停保护
     * 输出目录：{outputBaseDir}/speaker-samples/
     */
    void generateAllSpeakerSamples();

signals:
    void isRunningChanged();
    void totalFilesChanged();
    void completedFilesChanged();
    void failedFilesChanged();
    void currentFileChanged();
    void progressChanged();
    // ✅ 2026-02-26 23:30 [Phase 7.47.21]: 添加时间统计信号
    void elapsedTimeChanged();
    void estimatedTimeChanged();

    /**
     * @brief 日志消息
     * @param level 级别：info, warn, error
     * @param message 消息内容
     */
    void logMessage(const QString &level, const QString &message);

    /**
     * @brief 完成信号
     * @param success 是否成功
     * @param message 完成消息
     */
    void finished(bool success, const QString &message);

private:
    struct FileTask {
        QString category;       // 分类
        QString text;           // 文本内容
        QString outputPath;     // 输出路径
        QString engineName;     // 引擎名称
        QString modelName;      // 模型名称
        int speakerId;          // 说话人ID
        // ✅ 2026-02-27 06:00 [Phase 7.47.31]: 添加语速和音量
        double rate = 1.0;
        double volume = 0.8;
    };

    struct EngineConfig {
        QString engineName;
        QString modelName;
        int speakerId;
        QString outputFolder;
        // ✅ 2026-02-27 06:00 [Phase 7.47.31]: 添加语速和音量，使用语音管理界面保存的参数
        double rate = 1.0;
        double volume = 0.8;
    };

    // 生成任务列表
    void generateTasks();

    // 生成特定分类的任务
    void generateSwitchInputTasks(const EngineConfig &engine);
    void generateAnalogInputTasks(const EngineConfig &engine);
    void generateMotorTasks(const EngineConfig &engine);
    void generateBrakeTasks(const EngineConfig &engine);
    void generateTensionTasks(const EngineConfig &engine);
    void generateLinePositionTasks(const EngineConfig &engine);
    void generateSystemSoundTasks(const EngineConfig &engine);
    // ✅ 2026-02-27 05:30 [Phase 7.47.30]: 补充1#PD已有但批量代码缺失的语音分类
    void generateBeltOperationTasks(const EngineConfig &engine);
    void generateSystemStatusTasks(const EngineConfig &engine);
    // ✅ 2026-03-02 [Phase 7.47.69]: 新增 - 模块在线状态语音（离线提示）
    void generateModuleStatusTasks(const EngineConfig &engine);

    // 执行单个任务
    bool executeTask(const FileTask &task);

    // 生成报告
    void generateReport();

    // 配置
    QVariantMap m_config;
    QStringList m_categories;
    QList<int> m_beltNumbers;
    QList<int> m_motorNumbers;
    QList<int> m_brakeNumbers;
    QList<int> m_tensionNumbers;
    int m_linePositionStart;
    int m_linePositionEnd;
    bool m_skipExisting;
    bool m_generateReport;
    QString m_outputBaseDir;
    QList<EngineConfig> m_engines;

    // ✅ 2026-03-25 [Phase 7.48.88.18]: 自定义皮带名称映射（皮带编号 → 自定义名称）
    // 例如：{2: "1109顺槽皮带"}, TTS文本中"2号皮带"会被替换为"1109顺槽皮带"
    QMap<int, QString> m_beltNames;

    // 任务列表
    QList<FileTask> m_tasks;

    // 状态
    bool m_isRunning;
    int m_totalFiles;
    int m_completedFiles;
    int m_failedFiles;
    QString m_currentFile;
    QDateTime m_startTime;
    QStringList m_logMessages;
    // ✅ 2026-02-26 23:30 [Phase 7.47.21]: 添加时间统计成员
    qint64 m_elapsedMs;  // 已用时间（毫秒）

    // ✅ 2026-02-26 08:35 [Phase 7.47.3]: TTS 引擎管理器
    TTSEngineManager *m_ttsEngineManager;

    // 线程安全
    QMutex m_mutex;
};

#endif // BATCHAUDIOGENERATOR_H
