# SIP 视频通话功能实施指南

## 项目概述

为皮带控制系统添加完整的 SIP 视频通话功能，支持 Windows x64 和 AArch64 Linux 平台。

## 文档索引

### 📋 规划文档
- **[VIDEO_CALL_IMPLEMENTATION_PLAN.md](VIDEO_CALL_IMPLEMENTATION_PLAN.md)** - 完整实施计划 (16-25天)
  - 8个实施阶段详细说明
  - 技术架构设计
  - 文件结构规划
  - 风险评估和时间估算

### 🔍 调研报告
- **[VIDEO_RESEARCH_SUMMARY.md](VIDEO_RESEARCH_SUMMARY.md)** - 技术调研总结
  - 当前系统状态分析
  - PJSIP 配置验证
  - 依赖库版本确定
  - 编译方案详解

## 快速开始

### 当前状态

✅ **阶段 1 完成**: 调研和规划
- 已分析现有 PJSIP 配置
- 已确定技术方案 (方案 A: 完整实现)
- 已明确依赖库版本
- 已规划文件结构

### 下一步 (阶段 2-3)

您需要执行以下步骤：

#### 1. 下载依赖库

```bash
# x264 (H.264 编码器)
git clone https://code.videolan.org/videolan/x264.git
cd x264
git checkout stable

# FFmpeg 6.0
wget https://ffmpeg.org/releases/ffmpeg-6.0.tar.xz
tar -xf ffmpeg-6.0.tar.xz

# SDL2 2.28.5 (预编译)
wget https://github.com/libsdl-org/SDL/releases/download/release-2.28.5/SDL2-devel-2.28.5-VC.zip
```

#### 2. 安装 MSYS2 (Windows)

从 https://www.msys2.org/ 下载并安装

#### 3. 编译依赖库

详见 `VIDEO_RESEARCH_SUMMARY.md` 中的编译步骤

#### 4. 重新编译 PJSIP

详见 `VIDEO_RESEARCH_SUMMARY.md` 中的 PJSIP 编译方案

## 技术栈

### 核心组件
- **PJSIP 2.15.1** - SIP 协议栈
- **FFmpeg 6.0** - 视频编解码 (H.264)
- **SDL2 2.28.5** - 视频渲染
- **Qt 6** - UI 框架

### 编解码器
- **视频**: H.264 (主要), VP8 (备选)
- **音频**: Opus, G.711

## 实施阶段

| 阶段 | 任务 | 状态 | 预计时间 |
|-----|-----|------|---------|
| 1 | 调研和规划 | ✅ 完成 | 1天 |
| 2 | 下载依赖库 | ⏳ 待执行 | 1天 |
| 3 | 编译 x264 和 FFmpeg | ⏳ 待执行 | 1-2天 |
| 4 | 重新编译 PJSIP | ⏳ 待执行 | 1-2天 |
| 5 | 修改 CMakeLists.txt | ⏳ 待执行 | 0.5天 |
| 6 | 实现 C++ VideoCallManager | ⏳ 待执行 | 3-4天 |
| 7 | 实现 QML 视频界面 | ⏳ 待执行 | 2-3天 |
| 8 | 测试 Windows 平台 | ⏳ 待执行 | 3-4天 |
| 9 | 交叉编译 AArch64 | ⏳ 待执行 | 2-3天 |
| 10 | 测试 AArch64 平台 | ⏳ 待执行 | 2-3天 |

## 关键发现

### ✅ 现有基础良好
- Risip SDK 已有视频支持框架
- 代码注释中提到 "Audio/Video"
- 架构设计上支持视频

### ❌ 需要启用的功能
- PJSIP 当前未编译视频支持
- 缺少 FFmpeg 和 SDL2 依赖
- 需要重新编译 PJSIP

### ⚠️ 主要挑战
1. **编译复杂度**: 需要编译多个依赖库
2. **平台兼容性**: Windows 和 AArch64 差异
3. **性能优化**: AArch64 设备性能有限
4. **调试困难**: 视频问题定位复杂

## 风险缓解

### 技术风险
- ✅ 使用经过验证的稳定版本
- ✅ 先在 Windows 完整测试
- ✅ 准备降级方案 (640x480)
- ✅ 详细日志和分阶段测试

### 开发风险
- ✅ 提供详细编译脚本
- ✅ 准备预编译库 fallback
- ✅ 抽象平台差异代码
- ✅ 明确的里程碑和验证点

## 预期成果

### Windows x64 平台
- [x] 本地视频预览 (摄像头)
- [x] H.264 视频编码/解码
- [x] SIP 视频通话 (双向)
- [x] 视频控制 (开/关, 切换摄像头)
- [x] 640x480 @ 25fps

### AArch64 平台
- [x] 所有 Windows 功能
- [x] 硬件加速 (如果支持)
- [x] 性能优化

## 参考资源

### 官方文档
- PJSIP 视频指南: https://docs.pjsip.org/en/latest/specific-guides/video_users_guide.html
- FFmpeg 编译指南: https://trac.ffmpeg.org/wiki/CompilationGuide
- SDL2 官网: https://www.libsdl.org/

### 示例代码
- pjsip-apps/vidgui: `F:/0/pjproject-2.15.1/pjproject-2.15.1/pjsip-apps/src/vidgui/`

## 支持

### 遇到问题？

1. **编译失败**: 检查 `VIDEO_RESEARCH_SUMMARY.md` 中的详细步骤
2. **链接错误**: 验证库文件路径和版本
3. **运行时错误**: 查看详细日志，检查依赖 DLL

### 联系方式
- 项目 Issues: (GitHub URL)
- 文档问题: 查看 markdown 文件中的详细说明

---

**最后更新**: 2025-12-03 16:40
**状态**: 阶段 1 完成，准备进入阶段 2
**负责人**: Claude (AI Assistant) - 全程自主实施
