# Phase7.46.14 - 修复TTS服务脚本缺失问题

**日期**: 2026-02-16
**阶段**: Phase 7.46.14
**状态**: ✅ 已完成

---

## 📋 问题描述

### 现象

从 voip.md 日志（第 732 行）可以看到：

```
[WARNING] ❌ [PaddleSpeech] 服务脚本不存在: "/app/tts_engines/paddlespeech/paddle_tts_service.py"
```

**症状**：
- ✅ PaddleSpeech 和 MeloTTS 引擎注册成功
- ✅ 模型路径正确生成
- ✅ 初始化方法被调用
- ❌ 容器内 `/app/tts_engines/` 目录不存在
- ❌ Python 服务脚本无法找到

---

## 🔍 根本原因

### 问题分析

**构建流程**：
1. ✅ `build-ubuntu24-apt.ps1` 复制 `docker/rk3588/tts_engines` 到构建上下文（第 1202-1211 行）
2. ❌ `Dockerfile.ubuntu24-apt` **缺少** `COPY tts_engines /app/tts_engines` 命令
3. ❌ 构建上下文中的文件没有被复制到 Docker 镜像

**关键发现**：
- Dockerfile 有 `COPY belt_control_system`、`COPY lib`、`COPY plugins` 等命令
- 但是**没有** `COPY tts_engines` 命令
- 导致服务脚本虽然在构建上下文中，但没有进入最终镜像

---

## 🛠️ 修复方案

### 修改：Dockerfile.ubuntu24-apt

**文件**: `Dockerfile.ubuntu24-apt`

**位置**: 第 18-22 行（在 `COPY qml` 之后）

**修改内容**：

```dockerfile
COPY belt_control_system /app/belt_control_system
COPY sherpa_tts_service /app/sherpa_tts_service
COPY lib /app/lib
COPY plugins /app/plugins
COPY qml /app/qml

# ✅ 2026-02-16 00:20: 复制 TTS 引擎服务脚本到镜像
# 原因：PaddleSpeech 和 MeloTTS 需要 Python 服务脚本
# 路径：/app/tts_engines/paddlespeech/paddle_tts_service.py
#       /app/tts_engines/melotts/melo_tts_service.py
COPY tts_engines /app/tts_engines
```

**说明**：
- 添加 `COPY tts_engines /app/tts_engines` 命令
- 将构建上下文中的 `tts_engines` 目录复制到镜像的 `/app/tts_engines`
- 包含 PaddleSpeech 和 MeloTTS 的 Python 服务脚本

---

## 📦 服务脚本清单

### 本地文件（已存在）

**路径**: `docker/rk3588/tts_engines/`

```
tts_engines/
├── paddlespeech/
│   ├── paddle_tts_service.py    (7.8 KB)
│   └── requirements.txt         (247 B)
└── melotts/
    ├── melo_tts_service.py      (7.2 KB)
    └── requirements.txt         (195 B)
```

**总大小**: ~15 KB

### 镜像内路径（修复后）

```
/app/tts_engines/
├── paddlespeech/
│   ├── paddle_tts_service.py
│   └── requirements.txt
└── melotts/
    ├── melo_tts_service.py
    └── requirements.txt
```

---

## 🚀 部署流程

### 步骤1：重新构建镜像

```powershell
.\build-ubuntu24-apt.ps1 186
```

**自动完成**：
1. 检测 Dockerfile 变化
2. 复制 `tts_engines` 到构建上下文
3. 构建 Docker 镜像（包含 `tts_engines` 目录）
4. 部署到设备 192.168.10.186

### 步骤2：验证服务脚本

**检查容器内文件**：
```bash
ssh pi@192.168.10.186 "docker exec belt-control-app ls -lh /app/tts_engines/"
```

**预期输出**：
```
drwxr-xr-x 2 root root 4.0K paddlespeech
drwxr-xr-x 2 root root 4.0K melotts
```

**检查具体文件**：
```bash
ssh pi@192.168.10.186 "docker exec belt-control-app ls -lh /app/tts_engines/paddlespeech/"
```

**预期输出**：
```
-rw-r--r-- 1 root root 7.8K paddle_tts_service.py
-rw-r--r-- 1 root root  247 requirements.txt
```

### 步骤3：测试引擎初始化

**操作**：
1. 启动应用程序
2. 打开 TTS 配置界面
3. 切换到 PaddleSpeech 引擎
4. 选择模型
5. 点击"测试"按钮

**预期日志**：
```
[DEBUG] 🔧 [PaddleSpeech] 初始化 - 模型: "/home/pi/belt-control-data/models/tts_models/paddlespeech/fastspeech2_csmsc"
[DEBUG] ✅ 找到TTS服务: "/app/tts_engines/paddlespeech/paddle_tts_service.py"
[DEBUG] 🚀 启动TTS服务进程...
[DEBUG] ✅ TTS服务进程已启动，PID: XXX
[DEBUG] ✅ [PaddleSpeech] 初始化成功
```

---

## 📊 修复前后对比

### 修复前

**构建流程**：
```
build-ubuntu24-apt.ps1 → 复制 tts_engines 到构建上下文 ✅
Dockerfile.ubuntu24-apt → ❌ 没有 COPY tts_engines 命令
Docker 镜像 → ❌ 没有 /app/tts_engines/ 目录
容器运行 → ❌ 服务脚本不存在
```

**日志**：
```
[WARNING] ❌ [PaddleSpeech] 服务脚本不存在: "/app/tts_engines/paddlespeech/paddle_tts_service.py"
[WARNING] ❌ [CommonControl] TTS 引擎初始化失败
```

### 修复后

**构建流程**：
```
build-ubuntu24-apt.ps1 → 复制 tts_engines 到构建上下文 ✅
Dockerfile.ubuntu24-apt → ✅ COPY tts_engines /app/tts_engines
Docker 镜像 → ✅ 包含 /app/tts_engines/ 目录
容器运行 → ✅ 服务脚本存在
```

**预期日志**：
```
[DEBUG] ✅ 找到TTS服务: "/app/tts_engines/paddlespeech/paddle_tts_service.py"
[DEBUG] 🚀 启动TTS服务进程...
[DEBUG] ✅ TTS服务进程已启动，PID: XXX
[DEBUG] ✅ [PaddleSpeech] 初始化成功
```

---

## 🎯 完成的功能

### TTS引擎管理（Phase 7.46.12-7.46.14）

| 功能 | 状态 | 说明 |
|------|------|------|
| 引擎注册 | ✅ 完成 | PaddleSpeech、MeloTTS 自动注册 |
| 引擎切换 | ✅ 完成 | 支持动态切换引擎 |
| 模型列表 | ✅ 完成 | 显示当前引擎的模型列表 |
| 模型切换 | ✅ 完成 | 自动生成模型路径并初始化 |
| 引擎初始化 | ✅ 完成 | 调用适配器的 `initialize()` 方法 |
| 服务脚本 | ✅ 完成 | Dockerfile 包含服务脚本 |

### TTS引擎状态

| 引擎名称 | 注册状态 | 初始化逻辑 | 服务脚本 | 模型文件 | 可用性 |
|---------|---------|-----------|---------|---------|--------|
| Sherpa-ONNX | ✅ 已注册 | ✅ C++实现 | ✅ 已包含 | ✅ 已上传 | ✅ 可用 |
| PaddleSpeech | ✅ 已注册 | ✅ 已实现 | ✅ 已包含 | ✅ 已上传 | ⏳ 待测试 |
| MeloTTS | ✅ 已注册 | ✅ 已实现 | ✅ 已包含 | ✅ 已上传 | ⏳ 待测试 |
| Coqui TTS | ❌ 未注册 | ❌ 未实现 | ❌ 未实现 | ✅ 已上传 | ❌ 不可用 |
| Piper TTS | ❌ 未注册 | ❌ 未实现 | ❌ 未实现 | ✅ 已上传 | ❌ 不可用 |

---

## 📝 相关文档

1. [34-TTS引擎问题诊断报告.md](../2026-02-15/34-TTS引擎问题诊断报告.md) - 问题分析
2. [35-Phase7.46.12-修复TTS引擎注册问题.md](../2026-02-15/35-Phase7.46.12-修复TTS引擎注册问题.md) - 引擎注册修复
3. [36-Phase7.46.13-TTS引擎初始化功能完成总结.md](../2026-02-15/36-Phase7.46.13-TTS引擎初始化功能完成总结.md) - 初始化功能实现
4. [29-四引擎TTS模型下载完整总结.md](../2026-02-15/29-四引擎TTS模型下载完整总结.md) - 模型下载

---

## ✅ Git提交记录

**提交**: Phase 7.46.14 - 修复TTS服务脚本缺失问题

**修改文件**：
- `Dockerfile.ubuntu24-apt` - 添加 `COPY tts_engines /app/tts_engines`
- `docs/2026-02-16/37-Phase7.46.14-修复TTS服务脚本缺失问题.md` - 修复总结文档

**提交信息**：
```
fix: Phase 7.46.14 - 修复TTS服务脚本缺失问题

- 在 Dockerfile.ubuntu24-apt 添加 COPY tts_engines 命令
- 确保 PaddleSpeech 和 MeloTTS 服务脚本包含在镜像中
- 修复容器内 /app/tts_engines/ 目录不存在的问题
```

---

## 🎯 下一步工作

### 立即执行

1. **重新构建镜像**
   ```powershell
   .\build-ubuntu24-apt.ps1 186
   ```

2. **验证服务脚本**
   ```bash
   ssh pi@192.168.10.186 "docker exec belt-control-app ls -lh /app/tts_engines/"
   ```

3. **测试 PaddleSpeech 引擎**
   - 切换到 PaddleSpeech 引擎
   - 选择模型
   - 点击"测试"按钮
   - 验证语音合成成功

4. **测试 MeloTTS 引擎**
   - 切换到 MeloTTS 引擎
   - 选择模型
   - 点击"测试"按钮
   - 验证语音合成成功

### 后续工作

5. **实现 Coqui TTS 适配器**（低优先级）
6. **实现 Piper TTS 适配器**（低优先级）
7. **优化引擎切换性能**
8. **添加引擎状态监控**

---

**完成时间**: 2026-02-16 00:25
**下次测试**: 重新构建镜像后
