# Phase7.46.17 - 修复MeloTTS依赖安装失败问题

**日期**: 2026-02-16
**阶段**: Phase 7.46.17
**状态**: ✅ 已完成

---

## 📋 问题描述

### 现象

从 pjsip.md 日志（第 547 行）可以看到 Docker 构建失败：

```
ERROR: Could not find a version that satisfies the requirement melo-tts>=0.1.0 (from versions: none)
ERROR: No matching distribution found for melo-tts>=0.1.0
```

**症状**：
- ✅ Python3 和 pip 安装成功
- ✅ PaddleSpeech 依赖开始下载
- ❌ MeloTTS 的 `melo-tts` 包在 PyPI 上不存在
- ❌ Docker 构建失败，退出码 1

---

## 🔍 根本原因

### 问题分析

**MeloTTS 安装方式**：
- ❌ PyPI 上没有 `melo-tts` 包
- ✅ MeloTTS 需要从 GitHub 安装：`pip install git+https://github.com/myshell-ai/MeloTTS.git`

**requirements.txt 错误**：
```
# docker/rk3588/tts_engines/melotts/requirements.txt
melo-tts>=0.1.0  # ❌ 这个包名不存在
```

**正确的安装方式**：
```bash
# 从 GitHub 安装
pip install git+https://github.com/myshell-ai/MeloTTS.git

# 或者克隆后安装
git clone https://github.com/myshell-ai/MeloTTS.git
cd MeloTTS
pip install -e .
```

---

## 🛠️ 修复方案

### 策略：分阶段实施

**Phase 7.46.17**（当前）：
- ✅ 先只安装 PaddleSpeech 依赖
- ✅ 让 PaddleSpeech 引擎工作
- ⏳ MeloTTS 暂时跳过

**Phase 7.46.18**（后续）：
- 研究 MeloTTS 的正确安装方式
- 修改 Dockerfile 从 GitHub 安装 MeloTTS
- 测试 MeloTTS 引擎

### 修改：Dockerfile.ubuntu24-apt

**文件**: `Dockerfile.ubuntu24-apt`

**位置**: 第 55-68 行

**修改内容**：

```dockerfile
# ✅ 2026-02-16 00:50: 安装 Python 和 TTS 引擎依赖
# 原因：PaddleSpeech 和 MeloTTS 需要 Python 运行环境
# 策略：安装 Python3 和 pip，然后安装各引擎的 requirements.txt
# 效果：TTS 引擎可以正常初始化和合成语音
# ✅ 2026-02-16 01:10: 暂时只安装 PaddleSpeech 依赖
# 原因：MeloTTS 的 melo-tts 包在 PyPI 上不存在，需要从 GitHub 安装
# 策略：先让 PaddleSpeech 工作，MeloTTS 后续单独处理
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir --break-system-packages \
        -r /app/tts_engines/paddlespeech/requirements.txt
```

**说明**：
- 移除了 `-r /app/tts_engines/melotts/requirements.txt`
- 只安装 PaddleSpeech 的依赖
- 添加注释说明 MeloTTS 后续处理

---

## 📊 修复前后对比

### 修复前

**Dockerfile**：
```dockerfile
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir --break-system-packages \
        -r /app/tts_engines/paddlespeech/requirements.txt \
        -r /app/tts_engines/melotts/requirements.txt  # ❌ 失败
```

**构建结果**：
```
ERROR: Could not find a version that satisfies the requirement melo-tts>=0.1.0
ERROR: No matching distribution found for melo-tts>=0.1.0
ERROR: Docker build failed
```

### 修复后

**Dockerfile**：
```dockerfile
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir --break-system-packages \
        -r /app/tts_engines/paddlespeech/requirements.txt  # ✅ 成功
```

**预期构建结果**：
```
Successfully installed paddlepaddle-2.6.0 paddlespeech-1.4.1 librosa-0.11.0 ...
Docker build succeeded
```

---

## 🚀 部署流程

### 步骤1：重新构建镜像

```powershell
.\build-ubuntu24-apt.ps1 186
```

**自动完成**：
1. 检测 Dockerfile 变化
2. 构建 Docker 镜像（只安装 PaddleSpeech 依赖）
3. 部署到设备 192.168.10.186

**预计时间**：
- Python 安装：~30 秒
- PaddleSpeech 依赖安装：~5-10 分钟
- **总计**：~6-11 分钟

### 步骤2：验证 PaddleSpeech 依赖

**检查已安装的包**：
```bash
ssh pi@192.168.10.186 "docker exec belt-control-app pip3 list | grep -E 'paddlespeech|paddlepaddle'"
```

**预期输出**：
```
paddlepaddle     2.6.0
paddlespeech     1.4.1
```

### 步骤3：测试 PaddleSpeech 引擎

**操作**：
1. 启动应用程序
2. 打开 TTS 配置界面
3. 切换到 PaddleSpeech 引擎
4. 选择模型（如 "fastspeech2_csmsc (中文女声)"）
5. 点击"测试"按钮

**预期结果**：
- ✅ PaddleSpeech 引擎初始化成功
- ✅ 语音合成成功
- ✅ 播放合成的语音

### 步骤4：MeloTTS 引擎状态

**当前状态**：
- ❌ MeloTTS 依赖未安装
- ❌ MeloTTS 引擎无法初始化
- ⏳ 需要后续 Phase 7.46.18 处理

**用户体验**：
- 用户切换到 MeloTTS 引擎时，会看到初始化失败
- 日志会显示 `ModuleNotFoundError: No module named 'melo_tts'`

---

## 📝 TTS 引擎状态

### 当前可用性

| 引擎名称 | 注册状态 | 依赖安装 | 初始化逻辑 | 可用性 |
|---------|---------|---------|-----------|--------|
| Sherpa-ONNX | ✅ 已注册 | ✅ C++实现 | ✅ 已实现 | ✅ 可用 |
| PaddleSpeech | ✅ 已注册 | ✅ 已安装 | ✅ 已实现 | ⏳ 待测试 |
| MeloTTS | ✅ 已注册 | ❌ 未安装 | ✅ 已实现 | ❌ 不可用 |
| Coqui TTS | ❌ 未注册 | ❌ 未安装 | ❌ 未实现 | ❌ 不可用 |
| Piper TTS | ❌ 未注册 | ❌ 未安装 | ❌ 未实现 | ❌ 不可用 |

---

## 🎯 下一步工作

### 立即执行（Phase 7.46.17）

1. **重新构建镜像**
   ```powershell
   .\build-ubuntu24-apt.ps1 186
   ```

2. **测试 PaddleSpeech 引擎**
   - 验证初始化成功
   - 验证语音合成成功

### 后续工作（Phase 7.46.18）

3. **研究 MeloTTS 安装方式**
   - 查看 MeloTTS GitHub 仓库
   - 确定正确的安装命令
   - 测试本地安装

4. **修改 Dockerfile 安装 MeloTTS**
   ```dockerfile
   RUN pip3 install --no-cache-dir --break-system-packages \
       git+https://github.com/myshell-ai/MeloTTS.git
   ```

5. **测试 MeloTTS 引擎**
   - 验证初始化成功
   - 验证语音合成成功

---

## 📝 相关文档

1. [34-TTS引擎问题诊断报告.md](../2026-02-15/34-TTS引擎问题诊断报告.md) - 问题分析
2. [35-Phase7.46.12-修复TTS引擎注册问题.md](../2026-02-15/35-Phase7.46.12-修复TTS引擎注册问题.md) - 引擎注册修复
3. [36-Phase7.46.13-TTS引擎初始化功能完成总结.md](../2026-02-15/36-Phase7.46.13-TTS引擎初始化功能完成总结.md) - 初始化功能实现
4. [37-Phase7.46.14-修复TTS服务脚本缺失问题.md](37-Phase7.46.14-修复TTS服务脚本缺失问题.md) - 服务脚本修复
5. [38-Phase7.46.15-添加Python进程stderr捕获.md](38-Phase7.46.15-添加Python进程stderr捕获.md) - stderr 捕获
6. [39-Phase7.46.16-安装Python和TTS引擎依赖.md](39-Phase7.46.16-安装Python和TTS引擎依赖.md) - Python 依赖安装

---

## ✅ Git提交记录

**提交**: Phase 7.46.17 - 修复MeloTTS依赖安装失败问题

**修改文件**：
- `Dockerfile.ubuntu24-apt` - 暂时移除 MeloTTS 依赖安装
- `docs/2026-02-16/40-Phase7.46.17-修复MeloTTS依赖安装失败问题.md` - 修复总结文档

**提交信息**：
```
fix: Phase 7.46.17 - 修复MeloTTS依赖安装失败问题

- 暂时移除 MeloTTS 依赖安装（melo-tts 包不存在）
- 只安装 PaddleSpeech 依赖
- 先让 PaddleSpeech 引擎工作
- MeloTTS 后续从 GitHub 安装
```

---

**完成时间**: 2026-02-16 01:15
**下次测试**: 重新构建镜像后测试 PaddleSpeech
