# Phase 7.47.4 - 修复 fastspeech2_aishell3 模型合成失败问题

**创建时间**: 2026-02-26 09:30
**问题类型**: Bug 修复
**优先级**: 高
**状态**: 待修复

---

## 📋 问题描述

用户在语音管理界面选择 `fastspeech2_aishell3` 模型（说话人ID 21）进行 TTS 合成时失败，错误信息：

```
RuntimeError: Download from https://paddlespeech.cdn.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_nosil_aishell3_ckpt_0.4.zip failed. Retry limit reached
```

---

## 🔍 问题诊断

### 日志分析

**失败日志**（voip.md 第 1064-1065 行）：
```
[2026-02-26 00:17:43,707] [ERROR] ❌ 合成失败: Download from https://paddlespeech.cdn.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_nosil_aishell3_ckpt_0.4.zip failed. Retry limit reached
```

**成功对比**：
- ✅ `fastspeech2_csmsc`（模型索引 0）合成成功
- ❌ `fastspeech2_aishell3`（模型索引 1）合成失败

### 根本原因

1. **模型文件存在但未被识别**
   - 模型文件位置：`/home/linaro/belt-control-data/models/tts_models/paddlespeech/models/fastspeech2_aishell3-zh/1.0/fastspeech2_nosil_aishell3_ckpt_0.4`
   - PaddleSpeech 默认查找路径：`~/.paddlespeech/`
   - **路径不匹配**

2. **PaddleSpeech 尝试自动下载**
   - 找不到本地模型时，尝试从百度云 CDN 下载
   - 网络连接失败（可能是防火墙或网络问题）
   - 重试次数用尽后报错

3. **为什么 fastspeech2_csmsc 成功？**
   - 该模型已被 PaddleSpeech 正确识别
   - 可能之前已经下载到默认路径

---

## 🔧 解决方案

### 方案 1：设置环境变量（推荐）⭐

**优点**：
- 简单快速
- 不需要修改代码
- 适用于所有模型

**实施步骤**：

1. **修改 Docker 启动脚本**

文件：`docker/rk3588/app-entrypoint.sh`

```bash
# ✅ 2026-02-26 09:30 [Phase 7.47.4]: 设置 PaddleSpeech 模型路径
# 原因：PaddleSpeech 默认在 ~/.paddlespeech/ 查找模型，导致找不到本地模型
# 效果：指定本地模型目录，避免网络下载
export PADDLESPEECH_HOME=/home/linaro/belt-control-data/models/tts_models/paddlespeech
```

2. **重新构建和部署**

```powershell
.\build-ubuntu24-apt.ps1 185
```

---

### 方案 2：修改 Python 代码使用绝对路径

**优点**：
- 更精确控制模型路径
- 可以支持多个模型目录

**缺点**：
- 需要修改代码
- 维护成本较高

**实施步骤**：

1. **修改 paddle_tts_service.py**

文件：`docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py`

在 `synthesize_speech()` 函数中添加：

```python
# ✅ 2026-02-26 09:30 [Phase 7.47.4]: 使用本地模型路径
# 原因：避免 PaddleSpeech 尝试下载模型
# 效果：直接使用本地已下载的模型文件

# 模型基础路径
MODEL_BASE = "/home/linaro/belt-control-data/models/tts_models/paddlespeech/models"

# 构建完整模型路径
if 'aishell3' in am_name:
    am_path = f"{MODEL_BASE}/fastspeech2_aishell3-zh/1.0/fastspeech2_nosil_aishell3_ckpt_0.4"
    voc_path = f"{MODEL_BASE}/hifigan_aishell3-zh/1.0/hifigan_aishell3_ckpt_0.2.0"
elif 'csmsc' in am_name:
    am_path = f"{MODEL_BASE}/fastspeech2_csmsc-zh/1.0/fastspeech2_nosil_baker_ckpt_0.4"
    voc_path = f"{MODEL_BASE}/pwgan_csmsc-zh/1.0/pwg_baker_ckpt_0.4"
else:
    # 使用预定义模型名称（可能触发下载）
    am_path = am_name
    voc_path = voc_name

logger.info(f"📦 使用模型路径: am={am_path}, voc={voc_path}")

# 调用 PaddleSpeech 合成
tts_executor(
    text=text,
    output=output_path,
    am=am_path,        # 使用完整路径或预定义名称
    voc=voc_path,      # 使用完整路径或预定义名称
    lang=lang,
    spk_id=speaker_id
)
```

2. **重新构建和部署**

```powershell
.\build-ubuntu24-apt.ps1 185
```

---

### 方案 3：创建符号链接（临时方案）

**优点**：
- 不需要修改代码或配置
- 快速验证

**缺点**：
- 需要手动操作
- 容器重启后可能失效

**实施步骤**：

```bash
# 在设备上执行
ssh linaro@192.168.10.185

# 创建 PaddleSpeech 默认目录
docker exec belt-control-app mkdir -p /root/.paddlespeech

# 创建符号链接
docker exec belt-control-app ln -s \
  /home/linaro/belt-control-data/models/tts_models/paddlespeech/models \
  /root/.paddlespeech/models
```

---

## 📊 推荐方案

**推荐使用方案 1（设置环境变量）**

理由：
1. ✅ 简单快速，只需修改一行配置
2. ✅ 适用于所有模型，无需逐个配置
3. ✅ 符合 PaddleSpeech 的设计理念
4. ✅ 维护成本低

---

## 🧪 测试计划

### 测试步骤

1. **修复后测试**
   - 选择 `fastspeech2_aishell3` 模型
   - 选择说话人ID 21
   - 输入测试文本："一号皮带准备启动，请注意"
   - 点击"生成测试语音"

2. **预期结果**
   - ✅ 合成成功，生成 `/tmp/test_tts.wav`
   - ✅ 日志显示：`✅ [PaddleSpeech] 合成成功`
   - ✅ 音频播放正常

3. **回归测试**
   - 测试 `fastspeech2_csmsc` 模型（确保不影响原有功能）
   - 测试其他说话人ID（0-173）

---

## 📁 相关文件

### 需要修改的文件
1. `docker/rk3588/app-entrypoint.sh` - 添加环境变量

### 参考文件
1. `docker/rk3588/tts_engines/paddlespeech/paddle_tts_service.py` - Python 服务
2. `src/control/tts/PaddleSpeechAdapter.cpp` - C++ 适配器
3. `docs/log/voip.md` - 错误日志

---

## 🚀 实施步骤

1. **修改配置文件**（5 分钟）
2. **重新构建镜像**（10 分钟）
3. **部署到设备**（5 分钟）
4. **测试验证**（5 分钟）

**总计**：约 25 分钟

---

## 📝 补充说明

### PaddleSpeech 模型查找机制

PaddleSpeech 按以下顺序查找模型：

1. **环境变量 `PADDLESPEECH_HOME`**
   - 如果设置，在 `$PADDLESPEECH_HOME/models/` 查找

2. **默认路径 `~/.paddlespeech/`**
   - 如果未设置环境变量，使用默认路径

3. **自动下载**
   - 如果本地找不到，尝试从 CDN 下载

### 模型目录结构

```
/home/linaro/belt-control-data/models/tts_models/paddlespeech/models/
├── fastspeech2_aishell3-zh/
│   └── 1.0/
│       └── fastspeech2_nosil_aishell3_ckpt_0.4/
├── fastspeech2_csmsc-zh/
│   └── 1.0/
│       └── fastspeech2_nosil_baker_ckpt_0.4/
├── hifigan_aishell3-zh/
│   └── 1.0/
│       └── hifigan_aishell3_ckpt_0.2.0/
└── pwgan_csmsc-zh/
    └── 1.0/
        └── pwg_baker_ckpt_0.4/
```

---

**文档版本**: v1.0
**最后更新**: 2026-02-26 09:40
