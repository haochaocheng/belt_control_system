// ✅ 2026-02-25 10:55 [Phase 7.47.1]: TTS 批量生成配置数据结构
// 用途：定义批量语音合成的配置和数据结构
// 参考：docs/2026-02-24/03-语音管理界面批量合成功能实施计划.md

#ifndef TTSBATCHCONFIG_H
#define TTSBATCHCONFIG_H

#include <QString>
#include <QStringList>
#include <QVector>
#include <QObject>

// ========== 保护类型枚举 ==========
enum class ProtectionCategory {
    SwitchInput,      // 开关量输入保护
    AnalogInput,      // 模拟量输入保护
    Motor,            // 电机保护
    Brake,            // 制动器保护
    Tension,          // 张紧控制保护
    LinePosition,     // 沿线点位保护
    SystemSound       // 系统提示音
};

// ========== TTS 引擎配置 ==========
struct TTSEngineConfig {
    QString engineName;      // 引擎名称: "paddlespeech"
    QString modelName;       // 模型名称: "fastspeech2-aishell3"
    int speakerId;           // 说话人ID: 174, 175, 176 等
    QString outputFolder;    // 输出文件夹名: "paddlespeech-fastspeech2-aishell3-spk174"

    // 默认构造函数
    TTSEngineConfig() : speakerId(174) {}

    TTSEngineConfig(const QString& engine, const QString& model, int spkId)
        : engineName(engine), modelName(model), speakerId(spkId) {
        outputFolder = QString("%1-%2-spk%3").arg(engine).arg(model).arg(spkId);
    }
};

// ========== 批量生成配置 ==========
struct TTSBatchConfig {
    // 生成清单
    QVector<ProtectionCategory> categories;

    // 生成范围
    QVector<int> beltNumbers;        // 皮带编号: 1-8
    QVector<int> motorNumbers;       // 电机编号: 1-4
    QVector<int> brakeNumbers;       // 制动器编号: 1-4
    QVector<int> tensionNumbers;     // 张紧装置编号: 1-2
    int linePositionStart;           // 沿线点位起始: 1
    int linePositionEnd;             // 沿线点位结束: 64

    // TTS 引擎配置
    QVector<TTSEngineConfig> engines;

    // 输出目录
    QString outputBaseDir;           // 基础输出目录: "E:/AUDIO/"

    // 生成选项
    bool skipExisting;               // 跳过已存在的文件
    bool generateReport;             // 生成报告
    int parallelCount;               // 并行生成数量（1=串行）

    // 默认构造函数
    TTSBatchConfig()
        : linePositionStart(1)
        , linePositionEnd(64)
        , outputBaseDir("E:/AUDIO/")
        , skipExisting(true)
        , generateReport(true)
        , parallelCount(1) {
        // 默认皮带编号 1-8
        for (int i = 1; i <= 8; ++i) beltNumbers.append(i);
        // 默认电机编号 1-4
        for (int i = 1; i <= 4; ++i) motorNumbers.append(i);
        // 默认制动器编号 1-4
        for (int i = 1; i <= 4; ++i) brakeNumbers.append(i);
        // 默认张紧装置编号 1-2
        for (int i = 1; i <= 2; ++i) tensionNumbers.append(i);
    }
};

// ========== 语音文件项 ==========
struct VoiceFileItem {
    QString id;              // 唯一标识: "switch_input_belt1_001"
    QString category;        // 分类: "开关量输入保护"
    QString text;            // 文本内容: "1号皮带急停保护"
    QString filename;        // 文件名: "001.wav"
    QString relativePath;    // 相对路径: "开关量输入保护/1号皮带/"

    // 生成状态
    enum class Status {
        Pending,             // 待生成
        Generating,          // 生成中
        Success,             // 成功
        Failed,              // 失败
        Skipped              // 跳过（已存在）
    };
    Status status;
    QString errorMessage;    // 错误信息（如果失败）

    VoiceFileItem() : status(Status::Pending) {}
};

// ========== 批量生成进度 ==========
struct TTSBatchProgress {
    int totalFiles;          // 总文件数
    int completedFiles;      // 已完成数
    int successFiles;        // 成功数
    int failedFiles;         // 失败数
    int skippedFiles;        // 跳过数

    QString currentFile;     // 当前正在生成的文件
    QString currentText;     // 当前正在生成的文本
    int currentEngine;       // 当前引擎索引
    int totalEngines;        // 总引擎数

    double elapsedSeconds;   // 已用时间（秒）
    double estimatedSeconds; // 预计剩余时间（秒）

    bool isRunning;          // 是否正在运行
    bool isPaused;           // 是否暂停
    bool isCancelled;        // 是否取消

    TTSBatchProgress()
        : totalFiles(0), completedFiles(0), successFiles(0)
        , failedFiles(0), skippedFiles(0)
        , currentEngine(0), totalEngines(0)
        , elapsedSeconds(0), estimatedSeconds(0)
        , isRunning(false), isPaused(false), isCancelled(false) {}

    // 计算进度百分比
    double progressPercent() const {
        if (totalFiles == 0) return 0;
        return (double)completedFiles / totalFiles * 100.0;
    }
};

#endif // TTSBATCHCONFIG_H
