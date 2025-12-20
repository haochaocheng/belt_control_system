# FreeSWITCH video_fps=30 配置不生效故障排查

**日期**: 2025-12-10
**问题**: vars.xml 中设置了 `video_fps=30`，FreeSWITCH 也重启了，但实际视频仍然只有 5-13 FPS
**状态**: 🔍 故障排查中

---

## 📊 问题现象

### 配置状态
```xml
<!-- vars.xml 中的配置 -->
<X-PRE-PROCESS cmd="set" data="video_fps=30"/>
<X-PRE-PROCESS cmd="set" data="video_bitrate=1536"/>
<X-PRE-PROCESS cmd="set" data="video_width=640"/>
<X-PRE-PROCESS cmd="set" data="video_height=360"/>
```
✅ 配置语法正确
✅ 配置位置正确（在 `</include>` 之前）
✅ FreeSWITCH 服务已重启
✅ 用户确认"的确是30"（可能通过 fs_cli 验证过）

### 实际测试结果（57秒通话）
```
🎯 [PJSIP CALLBACK FPS] "40.7" | Total callbacks: 2297 | Video frames: 319 | Empty: 1977
📊 [REMOTE VIDEO PUSH] Enqueued FPS: "11.9" | Total frames: 338
🔧 [ASYNC WORKER] Processed FPS: "6.2"
```

**分析**:
- **实际视频帧**: 319 帧 / 57 秒 = **5.6 FPS** ❌
- **空帧占比**: 1977 / 2297 = **86%** ❌
- **结论**: FreeSWITCH 实际只发送了 5-6 FPS，远低于配置的 30 FPS

---

## 🔍 可能的原因

### 原因 1: vars.xml 中的变量未被实际使用 ⭐ 最可能

**问题**: `video_fps` 变量定义了，但**没有任何配置文件引用它**。

**解释**:
```
vars.xml 的作用只是定义变量:
$${video_fps} = 30

但这个变量需要在其他配置文件中被引用:
<param name="video-fps" value="$${video_fps}"/>
                                    ↑
                              如果没有这一行，变量不会生效
```

**验证方法**:
```bash
cd C:\FreeSWITCH\conf
# 搜索所有引用 video_fps 变量的地方
findstr /s /i "video.fps" *.xml
findstr /s /i "video_fps" *.xml
```

**预期结果**:
- 如果只在 `vars.xml` 中找到，说明**变量定义了但没被使用**
- 需要在其他配置文件中添加引用

---

### 原因 2: 需要在 conference.conf.xml 中配置

**问题**: 视频通话使用 conference bridge，帧率需要在 conference 配置中设置。

**检查文件**: `C:\FreeSWITCH\conf\autoload_configs\conference.conf.xml`

**查找**:
```xml
<profile name="default">
  <param name="video-mode" value="mux"/>
  <param name="video-layout-name" value="1x1"/>
  <param name="video-canvas-size" value="640x360"/>
  <param name="video-canvas-bgcolor" value="#333333"/>
  <!-- ❌ 缺少这一行 -->
  <param name="video-fps" value="30"/>
</profile>
```

**修复步骤**:
1. 打开 `C:\FreeSWITCH\conf\autoload_configs\conference.conf.xml`
2. 找到 `<profile name="default">` 或你使用的 profile
3. 在 video 相关参数中添加:
```xml
<param name="video-fps" value="$${video_fps}"/>
```
或直接硬编码:
```xml
<param name="video-fps" value="30"/>
```
4. 保存文件
5. 在 fs_cli 中执行: `reloadxml`

---

### 原因 3: SIP Profile 中的视频编码器设置

**检查文件**: `C:\FreeSWITCH\conf\sip_profiles\internal.xml`

**查找**:
```xml
<param name="rtp-timeout-sec" value="300"/>
<param name="rtp-hold-timeout-sec" value="1800"/>

<!-- 检查是否有限制视频的参数 -->
<param name="disable-transcoding" value="true"/>
```

**可能的冲突**:
- 如果 `disable-transcoding=true`，FreeSWITCH 不会重新编码视频
- 此时帧率由对方（呼叫方）决定，而不是 FreeSWITCH 配置

---

### 原因 4: mod_h264 编码器配置

**检查文件**: `C:\FreeSWITCH\conf\autoload_configs\h264.conf.xml`

如果这个文件存在，检查:
```xml
<configuration name="h264.conf" description="H264 Config">
  <settings>
    <param name="fps" value="15"/>  <!-- ❌ 可能被硬编码为 15 -->
  </settings>
</configuration>
```

**修复**: 将 `fps` 改为 `30`

---

### 原因 5: codec 参数限制

**检查**: `C:\FreeSWITCH\conf\vars.xml` 中的 codec 相关配置

```xml
<X-PRE-PROCESS cmd="set" data="global_codec_prefs=OPUS,G722,PCMU,PCMA,H264"/>
<X-PRE-PROCESS cmd="set" data="outbound_codec_prefs=OPUS,G722,PCMU,PCMA,H264"/>
```

**问题**: H264 编码器可能有默认限制

**解决**: 明确指定 H264 参数（如果支持）:
```xml
<X-PRE-PROCESS cmd="set" data="global_codec_prefs=OPUS,G722,PCMU,PCMA,H264@30fps"/>
```

---

### 原因 6: 网络或呼叫流程问题

**场景**: FreeSWITCH 在 Windows 客户端**本机**运行（192.168.10.243）

**可能的问题**:
1. **环回调用**: 客户端和 FreeSWITCH 在同一台机器上
   - FreeSWITCH 可能检测到这是本地环回
   - 为节省资源，自动降低帧率

2. **SDP 协商**:
   - 呼叫建立时，双方协商的帧率可能不是 30
   - 需要查看 SIP 消息中的 SDP offer/answer

**验证**: 在 fs_cli 中查看通话详情:
```bash
fs_cli
show calls
show channels
```

---

## 🔧 故障排查步骤

### 步骤 1: 验证变量是否被引用

在 Windows 命令行中:
```cmd
cd C:\FreeSWITCH\conf
findstr /s /i "video.fps" *.xml
findstr /s /i "video_fps" *.xml
```

**预期输出**: 应该在多个文件中找到引用，不只是 `vars.xml`

**如果只在 vars.xml 中找到**: 说明变量定义了但没被使用，这是最可能的原因。

---

### 步骤 2: 检查 conference.conf.xml

```cmd
type C:\FreeSWITCH\conf\autoload_configs\conference.conf.xml | findstr /i "fps"
```

**如果没有输出**: 说明 conference 配置中没有 fps 参数，需要添加。

**修复**:
1. 编辑 `C:\FreeSWITCH\conf\autoload_configs\conference.conf.xml`
2. 在你使用的 profile 中添加:
```xml
<profile name="default">
  <!-- 其他参数... -->
  <param name="video-fps" value="30"/>
</profile>
```
3. 保存后在 fs_cli 执行: `reloadxml`

---

### 步骤 3: 检查 H.264 编码器配置

```cmd
type C:\FreeSWITCH\conf\autoload_configs\h264.conf.xml
```

**如果文件不存在**: 可能需要创建。

**如果存在**: 检查 `fps` 参数是否被硬编码为 15。

---

### 步骤 4: 查看 FreeSWITCH 日志

打开日志文件:
```cmd
type C:\FreeSWITCH\log\freeswitch.log | findstr /i "video"
type C:\FreeSWITCH\log\freeswitch.log | findstr /i "fps"
type C:\FreeSWITCH\log\freeswitch.log | findstr /i "h264"
```

**查找关键信息**:
- 视频编码器初始化日志
- 帧率协商日志
- 任何警告或错误

---

### 步骤 5: 实时查看 SIP 消息

在 fs_cli 中:
```bash
# 启用 SIP 消息跟踪
sofia global siptrace on

# 拨打测试电话

# 查看 SDP 中协商的参数
```

**查找**: SDP 中的 `a=framerate:` 行，查看协商的帧率是多少。

---

## 💡 推荐的修复方案

### 方案 A: 在 conference.conf.xml 中添加 fps 参数 ⭐ 最推荐

**原理**: 如果通话使用 conference bridge，需要在 conference 配置中明确设置帧率。

**步骤**:
1. 编辑 `C:\FreeSWITCH\conf\autoload_configs\conference.conf.xml`
2. 找到你使用的 profile（通常是 `default`）
3. 添加:
```xml
<profile name="default">
  <param name="video-mode" value="mux"/>
  <param name="video-canvas-size" value="640x360"/>
  <param name="video-fps" value="30"/>  <!-- 添加这一行 -->
  <!-- 其他参数... -->
</profile>
```
4. 保存文件
5. 在 fs_cli 中执行:
```bash
reloadxml
conference default reload
```

**测试**: 重新拨打视频电话，观察客户端日志中的 FPS。

---

### 方案 B: 创建 H.264 编码器配置文件

**原理**: 如果缺少 H.264 编码器配置，FreeSWITCH 可能使用默认值（15 fps）。

**步骤**:
1. 创建文件 `C:\FreeSWITCH\conf\autoload_configs\h264.conf.xml`:
```xml
<?xml version="1.0"?>
<configuration name="h264.conf" description="H264 Video Codec">
  <settings>
    <param name="preset" value="ultrafast"/>
    <param name="tune" value="zerolatency"/>
    <param name="fps" value="30"/>
    <param name="width" value="640"/>
    <param name="height" value="360"/>
    <param name="bitrate" value="1536000"/>
  </settings>
</configuration>
```
2. 保存文件
3. 重启 FreeSWITCH 服务
4. 测试

---

### 方案 C: 检查是否是 SDP 协商问题

**原理**: 实际帧率由 SIP 协商决定，而不是 FreeSWITCH 单方面配置。

**步骤**:
1. 在 fs_cli 中启用详细日志:
```bash
console loglevel DEBUG
sofia loglevel all 9
```
2. 拨打视频电话
3. 查看 SDP offer/answer 中的帧率
4. 如果 SDP 中协商的就是 15 fps，说明对方（客户端）只请求了 15 fps

**如果是客户端限制**: 需要在客户端应用中修改 SDP offer，请求 30 fps。

---

## 🎯 快速诊断命令

### 在 Windows 命令行执行:

```cmd
echo === 检查 vars.xml 配置 ===
type C:\FreeSWITCH\conf\vars.xml | findstr /i "video_fps"

echo.
echo === 搜索所有引用 video_fps 的地方 ===
cd C:\FreeSWITCH\conf
findstr /s /i "video.fps" *.xml
findstr /s /i "video_fps" *.xml

echo.
echo === 检查 conference.conf.xml 中的 fps ===
type C:\FreeSWITCH\conf\autoload_configs\conference.conf.xml | findstr /i "fps"

echo.
echo === 检查 h264.conf.xml 是否存在 ===
if exist C:\FreeSWITCH\conf\autoload_configs\h264.conf.xml (
    echo 文件存在
    type C:\FreeSWITCH\conf\autoload_configs\h264.conf.xml
) else (
    echo 文件不存在 - 可能是原因之一
)

echo.
echo === 查看最近的 FreeSWITCH 日志错误 ===
type C:\FreeSWITCH\log\freeswitch.log | findstr /i "video fps h264" | more
```

---

## 📞 下一步行动

### 立即执行

请将上面"快速诊断命令"中的命令复制到 Windows 命令行执行，然后将输出结果发给我，这样我可以准确定位问题。

### 根据诊断结果

1. **如果 conference.conf.xml 中没有 fps 参数**:
   - 执行**方案 A**（在 conference.conf.xml 中添加 fps 参数）
   - 这是最可能的原因

2. **如果 h264.conf.xml 不存在**:
   - 执行**方案 B**（创建 H.264 编码器配置文件）

3. **如果以上都正确**:
   - 执行**方案 C**（检查 SDP 协商）
   - 可能是客户端应用请求的就是低帧率

---

## 🎓 技术解释

### 为什么 vars.xml 中的变量可能不生效？

FreeSWITCH 的配置是**模块化**的：

```
vars.xml
  → 定义全局变量: $${video_fps} = 30
  → 但这只是定义，不会自动应用

conference.conf.xml
  → 需要引用: <param name="video-fps" value="$${video_fps}"/>
  → 如果没有这一行，conference 不知道要用 30 fps

h264.conf.xml
  → H.264 编码器的具体配置
  → 如果这里硬编码了 fps=15，会覆盖其他配置
```

**类比**:
```
vars.xml:  定义常量 MAX_SPEED = 100
其他文件:  需要使用 MAX_SPEED，否则这个常量没有意义
```

---

## 📊 预期结果

如果修复成功，测试时应该看到:

```
🎯 [PJSIP CALLBACK FPS] "60.0" | Total callbacks: 1800 | Video frames: 900 | Empty: 900
📊 [REMOTE VIDEO PUSH] Enqueued FPS: "28-30"
🔧 [ASYNC WORKER] Processed FPS: "28-30"
```

- **有效视频帧**: ~50% (之前是 14-20%)
- **实际 FPS**: 28-30 (之前是 5-13)
- **视频流畅度**: 显著改善

---

**创建日期**: 2025-12-10
**优先级**: 🔥 高（用户体验严重受影响）
**下一步**: 执行快速诊断命令，根据输出结果选择修复方案
