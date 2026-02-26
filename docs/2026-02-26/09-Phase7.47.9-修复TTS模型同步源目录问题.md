# Phase 7.47.9 - 修复 TTS 模型同步源目录问题

**创建时间**: 2026-02-26 14:00
**问题类型**: Bug 修复
**优先级**: 高
**状态**: 📝 分析完成

---

## 📋 问题描述

PaddleSpeech TTS 合成失败，日志显示：
```
⚠️ 使用容器内模型路径（回退方案）
RuntimeError: Download from https://paddlespeech.cdn.bcebos.com/.../fastspeech2_nosil_aishell3_ckpt_0.4.zip failed
```

---

## 🔍 问题诊断

### 目录结构分析

项目中存在两个 tts_models 目录：

| 目录 | 内容 | 说明 |
|------|------|------|
| `libs/tts_models/paddlespeech/` | vits_csmsc | 不完整，缺少 models 子目录 |
| `tts_models/paddlespeech/models/` | fastspeech2_aishell3, hifigan 等 | 完整的 PaddleSpeech 模型 |

### 同步脚本配置

**文件**: `scripts/2026-02-13/02-sync-tts-models.ps1`

```powershell
$ModelsSourceDir = Join-Path $ProjectRoot "libs\tts_models"  # ❌ 错误的源目录
```

### 根本原因

同步脚本同步的是 `libs/tts_models`，但实际的 PaddleSpeech 模型在 `tts_models/` 目录下。

---

## 🔧 解决方案

### 方案 1：修改同步脚本（推荐）

修改 `scripts/2026-02-13/02-sync-tts-models.ps1`：

```powershell
# 修改前
$ModelsSourceDir = Join-Path $ProjectRoot "libs\tts_models"

# 修改后
$ModelsSourceDir = Join-Path $ProjectRoot "tts_models"
```

### 方案 2：合并目录

将 `tts_models/paddlespeech` 复制到 `libs/tts_models/paddlespeech`：

```powershell
Copy-Item -Path "tts_models\paddlespeech" -Destination "libs\tts_models\paddlespeech" -Recurse -Force
```

---

## 📁 目录内容对比

### libs/tts_models/paddlespeech/（不完整）
```
paddlespeech/
├── vits_csmsc/
│   └── vits_csmsc_ckpt_1.4.0/
└── vits_csmsc_ckpt_1.4.0/
```

### tts_models/paddlespeech/（完整）
```
paddlespeech/
├── conf/
│   └── cache.yaml
└── models/
    ├── fastspeech2_aishell3-zh/
    │   └── 1.0/
    │       ├── fastspeech2_nosil_aishell3_ckpt_0.4/
    │       └── fastspeech2_aishell3_ckpt_1.1.0/
    ├── fastspeech2_csmsc-zh/
    │   └── 1.0/
    │       └── fastspeech2_nosil_baker_ckpt_0.4/
    ├── hifigan_aishell3-zh/
    │   └── 1.0/
    │       └── hifigan_aishell3_ckpt_0.2.0/
    ├── hifigan_csmsc-zh/
    │   └── 1.0/
    │       └── hifigan_csmsc_ckpt_0.1.1/
    ├── pwgan_csmsc-zh/
    │   └── 1.0/
    │       └── pwg_baker_ckpt_0.4/
    ├── speedyspeech_csmsc-zh/
    │   └── 1.0/
    │       └── speedyspeech_csmsc_ckpt_0.2.0/
    └── G2PWModel_1.1/
```

---

## 🧪 验证步骤

1. 修改同步脚本源目录
2. 重新同步模型到设备：
   ```powershell
   .\scripts\2026-02-13\02-sync-tts-models.ps1 185 -Force
   ```
3. 重新部署应用
4. 检查启动日志，应显示：
   ```
   ✅ 检测到 linaro 用户模型路径
   ```
5. 测试 TTS 合成

---

## 📊 影响范围

- 同步脚本：`scripts/2026-02-13/02-sync-tts-models.ps1`
- 设备路径：`/home/linaro/belt-control-data/tts_models/paddlespeech/models/`

---

**文档版本**: v1.0
**最后更新**: 2026-02-26 14:00
