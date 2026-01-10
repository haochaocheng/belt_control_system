# 2026-01-10 工作总结：自动 Core Dump 分析集成

## 📋 工作概述

完成了自动 Core Dump 分析功能集成到 `build-ubuntu24-apt.ps1` 脚本中，实现了程序崩溃后自动分析并显示崩溃原因的功能。

## 🎯 主要工作

### 1. Core Dump 根因分析

**文件**: `docs/2026-01-09/72-Core-Dump分析-编码器初始化崩溃根因.md`

完成了对 808MB Core Dump 文件的详细分析，定位了视频通话崩溃的根本原因：

**崩溃路径**:
```
RKMPP 解码器 → DRM_PRIME (179) - GPU 内存格式
      ↓
FFmpeg 尝试创建格式转换链（DRM_PRIME → I420）
      ↓
❌ 转换链初始化失败
      ↓
libx264 编码器期望 I420 (0) - 系统内存格式
      ↓
avcodec_open2() 失败 → avcodec_close() → free() 崩溃
```

**Core Dump 堆栈**:
```
#0  __GI___libc_free() ← 尝试释放无效指针
#1  avcodec_close() ← 清理失败的编码器上下文
#2  avcodec_open2() ← 编码器初始化失败
#3  open_ffmpeg_codec() ← PJSIP 打开编码器
```

### 2. Fix 100.12 解决方案

**文件**: `docs/2026-01-09/73-Fix100.12-硬件编码器解决DRM_PRIME问题.md`

确认了解决方案并发现代码已实现：

**核心发现**: Fix 97（2026-01-09 17:30）已实现硬件/软件编码器切换机制，无需修改代码！

**环境变量控制**:
```bash
USE_HARDWARE_ENCODER=1  # 启用硬件编码器（默认）
USE_HARDWARE_ENCODER=0  # 回退到软件编码器
```

**为什么硬件编码器可以解决问题**:
- ✅ h264_rkmpp 硬件编码器原生支持 DRM_PRIME 格式输入
- ✅ 零拷贝传输，无需格式转换
- ✅ Jellyfin/Frigate 生产环境验证可行

### 3. 自动 Core Dump 分析集成 ⭐

**文件**: `build-ubuntu24-apt.ps1` (Lines 1595-1679)

在构建脚本中集成了自动 Core Dump 分析功能，满足所有用户需求：

#### 功能特性

1. **自动检测崩溃**
   - 监控 exit code 139（SIGSEGV）
   - 自动触发 Core Dump 分析

2. **智能缓存机制**
   - 检查 `.analysis.txt` 缓存文件
   - 避免重复分析同一个 Core Dump
   - 节省分析时间

3. **完整分析报告**
   - 崩溃位置（backtrace）
   - 寄存器状态
   - Frame 2 详情（avcodec_open2）
   - Frame 3 详情（open_ffmpeg_codec）

4. **简洁崩溃摘要**
   - 每次崩溃自动显示摘要
   - 即使使用缓存也显示摘要
   - 提供完整分析文件路径

#### 实现代码

```powershell
# 检测段错误
if [ $EXIT_CODE -eq 139 ]; then
    echo ""
    echo "========================================"
    echo "检测到段错误（SIGSEGV）- 自动分析 Core Dump"
    echo "========================================"

    # 查找最新的 Core Dump
    LATEST_CORE=$(ls -t /tmp/belt-control-cores/core.* 2>/dev/null | head -1)

    if [ -z "$LATEST_CORE" ]; then
        echo "⚠️ 未找到 Core Dump 文件"
    else
        CORE_NAME=$(basename "$LATEST_CORE")
        ANALYSIS_FILE="/tmp/belt-control-cores/${CORE_NAME}.analysis.txt"

        # 检查是否已分析（避免重复分析）
        if [ -f "$ANALYSIS_FILE" ]; then
            echo "ℹ️  Core Dump 已分析（使用缓存）"
        else
            echo "✓ 找到 Core Dump: $LATEST_CORE"
            echo "正在分析崩溃原因（这需要几秒钟）..."

            # 运行 GDB 分析并缓存结果
            sudo docker run --rm --security-opt apparmor=unconfined \
                -v /tmp/belt-control-cores:/cores:ro \
                belt-control:v3.5-apt \
                bash -c "gdb -batch -ex 'set pagination off' \
                    -ex 'echo \n[1] 崩溃位置\n' \
                    -ex 'bt 3' \
                    -ex 'echo \n[2] 寄存器状态\n' \
                    -ex 'info registers rip rsp rbp' \
                    -ex 'echo \n[3] Frame 2 详情（avcodec_open2）\n' \
                    -ex 'frame 2' \
                    -ex 'info locals' \
                    -ex 'echo \n[4] Frame 3 详情（open_ffmpeg_codec）\n' \
                    -ex 'frame 3' \
                    -ex 'info locals' \
                    -ex 'quit' \
                    /app/belt_control_system /cores/$CORE_NAME" 2>&1 | tee "$ANALYSIS_FILE"
        fi

        # 始终显示崩溃原因摘要
        echo ""
        echo "========================================"
        echo "崩溃原因摘要"
        echo "========================================"
        grep -A 3 "\[1\] 崩溃位置" "$ANALYSIS_FILE" 2>/dev/null || echo "（无法提取堆栈信息）"
        echo ""
        echo "完整分析: $ANALYSIS_FILE"
    fi
fi
```

#### 用户需求对照

| 用户需求 | 实现状态 |
|---------|---------|
| "不是另外起一个，而是在build-ubuntu24-apt.ps1" | ✅ 集成到构建脚本 |
| "不需要另外也给脚本，就集成到本项目里" | ✅ 无独立脚本 |
| "这样每次崩溃都知道原因" | ✅ 自动分析每次崩溃 |
| "不需要每次都重新分析" | ✅ 缓存机制 |
| "只要崩溃，就在最后打印出原因" | ✅ 始终显示摘要 |

## 📊 当前状态

### 已完成

- ✅ Core Dump 根因分析完成
- ✅ Fix 100.12 方案确认（代码已实现）
- ✅ 自动 Core Dump 分析功能集成
- ✅ 满足所有用户需求

### 待验证

- ⏳ 用户在 192.168.10.188 设备上测试最新代码
- ⏳ 验证硬件编码器是否生效（USE_HARDWARE_ENCODER=1）
- ⏳ 验证自动 Core Dump 分析功能是否正常工作

### 发现的问题

**最新日志显示软件编码器仍在使用**:
```log
00:08:15.444    ffmpeg_vid_codecs.c  .......   Encoder: libx264rgb
```

**预期**: 应该显示 "Encoder: h264_rkmpp"（硬件编码器）

**可能原因**:
1. 环境变量 USE_HARDWARE_ENCODER 未设置或设置为 0
2. 启动脚本配置问题
3. 硬件编码器注册失败

## 🔍 技术细节

### DRM_PRIME 格式问题

**问题本质**: 硬件解码器和软件编码器之间的像素格式不兼容

- **RKMPP 解码器输出**: DRM_PRIME (format 179) - GPU 内存格式
- **libx264 编码器期望**: I420 (format 0) - 系统内存格式
- **FFmpeg 转换失败**: 无法创建 DRM_PRIME → I420 转换链

### 解决方案对比

| 方案 | 描述 | 优点 | 缺点 | 状态 |
|-----|------|------|------|------|
| A | 修改 FFmpeg 支持 DRM_PRIME 转换 | 保留软件编码器 | 需要修改 FFmpeg 源码，复杂度高 | ❌ 未采用 |
| B | 使用硬件编码器 h264_rkmpp | 原生支持 DRM_PRIME，零拷贝 | 依赖硬件 | ✅ 已采用 |

### Fix 97 实现细节

**文件**: `cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`

**关键代码**:
```c
// Line 1128-1131: 环境变量处理
const char* use_hw_encoder = getenv("USE_HARDWARE_ENCODER");
int enable_hw_encoder = 1;  // 默认：1（启用硬件编码器）
if (use_hw_encoder) {
    enable_hw_encoder = atoi(use_hw_encoder);
}

// Line 1192-1197: 硬件编码器注册（默认启用）
if (hw_encoder_name && enable_hw_encoder == 1) {
    PJ_LOG(1,(THIS_FILE, "✅ [FIX 97] Hardware encoder ENABLED..."));
    c = avcodec_find_encoder_by_name(hw_encoder_name);  // h264_rkmpp
}

// Line 1278-1284: 软件编码器回退
else if (hw_encoder_name) {
    PJ_LOG(1,(THIS_FILE, "⚠️ [FIX 97] Hardware encoder DISABLED..."));
    c = avcodec_find_encoder(codec_id);  // libx264
}
```

## 📚 参考文档

### 本次会话创建的文档

1. **Core Dump 分析**: [docs/2026-01-09/72-Core-Dump分析-编码器初始化崩溃根因.md](docs/2026-01-09/72-Core-Dump分析-编码器初始化崩溃根因.md)
2. **Fix 100.12 方案**: [docs/2026-01-09/73-Fix100.12-硬件编码器解决DRM_PRIME问题.md](docs/2026-01-09/73-Fix100.12-硬件编码器解决DRM_PRIME问题.md)
3. **本工作总结**: [docs/2026-01-10/01-工作总结-自动Core-Dump分析集成.md](docs/2026-01-10/01-工作总结-自动Core-Dump分析集成.md)

### 相关历史文档

1. **MPP Issue 157 调研**: [docs/2026-01-08/17-Rockchip-MPP-Issue157全网调研报告.md](docs/2026-01-08/17-Rockchip-MPP-Issue157全网调研报告.md)
2. **Fix 100.10 音频设备**: [docs/2026-01-09/68-Fix100.10-修复音频设备找不到默认设备错误.md](docs/2026-01-09/68-Fix100.10-修复音频设备找不到默认设备错误.md)
3. **Fix 100.11 hwdevice 恢复**: [docs/2026-01-09/69-Fix100.10.1-音频设备智能选择最终版.md](docs/2026-01-09/69-Fix100.10.1-音频设备智能选择最终版.md)

## 🎯 下一步计划

1. **等待用户测试结果** - 用户在 192.168.10.188 设备上验证最新代码
2. **验证硬件编码器** - 检查 USE_HARDWARE_ENCODER=1 是否生效
3. **测试自动分析功能** - 验证崩溃时是否自动显示分析结果
4. **如仍有崩溃** - 利用自动 Core Dump 分析快速定位新问题

## 💡 经验总结

### 技术收获

1. **Core Dump 分析技术** - 掌握了 GDB 批处理模式分析大型 Core Dump
2. **硬件视频编解码** - 深入理解了 DRM_PRIME 格式和零拷贝技术
3. **自动化调试** - 实现了崩溃自动分析，提高调试效率

### 流程优化

1. **缓存机制** - 避免重复分析，节省时间
2. **集成到构建流程** - 无需额外操作，自动触发
3. **简洁输出** - 摘要 + 完整报告，兼顾快速查看和深入分析

### 问题教训

1. **代码已实现但未生效** - 需要验证环境变量和启动配置
2. **日志信息重要性** - 日志中的编码器名称暴露了问题
3. **多层调试工具** - Core Dump、GDB、日志多管齐下

## 📝 备注

- **设备信息**: 192.168.10.188 (用户名: linaro, 密码: linaro)
- **旧设备**: 192.168.1.8 (用户名: pi, 密码: pi)
- **当前版本**: v111
- **目标**: 解决新工控机视频通话崩溃问题

---

**创建时间**: 2026-01-10
**作者**: Claude (Sonnet 4.5)
**状态**: ✅ 自动 Core Dump 分析功能已完成集成
