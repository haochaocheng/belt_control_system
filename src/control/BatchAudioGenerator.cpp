// ✅ 2026-02-26 08:15 [Phase 7.47.3]: 批量音频生成器实现
// 用途：批量生成语音文件，支持多分类、多引擎、进度统计
// 参考：docs/2026-02-24/03-语音管理界面批量合成功能实施计划.md

#include "BatchAudioGenerator.h"
#include "tts/TTSBatchConfig.h"
#include "tts/TTSEngineManager.h"
// #include "tts/VoiceFileList.h"  // ⚠️ 2026-02-28 [Phase 7.47.42]: 已废弃，不再使用
//                                  // 原因：VoiceFileList.h的保护项与真实DI模块不一致
//                                  // 现在使用内联定义（来自docs/2026-02-24/01-TTS语音文件批量生成清单.md）
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QDebug>
#include <QElapsedTimer>
#include <QCoreApplication>

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
        // ✅ 2026-02-27 06:00 [Phase 7.47.31]: 读取语音管理界面保存的语速和音量参数
        engine.rate = engineMap.value("rate", 1.0).toDouble();
        engine.volume = engineMap.value("volume", 0.8).toDouble();
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

    // 生成任务
    generateTasks();

    // ✅ 2026-02-27 08:00 [Phase 7.47.33]: 重新计算totalFiles，确保与实际任务数一致
    m_totalFiles = m_tasks.size();
    emit totalFilesChanged();

    emit logMessage("info", "========== 开始批量生成 ==========");
    emit logMessage("info", QString("总任务数：%1").arg(m_totalFiles));

    // 执行任务
    QElapsedTimer timer;
    timer.start();

    for (int i = 0; i < m_tasks.size(); ++i) {
        // ✅ 2026-02-27 09:00 [Phase 7.47.33]: 处理事件队列，让 QML 的 stop() 调用能被送达
        // 原因：start() 在主线程同步执行，for 循环阻塞事件循环
        //       不调用 processEvents，QML 的 stop 按钮点击永远无法被处理
        QCoreApplication::processEvents();

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

    // ✅ 2026-02-27 09:00 [Phase 7.47.33]: 通知 TTS 引擎取消当前正在等待的合成命令
    // 原因：sendCommand() 用 waitForReadyRead 轮询阻塞，需要通过 cancelPending 中断
    //       否则 stop 后 sendCommand 仍在等响应，再次 start 会协议错位导致死锁
    if (m_ttsEngineManager) {
        m_ttsEngineManager->stop();
    }

    // ✅ 2026-02-27 08:00 [Phase 7.47.33]: 清空任务列表，防止残留任务
    // 原因：stop后如果sendCommand还在等待响应，响应回来后循环会检查m_isRunning退出
    //       但如果用户立即再次start，需要确保旧任务不会干扰
    m_tasks.clear();
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
            // ✅ 2026-03-02 [Phase 7.47.69]: 新增模块在线状态语音分类
            } else if (category == "moduleStatus") {
                generateModuleStatusTasks(engine);
            }
        }
    }
}

void BatchAudioGenerator::generateSwitchInputTasks(const EngineConfig &engine)
{
    // ✅ 2026-02-28 [Phase 7.47.42]: 重构为真实文档定义
    // 来源：docs/2026-02-24/01-TTS语音文件批量生成清单.md 第二章（8种DI保护）
    // 规则：TTS合成文本 = 完整中文句子（含皮带号），如"1号皮带沿线急停保护"
    //       音频文件名  = 短名（去掉"X号皮带"前缀，去掉"保护"后缀），如"沿线急停.wav"
    //       触发查找   = 与文件名完全一致，如"沿线急停"
    // 与AudioPathMapper.PROTECTION_NAME_MAP中的8个条目一致
    //
    // 旧代码（使用VoiceFileList.h的33项）已废弃：
    // const QStringList &items = SwitchInputVoice::PROTECTION_ITEMS;
    // protName.replace("%1号皮带", "");
    // task.outputPath = QString("%1%2.wav").arg(outputDir, protName);

    struct ProtDef {
        QString textTemplate;   // TTS合成文本模板（%1=皮带号）
        QString fileName;       // 音频文件短名（不含.wav后缀）
    };
    static const QList<ProtDef> DEFS = {
        {"%1号皮带沿线急停保护", "沿线急停"},    // bit 0 (channelNumber: 0)
        {"%1号皮带沿线跑偏保护", "沿线跑偏"},    // bit 1 (channelNumber: 1)
        {"%1号皮带沿线撕裂保护", "沿线撕裂"},    // bit 2 (channelNumber: 2)
        {"%1号皮带烟雾保护",     "烟雾"},        // bit 3 (channelNumber: 3)
        {"%1号皮带温度保护",     "温度"},        // bit 4 (channelNumber: 4)
        {"%1号皮带护网保护",     "护网"},        // bit 5 (channelNumber: 5)
        {"%1号皮带堆煤保护",     "堆煤"},        // bit 6 (channelNumber: 6)
        {"%1号皮带主机急停保护", "主机急停"},    // bit 7 (channelNumber: 7)
    };

    for (int beltNum : m_beltNumbers) {
        // 目录格式：{outputBaseDir}/{engineFolder}/{皮带号}#PD/
        QString outputDir = QString("%1/%2/%3#PD/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltNum);

        for (const ProtDef &def : DEFS) {
            FileTask task;
            task.category = "switchInput";
            task.text = def.textTemplate.arg(beltNum);              // TTS合成内容
            task.outputPath = QString("%1%2.wav").arg(outputDir, def.fileName);  // 文件路径
            task.engineName = engine.engineName;
            task.modelName = engine.modelName;
            task.speakerId = engine.speakerId;
            task.rate = engine.rate;
            task.volume = engine.volume;
            m_tasks.append(task);
        }
    }
}

void BatchAudioGenerator::generateAnalogInputTasks(const EngineConfig &engine)
{
    // ✅ 2026-02-28 [Phase 7.47.42]: 重构为真实文档定义
    // 来源：docs/2026-02-24/01-TTS语音文件批量生成清单.md 第三章（8种模拟量保护）
    // 规则：TTS合成文本 = 完整中文句子，音频文件名 = 短名（去掉皮带号前缀+保护后缀）
    //
    // 旧代码（使用VoiceFileList.h的16项）已废弃：
    // const QStringList &items = AnalogInputVoice::PROTECTION_ITEMS;
    // protName.replace("%1号皮带", "");

    struct ProtDef {
        QString textTemplate;
        QString fileName;
    };
    // ✅ 2026-03-05 [Phase 7.48.5]: 扩展模拟量保护从8项到21项
    // 改名6项：张力过大→张力上限、张力过小→张力下限、温度一过高→温度一、温度二过高→温度二、电压过高→电压过压、电压过低→电压欠压
    // 新增13项：煤流、煤仓高度、温度、湿度、烟雾浓度、气压、氧气、甲烷、一氧化碳、硫化氢、二氧化碳、风速、粉尘浓度
    static const QList<ProtDef> DEFS = {
        // 设备运行保护（10项）
        {"%1号皮带速度超速保护",   "速度超速"},
        {"%1号皮带低速打滑保护",   "低速打滑"},
        {"%1号皮带张力上限保护",   "张力上限"},      // 原"张力过大"改名
        {"%1号皮带张力下限保护",   "张力下限"},      // 原"张力过小"改名
        {"%1号皮带煤流保护",       "煤流"},          // 新增
        {"%1号皮带煤仓高度保护",   "煤仓高度"},      // 新增
        {"%1号皮带温度一保护",     "温度一"},        // 原"温度一过高"改名
        {"%1号皮带温度二保护",     "温度二"},        // 原"温度二过高"改名
        {"%1号皮带电压过压保护",   "电压过压"},      // 原"电压过高"改名
        {"%1号皮带电压欠压保护",   "电压欠压"},      // 原"电压过低"改名
        // 环境安全监测（8项）
        {"%1号皮带温度保护",       "温度"},          // 新增 - 环境温度（区别于设备温度一/二）
        {"%1号皮带湿度保护",       "湿度"},          // 新增
        {"%1号皮带烟雾浓度保护",   "烟雾浓度"},      // 新增 - 烟雾浓度（区别于开关量烟雾）
        {"%1号皮带气压保护",       "气压"},          // 新增
        {"%1号皮带氧气保护",       "氧气"},          // 新增
        {"%1号皮带甲烷保护",       "甲烷"},          // 新增
        {"%1号皮带一氧化碳保护",   "一氧化碳"},      // 新增
        {"%1号皮带硫化氢保护",     "硫化氢"},        // 新增
        // 安全规程补充（3项）
        {"%1号皮带二氧化碳保护",   "二氧化碳"},      // 新增
        {"%1号皮带风速保护",       "风速"},          // 新增
        {"%1号皮带粉尘浓度保护",   "粉尘浓度"},      // 新增
    };

    for (int beltNum : m_beltNumbers) {
        QString outputDir = QString("%1/%2/%3#PD/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltNum);

        for (const ProtDef &def : DEFS) {
            FileTask task;
            task.category = "analogInput";
            task.text = def.textTemplate.arg(beltNum);
            task.outputPath = QString("%1%2.wav").arg(outputDir, def.fileName);
            task.engineName = engine.engineName;
            task.modelName = engine.modelName;
            task.speakerId = engine.speakerId;
            task.rate = engine.rate;
            task.volume = engine.volume;
            m_tasks.append(task);
        }
    }
}

void BatchAudioGenerator::generateMotorTasks(const EngineConfig &engine)
{
    // ✅ 2026-02-28 [Phase 7.47.42]: 重构为真实文档定义
    // 来源：docs/2026-02-24/01-TTS语音文件批量生成清单.md 第四章（9种电机保护）
    // 规则：文本模板 %1=皮带号, %2=电机号
    //       文件名模板 %1=电机号（保留电机号，去掉皮带号前缀和保护后缀）
    //
    // 旧代码（使用VoiceFileList.h的12项）已废弃：
    // const QStringList &items = MotorVoice::PROTECTION_ITEMS;

    struct ProtDef {
        QString textTemplate;   // %1=皮带号, %2=电机号
        QString fileNameTpl;    // %1=电机号
    };
    // ✅ 2026-03-10 [Phase 7.48.30]: 从9种扩展到14种电机保护语音
    // ✅ 2026-03-10 [Phase 7.48.37]: 从14种扩展到15种（新增启动预警）
    // 旧：14项（电流过载~运行失败）
    static const QList<ProtDef> DEFS = {
        {"%1号皮带%2号电机电流过载保护",     "%1号电机电流过载"},
        {"%1号皮带%2号电机温度过高保护",     "%1号电机温度过高"},
        {"%1号皮带%2号电机前轴承温度过高保护", "%1号电机前轴承温度过高"},
        {"%1号皮带%2号电机后轴承温度过高保护", "%1号电机后轴承温度过高"},
        // ✅ 2026-03-13 [Phase 7.48.43]: A/B/C→甲/乙/丙，X/Y→水平/垂直（TTS中文兼容）
        // 旧：X轴振动/Y轴振动/A相绕组/B相绕组/C相绕组
        {"%1号皮带%2号电机水平振动过大保护",      "%1号电机水平振动过大"},
        {"%1号皮带%2号电机垂直振动过大保护",      "%1号电机垂直振动过大"},
        {"%1号皮带%2号电机甲相绕组温度过高保护",  "%1号电机甲相绕组温度过高"},
        {"%1号皮带%2号电机乙相绕组温度过高保护",  "%1号电机乙相绕组温度过高"},
        {"%1号皮带%2号电机丙相绕组温度过高保护",  "%1号电机丙相绕组温度过高"},
        {"%1号皮带%2号电机堵转保护",         "%1号电机堵转"},
        {"%1号皮带%2号电机起动超时保护",     "%1号电机起动超时"},
        {"%1号皮带%2号电机功率异常保护",     "%1号电机功率异常"},
        {"%1号皮带%2号电机三相不平衡保护",   "%1号电机三相不平衡"},
        // ✅ 2026-03-11 [Phase 7.48.37]: 修改文件名和TTS文字
        // 旧："%1号皮带%2号电机启动预警" → "1号电机启动预警.wav"
        // 新：TTS文字="X号皮带X号电机准备启动，请注意安全" → 文件名="电机X启动.wav"
        {"%1号皮带%2号电机准备启动，请注意安全",  "电机%1启动"},    // ✅ 2026-03-11 [Phase 7.48.37]: 修改
        {"%1号皮带%2号电机运行失败",              "电机%1失败"},    // ✅ 2026-03-11 [Phase 7.48.37]: 修改
    };

    for (int beltNum : m_beltNumbers) {
        QString outputDir = QString("%1/%2/%3#PD/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltNum);

        for (int motorNum : m_motorNumbers) {
            for (const ProtDef &def : DEFS) {
                FileTask task;
                task.category = "motor";
                task.text = def.textTemplate.arg(beltNum).arg(motorNum);
                task.outputPath = QString("%1%2.wav")
                                  .arg(outputDir)
                                  .arg(def.fileNameTpl.arg(motorNum));
                task.engineName = engine.engineName;
                task.modelName = engine.modelName;
                task.speakerId = engine.speakerId;
                task.rate = engine.rate;
                task.volume = engine.volume;
                m_tasks.append(task);
            }
        }
    }
}

void BatchAudioGenerator::generateBrakeTasks(const EngineConfig &engine)
{
    // ✅ 2026-02-28 [Phase 7.47.42]: 重构为真实文档定义
    // 来源：docs/2026-02-24/01-TTS语音文件批量生成清单.md 第五章（3种制动器保护）
    // 规则：文件名保留制动器编号，去掉皮带号前缀和保护后缀
    //
    // 旧代码（使用VoiceFileList.h的8项）已废弃：
    // const QStringList &items = BrakeVoice::PROTECTION_ITEMS;

    struct ProtDef {
        QString textTemplate;   // %1=皮带号, %2=制动器号
        QString fileNameTpl;    // %1=制动器号
    };
    static const QList<ProtDef> DEFS = {
        {"%1号皮带%2号制动器温度过高保护", "%1号制动器温度过高"},
        {"%1号皮带%2号制动器压力异常保护", "%1号制动器压力异常"},
        {"%1号皮带%2号制动器故障保护",     "%1号制动器故障"},
        // ✅ 2026-03-14 [Phase 7.48.45]: 新增松闸预警、松闸失败、抱闸失败
        {"%1号皮带%2号制动器准备松闸，请注意安全", "制动器%1松闸"},
        {"%1号皮带%2号制动器松闸失败",             "制动器%1松闸失败"},
        {"%1号皮带%2号制动器抱闸失败",             "制动器%1抱闸失败"},
    };

    for (int beltNum : m_beltNumbers) {
        QString outputDir = QString("%1/%2/%3#PD/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltNum);

        for (int brakeNum : m_brakeNumbers) {
            for (const ProtDef &def : DEFS) {
                FileTask task;
                task.category = "brake";
                task.text = def.textTemplate.arg(beltNum).arg(brakeNum);
                task.outputPath = QString("%1%2.wav")
                                  .arg(outputDir)
                                  .arg(def.fileNameTpl.arg(brakeNum));
                task.engineName = engine.engineName;
                task.modelName = engine.modelName;
                task.speakerId = engine.speakerId;
                task.rate = engine.rate;
                task.volume = engine.volume;
                m_tasks.append(task);
            }
        }
    }
}

void BatchAudioGenerator::generateTensionTasks(const EngineConfig &engine)
{
    // ✅ 2026-02-28 [Phase 7.47.42]: 重构为真实文档定义
    // 来源：docs/2026-02-24/01-TTS语音文件批量生成清单.md 第六章（3种张紧保护）
    // 规则：文件名保留张紧装置编号，去掉皮带号前缀和保护后缀
    //
    // 旧代码（使用VoiceFileList.h的10项）已废弃：
    // const QStringList &items = TensionVoice::PROTECTION_ITEMS;

    struct ProtDef {
        QString textTemplate;   // %1=皮带号, %2=张紧号
        QString fileNameTpl;    // %1=张紧号
    };
    static const QList<ProtDef> DEFS = {
        {"%1号皮带%2号张紧装置张紧力过大保护", "%1号张紧装置张紧力过大"},
        {"%1号皮带%2号张紧装置张紧力过小保护", "%1号张紧装置张紧力过小"},
        {"%1号皮带%2号张紧装置故障保护",       "%1号张紧装置故障"},
    };

    for (int beltNum : m_beltNumbers) {
        QString outputDir = QString("%1/%2/%3#PD/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltNum);

        for (int tensionNum : m_tensionNumbers) {
            for (const ProtDef &def : DEFS) {
                FileTask task;
                task.category = "tension";
                task.text = def.textTemplate.arg(beltNum).arg(tensionNum);
                task.outputPath = QString("%1%2.wav")
                                  .arg(outputDir)
                                  .arg(def.fileNameTpl.arg(tensionNum));
                task.engineName = engine.engineName;
                task.modelName = engine.modelName;
                task.speakerId = engine.speakerId;
                task.rate = engine.rate;
                task.volume = engine.volume;
                m_tasks.append(task);
            }

            // ✅ 2026-03-18 [Phase 7.48.53]: 从generateBeltOperationTasks移入，确保tension分类包含启动预警和运行失败语音
            // 张紧启动预警：每台张紧1个
            {
                FileTask task;
                task.category = "tension";
                task.text = QString("%1号皮带%2号张紧准备启动，请注意安全").arg(beltNum).arg(tensionNum);
                task.outputPath = QString("%1%2号张紧启动.wav").arg(outputDir).arg(tensionNum);
                task.engineName = engine.engineName;
                task.modelName = engine.modelName;
                task.speakerId = engine.speakerId;
                task.rate = engine.rate;
                task.volume = engine.volume;
                m_tasks.append(task);
            }

            // 张紧运行失败：每台张紧1个
            // 旧：task.text = QString("%1号张紧运行失败").arg(tensionNum);  // 缺少皮带号
            // ✅ 2026-03-18 [Phase 7.48.53]: 修复TTS文本包含皮带号，如"1号皮带1号张紧运行失败"
            {
                FileTask task;
                task.category = "tension";
                task.text = QString("%1号皮带%2号张紧运行失败").arg(beltNum).arg(tensionNum);
                task.outputPath = QString("%1%2号张紧运行失败.wav").arg(outputDir).arg(tensionNum);
                task.engineName = engine.engineName;
                task.modelName = engine.modelName;
                task.speakerId = engine.speakerId;
                task.rate = engine.rate;
                task.volume = engine.volume;
                m_tasks.append(task);
            }
        }
    }
}

void BatchAudioGenerator::generateLinePositionTasks(const EngineConfig &engine)
{
    // ✅ 2026-02-28 [Phase 7.47.42]: 重构为真实文档定义（3种保护类型）
    // 来源：docs/2026-02-24/01-TTS语音文件批量生成清单.md 第七章（3种沿线点位保护）
    // 规则：每个点位生成3个文件（急停/跑偏/撕裂）
    //       文件名保留点位号，去掉皮带号前缀和保护后缀
    //
    // 旧代码（只生成1种"故障"）已废弃：
    // const QString &itemTemplate = LinePositionVoice::PROTECTION_TEMPLATE;
    // task.text = itemTemplate.arg(beltNum).arg(pos);
    // task.outputPath = QString("%1%2号点位故障.wav").arg(outputDir).arg(pos);

    struct ProtDef {
        QString textTemplate;   // %1=皮带号, %2=点位号
        QString fileNameTpl;    // %1=点位号
    };
    static const QList<ProtDef> DEFS = {
        {"%1号皮带%2号沿线急停保护", "%1号沿线急停"},
        {"%1号皮带%2号沿线跑偏保护", "%1号沿线跑偏"},
        {"%1号皮带%2号沿线撕裂保护", "%1号沿线撕裂"},
    };

    for (int beltNum : m_beltNumbers) {
        QString outputDir = QString("%1/%2/%3#PD/")
                            .arg(m_outputBaseDir)
                            .arg(engine.outputFolder)
                            .arg(beltNum);

        for (int pos = m_linePositionStart; pos <= m_linePositionEnd; ++pos) {
            for (const ProtDef &def : DEFS) {
                FileTask task;
                task.category = "linePosition";
                task.text = def.textTemplate.arg(beltNum).arg(pos);
                task.outputPath = QString("%1%2.wav")
                                  .arg(outputDir)
                                  .arg(def.fileNameTpl.arg(pos));
                task.engineName = engine.engineName;
                task.modelName = engine.modelName;
                task.speakerId = engine.speakerId;
                task.rate = engine.rate;
                task.volume = engine.volume;
                m_tasks.append(task);
            }
        }
    }
}

void BatchAudioGenerator::generateSystemSoundTasks(const EngineConfig &engine)
{
    // ✅ 2026-02-28 [Phase 7.47.42]: 重构为真实文档定义（16种系统提示音）
    // 来源：docs/2026-02-24/01-TTS语音文件批量生成清单.md 第八章（系统状态提示音）
    // 规则：系统提示音无皮带号前缀，TTS文本=文件名（完整中文）
    //
    // 旧代码（使用VoiceFileList.h的20项）已废弃：
    // const QStringList &soundNames = SystemSoundVoice::SOUND_ITEMS;

    // 系统提示音：TTS文本 = 文件名（无皮带号前缀，无需短名转换）
    static const QStringList SOUNDS = {
        // 8.1 通用提示音
        "系统启动完成",
        "系统正在关闭",
        "设备配置已保存",
        "设备配置保存失败",
        "网络连接正常",
        "网络连接断开",
        "MQTT连接成功",
        "MQTT连接失败",
        "数据同步完成",
        "数据同步失败",
        // 8.2 操作提示音
        "请确认操作",
        "操作已取消",
        "操作成功",
        "操作失败",
        "参数超出范围",
        "请输入有效数值",
    };

    // 系统提示音放在 Sounds 目录
    QString outputDir = QString("%1/%2/Sounds/")
                        .arg(m_outputBaseDir)
                        .arg(engine.outputFolder);

    for (const QString &soundName : SOUNDS) {
        FileTask task;
        task.category = "systemSound";
        task.text = soundName;                                              // TTS合成内容
        task.outputPath = QString("%1%2.wav").arg(outputDir, soundName);    // 文件名=TTS文本
        task.engineName = engine.engineName;
        task.modelName = engine.modelName;
        task.speakerId = engine.speakerId;
        task.rate = engine.rate;
        task.volume = engine.volume;
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
        // ✅ 2026-03-20 [Phase 7.48.60]: 中文数字映射（用于TTS自然语音）
        static const QStringList chineseNums = {
            "", "一", "二", "三", "四", "五", "六", "七", "八"
        };
        for (const QString &op : beltOps) {
            FileTask task;
            task.category = "beltOperation";
            // ✅ 2026-03-20 [Phase 7.48.60]: 启动语音使用自然语言TTS文字，文件名不变
            // ❌ 原来: task.text = QString("%1号%2").arg(beltNum).arg(op)
            if (op == "皮带启动") {
                QString chNum = (beltNum >= 1 && beltNum <= 8) ? chineseNums.at(beltNum) : QString::number(beltNum);
                task.text = QString("%1号皮带准备启动，注意安全").arg(chNum);
            } else {
                task.text = QString("%1号%2").arg(beltNum).arg(op);
            }
            task.outputPath = QString("%1%2号%3.wav").arg(outputDir).arg(beltNum).arg(op);
            task.engineName = engine.engineName;
            task.modelName = engine.modelName;
            task.speakerId = engine.speakerId;
            task.rate = engine.rate;
            task.volume = engine.volume;
            m_tasks.append(task);
        }

        // 旧：电机运行失败：每台电机1个（已在DEFS中定义"电机%1失败"，此处重复且文件名不一致）
        // ✅ 2026-03-13 [Phase 7.48.44]: 注释掉重复代码，避免生成"1号电机运行失败.wav"和"电机1失败.wav"两个文件
        // for (int motorNum : m_motorNumbers) {
        //     FileTask task;
        //     task.category = "beltOperation";
        //     task.text = QString("%1号电机运行失败").arg(motorNum);
        //     task.outputPath = QString("%1%2号电机运行失败.wav").arg(outputDir).arg(motorNum);
        //     task.engineName = engine.engineName;
        //     task.modelName = engine.modelName;
        //     task.speakerId = engine.speakerId;
        //     task.rate = engine.rate;
        //     task.volume = engine.volume;
        //     m_tasks.append(task);
        // }

        // 旧：松闸运行失败（已在DEFS中定义"制动器X松闸失败"，此处重复且文件名不一致）
        // ✅ 2026-03-14 [Phase 7.48.45]: 注释掉重复代码
        // for (int brakeNum : m_brakeNumbers) {
        //     FileTask task;
        //     task.category = "beltOperation";
        //     task.text = QString("%1号松闸运行失败").arg(brakeNum);
        //     task.outputPath = QString("%1%2号松闸运行失败.wav").arg(outputDir).arg(brakeNum);
        //     task.engineName = engine.engineName;
        //     task.modelName = engine.modelName;
        //     task.speakerId = engine.speakerId;
        //     task.rate = engine.rate;
        //     task.volume = engine.volume;
        //     m_tasks.append(task);
        // }

        // 旧：张紧启动预警和运行失败
        // ✅ 2026-03-18 [Phase 7.48.53]: 已移至generateTensionTasks中，确保tension分类勾选即可生成
        // for (int tensionNum : m_tensionNumbers) {
        //     FileTask task;
        //     task.category = "beltOperation";
        //     task.text = QString("%1号皮带%2号张紧准备启动，请注意安全").arg(beltNum).arg(tensionNum);
        //     task.outputPath = QString("%1%2号张紧启动.wav").arg(outputDir).arg(tensionNum);
        //     ...
        // }
        // for (int tensionNum : m_tensionNumbers) {
        //     FileTask task;
        //     task.category = "beltOperation";
        //     task.text = QString("%1号张紧运行失败").arg(tensionNum);
        //     task.outputPath = QString("%1%2号张紧运行失败.wav").arg(outputDir).arg(tensionNum);
        //     ...
        // }
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
            task.rate = engine.rate;
            task.volume = engine.volume;
            m_tasks.append(task);
        }
    }
}

// ✅ 2026-03-02 [Phase 7.47.69]: 模块在线状态语音（连接失败/模块离线）
// 文件存储在 {outputBaseDir}/{engine.outputFolder}/Status/ 目录
// 路径格式：{audioBaseDir}/{engine}-{model}-spk{id}/Status/{name}.wav
// AudioPathMapper 的静态方法读取相同的 TTSConfigManager 配置，构造一致路径
void BatchAudioGenerator::generateModuleStatusTasks(const EngineConfig &engine)
{
    struct StatusDef {
        QString text;      // TTS 合成文本
        QString fileName;  // 输出文件名（不含 .wav）
    };

    static const QList<StatusDef> DEFS = {
        {"连接MQTT服务器失败，请检查网络连接",      "连接服务器失败"},
        {"开关量输入模块一离线，请检查设备连接",    "开关量模块一离线"},
        {"开关量输入模块二离线，请检查设备连接",    "开关量模块二离线"},
        {"模拟量输入模块一离线，请检查设备连接",    "模拟量模块一离线"},
        {"模拟量输入模块二离线，请检查设备连接",    "模拟量模块二离线"},
    };

    QString statusDir = QString("%1/%2/Status/")
                        .arg(m_outputBaseDir)
                        .arg(engine.outputFolder);

    for (const StatusDef &def : DEFS) {
        FileTask task;
        task.category   = "moduleStatus";
        task.text       = def.text;
        task.outputPath = statusDir + def.fileName + ".wav";
        task.engineName = engine.engineName;
        task.modelName  = engine.modelName;
        task.speakerId  = engine.speakerId;
        task.rate       = engine.rate;
        task.volume     = engine.volume;
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
    // ✅ 2026-02-26 10:00 [Phase 7.47.5]: 修复API调用，使用setCurrentEngine代替switchEngine
    // 调用 TTS 引擎生成音频
    if (!m_ttsEngineManager) {
        emit logMessage("error", "TTS 引擎管理器未初始化");
        return false;
    }

    // 设置 TTS 参数
    // ✅ 2026-02-27 06:00 [Phase 7.47.31]: 使用语音管理界面保存的参数，不再硬编码
    TTSParameters params;
    params.speakerId = task.speakerId;
    // params.rate = 1.0;   // 2026-02-27 06:00 注释：原硬编码值
    // params.volume = 0.8; // 2026-02-27 06:00 注释：原硬编码值
    params.rate = task.rate;
    params.volume = task.volume;

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
