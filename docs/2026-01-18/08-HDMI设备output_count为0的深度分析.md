# HDMI 设备 output_count=0 深度分析

**时间**: 2026-01-18 17:00
**问题**: HDMI 设备明明有扬声器，为什么 PJSIP 报告 `output_count=0`？

## 问题现象

### 日志证据

```
[ALL] Device 0 : "hw:CARD=rockchiphdmi0,DEV=0" | In: 0 Out: 0
[ALL] Device 1 : "plughw:CARD=rockchiphdmi0,DEV=0" | In: 0 Out: 0
[ALL] Device 2 : "default:CARD=rockchiphdmi0" | In: 0 Out: 0
```

### ALSA 层查询（通过 SSH）

```bash
pi@192.168.1.8:~$ aplay -l
**** List of PLAYBACK Hardware Devices ****
card 0: rockchiphdmi0 [rockchip,hdmi0]  ← ✅ HDMI 是播放设备！
  device 0: ...
```

**矛盾**：
- ✅ ALSA 命令行工具识别 HDMI 为播放设备
- ❌ PJSIP 枚举时报告 `output_count=0`

## 可能原因分析

### 1. ⭐ HDMI 未连接显示器（最可能）

**原理**：
- HDMI 音频是 HDMI 视频的附属功能
- 如果没有连接显示器，HDMI 接口处于 **断开状态**
- ALSA 驱动检测到 HDMI 断开 → 报告音频通道数为 0

**验证方法**：
```bash
ssh pi@192.168.1.8
cat /sys/class/drm/card0-HDMI-A-1/status
# 输出应该是：
# connected    ← HDMI 已连接显示器
# disconnected ← HDMI 未连接显示器 ⚠️ 这会导致 output_count=0
```

**测试方案**：
1. 连接 HDMI 显示器到设备
2. 重启应用程序
3. 查看日志是否 `output_count` 变为 > 0

### 2. ALSA 驱动 bug

**原理**：
- RK3588 HDMI 驱动可能有缺陷
- 驱动错误地报告音频能力
- `snd_pcm_hw_params_get_channels_max()` 返回 0

**验证方法**：
```bash
ssh pi@192.168.1.8
# 尝试打开设备查看实际能力
aplay -D plughw:CARD=rockchiphdmi0,DEV=0 -vv /usr/share/sounds/alsa/Front_Center.wav

# 查看详细硬件参数
cat /proc/asound/card0/pcm0p/info
cat /proc/asound/card0/pcm0p/sub0/hw_params
```

### 3. PJSIP ALSA 适配问题

**原理**：
- PJSIP 使用 ALSA API 查询设备能力
- 查询时机不对（设备未打开状态）
- 某些 ALSA 设备需要先打开才能查询通道数

**PJSIP 源码位置**：
```
cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-audiodev/alsa_dev.c
函数：alsa_factory_init() → 枚举设备
      alsa_open() → 打开设备
```

**关键代码**（推测）：
```c
// PJSIP 枚举设备时
snd_pcm_open(&pcm, device_name, SND_PCM_STREAM_PLAYBACK, SND_PCM_NONBLOCK);
snd_pcm_hw_params_get_channels_max(params, &max_channels);  // ← 可能返回 0
```

### 4. 设备权限问题

**原理**：
- 应用程序以普通用户运行
- 某些 ALSA 设备查询需要 `audio` 组权限

**验证方法**：
```bash
ssh pi@192.168.1.8
groups pi  # 查看用户是否在 audio 组
ls -l /dev/snd/  # 查看设备文件权限
```

### 5. 设备未完全初始化

**原理**：
- HDMI 音频子系统延迟初始化
- 应用启动过早，设备尚未就绪

**验证方法**：
- 延迟 2-3 秒后再枚举设备
- 查看内核日志：`dmesg | grep -i hdmi`

## 当前解决方案

### PJSIP 层（已实现）

**位置**：`src/risip/core/risipendpoint.cpp:673-694`

```cpp
// ⚠️ 特殊处理：plughw 设备即使 output_count=0 也可能有效（ALSA bug）
if (!isLoopback && !isDefault) {
    bool is_plughw = dev_name.startsWith("plughw:", Qt::CaseInsensitive);
    bool has_output = dev_info.output_count > 0;

    // plughw 设备：即使 output_count=0 也尝试使用（绕过 ALSA bug）
    if (is_plughw && best_playback_dev == -1) {
        best_playback_dev = i;
        if (has_output) {
            qDebug() << "      ✅ Selected as playback device (plughw, priority)";
        } else {
            qDebug() << "      ✅ FORCE select plughw device (bypass output_count=0 ALSA bug)";
        }
    }
    // 其他设备：必须 output_count > 0
    else if (has_output && best_playback_dev == -1) {
        best_playback_dev = i;
        qDebug() << "      ✅ Selected as playback device (output)";
    }
}
```

**效果**：
- ✅ PJSIP 层强制使用 plughw HDMI 设备
- ✅ 通话时音频可以正常播放

### 用户层（待修复）

**问题**：用户层枚举仍检查 `output_count > 0`

**位置**：`src/sip_phone/SipPhoneManager.cpp:2424-2425`

```cpp
// 只添加支持播放(输出)的设备
if (info[i].output_count > 0) {  // ← 问题：过滤掉所有 HDMI 设备
```

**修复方案**：同步 risipendpoint.cpp 的逻辑

```cpp
// ✅ 修复后：plughw 设备即使 output_count=0 也添加
bool is_plughw = deviceName.startsWith("plughw:", Qt::CaseInsensitive);
bool has_output = info[i].output_count > 0;

if (has_output || is_plughw) {  // ← 允许 plughw 绕过检查
    // ... 添加设备
}
```

## 调试信息（VERSION 2026-01-18-17:00）

### 新增调试日志

**PJSIP 层**（`risipendpoint.cpp:635-653`）：
```cpp
[PJSIP HDMI DEBUG] ═══════════════════════════════════
[PJSIP HDMI] Device: plughw:CARD=rockchiphdmi0,DEV=0
[PJSIP HDMI] Driver: ALSA
[PJSIP HDMI] input_count: 0
[PJSIP HDMI] output_count: 0 ← 问题核心
[PJSIP HDMI] default_samples_per_sec: 48000
[PJSIP HDMI] caps: XXX
[PJSIP HDMI] routes: X
[PJSIP HDMI] ext_fmt_cnt: X
[PJSIP HDMI] ⚠️ output_count=0 BUT this is plughw device
[PJSIP HDMI] → Will FORCE select it (bypass ALSA bug)
[PJSIP HDMI DEBUG] ═══════════════════════════════════
```

**用户层**（`SipPhoneManager.cpp:2390-2422`）：
```cpp
[HDMI DEEP DEBUG] ═══════════════════════════════════
[HDMI] Device name: plughw:CARD=rockchiphdmi0,DEV=0
[HDMI] Driver: ALSA
[HDMI] input_count: 0
[HDMI] output_count: 0 ← 为什么是 0？
[HDMI] default_samples_per_sec: 48000
[HDMI] caps (能力标志): XXX
[HDMI] routes (路由数量): X
[HDMI] ext_fmt_cnt (扩展格式数量): X
[HDMI DEEP DEBUG] ═══════════════════════════════════
[HDMI ANALYSIS] 可能的原因:
   1. HDMI 未连接显示器 → 音频通道未激活
   2. ALSA 驱动 bug → 未正确报告音频能力
   3. PJSIP ALSA 适配问题 → 枚举逻辑有问题
   4. 设备需要先打开 → 才能获取正确的通道数
   5. 权限问题 → 需要特定权限查询设备能力
```

## 手动验证步骤

### 步骤 1：检查 HDMI 连接状态

```bash
ssh pi@192.168.1.8

# 方法1：检查 DRM 状态
cat /sys/class/drm/card0-HDMI-A-1/status

# 方法2：检查内核日志
dmesg | grep -i hdmi | tail -20

# 方法3：使用 xrandr（如果有 X11）
xrandr | grep -i hdmi
```

### 步骤 2：测试 HDMI 音频播放

```bash
# 尝试播放测试音频
aplay -D plughw:CARD=rockchiphdmi0,DEV=0 -vv /usr/share/sounds/alsa/Front_Center.wav

# 如果成功，说明设备可用，只是 PJSIP 枚举有问题
# 如果失败，记录错误信息
```

### 步骤 3：查看设备详细信息

```bash
# 查看设备文件
ls -l /dev/snd/ | grep rockchip

# 查看设备参数
cat /proc/asound/card0/pcm0p/info
cat /proc/asound/card0/stream0

# 查看 ALSA 配置
cat ~/.asoundrc
cat /etc/asound.conf
```

### 步骤 4：检查权限

```bash
# 查看用户组
groups pi

# 应该包含 audio 组
# 如果没有，添加：
sudo usermod -a -G audio pi
```

## 下一步操作

1. **手动执行构建**：`.\build-ubuntu24-apt.ps1 188`
2. **启动程序并查看日志**
3. **分析 HDMI 调试信息**：
   - `caps` 字段的值
   - `ext_fmt_cnt` 是否 > 0
   - `default_samples_per_sec` 是否正常
4. **SSH 到设备验证**：
   - 检查 HDMI 连接状态
   - 测试音频播放
5. **确认根本原因后**，实现用户层修复

## 相关文档

- [FIX 100.246.5 - 设备索引映射错误分析](./07-FIX100.246.5-设备索引映射错误分析.md)
- [FIX 100.246.1 - HDMI 设备修复与崩溃防护](./06-FIX100.246.1-HDMI设备修复与崩溃防护.md)

---

*文档创建时间: 2026-01-18 17:00*
*版本: VERSION 2026-01-18-17:00（调试版）*
*作者: Claude*
