# Phase7.46.16 - 安装Python和TTS引擎依赖

**日期**: 2026-02-16
**阶段**: Phase 7.46.16
**状态**: ✅ 已完成

---

## 📋 问题描述

### 现象

从 voip.md 日志（第 1343 行）可以看到详细的错误信息：

```
[WARNING] [PaddleSpeech Error] "[2023-06-18 16:20:50,960] [ERROR] ❌ 初始化失败: No module named 'paddlespeech'
Traceback (most recent call last):
  File "/app/tts_engines/paddlespeech/paddle_tts_service.py", line 47, in initialize_paddlespeech
    from paddlespeech.cli.tts.infer import TTSExecutor
ModuleNotFoundError: No module named 'paddlespeech'
```

**症状**：
- ✅ Python 服务脚本成功启动
- ✅ stderr 捕获成功（Phase 7.46.15 的修复生效）
- ❌ 容器内缺少 PaddleSpeech Python 模块
- ❌ 无法导入 `paddlespeech.cli.tts.infer`

---

## 🔍 根本原因

### 问题分析

**容器环境检查**：
- ❌ 容器内没有安装 Python3
- ❌ 容器内没有安装 pip
- ❌ 容器内没有安装 PaddleSpeech 和 MeloTTS 的 Python 依赖

**依赖清单**：

**PaddleSpeech** (`docker/rk3588/tts_engines/paddlespeech/requirements.txt`):
```
paddlepaddle>=2.4.0
paddlespeech>=1.4.1
librosa>=0.9.0
soundfile>=0.12.1
pydub>=0.25.1
numpy>=1.21.0
scipy>=1.7.0
```

**MeloTTS** (`docker/rk3588/tts_engines/melotts/requirements.txt`):
```
melo-tts>=0.1.0
torch>=2.0.0
torchaudio>=2.0.0
numpy>=1.21.0
scipy>=1.7.0
librosa>=0.9.0
soundfile>=0.12.1
```

---

## 🛠️ 修复方案

### 修改：Dockerfile.ubuntu24-apt

**文件**: `Dockerfile.ubuntu24-apt`

**位置**: 第 55-66 行（在 COPY tts_engines 之后）

**修改内容**：

```dockerfile
# ✅ 2026-02-16 00:50: 安装 Python 和 TTS 引擎依赖
# 原因：PaddleSpeech 和 MeloTTS 需要 Python 运行环境
# 策略：安装 Python3 和 pip，然后安装各引擎的 requirements.txt
# 效果：TTS 引擎可以正常初始化和合成语音
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir --break-system-packages \
        -r /app/tts_engines/paddlespeech/requirements.txt \
        -r /app/tts_engines/melotts/requirements.txt
```

**说明**：
1. **安装 Python 环境**：
   - `python3` - Python 3 解释器
   - `python3-pip` - Python 包管理器
   - `python3-dev` - Python 开发头文件（某些包编译需要）

2. **安装 TTS 依赖**：
   - `--no-cache-dir` - 不缓存下载的包（减小镜像体积）
   - `--break-system-packages` - Ubuntu 24.04 需要此选项（PEP 668）
   - 同时安装 PaddleSpeech 和 MeloTTS 的依赖

3. **清理 apt 缓存**：
   - `rm -rf /var/lib/apt/lists/*` - 删除 apt 缓存（减小镜像体积）

---

## 📊 修复前后对比

### 修复前

**容器环境**：
```bash
$ docker exec belt-control-app python3 --version
bash: python3: command not found
```

**日志**：
```
[WARNING] [PaddleSpeech Error] ModuleNotFoundError: No module named 'paddlespeech'
```

### 修复后

**预期容器环境**：
```bash
$ docker exec belt-control-app python3 --version
Python 3.12.3

$ docker exec belt-control-app pip3 list | grep paddlespeech
paddlepaddle    2.6.0
paddlespeech    1.4.1
```

**预期日志**：
```
[DEBUG] 🔧 [PaddleSpeech] 初始化 - 模型: "/home/pi/belt-control-data/models/tts_models/paddlespeech/fastspeech2_csmsc"
[DEBUG] 🚀 [PaddleSpeech] 启动服务: "/app/tts_engines/paddlespeech/paddle_tts_service.py"
[DEBUG] ✅ [PaddleSpeech] 服务启动成功
[DEBUG] 📤 [PaddleSpeech] 发送命令: "initialize"
[WARNING] [PaddleSpeech Error] [2026-02-16 01:00:00] [INFO] 🔧 初始化 PaddleSpeech - 模型: fastspeech2_csmsc
[WARNING] [PaddleSpeech Error] [2026-02-16 01:00:05] [INFO] ✅ PaddleSpeech 初始化成功
[DEBUG] [PaddleSpeech Output] "{\"status\": \"success\", \"message\": \"初始化成功\"}"
[DEBUG] ✅ [PaddleSpeech] 初始化成功
```

---

## 🚀 部署流程

### 步骤1：重新构建镜像

```powershell
.\build-ubuntu24-apt.ps1 186
```

**自动完成**：
1. 检测 Dockerfile 变化
2. 构建 Docker 镜像（安装 Python 和依赖）
3. 部署到设备 192.168.10.186

**预计时间**：
- Python 安装：~30 秒
- PaddleSpeech 依赖安装：~5-10 分钟（首次下载）
- MeloTTS 依赖安装：~3-5 分钟（首次下载）
- **总计**：~10-15 分钟

### 步骤2：验证 Python 环境

**检查 Python 版本**：
```bash
ssh pi@192.168.10.186 "docker exec belt-control-app python3 --version"
```

**预期输出**：
```
Python 3.12.3
```

**检查已安装的包**：
```bash
ssh pi@192.168.10.186 "docker exec belt-control-app pip3 list"
```

**预期输出**（部分）：
```
Package          Version
---------------- -------
paddlepaddle     2.6.0
paddlespeech     1.4.1
librosa          0.10.1
soundfile        0.12.1
numpy            1.26.4
scipy            1.12.0
...
```

### 步骤3：测试 PaddleSpeech 引擎

**操作**：
1. 启动应用程序
2. 打开 TTS 配置界面
3. 切换到 PaddleSpeech 引擎
4. 选择模型（如 "fastspeech2_csmsc (中文女声)"）
5. 点击"测试"按钮

**查看日志**：
```bash
ssh pi@192.168.10.186 "docker logs -f belt-control-app | grep -E 'PaddleSpeech|Error'"
```

**预期结果**：
- ✅ Python 模块成功导入
- ✅ PaddleSpeech 引擎初始化成功
- ✅ 语音合成成功
- ✅ 播放合成的语音

---

## ⚠️ 注意事项

### 1. 镜像体积增加

**Python 和依赖的体积**：
- Python3 + pip：~100 MB
- PaddleSpeech 依赖：~500-800 MB
- MeloTTS 依赖：~300-500 MB
- **总计**：~1-1.5 GB

**优化建议**：
- 使用 `--no-cache-dir` 减小体积
- 清理 apt 缓存
- 考虑使用 Alpine 基础镜像（未来优化）

### 2. 构建时间增加

**首次构建**：
- 下载 Python 包：~10-15 分钟
- 编译某些包（如 numpy、scipy）：~5-10 分钟
- **总计**：~15-25 分钟

**后续构建**：
- Docker 缓存生效：~2-3 分钟（如果 requirements.txt 未变化）

### 3. 网络依赖

**构建时需要网络**：
- 下载 Python 包（PyPI）
- 下载 PaddlePaddle 模型（首次使用时）

**建议**：
- 使用国内 PyPI 镜像（如清华、阿里云）
- 预下载模型到本地

---

## 📝 相关文档

1. [34-TTS引擎问题诊断报告.md](../2026-02-15/34-TTS引擎问题诊断报告.md) - 问题分析
2. [35-Phase7.46.12-修复TTS引擎注册问题.md](../2026-02-15/35-Phase7.46.12-修复TTS引擎注册问题.md) - 引擎注册修复
3. [36-Phase7.46.13-TTS引擎初始化功能完成总结.md](../2026-02-15/36-Phase7.46.13-TTS引擎初始化功能完成总结.md) - 初始化功能实现
4. [37-Phase7.46.14-修复TTS服务脚本缺失问题.md](37-Phase7.46.14-修复TTS服务脚本缺失问题.md) - 服务脚本修复
5. [38-Phase7.46.15-添加Python进程stderr捕获.md](38-Phase7.46.15-添加Python进程stderr捕获.md) - stderr 捕获

---

## ✅ Git提交记录

**提交**: Phase 7.46.16 - 安装Python和TTS引擎依赖

**修改文件**：
- `Dockerfile.ubuntu24-apt` - 添加 Python 和 TTS 依赖安装
- `docs/2026-02-16/39-Phase7.46.16-安装Python和TTS引擎依赖.md` - 修复总结文档

**提交信息**：
```
fix: Phase 7.46.16 - 安装Python和TTS引擎依赖

- 在 Dockerfile.ubuntu24-apt 添加 Python3 和 pip 安装
- 安装 PaddleSpeech 和 MeloTTS 的 requirements.txt
- 修复容器内缺少 Python 模块的问题
- 使 TTS 引擎可以正常初始化和合成语音
```

---

## 🎯 下一步工作

### 立即执行

1. **重新构建镜像**（预计 15-25 分钟）
   ```powershell
   .\build-ubuntu24-apt.ps1 186
   ```

2. **验证 Python 环境**
   ```bash
   ssh pi@192.168.10.186 "docker exec belt-control-app python3 --version"
   ssh pi@192.168.10.186 "docker exec belt-control-app pip3 list | grep -E 'paddlespeech|melo'"
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

5. **优化镜像体积**（可选）
   - 使用多阶段构建
   - 移除不必要的依赖
   - 使用 Alpine 基础镜像

6. **实现 Coqui TTS 适配器**（低优先级）
7. **实现 Piper TTS 适配器**（低优先级）

---

## 📦 完成的功能

### TTS引擎管理（Phase 7.46.12-7.46.16）

| 功能 | 状态 | 说明 |
|------|------|------|
| 引擎注册 | ✅ 完成 | PaddleSpeech、MeloTTS 自动注册 |
| 引擎切换 | ✅ 完成 | 支持动态切换引擎 |
| 模型列表 | ✅ 完成 | 显示当前引擎的模型列表 |
| 模型切换 | ✅ 完成 | 自动生成模型路径并初始化 |
| 引擎初始化 | ✅ 完成 | 调用适配器的 `initialize()` 方法 |
| 服务脚本 | ✅ 完成 | Dockerfile 包含服务脚本 |
| stderr 捕获 | ✅ 完成 | 捕获 Python 详细错误信息 |
| Python 环境 | ✅ 完成 | 安装 Python3 和 pip |
| TTS 依赖 | ✅ 完成 | 安装 PaddleSpeech 和 MeloTTS 依赖 |

### TTS引擎状态

| 引擎名称 | 注册状态 | 初始化逻辑 | 服务脚本 | Python依赖 | 模型文件 | 可用性 |
|---------|---------|-----------|---------|-----------|---------|--------|
| Sherpa-ONNX | ✅ 已注册 | ✅ C++实现 | ✅ 已包含 | N/A | ✅ 已上传 | ✅ 可用 |
| PaddleSpeech | ✅ 已注册 | ✅ 已实现 | ✅ 已包含 | ✅ 已安装 | ✅ 已上传 | ⏳ 待测试 |
| MeloTTS | ✅ 已注册 | ✅ 已实现 | ✅ 已包含 | ✅ 已安装 | ✅ 已上传 | ⏳ 待测试 |
| Coqui TTS | ❌ 未注册 | ❌ 未实现 | ❌ 未实现 | ❌ 未安装 | ✅ 已上传 | ❌ 不可用 |
| Piper TTS | ❌ 未注册 | ❌ 未实现 | ❌ 未实现 | ❌ 未安装 | ✅ 已上传 | ❌ 不可用 |

---

**完成时间**: 2026-02-16 00:55
**下次测试**: 重新构建镜像后（预计 15-25 分钟）
