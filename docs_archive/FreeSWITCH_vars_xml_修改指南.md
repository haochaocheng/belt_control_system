# FreeSWITCH vars.xml 修改指南 - 添加视频帧率配置

**日期**: 2025-12-10
**目标**: 将视频帧率从默认 15fps 提升到 30fps

---

## 📋 当前配置

从你提供的 vars.xml 可以看到：

### 已有的视频配置

```xml
<!--  Video Settings  -->
<!--  Setting the max bandwdith  -->
<X-PRE-PROCESS cmd="set" data="rtp_video_max_bandwidth_in=3mb"/>
<X-PRE-PROCESS cmd="set" data="rtp_video_max_bandwidth_out=3mb"/>
```

### 缺少的配置

❌ **没有 `video_fps` 配置**
❌ **没有 `video_bitrate` 配置**

这就是为什么 FreeSWITCH 使用默认帧率（通常是 15fps）的原因。

---

## 🔧 修改步骤

### 步骤 1: 备份原文件

```bash
sudo cp /etc/freeswitch/vars.xml /etc/freeswitch/vars.xml.backup
```

### 步骤 2: 编辑 vars.xml

```bash
sudo vi /etc/freeswitch/vars.xml
# 或者
sudo nano /etc/freeswitch/vars.xml
```

### 步骤 3: 在视频配置部分添加以下行

找到这个部分：

```xml
<!--  Video Settings  -->
<!--  Setting the max bandwdith  -->
<X-PRE-PROCESS cmd="set" data="rtp_video_max_bandwidth_in=3mb"/>
<X-PRE-PROCESS cmd="set" data="rtp_video_max_bandwidth_out=3mb"/>
```

在后面**添加**以下配置：

```xml
<!--  Video Settings  -->
<!--  Setting the max bandwdith  -->
<X-PRE-PROCESS cmd="set" data="rtp_video_max_bandwidth_in=3mb"/>
<X-PRE-PROCESS cmd="set" data="rtp_video_max_bandwidth_out=3mb"/>

<!-- ✅ 添加以下行 -->
<!--  Video Frame Rate and Bitrate  -->
<X-PRE-PROCESS cmd="set" data="video_fps=30"/>
<X-PRE-PROCESS cmd="set" data="video_bitrate=1536"/>
<X-PRE-PROCESS cmd="set" data="video_width=640"/>
<X-PRE-PROCESS cmd="set" data="video_height=360"/>
```

### 步骤 4: 验证配置

保存文件后，验证 XML 格式是否正确：

```bash
xmllint --noout /etc/freeswitch/vars.xml
```

如果没有输出，说明格式正确。

### 步骤 5: 重启 FreeSWITCH

```bash
sudo systemctl restart freeswitch
```

或者在 FreeSWITCH 控制台：

```bash
fs_cli
reloadxml
```

---

## 📝 完整的视频配置部分（修改后）

修改后，你的视频配置部分应该看起来像这样：

```xml
<!--  Video Settings  -->
<!--  Setting the max bandwdith  -->
<X-PRE-PROCESS cmd="set" data="rtp_video_max_bandwidth_in=3mb"/>
<X-PRE-PROCESS cmd="set" data="rtp_video_max_bandwidth_out=3mb"/>

<!--  Video Frame Rate and Bitrate Settings  -->
<X-PRE-PROCESS cmd="set" data="video_fps=30"/>
<X-PRE-PROCESS cmd="set" data="video_bitrate=1536"/>
<X-PRE-PROCESS cmd="set" data="video_width=640"/>
<X-PRE-PROCESS cmd="set" data="video_height=360"/>

<!--  WebRTC Video  -->
<!--  Suppress CNG for WebRTC Audio  -->
<X-PRE-PROCESS cmd="set" data="suppress_cng=true"/>
```

---

## 🎯 参数说明

| 参数 | 值 | 说明 |
|------|-----|------|
| `video_fps` | 30 | 视频帧率：30fps（平衡性能与质量） |
| `video_bitrate` | 1536 | 视频比特率：1.5Mbps（高质量） |
| `video_width` | 640 | 视频宽度：640像素 |
| `video_height` | 360 | 视频高度：360像素 |
| `rtp_video_max_bandwidth_in` | 3mb | 入站视频最大带宽：3Mbps |
| `rtp_video_max_bandwidth_out` | 3mb | 出站视频最大带宽：3Mbps |

### 为什么选择这些值？

1. **30fps**:
   - 平衡性能和流畅度
   - 比 15fps 流畅度翻倍
   - 服务器负载可控

2. **1536 kbps**:
   - 足够支持 640x360 @ 30fps 的高质量视频
   - 不会超过 3Mbps 带宽限制

3. **640x360**:
   - 与客户端实际接收的分辨率匹配
   - nHD 标准分辨率

---

## 🧪 测试验证

### 1. 检查配置是否生效

重启后，在 FreeSWITCH 控制台查看：

```bash
fs_cli -x "eval $${video_fps}"
```

应该输出：`30`

### 2. 拨打测试电话

从客户端应用拨打视频电话，查看日志：

**预期看到**：
```
📊 [REMOTE VIDEO PUSH] Received FPS: "28-30"  ← 应该接近 30
Avg interval: "33-36" ms
```

**对比优化前**：
```
📊 [REMOTE VIDEO PUSH] Received FPS: "13-15"  ← 之前只有 15
Avg interval: "65-77" ms
```

---

## 🔍 进阶配置（可选）

### 如果想要更高帧率（40-50fps）

```xml
<X-PRE-PROCESS cmd="set" data="video_fps=40"/>
<X-PRE-PROCESS cmd="set" data="video_bitrate=2048"/>
```

**注意**：更高帧率需要：
- 更强的服务器 CPU
- 更大的网络带宽
- 客户端支持更高帧率

### H.264 编码器优化（可选）

如果存在 `/etc/freeswitch/autoload_configs/h264.conf.xml`，可以添加：

```xml
<configuration name="h264.conf">
  <settings>
    <param name="preset" value="ultrafast"/>
    <param name="tune" value="zerolatency"/>
    <param name="fps" value="30"/>
  </settings>
</configuration>
```

---

## ⚠️ 常见问题

### Q1: 修改后帧率仍然是 15fps？

**可能原因**：
1. 配置文件格式错误（用 xmllint 验证）
2. FreeSWITCH 没有重启
3. 其他配置文件覆盖了这个设置

**解决方法**：
```bash
# 查看所有 fps 配置
grep -r "fps" /etc/freeswitch/ | grep -v ".log"

# 确保只有一个 fps 配置生效
```

### Q2: 服务器 CPU 使用率很高？

**解决方法**：
- 降低帧率到 25fps
- 降低比特率到 1024 kbps
- 使用硬件加速（如果可用）

### Q3: 视频质量变差了？

**解决方法**：
- 提高比特率到 2048 kbps
- 检查网络带宽是否足够

---

## 📊 预期改善

| 指标 | 修改前 | 修改后 | 提升 |
|------|--------|--------|------|
| **接收 FPS** | 13-15 | **28-30** | ↑ **翻倍** |
| **帧间隔** | 65-77ms | **33-36ms** | ↓ 50% |
| **视频流畅度** | 卡顿 | **流畅** | ✅ 显著改善 |
| **服务器 CPU** | 低 | 中 | ↑ 轻微增加 |
| **带宽使用** | 512 kbps | **1.5 Mbps** | ↑ 3倍（仍在限制内） |

---

## 📞 完整修改命令（复制粘贴）

```bash
# 1. 备份
sudo cp /etc/freeswitch/vars.xml /etc/freeswitch/vars.xml.backup

# 2. 在视频配置部分添加以下行（需要手动编辑）
sudo vi /etc/freeswitch/vars.xml

# 在 rtp_video_max_bandwidth_out 后面添加：
# <X-PRE-PROCESS cmd="set" data="video_fps=30"/>
# <X-PRE-PROCESS cmd="set" data="video_bitrate=1536"/>
# <X-PRE-PROCESS cmd="set" data="video_width=640"/>
# <X-PRE-PROCESS cmd="set" data="video_height=360"/>

# 3. 验证 XML 格式
xmllint --noout /etc/freeswitch/vars.xml

# 4. 重启 FreeSWITCH
sudo systemctl restart freeswitch

# 5. 验证配置生效
fs_cli -x "eval \$\${video_fps}"
```

---

## 🎯 总结

**问题根因**: vars.xml 中缺少 `video_fps` 配置，FreeSWITCH 使用默认的 15fps

**解决方案**: 在 vars.xml 的视频配置部分添加 `video_fps=30`

**预期效果**:
- ✅ 视频帧率从 15fps 提升到 30fps（翻倍）
- ✅ 视频流畅度显著改善
- ✅ 用户体验大幅提升

---

**创建日期**: 2025-12-10
**状态**: 待实施
**优先级**: 高（用户体验直接相关）
