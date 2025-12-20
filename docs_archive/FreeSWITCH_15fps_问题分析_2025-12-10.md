# FreeSWITCH 15fps 问题分析与解决方案

**日期**: 2025-12-10
**问题**: FreeSWITCH 声明 60fps 但实际只发送 15fps
**状态**: 🔍 待验证和修复

---

## 📊 问题现象

### SDP 协商 vs 实际传输

**SDP 协商结果**（PJSIP 日志）：
```
Decoding format changed: 640x360 I420<- 60/1(~60)fps
RX pt=100, size=640x360, fps=60.00
```
FreeSWITCH **声明** 能发送 60fps

**实际接收统计**（应用日志）：
```
📊 [REMOTE VIDEO PUSH] Received FPS: "13-15"
```
实际只收到 **13-15 fps**

**网络抓包验证**：
```
RTP Time 差 = 未提供完整数据
预估实际帧率：15fps 左右
```

---

## 🔍 根本原因分析

### 1. FreeSWITCH 配置限制 ⭐ 最可能

FreeSWITCH 的实际发送帧率通常由配置文件控制，而不是 SDP 协商值。

#### 配置文件位置

**主要配置文件**：
- `/etc/freeswitch/vars.xml` - 全局变量
- `/etc/freeswitch/autoload_configs/conference.conf.xml` - 会议配置
- `/etc/freeswitch/dialplan/default.xml` - 拨号计划

#### 典型配置示例

```xml
<!-- vars.xml -->
<X-PRE-PROCESS cmd="set" data="video_fps=15"/>
<X-PRE-PROCESS cmd="set" data="video_bitrate=512"/>

<!-- conference.conf.xml -->
<param name="video-fps" value="15"/>
<param name="video-bitrate" value="512"/>
```

**检查方法**（在 FreeSWITCH 服务器上）：
```bash
grep -r "fps\|framerate" /etc/freeswitch/
grep -r "video-fps" /etc/freeswitch/
```

---

### 2. H.264 Profile/Level 限制

从 SDP 可以看到：
```
a=fmtp:100 profile-level-id=42e01e; packetization-mode=1
```

**解析**：
- `42` = Baseline Profile（基础档次）
- `e01e` = Level 3.0

**Level 3.0 的理论限制**：
- 最大分辨率：720x576 @ 30fps
- 最大比特率：10 Mbps
- 对于 640x360：理论可以达到 **30-40 fps**

但实际只有 15fps，说明**不是 Profile/Level 的限制**，而是配置问题。

---

### 3. 服务器性能限制

#### CPU 负载

H.264 编码非常耗 CPU：
- 640x360 @ 60fps 编码需要大量 CPU
- 如果服务器同时处理多路通话，会限制帧率

**检查方法**（在 FreeSWITCH 服务器上）：
```bash
# 查看 CPU 使用率
top -p $(pgrep freeswitch)

# 查看 FreeSWITCH 日志
tail -f /var/log/freeswitch/freeswitch.log | grep -i "video\|codec"
```

#### 编码器预设

FreeSWITCH 使用的 H.264 编码器（通常是 x264）有不同的速度预设：
- **ultrafast**: 最快，质量较差
- **medium**: 平衡（默认）
- **slow**: 慢，质量好，**可能导致帧率下降**

---

### 4. 网络带宽限制

当前配置：
```
a=rtpmap:100 H264/90000
b=AS:3072  ← 带宽限制 3072 kbps
```

**计算**：
- 640x360 @ 60fps H.264 需要约 2-3 Mbps
- 640x360 @ 15fps H.264 需要约 512 kbps - 1 Mbps

3072 kbps 的带宽**足够支持 60fps**，所以不是带宽问题。

---

## 🎯 解决方案

### 方案 1: 修改 FreeSWITCH 配置 ⭐⭐⭐ 最推荐

#### 步骤 1: 修改全局视频参数

编辑 `/etc/freeswitch/vars.xml`：

```xml
<!-- 在文件中添加或修改 -->
<X-PRE-PROCESS cmd="set" data="video_fps=30"/>
<X-PRE-PROCESS cmd="set" data="video_bitrate=1536"/>
<X-PRE-PROCESS cmd="set" data="video_max_bandwidth=3072"/>
```

#### 步骤 2: 修改会议配置（如果使用会议功能）

编辑 `/etc/freeswitch/autoload_configs/conference.conf.xml`：

```xml
<profile name="default">
  <param name="video-mode" value="mux"/>
  <param name="video-layout-name" value="1x1"/>
  <param name="video-canvas-size" value="640x360"/>
  <param name="video-canvas-fps" value="30"/>
  <param name="video-fps" value="30"/>
  <param name="video-bitrate" value="1536"/>
</profile>
```

#### 步骤 3: 重启 FreeSWITCH

```bash
sudo systemctl restart freeswitch

# 或者在 FreeSWITCH 控制台
fs_cli -x "reloadxml"
fs_cli -x "reload mod_conference"
```

#### 步骤 4: 验证

拨打测试电话，检查应用日志：
```
📊 [REMOTE VIDEO PUSH] Received FPS: "28-30"  ← 应该提升到接近30
```

---

### 方案 2: 优化 H.264 编码器设置

修改 `/etc/freeswitch/autoload_configs/h264.conf.xml`（如果存在）：

```xml
<configuration name="h264.conf">
  <settings>
    <param name="profile" value="baseline"/>
    <param name="level" value="3.1"/>
    <param name="preset" value="ultrafast"/>  <!-- 使用最快预设 -->
    <param name="tune" value="zerolatency"/>   <!-- 低延迟优化 -->
    <param name="fps" value="30"/>
  </settings>
</configuration>
```

---

### 方案 3: 使用 VP8/VP9 编码器（替代方案）

VP8/VP9 编码器可能比 H.264 更高效：

**修改 SIP 配置**（`/etc/freeswitch/sip_profiles/internal.xml`）：

```xml
<param name="inbound-codec-prefs" value="VP8,H264"/>
<param name="outbound-codec-prefs" value="VP8,H264"/>
```

**优点**：
- VP8 编码速度更快
- 开源，无专利限制
- 可能达到更高帧率

**缺点**：
- 客户端也需要支持 VP8
- 带宽消耗可能更高

---

### 方案 4: 检查和优化服务器资源

#### 检查 CPU 使用

```bash
# 查看 FreeSWITCH 进程 CPU 占用
top -H -p $(pgrep freeswitch)

# 查看每个线程的 CPU 使用
ps -eLf | grep freeswitch
```

#### 增加 CPU 资源

如果 CPU 负载高：
1. 升级服务器硬件
2. 减少同时通话数量
3. 使用硬件加速（如果可用）

---

## 📋 诊断检查清单

### 在 FreeSWITCH 服务器上

```bash
# 1. 检查配置文件中的 fps 设置
grep -r "fps" /etc/freeswitch/ | grep -v ".log"

# 2. 检查当前通话的视频参数
fs_cli -x "show channels"
fs_cli -x "uuid_display <uuid>"

# 3. 查看 H.264 编码器日志
tail -f /var/log/freeswitch/freeswitch.log | grep -i "h264\|video"

# 4. 检查 CPU 使用率
top -p $(pgrep freeswitch)

# 5. 检查网络统计
fs_cli -x "status"
```

### 在客户端

```bash
# 查看接收到的实际 FPS
# 从应用日志中查找：
grep "REMOTE VIDEO PUSH" logfile.txt

# 预期看到：
# 优化前：FPS: "13-15"
# 优化后：FPS: "28-30" 或更高
```

---

## 🔬 高级调试：Wireshark 分析

### 准确计算实际 FPS

**步骤 1**：在 Wireshark 中过滤 RTP 视频流

```
rtp and ip.src == 192.168.10.243 and h264
```

**步骤 2**：只显示帧结束包（Mark 位）

```
rtp.marker == 1 and ip.src == 192.168.10.243
```

**步骤 3**：使用 RTP Stream Analysis

菜单: `Telephony` → `RTP` → `Stream Analysis`

查看：
- **Packet Rate**: 包速率
- **Stream Info**: 实际帧率
- **Jitter**: 抖动

**步骤 4**：导出 RTP 统计

```bash
tshark -r capture.pcap -Y "rtp.marker == 1 and ip.src == 192.168.10.243" \
  -T fields -e frame.time_relative -e rtp.timestamp \
  | awk 'NR>1 {print ($2-prev)/90000; prev=$2}' \
  | awk '{sum+=$1; count++} END {print "Avg frame interval:", sum/count, "s"; print "FPS:", count/sum}'
```

---

## 💡 预期结果

### 优化前

```
📊 [REMOTE VIDEO PUSH] Received FPS: "13-15"
Avg interval: "65-77" ms
```

### 优化后（目标）

```
📊 [REMOTE VIDEO PUSH] Received FPS: "28-30"
Avg interval: "33-36" ms
```

**注意**：
- 可能无法达到完整的 60fps（需要服务器支持）
- 但 30fps 已经足够流畅
- 如果能稳定在 28-30fps，用户体验会显著改善

---

## 📞 联系 FreeSWITCH 管理员

如果你不能直接访问 FreeSWITCH 服务器，需要联系管理员：

**请求内容**：

> 您好，
>
> 我们在使用视频通话时发现，虽然 SDP 协商显示 60fps，但实际接收到的帧率只有 13-15 fps。
>
> 能否帮忙检查并修改以下配置：
>
> 1. `/etc/freeswitch/vars.xml` 中的 `video_fps` 参数
> 2. `/etc/freeswitch/autoload_configs/conference.conf.xml` 中的 `video-fps` 参数
>
> 建议设置为 **30 fps**（或更高，如果服务器支持）。
>
> 当前配置：
> - 分辨率：640x360
> - 编码器：H.264 Baseline Profile
> - 期望帧率：30 fps 或更高
>
> 谢谢！

---

## 🎯 总结

**问题根因**：FreeSWITCH 配置文件限制了视频帧率为 15fps

**最佳解决方案**：修改 FreeSWITCH 配置文件，将 `video_fps` 设置为 30

**预期改善**：
- FPS 从 13-15 提升到 28-30（**翻倍**）
- 视频流畅度显著改善
- 延迟降低

---

**创建日期**: 2025-12-10
**状态**: 待验证
**优先级**: 中（用户体验相关）
