// ✅ 2026-02-25 11:10 [Phase 7.47.1]: 语音文件清单数据
// 用途：定义所有保护类型的语音文件清单
// 参考：docs/2026-02-24/03-语音管理界面批量合成功能实施计划.md

#ifndef VOICEFILELIST_H
#define VOICEFILELIST_H

#include <QString>
#include <QStringList>
#include <QMap>

// ========== 开关量输入保护语音清单 ==========
// 每条皮带 33 个保护项
namespace SwitchInputVoice {

// 保护项模板（%1 = 皮带编号）
const QStringList PROTECTION_ITEMS = {
    "%1号皮带急停保护",
    "%1号皮带拉绳保护",
    "%1号皮带跑偏保护",
    "%1号皮带打滑保护",
    "%1号皮带堆煤保护",
    "%1号皮带撕裂保护",
    "%1号皮带烟雾保护",
    "%1号皮带温度保护",
    "%1号皮带超温保护",
    "%1号皮带欠速保护",
    "%1号皮带过速保护",
    "%1号皮带断带保护",
    "%1号皮带纵撕保护",
    "%1号皮带横撕保护",
    "%1号皮带溜槽堵塞",
    "%1号皮带料斗堵塞",
    "%1号皮带皮带机故障",
    "%1号皮带电机过载",
    "%1号皮带电机过热",
    "%1号皮带电机缺相",
    "%1号皮带变频器故障",
    "%1号皮带软启动器故障",
    "%1号皮带制动器故障",
    "%1号皮带张紧故障",
    "%1号皮带液压站故障",
    "%1号皮带润滑站故障",
    "%1号皮带冷却系统故障",
    "%1号皮带通讯故障",
    "%1号皮带传感器故障",
    "%1号皮带编码器故障",
    "%1号皮带限位开关故障",
    "%1号皮带安全门未关",
    "%1号皮带检修状态"
};

} // namespace SwitchInputVoice

// ========== 模拟量输入保护语音清单 ==========
// 每条皮带 16 个保护项
namespace AnalogInputVoice {

const QStringList PROTECTION_ITEMS = {
    "%1号皮带速度过高",
    "%1号皮带速度过低",
    "%1号皮带电流过大",
    "%1号皮带电流过小",
    "%1号皮带电压过高",
    "%1号皮带电压过低",
    "%1号皮带温度过高",
    "%1号皮带温度过低",
    "%1号皮带张力过大",
    "%1号皮带张力过小",
    "%1号皮带位移过大",
    "%1号皮带位移过小",
    "%1号皮带振动过大",
    "%1号皮带噪音过大",
    "%1号皮带功率过大",
    "%1号皮带功率过小"
};

} // namespace AnalogInputVoice

// ========== 电机保护语音清单 ==========
// 每台电机 12 个保护项
namespace MotorVoice {

const QStringList PROTECTION_ITEMS = {
    "%1号皮带%2号电机启动",
    "%1号皮带%2号电机停止",
    "%1号皮带%2号电机过载",
    "%1号皮带%2号电机过热",
    "%1号皮带%2号电机缺相",
    "%1号皮带%2号电机接地故障",
    "%1号皮带%2号电机轴承故障",
    "%1号皮带%2号电机绕组故障",
    "%1号皮带%2号电机冷却故障",
    "%1号皮带%2号电机振动过大",
    "%1号皮带%2号电机温度过高",
    "%1号皮带%2号电机运行正常"
};

} // namespace MotorVoice

// ========== 制动器保护语音清单 ==========
// 每台制动器 8 个保护项
namespace BrakeVoice {

const QStringList PROTECTION_ITEMS = {
    "%1号皮带%2号制动器打开",
    "%1号皮带%2号制动器关闭",
    "%1号皮带%2号制动器故障",
    "%1号皮带%2号制动器磨损",
    "%1号皮带%2号制动器过热",
    "%1号皮带%2号制动器卡死",
    "%1号皮带%2号制动器松动",
    "%1号皮带%2号制动器正常"
};

} // namespace BrakeVoice

// ========== 张紧控制保护语音清单 ==========
// 每台张紧装置 10 个保护项
namespace TensionVoice {

const QStringList PROTECTION_ITEMS = {
    "%1号皮带%2号张紧装置启动",
    "%1号皮带%2号张紧装置停止",
    "%1号皮带%2号张紧装置故障",
    "%1号皮带%2号张紧力过大",
    "%1号皮带%2号张紧力过小",
    "%1号皮带%2号张紧位移上限",
    "%1号皮带%2号张紧位移下限",
    "%1号皮带%2号张紧液压故障",
    "%1号皮带%2号张紧传感器故障",
    "%1号皮带%2号张紧装置正常"
};

} // namespace TensionVoice

// ========== 沿线点位保护语音清单 ==========
// 每个点位 1 个保护项
namespace LinePositionVoice {

// 模板：%1 = 皮带编号, %2 = 点位编号
const QString PROTECTION_TEMPLATE = "%1号皮带%2号点位故障";

} // namespace LinePositionVoice

// ========== 系统提示音语音清单 ==========
namespace SystemSoundVoice {

const QStringList SOUND_ITEMS = {
    "系统启动",
    "系统关闭",
    "操作成功",
    "操作失败",
    "警告",
    "错误",
    "提示",
    "确认",
    "请注意安全",
    "请佩戴安全帽",
    "请保持通道畅通",
    "设备检修中",
    "设备运行中",
    "设备已停止",
    "紧急停车",
    "恢复运行",
    "通讯正常",
    "通讯中断",
    "数据保存成功",
    "数据保存失败"
};

} // namespace SystemSoundVoice

// ========== 起车预警语音清单 ==========
namespace StartupWarningVoice {

const QStringList WARNING_ITEMS = {
    "%1号皮带即将启动",
    "%1号皮带启动倒计时%2秒",
    "%1号皮带启动中",
    "%1号皮带已启动",
    "%1号皮带启动失败",
    "全线即将启动",
    "全线启动倒计时%1秒",
    "全线启动中",
    "全线已启动",
    "全线启动失败"
};

// 倒计时秒数
const QList<int> COUNTDOWN_SECONDS = {30, 20, 10, 5, 4, 3, 2, 1};

} // namespace StartupWarningVoice

// ========== 故障报警语音清单 ==========
namespace FaultAlarmVoice {

const QStringList ALARM_LEVELS = {
    "一般故障",
    "严重故障",
    "紧急故障"
};

const QStringList ALARM_ACTIONS = {
    "请检查",
    "请处理",
    "请立即处理",
    "已自动停机"
};

} // namespace FaultAlarmVoice

// ========== 统计信息 ==========
namespace VoiceFileStats {

// 计算总文件数
inline int calculateTotalFiles(int beltCount, int motorCount, int brakeCount,
                                int tensionCount, int linePositionCount) {
    int total = 0;

    // 开关量输入保护: 33 项 x 皮带数
    total += SwitchInputVoice::PROTECTION_ITEMS.size() * beltCount;

    // 模拟量输入保护: 16 项 x 皮带数
    total += AnalogInputVoice::PROTECTION_ITEMS.size() * beltCount;

    // 电机保护: 12 项 x 皮带数 x 电机数
    total += MotorVoice::PROTECTION_ITEMS.size() * beltCount * motorCount;

    // 制动器保护: 8 项 x 皮带数 x 制动器数
    total += BrakeVoice::PROTECTION_ITEMS.size() * beltCount * brakeCount;

    // 张紧控制保护: 10 项 x 皮带数 x 张紧装置数
    total += TensionVoice::PROTECTION_ITEMS.size() * beltCount * tensionCount;

    // 沿线点位保护: 点位数 x 皮带数
    total += linePositionCount * beltCount;

    // 系统提示音
    total += SystemSoundVoice::SOUND_ITEMS.size();

    return total;
}

// 默认配置下的总文件数
// 8 皮带 x 4 电机 x 4 制动器 x 2 张紧 x 64 点位
// = 8*(33+16) + 8*4*12 + 8*4*8 + 8*2*10 + 8*64 + 20
// = 392 + 384 + 256 + 160 + 512 + 20 = 1724 个文件
inline int defaultTotalFiles() {
    return calculateTotalFiles(8, 4, 4, 2, 64);
}

} // namespace VoiceFileStats

#endif // VOICEFILELIST_H
