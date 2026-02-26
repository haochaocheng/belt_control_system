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
    emit completedFilesChanged();
    emit failedFilesChanged();
    emit progressChanged();

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

        emit completedFilesChanged();
        emit failedFilesChanged();
        emit progressChanged();
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
    out.setCodec("UTF-8");

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
            }
        }
    }
}

void BatchAudioGenerator::generateSwitchInputTasks(const EngineConfig &engine)
{
    // 开关量输入保护：33 个文件/皮带
    QStringList texts = {
        "急停保护", "拉绳保护", "跑偏保护", "打滑保护",
        "堆煤保护", "温度保护", "烟雾保护", "自动洒水",
        "撕裂保护", "纵撕保护", "超温保护", "欠速保护",
        "超速保护", "低速保护", "堵转保护", "过载保护",
        "欠载保护", "空载保护", "满载保护", "轻载保护",
        "重载保护", "启动保护", "停止保护", "正转保护",
        "反转保护", "前进保护", "后退保护", "上升保护",
        "下降保护", "开门保护", "关门保护", "锁定保护",
        "解锁保护"
    };

    for (int beltNum : m_beltNumbers) {
        QString beltFolder = QString("%1号皮带").arg(beltNum);
        QString outputDir = QString("%1/%2/开关量输入保护/%3/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltFolder);

        for (int i = 0; i < texts.size(); ++i) {
            FileTask task;
            task.category = "switchInput";
            task.text = QString("%1号皮带%2").arg(beltNum).arg(texts[i]);
            task.outputPath = QString("%1%2.wav").arg(outputDir).arg(i + 1, 3, 10, QChar('0'));
            task.engineName = engine.engineName;
            task.modelName = engine.modelName;
            task.speakerId = engine.speakerId;
            m_tasks.append(task);
        }
    }
}

void BatchAudioGenerator::generateAnalogInputTasks(const EngineConfig &engine)
{
    // 模拟量输入保护：16 个文件/皮带
    QStringList texts = {
        "电流过高", "电流过低", "电压过高", "电压过低",
        "温度过高", "温度过低", "速度过高", "速度过低",
        "压力过高", "压力过低", "流量过高", "流量过低",
        "液位过高", "液位过低", "功率过高", "功率过低"
    };

    for (int beltNum : m_beltNumbers) {
        QString beltFolder = QString("%1号皮带").arg(beltNum);
        QString outputDir = QString("%1/%2/模拟量输入保护/%3/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltFolder);

        for (int i = 0; i < texts.size(); ++i) {
            FileTask task;
            task.category = "analogInput";
            task.text = QString("%1号皮带%2").arg(beltNum).arg(texts[i]);
            task.outputPath = QString("%1%2.wav").arg(outputDir).arg(i + 1, 3, 10, QChar('0'));
            task.engineName = engine.engineName;
            task.modelName = engine.modelName;
            task.speakerId = engine.speakerId;
            m_tasks.append(task);
        }
    }
}

void BatchAudioGenerator::generateMotorTasks(const EngineConfig &engine)
{
    // 电机保护：12 个文件/皮带/电机
    QStringList texts = {
        "过载", "欠载", "过流", "欠流",
        "过压", "欠压", "过热", "欠热",
        "堵转", "失速", "缺相", "接地"
    };

    for (int beltNum : m_beltNumbers) {
        for (int motorNum : m_motorNumbers) {
            QString folder = QString("%1号皮带/%2号电机").arg(beltNum).arg(motorNum);
            QString outputDir = QString("%1/%2/电机保护/%3/")
                                .arg(m_outputBaseDir)
                                .arg(engine.outputFolder)
                                .arg(folder);

            for (int i = 0; i < texts.size(); ++i) {
                FileTask task;
                task.category = "motor";
                task.text = QString("%1号皮带%2号电机%3").arg(beltNum).arg(motorNum).arg(texts[i]);
                task.outputPath = QString("%1%2.wav").arg(outputDir).arg(i + 1, 3, 10, QChar('0'));
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
    // 制动器保护：8 个文件/皮带/制动器
    QStringList texts = {
        "制动失效", "制动过紧", "制动过松", "制动异响",
        "制动过热", "制动磨损", "制动卡死", "制动延迟"
    };

    for (int beltNum : m_beltNumbers) {
        for (int brakeNum : m_brakeNumbers) {
            QString folder = QString("%1号皮带/%2号制动器").arg(beltNum).arg(brakeNum);
            QString outputDir = QString("%1/%2/制动器保护/%3/")
                                .arg(m_outputBaseDir)
                                .arg(engine.outputFolder)
                                .arg(folder);

            for (int i = 0; i < texts.size(); ++i) {
                FileTask task;
                task.category = "brake";
                task.text = QString("%1号皮带%2号制动器%3").arg(beltNum).arg(brakeNum).arg(texts[i]);
                task.outputPath = QString("%1%2.wav").arg(outputDir).arg(i + 1, 3, 10, QChar('0'));
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
    // 张紧控制保护：10 个文件/皮带/张紧装置
    QStringList texts = {
        "张紧过紧", "张紧过松", "张紧失效", "张紧异响",
        "张紧过热", "张紧磨损", "张紧卡死", "张紧延迟",
        "张紧超限", "张紧欠限"
    };

    for (int beltNum : m_beltNumbers) {
        for (int tensionNum : m_tensionNumbers) {
            QString folder = QString("%1号皮带/%2号张紧装置").arg(beltNum).arg(tensionNum);
            QString outputDir = QString("%1/%2/张紧控制保护/%3/")
                                .arg(m_outputBaseDir)
                                .arg(engine.outputFolder)
                                .arg(folder);

            for (int i = 0; i < texts.size(); ++i) {
                FileTask task;
                task.category = "tension";
                task.text = QString("%1号皮带%2号张紧装置%3").arg(beltNum).arg(tensionNum).arg(texts[i]);
                task.outputPath = QString("%1%2.wav").arg(outputDir).arg(i + 1, 3, 10, QChar('0'));
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
    // 沿线点位保护：linePositionEnd - linePositionStart + 1 个文件/皮带
    for (int beltNum : m_beltNumbers) {
        QString beltFolder = QString("%1号皮带").arg(beltNum);
        QString outputDir = QString("%1/%2/沿线点位保护/%3/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltFolder);

        for (int pos = m_linePositionStart; pos <= m_linePositionEnd; ++pos) {
            FileTask task;
            task.category = "linePosition";
            task.text = QString("%1号皮带%2号点位").arg(beltNum).arg(pos);
            task.outputPath = QString("%1%2.wav").arg(outputDir).arg(pos, 3, 10, QChar('0'));
            task.engineName = engine.engineName;
            task.modelName = engine.modelName;
            task.speakerId = engine.speakerId;
            m_tasks.append(task);
        }
    }
}

void BatchAudioGenerator::generateSystemSoundTasks(const EngineConfig &engine)
{
    // 系统提示音：20 个文件
    QStringList texts = {
        "系统启动", "系统关闭", "系统重启", "系统故障",
        "系统正常", "系统异常", "系统报警", "系统警告",
        "操作成功", "操作失败", "操作取消", "操作确认",
        "数据保存", "数据加载", "数据删除", "数据导出",
        "网络连接", "网络断开", "电池电量低", "电池充电中"
    };

    QString outputDir = QString("%1/%2/系统提示音/")
                        .arg(m_outputBaseDir)
                        .arg(engine.outputFolder);

    for (int i = 0; i < texts.size(); ++i) {
        FileTask task;
        task.category = "systemSound";
        task.text = texts[i];
        task.outputPath = QString("%1%2.wav").arg(outputDir).arg(i + 1, 3, 10, QChar('0'));
        task.engineName = engine.engineName;
        task.modelName = engine.modelName;
        task.speakerId = engine.speakerId;
        m_tasks.append(task);
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

    // 切换到指定引擎和模型
    if (!m_ttsEngineManager->switchEngine(task.engineName)) {
        emit logMessage("error", QString("  无法切换到引擎: %1").arg(task.engineName));
        return false;
    }

    if (!m_ttsEngineManager->switchModel(task.modelName)) {
        emit logMessage("error", QString("  无法切换到模型: %1").arg(task.modelName));
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
    out.setCodec("UTF-8");

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
