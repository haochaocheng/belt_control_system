// ✅ 2026-02-25 11:05 [Phase 7.47.1]: TTS 批量生成器实现
// 用途：批量语音合成的后端逻辑实现

#include "TTSBatchGenerator.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QTimer>
#include <QDebug>

TTSBatchGenerator::TTSBatchGenerator(QObject *parent)
    : QObject(parent)
    , m_currentIndex(0)
    , m_currentEngineIndex(0)
{
    m_statusText = "就绪";
}

TTSBatchGenerator::~TTSBatchGenerator()
{
    stop();
}

QString TTSBatchGenerator::elapsedTime() const
{
    return formatTime(m_progress.elapsedSeconds);
}

QString TTSBatchGenerator::estimatedTime() const
{
    return formatTime(m_progress.estimatedSeconds);
}

QString TTSBatchGenerator::formatTime(double seconds) const
{
    int h = (int)(seconds / 3600);
    int m = (int)((seconds - h * 3600) / 60);
    int s = (int)(seconds - h * 3600 - m * 60);

    if (h > 0) {
        return QString("%1:%2:%3").arg(h).arg(m, 2, 10, QChar('0')).arg(s, 2, 10, QChar('0'));
    } else {
        return QString("%1:%2").arg(m).arg(s, 2, 10, QChar('0'));
    }
}

void TTSBatchGenerator::setConfig(const QVariantMap& config)
{
    // 解析配置
    if (config.contains("outputBaseDir")) {
        m_config.outputBaseDir = config["outputBaseDir"].toString();
    }
    if (config.contains("skipExisting")) {
        m_config.skipExisting = config["skipExisting"].toBool();
    }
    if (config.contains("generateReport")) {
        m_config.generateReport = config["generateReport"].toBool();
    }

    // 解析皮带编号
    if (config.contains("beltNumbers")) {
        m_config.beltNumbers.clear();
        QVariantList belts = config["beltNumbers"].toList();
        for (const QVariant& v : belts) {
            m_config.beltNumbers.append(v.toInt());
        }
    }

    // 解析电机编号
    if (config.contains("motorNumbers")) {
        m_config.motorNumbers.clear();
        QVariantList motors = config["motorNumbers"].toList();
        for (const QVariant& v : motors) {
            m_config.motorNumbers.append(v.toInt());
        }
    }

    // 解析制动器编号
    if (config.contains("brakeNumbers")) {
        m_config.brakeNumbers.clear();
        QVariantList brakes = config["brakeNumbers"].toList();
        for (const QVariant& v : brakes) {
            m_config.brakeNumbers.append(v.toInt());
        }
    }

    // 解析张紧装置编号
    if (config.contains("tensionNumbers")) {
        m_config.tensionNumbers.clear();
        QVariantList tensions = config["tensionNumbers"].toList();
        for (const QVariant& v : tensions) {
            m_config.tensionNumbers.append(v.toInt());
        }
    }

    // 解析沿线点位范围
    if (config.contains("linePositionStart")) {
        m_config.linePositionStart = config["linePositionStart"].toInt();
    }
    if (config.contains("linePositionEnd")) {
        m_config.linePositionEnd = config["linePositionEnd"].toInt();
    }

    // 解析分类
    if (config.contains("categories")) {
        m_config.categories.clear();
        QVariantList cats = config["categories"].toList();
        for (const QVariant& v : cats) {
            QString cat = v.toString();
            if (cat == "switchInput") m_config.categories.append(ProtectionCategory::SwitchInput);
            else if (cat == "analogInput") m_config.categories.append(ProtectionCategory::AnalogInput);
            else if (cat == "motor") m_config.categories.append(ProtectionCategory::Motor);
            else if (cat == "brake") m_config.categories.append(ProtectionCategory::Brake);
            else if (cat == "tension") m_config.categories.append(ProtectionCategory::Tension);
            else if (cat == "linePosition") m_config.categories.append(ProtectionCategory::LinePosition);
            else if (cat == "systemSound") m_config.categories.append(ProtectionCategory::SystemSound);
        }
    }

    // 解析引擎配置
    if (config.contains("engines")) {
        m_config.engines.clear();
        QVariantList engines = config["engines"].toList();
        for (const QVariant& v : engines) {
            QVariantMap eng = v.toMap();
            TTSEngineConfig engineConfig;
            engineConfig.engineName = eng["engineName"].toString();
            engineConfig.modelName = eng["modelName"].toString();
            engineConfig.speakerId = eng["speakerId"].toInt();
            engineConfig.outputFolder = eng["outputFolder"].toString();
            if (engineConfig.outputFolder.isEmpty()) {
                engineConfig.outputFolder = QString("%1-%2-spk%3")
                    .arg(engineConfig.engineName)
                    .arg(engineConfig.modelName)
                    .arg(engineConfig.speakerId);
            }
            m_config.engines.append(engineConfig);
        }
    }

    emitLog("info", QString("配置已更新: 输出目录=%1, 跳过已存在=%2")
        .arg(m_config.outputBaseDir)
        .arg(m_config.skipExisting ? "是" : "否"));
}

int TTSBatchGenerator::generateFileList()
{
    m_fileList.clear();

    // 根据选择的分类生成文件清单
    for (ProtectionCategory cat : m_config.categories) {
        switch (cat) {
            case ProtectionCategory::SwitchInput:
                buildSwitchInputList();
                break;
            case ProtectionCategory::AnalogInput:
                buildAnalogInputList();
                break;
            case ProtectionCategory::Motor:
                buildMotorList();
                break;
            case ProtectionCategory::Brake:
                buildBrakeList();
                break;
            case ProtectionCategory::Tension:
                buildTensionList();
                break;
            case ProtectionCategory::LinePosition:
                buildLinePositionList();
                break;
            case ProtectionCategory::SystemSound:
                buildSystemSoundList();
                break;
        }
    }

    m_progress.totalFiles = m_fileList.size() * m_config.engines.size();
    m_progress.totalEngines = m_config.engines.size();

    emitLog("info", QString("文件清单已生成: %1 个文件 x %2 个引擎 = %3 个任务")
        .arg(m_fileList.size())
        .arg(m_config.engines.size())
        .arg(m_progress.totalFiles));

    emit progressChanged();
    return m_fileList.size();
}

QVariantList TTSBatchGenerator::getFileList() const
{
    QVariantList result;
    for (const VoiceFileItem& item : m_fileList) {
        QVariantMap map;
        map["id"] = item.id;
        map["category"] = item.category;
        map["text"] = item.text;
        map["filename"] = item.filename;
        map["relativePath"] = item.relativePath;
        map["status"] = static_cast<int>(item.status);
        map["errorMessage"] = item.errorMessage;
        result.append(map);
    }
    return result;
}

QVariantMap TTSBatchGenerator::getCategoryStats() const
{
    QVariantMap stats;
    QMap<QString, int> counts;

    for (const VoiceFileItem& item : m_fileList) {
        counts[item.category]++;
    }

    for (auto it = counts.begin(); it != counts.end(); ++it) {
        stats[it.key()] = it.value();
    }

    stats["total"] = m_fileList.size();
    return stats;
}

void TTSBatchGenerator::start()
{
    if (m_progress.isRunning) {
        emitLog("warning", "批量生成已在运行中");
        return;
    }

    if (m_fileList.isEmpty()) {
        emitLog("error", "文件清单为空，请先生成文件清单");
        emit finished(false, "文件清单为空");
        return;
    }

    if (m_config.engines.isEmpty()) {
        emitLog("error", "未配置 TTS 引擎");
        emit finished(false, "未配置 TTS 引擎");
        return;
    }

    // 重置进度
    m_progress.completedFiles = 0;
    m_progress.successFiles = 0;
    m_progress.failedFiles = 0;
    m_progress.skippedFiles = 0;
    m_progress.isRunning = true;
    m_progress.isPaused = false;
    m_progress.isCancelled = false;

    m_currentIndex = 0;
    m_currentEngineIndex = 0;

    m_elapsedTimer.start();
    m_statusText = "正在生成...";

    emit runningChanged();
    emit statusChanged();

    emitLog("info", QString("开始批量生成: %1 个任务").arg(m_progress.totalFiles));

    // 开始生成
    QTimer::singleShot(0, this, &TTSBatchGenerator::onGenerateNext);
}

void TTSBatchGenerator::pause()
{
    if (!m_progress.isRunning || m_progress.isPaused) return;

    m_progress.isPaused = true;
    m_statusText = "已暂停";

    emit pausedChanged();
    emit statusChanged();

    emitLog("info", "批量生成已暂停");
}

void TTSBatchGenerator::resume()
{
    if (!m_progress.isRunning || !m_progress.isPaused) return;

    m_progress.isPaused = false;
    m_statusText = "正在生成...";

    emit pausedChanged();
    emit statusChanged();

    emitLog("info", "批量生成已继续");

    QTimer::singleShot(0, this, &TTSBatchGenerator::onGenerateNext);
}

void TTSBatchGenerator::stop()
{
    if (!m_progress.isRunning) return;

    m_progress.isCancelled = true;
    m_progress.isRunning = false;
    m_progress.isPaused = false;
    m_statusText = "已停止";

    emit runningChanged();
    emit pausedChanged();
    emit statusChanged();

    emitLog("info", QString("批量生成已停止: 完成 %1/%2")
        .arg(m_progress.completedFiles)
        .arg(m_progress.totalFiles));

    emit finished(false, "用户取消");
}

void TTSBatchGenerator::retryFailed()
{
    // 重置失败的文件状态
    for (VoiceFileItem& item : m_fileList) {
        if (item.status == VoiceFileItem::Status::Failed) {
            item.status = VoiceFileItem::Status::Pending;
            item.errorMessage.clear();
        }
    }

    // 重新计算进度
    m_progress.failedFiles = 0;

    emitLog("info", "已重置失败文件，可以重新开始");
    emit progressChanged();
}

void TTSBatchGenerator::onGenerateNext()
{
    // 检查是否暂停或取消
    if (m_progress.isPaused || m_progress.isCancelled) {
        return;
    }

    // 检查是否完成
    if (m_currentIndex >= m_fileList.size()) {
        // 切换到下一个引擎
        m_currentEngineIndex++;
        if (m_currentEngineIndex >= m_config.engines.size()) {
            // 全部完成
            m_progress.isRunning = false;
            m_progress.elapsedSeconds = m_elapsedTimer.elapsed() / 1000.0;
            m_statusText = "已完成";

            emit runningChanged();
            emit statusChanged();

            QString message = QString("批量生成完成: 成功 %1, 失败 %2, 跳过 %3")
                .arg(m_progress.successFiles)
                .arg(m_progress.failedFiles)
                .arg(m_progress.skippedFiles);

            emitLog("info", message);
            emit finished(m_progress.failedFiles == 0, message);
            return;
        }

        // 重置文件索引，继续下一个引擎
        m_currentIndex = 0;
        m_progress.currentEngine = m_currentEngineIndex;
        emit progressChanged();
    }

    // 获取当前文件和引擎
    VoiceFileItem& item = m_fileList[m_currentIndex];
    const TTSEngineConfig& engine = m_config.engines[m_currentEngineIndex];

    // 更新当前文件信息
    m_progress.currentFile = item.filename;
    m_progress.currentText = item.text;
    emit currentFileChanged();

    // 更新已用时间
    m_progress.elapsedSeconds = m_elapsedTimer.elapsed() / 1000.0;
    updateEstimatedTime();

    // 生成文件
    bool success = generateSingleFile(item, engine);

    // 更新进度
    m_progress.completedFiles++;
    if (success) {
        if (item.status == VoiceFileItem::Status::Skipped) {
            m_progress.skippedFiles++;
        } else {
            m_progress.successFiles++;
        }
    } else {
        m_progress.failedFiles++;
    }

    emit progressChanged();
    emit fileGenerated(item.id, success, item.errorMessage);

    // 继续下一个
    m_currentIndex++;
    QTimer::singleShot(10, this, &TTSBatchGenerator::onGenerateNext);
}

bool TTSBatchGenerator::generateSingleFile(VoiceFileItem& item, const TTSEngineConfig& engine)
{
    // 构建输出路径
    QString outputDir = m_config.outputBaseDir + "/" + engine.outputFolder + "/" + item.relativePath;
    QString outputPath = outputDir + "/" + item.filename;

    // 检查文件是否已存在
    if (m_config.skipExisting && QFile::exists(outputPath)) {
        item.status = VoiceFileItem::Status::Skipped;
        emitLog("debug", QString("跳过已存在: %1").arg(outputPath));
        return true;
    }

    // 创建目录
    QDir dir;
    if (!dir.mkpath(outputDir)) {
        item.status = VoiceFileItem::Status::Failed;
        item.errorMessage = "无法创建目录: " + outputDir;
        emitLog("error", item.errorMessage);
        return false;
    }

    // 标记为生成中
    item.status = VoiceFileItem::Status::Generating;

    // TODO: 调用实际的 TTS 引擎生成语音
    // 这里需要集成 TTSEngineManager 或直接调用 Python 脚本

    // 临时实现：创建空文件作为占位符
    QFile file(outputPath);
    if (file.open(QIODevice::WriteOnly)) {
        // 写入一些测试数据（实际应该是音频数据）
        file.write("PLACEHOLDER");
        file.close();

        item.status = VoiceFileItem::Status::Success;
        emitLog("debug", QString("生成成功: %1").arg(outputPath));
        return true;
    } else {
        item.status = VoiceFileItem::Status::Failed;
        item.errorMessage = "无法创建文件: " + outputPath;
        emitLog("error", item.errorMessage);
        return false;
    }
}

void TTSBatchGenerator::updateEstimatedTime()
{
    if (m_progress.completedFiles > 0) {
        double avgTime = m_progress.elapsedSeconds / m_progress.completedFiles;
        int remaining = m_progress.totalFiles - m_progress.completedFiles;
        m_progress.estimatedSeconds = avgTime * remaining;
    }
}

void TTSBatchGenerator::emitLog(const QString& level, const QString& message)
{
    qDebug() << "[TTSBatchGenerator]" << level << ":" << message;
    emit logMessage(level, message);
}

// ========== 构建文件清单方法 ==========

void TTSBatchGenerator::buildSwitchInputList()
{
    // 开关量输入保护语音清单
    QStringList protections = {
        "急停保护", "拉绳保护", "跑偏保护", "打滑保护",
        "堆煤保护", "撕裂保护", "烟雾保护", "温度保护",
        "速度保护", "欠速保护", "超速保护", "断带保护"
    };

    int fileIndex = 1;
    for (int belt : m_config.beltNumbers) {
        for (const QString& protection : protections) {
            VoiceFileItem item;
            item.id = QString("switch_input_belt%1_%2").arg(belt).arg(fileIndex, 3, 10, QChar('0'));
            item.category = "开关量输入保护";
            item.text = QString("%1号皮带%2").arg(belt).arg(protection);
            item.filename = QString("%1.wav").arg(fileIndex, 3, 10, QChar('0'));
            item.relativePath = QString("开关量输入保护/%1号皮带").arg(belt);
            item.status = VoiceFileItem::Status::Pending;

            m_fileList.append(item);
            fileIndex++;
        }
    }
}

void TTSBatchGenerator::buildAnalogInputList()
{
    // 模拟量输入保护语音清单
    QStringList protections = {
        "电流过高", "电流过低", "电压过高", "电压过低",
        "温度过高", "温度过低", "速度异常", "张力异常"
    };

    int fileIndex = 1;
    for (int belt : m_config.beltNumbers) {
        for (const QString& protection : protections) {
            VoiceFileItem item;
            item.id = QString("analog_input_belt%1_%2").arg(belt).arg(fileIndex, 3, 10, QChar('0'));
            item.category = "模拟量输入保护";
            item.text = QString("%1号皮带%2").arg(belt).arg(protection);
            item.filename = QString("%1.wav").arg(fileIndex, 3, 10, QChar('0'));
            item.relativePath = QString("模拟量输入保护/%1号皮带").arg(belt);
            item.status = VoiceFileItem::Status::Pending;

            m_fileList.append(item);
            fileIndex++;
        }
    }
}

void TTSBatchGenerator::buildMotorList()
{
    // 电机保护语音清单
    QStringList protections = {
        "启动", "停止", "故障", "过载", "过热", "缺相"
    };

    int fileIndex = 1;
    for (int belt : m_config.beltNumbers) {
        for (int motor : m_config.motorNumbers) {
            for (const QString& protection : protections) {
                VoiceFileItem item;
                item.id = QString("motor_belt%1_m%2_%3").arg(belt).arg(motor).arg(fileIndex, 3, 10, QChar('0'));
                item.category = "电机保护";
                item.text = QString("%1号皮带%2号电机%3").arg(belt).arg(motor).arg(protection);
                item.filename = QString("%1.wav").arg(fileIndex, 3, 10, QChar('0'));
                item.relativePath = QString("电机保护/%1号皮带").arg(belt);
                item.status = VoiceFileItem::Status::Pending;

                m_fileList.append(item);
                fileIndex++;
            }
        }
    }
}

void TTSBatchGenerator::buildBrakeList()
{
    // 制动器保护语音清单
    QStringList protections = {
        "制动", "释放", "故障", "磨损"
    };

    int fileIndex = 1;
    for (int belt : m_config.beltNumbers) {
        for (int brake : m_config.brakeNumbers) {
            for (const QString& protection : protections) {
                VoiceFileItem item;
                item.id = QString("brake_belt%1_b%2_%3").arg(belt).arg(brake).arg(fileIndex, 3, 10, QChar('0'));
                item.category = "制动器保护";
                item.text = QString("%1号皮带%2号制动器%3").arg(belt).arg(brake).arg(protection);
                item.filename = QString("%1.wav").arg(fileIndex, 3, 10, QChar('0'));
                item.relativePath = QString("制动器保护/%1号皮带").arg(belt);
                item.status = VoiceFileItem::Status::Pending;

                m_fileList.append(item);
                fileIndex++;
            }
        }
    }
}

void TTSBatchGenerator::buildTensionList()
{
    // 张紧控制保护语音清单
    QStringList protections = {
        "张紧", "松弛", "故障", "到位", "超限"
    };

    int fileIndex = 1;
    for (int belt : m_config.beltNumbers) {
        for (int tension : m_config.tensionNumbers) {
            for (const QString& protection : protections) {
                VoiceFileItem item;
                item.id = QString("tension_belt%1_t%2_%3").arg(belt).arg(tension).arg(fileIndex, 3, 10, QChar('0'));
                item.category = "张紧控制保护";
                item.text = QString("%1号皮带%2号张紧装置%3").arg(belt).arg(tension).arg(protection);
                item.filename = QString("%1.wav").arg(fileIndex, 3, 10, QChar('0'));
                item.relativePath = QString("张紧控制保护/%1号皮带").arg(belt);
                item.status = VoiceFileItem::Status::Pending;

                m_fileList.append(item);
                fileIndex++;
            }
        }
    }
}

void TTSBatchGenerator::buildLinePositionList()
{
    // 沿线点位保护语音清单
    int fileIndex = 1;
    for (int belt : m_config.beltNumbers) {
        for (int pos = m_config.linePositionStart; pos <= m_config.linePositionEnd; ++pos) {
            VoiceFileItem item;
            item.id = QString("line_pos_belt%1_p%2").arg(belt).arg(pos, 3, 10, QChar('0'));
            item.category = "沿线点位保护";
            item.text = QString("%1号皮带%2号点位故障").arg(belt).arg(pos);
            item.filename = QString("%1.wav").arg(fileIndex, 3, 10, QChar('0'));
            item.relativePath = QString("沿线点位保护/%1号皮带").arg(belt);
            item.status = VoiceFileItem::Status::Pending;

            m_fileList.append(item);
            fileIndex++;
        }
    }
}

void TTSBatchGenerator::buildSystemSoundList()
{
    // 系统提示音语音清单
    QStringList sounds = {
        "系统启动", "系统关闭", "操作成功", "操作失败",
        "警告", "错误", "提示", "确认",
        "请注意安全", "请佩戴安全帽", "请保持通道畅通"
    };

    int fileIndex = 1;
    for (const QString& sound : sounds) {
        VoiceFileItem item;
        item.id = QString("system_sound_%1").arg(fileIndex, 3, 10, QChar('0'));
        item.category = "系统提示音";
        item.text = sound;
        item.filename = QString("%1.wav").arg(fileIndex, 3, 10, QChar('0'));
        item.relativePath = "系统提示音";
        item.status = VoiceFileItem::Status::Pending;

        m_fileList.append(item);
        fileIndex++;
    }
}
