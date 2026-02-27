// ✅ 2026-02-26 08:15 [Phase 7.47.3]: 批量音频生成器实现
// 用途：批量生成语音文件，支持多分类、多引擎、进度统计
// 参考：docs/2026-02-24/03-语音管理界面批量合成功能实施计划.md

#include "BatchAudioGenerator.h"
#include "tts/TTSBatchConfig.h"
#include "tts/TTSEngineManager.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QDebug>
#include <QElapsedTimer>

BatchAudioGenerator::BatchAudioGenerator(TTSEngineManager *ttsManager, QObject *parent)
    : QObject(parent)
    , m_isRunning(false)
    , m_totalFiles(0)
    , m_completedFiles(0)
    , m_failedFiles(0)
    , m_linePositionStart(1)
    , m_linePositionEnd(64)
    , m_skipExisting(true)
    , m_generateReport(true)
    , m_elapsedMs(0)  // ✅ 2026-02-26 23:30 [Phase 7.47.21]: 初始化时间统计
    , m_ttsEngineManager(ttsManager)
{
    qDebug() << "[BatchAudioGenerator] 初始化";
}

BatchAudioGenerator::~BatchAudioGenerator()
{
    stop();
}

double BatchAudioGenerator::progress() const
{
    if (m_totalFiles == 0) return 0.0;
    return (double)m_completedFiles / m_totalFiles * 100.0;
}

// ✅ 2026-02-26 23:30 [Phase 7.47.21]: 格式化时间为 mm:ss 格式
QString BatchAudioGenerator::elapsedTime() const
{
    int totalSeconds = m_elapsedMs / 1000;
    int minutes = totalSeconds / 60;
    int seconds = totalSeconds % 60;
    return QString("%1:%2").arg(minutes).arg(seconds, 2, 10, QChar('0'));
}

QString BatchAudioGenerator::estimatedTime() const
{
    if (m_completedFiles == 0 || m_totalFiles == 0) {
        return "--:--";
    }

    // 计算平均每个文件的时间
    double avgTimePerFile = (double)m_elapsedMs / m_completedFiles;
    // 计算剩余文件数
    int remainingFiles = m_totalFiles - m_completedFiles;
    // 计算预计剩余时间
    qint64 estimatedMs = (qint64)(avgTimePerFile * remainingFiles);

    int totalSeconds = estimatedMs / 1000;
    int minutes = totalSeconds / 60;
    int seconds = totalSeconds % 60;
    return QString("%1:%2").arg(minutes).arg(seconds, 2, 10, QChar('0'));
}

void BatchAudioGenerator::setConfig(const QVariantMap &config)
{
    QMutexLocker locker(&m_mutex);

    qDebug() << "[BatchAudioGenerator] 设置配置:" << config;

    m_config = config;

    // 解析分类
    m_categories.clear();
    QVariantList categories = config.value("categories").toList();
    for (const QVariant &cat : categories) {
        m_categories.append(cat.toString());
    }

    // 解析编号范围
    m_beltNumbers.clear();
    QVariantList beltNumbers = config.value("beltNumbers").toList();
    for (const QVariant &num : beltNumbers) {
        m_beltNumbers.append(num.toInt());
    }

    m_motorNumbers.clear();
    QVariantList motorNumbers = config.value("motorNumbers").toList();
    for (const QVariant &num : motorNumbers) {
        m_motorNumbers.append(num.toInt());
    }

    m_brakeNumbers.clear();
    QVariantList brakeNumbers = config.value("brakeNumbers").toList();
    for (const QVariant &num : brakeNumbers) {
        m_brakeNumbers.append(num.toInt());
    }

    m_tensionNumbers.clear();
    QVariantList tensionNumbers = config.value("tensionNumbers").toList();
    for (const QVariant &num : tensionNumbers) {
        m_tensionNumbers.append(num.toInt());
    }

    m_linePositionStart = config.value("linePositionStart", 1).toInt();
    m_linePositionEnd = config.value("linePositionEnd", 64).toInt();

    // 解析选项
    m_skipExisting = config.value("skipExisting", true).toBool();
    m_generateReport = config.value("generateReport", true).toBool();
    m_outputBaseDir = config.value("outputBaseDir", "E:/AUDIO/").toString();

    // 解析引擎配置
    m_engines.clear();
    QVariantList engines = config.value("engines").toList();
    for (const QVariant &engineVar : engines) {
        QVariantMap engineMap = engineVar.toMap();
        EngineConfig engine;
        engine.engineName = engineMap.value("engineName").toString();
        engine.modelName = engineMap.value("modelName").toString();
        engine.speakerId = engineMap.value("speakerId").toInt();
        engine.outputFolder = engineMap.value("outputFolder").toString();
        m_engines.append(engine);
    }

    emit logMessage("info", QString("配置已更新：%1 个分类，%2 个引擎")
                    .arg(m_categories.size())
                    .arg(m_engines.size()));
}

int BatchAudioGenerator::generateFileList()
{
    QMutexLocker locker(&m_mutex);

    emit logMessage("info", "开始生成文件清单...");

    m_tasks.clear();
    generateTasks();

    m_totalFiles = m_tasks.size();
    emit totalFilesChanged();

    emit logMessage("info", QString("文件清单生成完成：共 %1 个任务").arg(m_totalFiles));

    return m_totalFiles;
}

void BatchAudioGenerator::start()
{
    if (m_isRunning) {
        emit logMessage("warn", "批量生成已在运行中");
        return;
    }

    m_isRunning = true;
    emit isRunningChanged();

    m_completedFiles = 0;
    m_failedFiles = 0;
    m_elapsedMs = 0;  // ✅ 2026-02-26 23:30 [Phase 7.47.21]: 重置时间统计
    emit completedFilesChanged();
    emit failedFilesChanged();
    emit progressChanged();
    emit elapsedTimeChanged();
    emit estimatedTimeChanged();

    m_startTime = QDateTime::currentDateTime();
    m_logMessages.clear();

    emit logMessage("info", "========== 开始批量生成 ==========");
    emit logMessage("info", QString("总任务数：%1").arg(m_totalFiles));

    // 生成任务
    generateTasks();

    // 执行任务
    QElapsedTimer timer;
    timer.start();

    for (int i = 0; i < m_tasks.size(); ++i) {
        if (!m_isRunning) {
            emit logMessage("warn", "批量生成已停止");
            break;
        }

        const FileTask &task = m_tasks[i];
        m_currentFile = task.outputPath;
        emit currentFileChanged();

        emit logMessage("info", QString("[%1/%2] 生成: %3")
                        .arg(i + 1)
                        .arg(m_totalFiles)
                        .arg(task.text));

        bool success = executeTask(task);

        m_completedFiles++;
        if (!success) {
            m_failedFiles++;
        }

        // ✅ 2026-02-26 23:30 [Phase 7.47.21]: 更新时间统计
        m_elapsedMs = timer.elapsed();

        emit completedFilesChanged();
        emit failedFilesChanged();
        emit progressChanged();
        emit elapsedTimeChanged();
        emit estimatedTimeChanged();
    }

    qint64 elapsed = timer.elapsed();
    double seconds = elapsed / 1000.0;

    emit logMessage("info", "========== 批量生成完成 ==========");
    emit logMessage("info", QString("总耗时：%.2f 秒").arg(seconds));
    emit logMessage("info", QString("成功：%1，失败：%2")
                    .arg(m_completedFiles - m_failedFiles)
                    .arg(m_failedFiles));

    if (m_generateReport) {
        generateReport();
    }

    m_isRunning = false;
    emit isRunningChanged();

    emit finished(m_failedFiles == 0, "批量生成完成");
}

void BatchAudioGenerator::stop()
{
    if (!m_isRunning) return;

    emit logMessage("info", "正在停止批量生成...");
    m_isRunning = false;
    emit isRunningChanged();
}

void BatchAudioGenerator::exportLog(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        emit logMessage("error", QString("无法导出日志：%1").arg(filePath));
        return;
    }

    QTextStream out(&file);
    // ✅ 2026-02-26 10:00 [Phase 7.47.5]: Qt 6移除了setCodec，UTF-8是默认编码
    // out.setCodec("UTF-8");  // Qt 6已移除

    for (const QString &msg : m_logMessages) {
        out << msg << "\n";
    }

    file.close();
    emit logMessage("info", QString("日志已导出：%1").arg(filePath));
}

void BatchAudioGenerator::generateTasks()
{
    m_tasks.clear();

    for (const EngineConfig &engine : m_engines) {
        for (const QString &category : m_categories) {
            if (category == "switchInput") {
                generateSwitchInputTasks(engine);
            } else if (category == "analogInput") {
                generateAnalogInputTasks(engine);
            } else if (category == "motor") {
                generateMotorTasks(engine);
            } else if (category == "brake") {
                generateBrakeTasks(engine);
            } else if (category == "tension") {
                generateTensionTasks(engine);
            } else if (category == "linePosition") {
                generateLinePositionTasks(engine);
            } else if (category == "systemSound") {
                generateSystemSoundTasks(engine);
            // ✅ 2026-02-27 05:30 [Phase 7.47.30]: 补充1#PD已有但批量代码缺失的语音分类
            } else if (category == "beltOperation") {
                generateBeltOperationTasks(engine);
            } else if (category == "systemStatus") {
                generateSystemStatusTasks(engine);
            }
        }
    }
}

void BatchAudioGenerator::generateSwitchInputTasks(const EngineConfig &engine)
{
    // ✅ 2026-02-26 23:15 [Phase 7.47.20]: 按照设计方案修改文件路径和命名
    // 参考：docs/2026-02-26/08-音频文件路径映射设计方案.md
    // 开关量输入保护：8 个文件/皮带（按设计方案）
    QStringList protectionNames = {
        "沿线急停保护", "沿线跑偏保护", "沿线撕裂保护", "烟雾保护",
        "温度保护", "护网保护", "堆煤保护", "主机急停保护"
    };

    for (int beltNum : m_beltNumbers) {
        // 目录格式：{outputBaseDir}/{engineFolder}/{皮带号}#PD/
        QString outputDir = QString("%1/%2/%3#PD/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltNum);

        for (const QString &protName : protectionNames) {
            FileTask task;
            task.category = "switchInput";
            // 文本格式：{皮带号}号皮带{保护名称}
            task.text = QString("%1号皮带%2").arg(beltNum).arg(protName);
            // 文件名格式：{皮带号}号皮带{保护名称}.wav
            task.outputPath = QString("%1%2号皮带%3.wav").arg(outputDir).arg(beltNum).arg(protName);
            task.engineName = engine.engineName;
            task.modelName = engine.modelName;
            task.speakerId = engine.speakerId;
            m_tasks.append(task);
        }
    }
}

void BatchAudioGenerator::generateAnalogInputTasks(const EngineConfig &engine)
{
    // ✅ 2026-02-26 23:15 [Phase 7.47.20]: 按照设计方案修改文件路径和命名
    // 模拟量输入保护：8 个文件/皮带（按设计方案）
    QStringList protectionNames = {
        "速度超速保护", "低速打滑保护", "张力过大保护", "张力过小保护",
        "温度一过高保护", "温度二过高保护", "电压过高保护", "电压过低保护"
    };

    for (int beltNum : m_beltNumbers) {
        QString outputDir = QString("%1/%2/%3#PD/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltNum);

        for (const QString &protName : protectionNames) {
            FileTask task;
            task.category = "analogInput";
            task.text = QString("%1号皮带%2").arg(beltNum).arg(protName);
            task.outputPath = QString("%1%2号皮带%3.wav").arg(outputDir).arg(beltNum).arg(protName);
            task.engineName = engine.engineName;
            task.modelName = engine.modelName;
            task.speakerId = engine.speakerId;
            m_tasks.append(task);
        }
    }
}

void BatchAudioGenerator::generateMotorTasks(const EngineConfig &engine)
{
    // ✅ 2026-02-26 23:15 [Phase 7.47.20]: 按照设计方案修改文件路径和命名
    // ✅ 2026-02-27 [Phase 7.47.29]: 与MotorControlPage.qml Tab页完全对应，共9项
    QStringList protectionNames = {
        "电流保护", "前轴承温度保护", "后轴承温度保护",
        "A相绕组保护", "B相绕组保护", "C相绕组保护",
        "电机温度保护", "X轴振动保护", "Y轴振动保护"
    };

    for (int beltNum : m_beltNumbers) {
        QString outputDir = QString("%1/%2/%3#PD/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltNum);

        for (int motorNum : m_motorNumbers) {
            for (const QString &protName : protectionNames) {
                FileTask task;
                task.category = "motor";
                task.text = QString("%1号皮带%2号电机%3").arg(beltNum).arg(motorNum).arg(protName);
                task.outputPath = QString("%1%2号皮带%3号电机%4.wav")
                                  .arg(outputDir).arg(beltNum).arg(motorNum).arg(protName);
                task.engineName = engine.engineName;
                task.modelName = engine.modelName;
                task.speakerId = engine.speakerId;
                m_tasks.append(task);
            }
        }
    }
}

void BatchAudioGenerator::generateBrakeTasks(const EngineConfig &engine)
{
    // ✅ 2026-02-26 23:15 [Phase 7.47.20]: 按照设计方案修改文件路径和命名
    // 制动器保护：3 个文件/皮带/制动器（按设计方案）
    QStringList protectionNames = {
        "制动失效保护", "制动过热保护", "制动磨损保护"
    };

    for (int beltNum : m_beltNumbers) {
        QString outputDir = QString("%1/%2/%3#PD/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltNum);

        for (int brakeNum : m_brakeNumbers) {
            for (const QString &protName : protectionNames) {
                FileTask task;
                task.category = "brake";
                task.text = QString("%1号皮带%2号制动器%3").arg(beltNum).arg(brakeNum).arg(protName);
                task.outputPath = QString("%1%2号皮带%3号制动器%4.wav")
                                  .arg(outputDir).arg(beltNum).arg(brakeNum).arg(protName);
                task.engineName = engine.engineName;
                task.modelName = engine.modelName;
                task.speakerId = engine.speakerId;
                m_tasks.append(task);
            }
        }
    }
}

void BatchAudioGenerator::generateTensionTasks(const EngineConfig &engine)
{
    // ✅ 2026-02-26 23:15 [Phase 7.47.20]: 按照设计方案修改文件路径和命名
    // 张紧控制保护：3 个文件/皮带/张紧装置（按设计方案）
    QStringList protectionNames = {
        "张紧过大保护", "张紧过小保护", "张紧失效保护"
    };

    for (int beltNum : m_beltNumbers) {
        QString outputDir = QString("%1/%2/%3#PD/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltNum);

        for (int tensionNum : m_tensionNumbers) {
            for (const QString &protName : protectionNames) {
                FileTask task;
                task.category = "tension";
                task.text = QString("%1号皮带%2号张紧%3").arg(beltNum).arg(tensionNum).arg(protName);
                task.outputPath = QString("%1%2号皮带%3号张紧%4.wav")
                                  .arg(outputDir).arg(beltNum).arg(tensionNum).arg(protName);
                task.engineName = engine.engineName;
                task.modelName = engine.modelName;
                task.speakerId = engine.speakerId;
                m_tasks.append(task);
            }
        }
    }
}

void BatchAudioGenerator::generateLinePositionTasks(const EngineConfig &engine)
{
    // ✅ 2026-02-26 23:15 [Phase 7.47.20]: 按照设计方案修改文件路径和命名
    // 沿线点位保护：3 个文件/皮带/点位（按设计方案）
    QStringList protectionNames = {
        "沿线急停保护", "沿线跑偏保护", "沿线撕裂保护"
    };

    for (int beltNum : m_beltNumbers) {
        QString outputDir = QString("%1/%2/%3#PD/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltNum);

        for (int pos = m_linePositionStart; pos <= m_linePositionEnd; ++pos) {
            for (const QString &protName : protectionNames) {
                FileTask task;
                task.category = "linePosition";
                task.text = QString("%1号皮带%2号%3").arg(beltNum).arg(pos).arg(protName);
                task.outputPath = QString("%1%2号皮带%3号%4.wav")
                                  .arg(outputDir).arg(beltNum).arg(pos).arg(protName);
                task.engineName = engine.engineName;
                task.modelName = engine.modelName;
                task.speakerId = engine.speakerId;
                m_tasks.append(task);
            }
        }
    }
}

void BatchAudioGenerator::generateSystemSoundTasks(const EngineConfig &engine)
{
    // ✅ 2026-02-26 23:15 [Phase 7.47.20]: 按照设计方案修改文件路径和命名
    // 系统提示音：16 个文件（按设计方案）
    QStringList soundNames = {
        "系统启动完成", "网络连接正常", "网络连接断开", "设备通讯正常",
        "设备通讯故障", "参数保存成功", "参数加载成功", "操作成功",
        "操作失败", "请确认操作", "报警已确认", "报警已解除",
        "紧急停止", "恢复运行", "维护提醒", "电量不足"
    };

    // 系统提示音放在 Sounds 目录
    QString outputDir = QString("%1/%2/Sounds/")
                        .arg(m_outputBaseDir)
                        .arg(engine.outputFolder);

    for (const QString &soundName : soundNames) {
        FileTask task;
        task.category = "systemSound";
        task.text = soundName;
        task.outputPath = QString("%1%2.wav").arg(outputDir).arg(soundName);
        task.engineName = engine.engineName;
        task.modelName = engine.modelName;
        task.speakerId = engine.speakerId;
        m_tasks.append(task);
    }
}

// ✅ 2026-02-27 05:30 [Phase 7.47.30]: 皮带操作状态语音（对比1#PD已有文件补充）
// 包含：皮带启动/停车/运行失败/通讯失败、电机运行失败、松闸运行失败、张紧运行失败
void BatchAudioGenerator::generateBeltOperationTasks(const EngineConfig &engine)
{
    for (int beltNum : m_beltNumbers) {
        QString outputDir = QString("%1/%2/%3#PD/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltNum);

        // 皮带级操作语音：5个/皮带
        QStringList beltOps = {
            "皮带启动", "皮带停车", "皮带运行失败", "皮带通讯失败", "皮带启动请注意"
        };
        for (const QString &op : beltOps) {
            FileTask task;
            task.category = "beltOperation";
            task.text = QString("%1号%2").arg(beltNum).arg(op);
            task.outputPath = QString("%1%2号%3.wav").arg(outputDir).arg(beltNum).arg(op);
            task.engineName = engine.engineName;
            task.modelName = engine.modelName;
            task.speakerId = engine.speakerId;
            m_tasks.append(task);
        }

        // 电机运行失败：每台电机1个
        for (int motorNum : m_motorNumbers) {
            FileTask task;
            task.category = "beltOperation";
            task.text = QString("%1号电机运行失败").arg(motorNum);
            task.outputPath = QString("%1%2号电机运行失败.wav").arg(outputDir).arg(motorNum);
            task.engineName = engine.engineName;
            task.modelName = engine.modelName;
            task.speakerId = engine.speakerId;
            m_tasks.append(task);
        }

        // 松闸运行失败：每台制动器1个
        for (int brakeNum : m_brakeNumbers) {
            FileTask task;
            task.category = "beltOperation";
            task.text = QString("%1号松闸运行失败").arg(brakeNum);
            task.outputPath = QString("%1%2号松闸运行失败.wav").arg(outputDir).arg(brakeNum);
            task.engineName = engine.engineName;
            task.modelName = engine.modelName;
            task.speakerId = engine.speakerId;
            m_tasks.append(task);
        }

        // 张紧运行失败：每台张紧1个
        for (int tensionNum : m_tensionNumbers) {
            FileTask task;
            task.category = "beltOperation";
            task.text = QString("%1号张紧运行失败").arg(tensionNum);
            task.outputPath = QString("%1%2号张紧运行失败.wav").arg(outputDir).arg(tensionNum);
            task.engineName = engine.engineName;
            task.modelName = engine.modelName;
            task.speakerId = engine.speakerId;
            m_tasks.append(task);
        }
    }
}

// ✅ 2026-02-27 05:30 [Phase 7.47.30]: 系统/通讯状态语音（对比1#PD已有文件补充）
// 包含：与主站通信失败、终端离线、继电器通讯、远程急停、集控停车、集控起车启动等
void BatchAudioGenerator::generateSystemStatusTasks(const EngineConfig &engine)
{
    QStringList statusNames = {
        "与主站通信失败", "未知皮带通讯失败", "终端离线",
        "继电器通讯", "远程急停", "集控停车", "集控起车启动"
    };

    for (int beltNum : m_beltNumbers) {
        QString outputDir = QString("%1/%2/%3#PD/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltNum);

        for (const QString &statusName : statusNames) {
            FileTask task;
            task.category = "systemStatus";
            task.text = statusName;
            task.outputPath = QString("%1%2.wav").arg(outputDir).arg(statusName);
            task.engineName = engine.engineName;
            task.modelName = engine.modelName;
            task.speakerId = engine.speakerId;
            m_tasks.append(task);
        }
    }
}

bool BatchAudioGenerator::executeTask(const FileTask &task)
{
    // 检查文件是否已存在
    if (m_skipExisting && QFile::exists(task.outputPath)) {
        emit logMessage("info", QString("  跳过（已存在）: %1").arg(task.outputPath));
        return true;
    }

    // 创建输出目录
    QFileInfo fileInfo(task.outputPath);
    QDir dir;
    if (!dir.mkpath(fileInfo.absolutePath())) {
        emit logMessage("error", QString("  创建目录失败: %1").arg(fileInfo.absolutePath()));
        return false;
    }

    // ✅ 2026-02-26 08:30 [Phase 7.47.3]: 集成 TTSEngineManager
    // ✅ 2026-02-26 10:00 [Phase 7.47.5]: 修复API调用，使用setCurrentEngine代替switchEngine
    // 调用 TTS 引擎生成音频
    if (!m_ttsEngineManager) {
        emit logMessage("error", "TTS 引擎管理器未初始化");
        return false;
    }

    // 设置 TTS 参数
    TTSParameters params;
    params.speakerId = task.speakerId;
    params.rate = 1.0;
    params.volume = 0.8;

    // 切换到指定引擎（模型通过speakerId在synthesize中指定）
    if (!m_ttsEngineManager->setCurrentEngine(task.engineName)) {
        emit logMessage("error", QString("  无法切换到引擎: %1").arg(task.engineName));
        return false;
    }

    // 执行合成
    bool success = m_ttsEngineManager->synthesize(task.text, task.outputPath, params);

    if (success) {
        emit logMessage("info", QString("  生成成功: %1").arg(task.outputPath));
    } else {
        emit logMessage("error", QString("  生成失败: %1").arg(task.outputPath));
    }

    return success;
}

void BatchAudioGenerator::generateReport()
{
    QString reportPath = QString("%1/batch_report_%2.txt")
                         .arg(m_outputBaseDir)
                         .arg(m_startTime.toString("yyyyMMdd_HHmmss"));

    QFile file(reportPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        emit logMessage("error", QString("无法生成报告：%1").arg(reportPath));
        return;
    }

    QTextStream out(&file);
    // ✅ 2026-02-26 10:00 [Phase 7.47.5]: Qt 6移除了setCodec，UTF-8是默认编码
    // out.setCodec("UTF-8");  // Qt 6已移除

    out << "========== 批量语音合成报告 ==========\n";
    out << "开始时间：" << m_startTime.toString("yyyy-MM-dd HH:mm:ss") << "\n";
    out << "结束时间：" << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss") << "\n";
    out << "总任务数：" << m_totalFiles << "\n";
    out << "已完成数：" << m_completedFiles << "\n";
    out << "成功数：" << (m_completedFiles - m_failedFiles) << "\n";
    out << "失败数：" << m_failedFiles << "\n";
    out << "========================================\n";

    file.close();
    emit logMessage("info", QString("报告已生成：%1").arg(reportPath));
}

// ✅ 2026-02-27 00:30 [Phase 7.47.23]: 生成所有说话人ID测试语音
void BatchAudioGenerator::generateAllSpeakerSamples()
{
    if (m_isRunning) {
        emit logMessage("warn", "批量生成已在运行中");
        return;
    }

    // ✅ 2026-02-27 01:00 [Phase 7.47.24]: 初始化输出基础目录
    // ✅ 2026-02-27 01:20 [Phase 7.47.26]: 修改为小写audio，与设备实际目录一致
    // ✅ 2026-02-27 01:30 [Phase 7.47.27]: 支持linaro和pi用户，使用环境变量
    // 原因：generateAllSpeakerSamples() 独立调用，不依赖 setConfig()
    if (m_outputBaseDir.isEmpty()) {
        // 从环境变量获取用户名，默认linaro
        QString userName = qEnvironmentVariable("BELT_CONTROL_USER", "linaro");
        m_outputBaseDir = QString("/home/%1/belt-control-data/audio").arg(userName);
    }

    m_isRunning = true;
    emit isRunningChanged();

    // 重置统计
    m_completedFiles = 0;
    m_failedFiles = 0;
    m_elapsedMs = 0;
    m_totalFiles = 174;  // fastspeech2_aishell3 有 174 个说话人（ID 0-173）
    emit totalFilesChanged();
    emit completedFilesChanged();
    emit failedFilesChanged();
    emit progressChanged();
    emit elapsedTimeChanged();
    emit estimatedTimeChanged();

    m_startTime = QDateTime::currentDateTime();
    m_logMessages.clear();

    emit logMessage("info", "========== 开始生成所有说话人测试语音 ==========");
    emit logMessage("info", QString("总说话人数：%1（ID 0-173）").arg(m_totalFiles));

    // 测试文本（符合煤矿场景）
    QString testText = "1108顺槽皮带沿线急停保护";

    // 输出目录
    QString outputDir = QString("%1/speaker-samples/").arg(m_outputBaseDir);

    // 创建输出目录
    QDir dir;
    if (!dir.mkpath(outputDir)) {
        emit logMessage("error", QString("创建目录失败: %1").arg(outputDir));
        m_isRunning = false;
        emit isRunningChanged();
        emit finished(false, "创建目录失败");
        return;
    }

    emit logMessage("info", QString("输出目录: %1").arg(outputDir));
    emit logMessage("info", QString("测试文本: %1").arg(testText));

    // 切换到 PaddleSpeech 引擎
    if (!m_ttsEngineManager->setCurrentEngine("PaddleSpeech")) {
        emit logMessage("error", "无法切换到 PaddleSpeech 引擎");
        m_isRunning = false;
        emit isRunningChanged();
        emit finished(false, "引擎切换失败");
        return;
    }

    QElapsedTimer timer;
    timer.start();

    // 遍历所有说话人 ID（0-173）
    for (int speakerId = 0; speakerId < 174; ++speakerId) {
        if (!m_isRunning) {
            emit logMessage("warn", "生成已停止");
            break;
        }

        // 文件名格式：spk000-测试文本.wav
        QString fileName = QString("spk%1-%2.wav")
                           .arg(speakerId, 3, 10, QChar('0'))
                           .arg(testText);
        QString outputPath = outputDir + fileName;

        m_currentFile = outputPath;
        emit currentFileChanged();

        emit logMessage("info", QString("[%1/%2] 生成说话人 ID %3: %4")
                        .arg(m_completedFiles + 1)
                        .arg(m_totalFiles)
                        .arg(speakerId)
                        .arg(testText));

        // 检查文件是否已存在
        if (m_skipExisting && QFile::exists(outputPath)) {
            emit logMessage("info", QString("  跳过（已存在）: %1").arg(outputPath));
            m_completedFiles++;
        } else {
            // 设置 TTS 参数
            TTSParameters params;
            params.speakerId = speakerId;
            params.rate = 1.0;
            params.volume = 0.8;

            // 执行合成
            bool success = m_ttsEngineManager->synthesize(testText, outputPath, params);

            m_completedFiles++;
            if (!success) {
                m_failedFiles++;
                emit logMessage("error", QString("  生成失败: spk%1").arg(speakerId, 3, 10, QChar('0')));
            } else {
                emit logMessage("info", QString("  生成成功: %1").arg(fileName));
            }
        }

        // 更新时间统计
        m_elapsedMs = timer.elapsed();

        emit completedFilesChanged();
        emit failedFilesChanged();
        emit progressChanged();
        emit elapsedTimeChanged();
        emit estimatedTimeChanged();
    }

    qint64 elapsed = timer.elapsed();
    double seconds = elapsed / 1000.0;

    emit logMessage("info", "========== 说话人测试语音生成完成 ==========");
    emit logMessage("info", QString("总耗时：%.2f 秒").arg(seconds));
    emit logMessage("info", QString("成功：%1，失败：%2")
                    .arg(m_completedFiles - m_failedFiles)
                    .arg(m_failedFiles));
    emit logMessage("info", QString("输出目录：%1").arg(outputDir));

    m_isRunning = false;
    emit isRunningChanged();

    emit finished(m_failedFiles == 0, "说话人测试语音生成完成");
}
