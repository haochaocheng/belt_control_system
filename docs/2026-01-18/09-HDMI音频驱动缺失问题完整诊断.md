# HDMI 音频驱动缺失问题 - 完整诊断报告

**时间**: 2026-01-18 18:00
**设备**: pi@192.168.1.8 (RK3588)
**内核**: 6.1.57
**问题**: HDMI 扬声器无声音
**状态**: ⚠️ 系统级问题 - HDMI 音频驱动未加载

## 问题现象

### 用户报告
1. HDMI **已连接显示器**（带扬声器）
2. 显示器扬声器连接 **PC 时有声音**
3. 连接 **RK3588 设备时无声音**
4. PJSIP 报告 `output_count=0`

### 应用层表现
```
[DEBUG] Device 1 : "plughw:CARD=rockchiphdmi0,DEV=0" | In: 0 Out: 0
[DEBUG] 🔊 [Device Enum] Total OUTPUT devices added: 0
[DEBUG] ⚠️ [Device Enum] No output devices found, added placeholder
```

### PJSIP 层错误
```
06:01:20  Set sound device: capture=5, playback=1
06:01:20  ..Unable to open playback device 'plughw:CARD=rockchiphdmi0,DEV=0', err: Device or resource busy
06:01:20  Unable to open sound device: PJMEDIA_EAUD_SYSERR [status=420002]
```

## 诊断过程

### 1. 检查 HDMI 物理连接 ✅
```bash
$ cat /sys/class/drm/card0-HDMI-A-1/status
connected
```
**结论**: HDMI 已连接显示器

### 2. 检查 ALSA 设备列表 ✅
```bash
$ aplay -l
**** List of PLAYBACK Hardware Devices ****
card 0: rockchiphdmi0 [rockchip,hdmi0], device 0: rockchip,hdmi0 i2s-hifi-0
  Subdevices: 0/1
  Subdevice #0: subdevice #0
```
**结论**: ALSA 识别了 HDMI 播放设备

### 3. 检查 ALSA 混音器 ⚠️
```bash
$ amixer -c 0
Simple mixer control 'ELD Bypass',0
  Playback channels: Mono
  Mono: Playback [off]  ← 初始是 off
```

**操作**: 启用 ELD Bypass
```bash
$ amixer -c 0 set 'ELD Bypass' on
Simple mixer control 'ELD Bypass',0
  Mono: Playback [on]  ← 现在是 on
```

**发现**: 没有常规音量控制（PCM、Master、HDMI Volume），只有路由选择开关

### 4. 测试音频播放 ❌
```bash
$ aplay -D plughw:CARD=rockchiphdmi0,DEV=0 /usr/share/sounds/alsa/Front_Center.wav
aplay: main:830: audio open error: Device or resource busy
```
**原因**: 设备被应用程序占用

### 5. 检查进程占用情况 ⚠️
```bash
$ sudo lsof /dev/snd/pcmC0D0p
COMMAND      PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
belt_cont 104510 root   49u   CHR  116,2      0t0  183 /dev/snd/pcmC0D0p
```

**发现**: 应用已占用设备

**矛盾**:
- `lsof` 显示设备被占用 ✅
- `pjsua_aud.c` 报告 "Unable to open" ❌

### 6. 检查 ALSA 设备状态 ❌ 问题核心！
```bash
$ cat /proc/asound/card0/pcm0p/sub0/hw_params
Device not opened or no active stream
```

**关键发现**: 即使 lsof 显示设备被打开，但 ALSA 内核层报告**没有活动音频流**！

```bash
$ ls -la /proc/asound/card0/
total 0
dr-xr-xr-x  3 root root 0 Jun 18  2023 .
dr-xr-xr-x 14 root root 0 Jun 18  2023 ..
-r--r--r--  1 root root 0 Jan 18 06:02 id
```

**致命问题**: `/proc/asound/card0/` 目录下**只有 `id` 文件**，缺少：
- `pcm0p/`（播放设备）
- `stream0`（音频流信息）
- 其他 ALSA 设备文件

### 7. 检查内核模块 ❌
```bash
$ lsmod | grep -i 'snd\|hdmi'
snd_usb_audio         286720  0
snd_hwdep              24576  1 snd_usb_audio
snd_usbmidi_lib        32768  1 snd_usb_audio
```

**发现**:
- ✅ USB 音频模块已加载
- ❌ **缺少 HDMI 音频模块**（`snd_soc_rockchip_hdmi`、`snd_soc_hdmi_codec` 等）

### 8. 搜索内核模块文件 ❌
```bash
$ find /lib/modules/6.1.57 -name '*hdmi*.ko*'
(无输出)

$ find /lib/modules/6.1.57 -path '*/sound/soc/*' -name '*.ko*' | grep -E '(rockchip|hdmi)'
/lib/modules/6.1.57/kernel/sound/soc/rockchip/snd-soc-rockchip-vad.ko
/lib/modules/6.1.57/kernel/sound/soc/rockchip/snd-soc-rockchip-max98090.ko
/lib/modules/6.1.57/kernel/sound/soc/rockchip/snd-soc-rockchip-rt5645.ko
```

**结论**: 没有 HDMI 音频内核模块（`.ko` 文件）

### 9. 检查设备树配置 ✅
```bash
$ ls /sys/firmware/devicetree/base/ | grep -i hdmi
hdmi0-sound        ← HDMI 音频设备树节点存在！
hdmi@fde80000
hdmiphy@fed60000

$ cat /sys/firmware/devicetree/base/hdmi0-sound/compatible
rockchip,hdmi

$ cat /sys/firmware/devicetree/base/hdmi0-sound/status
okay
```

**结论**: 设备树配置正确

### 10. 检查内核日志 ⚠️
```bash
$ dmesg | grep -i 'hdmi0-sound\|simple-audio-card'
(无输出)
```

**关键发现**: 内核日志中**没有 HDMI 音频驱动的探测消息**！

```bash
$ dmesg | grep -i 'hdmi.*audio\|rockchip.*hdmi'
[    3.270033] rockchip-hdptx-phy-hdmi fed60000.hdmiphy: hdptx phy init success
[    3.637449] rockchip-drm display-subsystem: bound fde80000.hdmi (ops 0xffffffc0092a57c0)
[   11.620026] dwhdmi-rockchip fde80000.hdmi: Rate 166000000 missing; compute N dynamically
```

**发现**:
- ✅ HDMI PHY 初始化成功
- ✅ HDMI DRM 驱动已绑定（视频工作）
- ⚠️ 音频时钟警告：`Rate 166000000 missing; compute N dynamically`
- ❌ **没有 HDMI 音频驱动加载消息**

## 根本原因

### 分析结论

1. **✅ 硬件支持 HDMI 音频**
   - 设备树存在 `hdmi0-sound` 节点
   - Compatible: `rockchip,hdmi`
   - Status: `okay`

2. **✅ HDMI 视频正常工作**
   - DRM 驱动已加载
   - HDMI PHY 初始化成功
   - 显示器正常显示画面

3. **❌ HDMI 音频驱动缺失**
   - 内核模块不存在（无 `.ko` 文件）
   - 或内置驱动未正确初始化
   - dmesg 中没有驱动探测消息

4. **❌ ALSA 设备不完整**
   - `/proc/asound/card0/` 目录为空
   - 无 PCM 设备文件
   - 无音频流支持

5. **❌ PJSIP 无法使用**
   - 枚举时 `output_count=0`
   - 无法打开设备（设备未初始化）
   - 退回到 null device

### 因果链

```
内核未编译 HDMI 音频支持 OR 驱动未加载
                 ↓
        /proc/asound/card0/ 为空
                 ↓
      ALSA 报告设备无播放能力
                 ↓
     PJSIP 枚举时 output_count=0
                 ↓
           无法打开设备播放
                 ↓
         扬声器没有声音 ❌
```

## 解决方案

### 方案 1：检查内核配置 ⭐ 推荐
需要确认内核是否编译了 HDMI 音频支持。

**步骤**：
1. 检查内核配置文件（如果可用）：
   ```bash
   zcat /proc/config.gz | grep -E 'CONFIG.*HDMI.*AUDIO|CONFIG.*SND.*HDMI'
   # 或
   cat /boot/config-6.1.57 | grep -E 'CONFIG.*HDMI.*AUDIO|CONFIG.*SND.*HDMI'
   ```

2. 查找所需的配置选项：
   - `CONFIG_SND_SOC_HDMI_CODEC=y` 或 `=m`
   - `CONFIG_SND_SOC_ROCKCHIP_*`
   - `CONFIG_SND_SIMPLE_CARD=y` 或 `=m`

3. 如果配置项不存在或为 `n`：
   - 需要重新编译内核，启用 HDMI 音频支持
   - 或使用官方支持 HDMI 音频的内核

### 方案 2：手动加载模块（如果是模块化编译）
如果 HDMI 音频编译为模块但未自动加载：
```bash
# 查找可能的模块名称
modprobe snd-soc-hdmi-codec
modprobe snd-soc-simple-card
modprobe snd-soc-rockchip-i2s
```

### 方案 3：修改设备树（如果驱动存在但未探测）
检查设备树 `hdmi0-sound` 节点是否正确配置了所需的属性。可能需要：
1. 添加音频 codec 节点
2. 配置 I2S 接口
3. 设置音频路由

**示例设备树片段**（参考）：
```dts
hdmi0-sound {
    compatible = "rockchip,hdmi";
    status = "okay";

    rockchip,cpu = <&i2s0_8ch>;
    rockchip,codec = <&hdmi>;

    simple-audio-card,name = "rockchip,hdmi0";
    simple-audio-card,format = "i2s";
    simple-audio-card,mclk-fs = <256>;

    simple-audio-card,codec {
        sound-dai = <&hdmi>;
    };

    simple-audio-card,cpu {
        sound-dai = <&i2s0_8ch>;
    };
};
```

### 方案 4：使用官方镜像（最简单）⭐
如果这是第三方定制系统，考虑使用官方支持 HDMI 音频的镜像。

**Rockchip 官方镜像通常支持**：
- RK3588 HDMI 音频
- 完整的 ALSA/PulseAudio 支持
- 正确的设备树配置

### 方案 5：临时绕过（应用层）
如果无法修复系统，应用层可以：
1. 使用 USB 音频设备（已验证工作）
2. 或使用其他音频输出接口

## 技术细节

### HDMI 音频架构（RK3588）

```
硬件层：
HDMI PHY (fed60000.hdmiphy) ✅ 已初始化
        ↓
HDMI Controller (fde80000.hdmi) ✅ 工作中（视频）
        ↓
I2S 音频接口 ❓ 未知状态
        ↓
HDMI 音频输出 ❌ 不工作

内核驱动层：
dwhdmi-rockchip ✅ 已加载（视频部分）
        ↓
snd-soc-hdmi-codec ❌ 未加载/不存在
        ↓
snd-soc-simple-card ❌ 未加载/不存在
        ↓
ALSA PCM 设备 ❌ 未创建

用户空间：
/proc/asound/card0/ ❌ 空目录
        ↓
PJSIP 枚举 ❌ output_count=0
        ↓
应用程序 ❌ 无法播放音频
```

### 相关内核配置

需要的内核配置选项（示例）：
```
CONFIG_SND_SOC=y
CONFIG_SND_SOC_ROCKCHIP=y
CONFIG_SND_SOC_ROCKCHIP_I2S=y
CONFIG_SND_SOC_HDMI_CODEC=y
CONFIG_SND_SIMPLE_CARD=y
CONFIG_DRM_ROCKCHIP=y
CONFIG_ROCKCHIP_DW_HDMI=y
```

## 下一步操作

### 立即可行的操作

1. **验证内核配置**（如果可访问）：
   ```bash
   ssh pi@192.168.1.8
   zcat /proc/config.gz 2>/dev/null | grep HDMI
   cat /boot/config-$(uname -r) 2>/dev/null | grep HDMI
   ```

2. **检查系统文档/README**：
   - 查看 RK3588 设备的官方文档
   - 确认 HDMI 音频是否支持
   - 是否需要特殊配置

3. **联系设备供应商**：
   - 询问 HDMI 音频支持情况
   - 获取正确的内核镜像
   - 或者获取配置指南

### 长期解决方案

1. **更新系统镜像**：
   - 使用官方支持 HDMI 音频的镜像
   - 或获取最新的内核版本

2. **重新编译内核**（如果需要）：
   - 启用所需的音频驱动配置
   - 正确配置设备树
   - 测试 HDMI 音频功能

3. **应用层适配**：
   - 确保应用支持多种音频输出方式
   - 提供 USB 音频设备作为备选
   - 添加音频设备检测和提示

## 相关文档

- [HDMI 设备 output_count=0 深度分析](./08-HDMI设备output_count为0的深度分析.md)
- [FIX 100.246.5 - 设备索引映射错误分析](./07-FIX100.246.5-设备索引映射错误分析.md)
- [FIX 100.246 失败分析 - HDMI 设备无输出通道](./05-FIX100.246失败分析-HDMI设备无输出通道.md)

## 附录：诊断命令摘要

```bash
# 1. 检查 HDMI 连接
cat /sys/class/drm/card0-HDMI-A-1/status

# 2. 列出 ALSA 播放设备
aplay -l

# 3. 查看混音器控制
amixer -c 0

# 4. 检查进程占用
sudo lsof /dev/snd/pcmC0D0p

# 5. 查看 ALSA 设备文件
ls -la /proc/asound/card0/

# 6. 检查活动音频流
cat /proc/asound/card0/pcm0p/sub0/hw_params

# 7. 查看加载的模块
lsmod | grep -i 'snd\|hdmi'

# 8. 搜索内核模块
find /lib/modules/$(uname -r) -name '*hdmi*.ko*'

# 9. 检查设备树
ls /sys/firmware/devicetree/base/ | grep hdmi
cat /sys/firmware/devicetree/base/hdmi0-sound/compatible
cat /sys/firmware/devicetree/base/hdmi0-sound/status

# 10. 查看内核日志
dmesg | grep -i 'hdmi.*audio\|hdmi0-sound'
```

---

**诊断完成时间**: 2026-01-18 18:00
**诊断人员**: Claude
**结论**: 系统级问题 - HDMI 音频驱动缺失或未初始化
**优先级**: 高 - 影响核心功能
**建议**: 联系设备供应商或使用官方支持 HDMI 音频的系统镜像
