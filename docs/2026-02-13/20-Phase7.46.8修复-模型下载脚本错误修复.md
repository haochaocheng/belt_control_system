# Phase 7.46.8 修复 - 模型下载脚本错误修复

**更新时间**: 2026-02-13 17:30
**问题**: 模型下载脚本执行失败，无法下载 PaddleSpeech 和 MeloTTS 模型

---

## 🐛 问题分析

### 错误 1: editdistance 编译失败
```
error: command 'C:\\Program Files\\Microsoft Visual Studio\\2022\\Enterprise\\VC\\Tools\\MSVC\\14.44.35207\\bin\\HostX86\\x64\\cl.exe' failed with exit code 2
```

**原因**:
- `editdistance` 是 PaddleSpeech 的可选依赖
- 需要 C++ 编译器编译
- Windows 上编译失败

**影响**:
- 阻止 PaddleSpeech 安装
- 导致模型无法下载

---

### 错误 2: melo-tts 包不存在
```
ERROR: Could not find a version that satisfies the requirement melo-tts (from versions: none)
ERROR: No matching distribution found for melo-tts
```

**原因**:
- PyPI 上不存在 `melo-tts` 包
- 可能需要从 GitHub 安装
- 包名可能不正确

**影响**:
- 脚本执行失败
- MeloTTS 无法安装

---

### 错误 3: Python 语法错误
```python
print(f'  📂 模型位置: {os.path.expanduser(\"~/.paddlespeech\")}')
                                      ^
SyntaxError: unexpected character after line continuation character
```

**原因**:
- PowerShell here-string 中的转义字符冲突
- `\"` 在 Python f-string 中被错误解析

**影响**:
- Python 脚本执行失败
- 模型下载中断

---

## ✅ 修复方案

### 修复 1: 跳过 editdistance 依赖

**位置**: `scripts/2026-02-13/01-download-tts-models.ps1` 第 110-120 行

**修改前**:
```powershell
& $pipCmd install paddlespeech --quiet
```

**修改后**:
```powershell
# ✅ 2026-02-13 17:30 [Phase 7.46.8 修复]: 跳过依赖检查，避免 editdistance 编译失败
& $pipCmd install paddlespeech --no-deps 2>&1 | Out-Host
# 手动安装核心依赖（跳过需要编译的依赖）
& $pipCmd install numpy scipy librosa soundfile tqdm colorlog yacs visualdl 2>&1 | Out-Host
```

**说明**:
- 使用 `--no-deps` 跳过自动依赖安装
- 手动安装核心依赖（不包括 editdistance）
- `editdistance` 是可选依赖，不影响 TTS 功能

---

### 修复 2: 移除 melo-tts 安装

**位置**: `scripts/2026-02-13/01-download-tts-models.ps1` 第 122-133 行

**修改前**:
```powershell
Write-Host "  📦 安装 melo-tts..." -ForegroundColor Cyan
try {
    & $pipCmd install melo-tts --quiet
    Write-Host "  ✅ melo-tts 安装完成" -ForegroundColor Green
} catch {
    Write-Host "  ❌ melo-tts 安装失败: $_" -ForegroundColor Red
    exit 1
}
```

**修改后**:
```powershell
# ❌ 2026-02-13 17:30 [Phase 7.46.8 修复]: 移除 melo-tts 安装（PyPI 上不存在此包）
# 原因：melo-tts 包名不正确或需要从 GitHub 安装
# 后续如需 MeloTTS，需要使用正确的安装方式
Write-Host "  ⚠️  跳过 MeloTTS 安装（需要从 GitHub 安装）" -ForegroundColor Yellow
```

**说明**:
- 暂时跳过 MeloTTS 安装
- 优先确保 PaddleSpeech 可用
- 后续可以从 GitHub 安装 MeloTTS

---

### 修复 3: 修复 Python 语法错误

**位置**: `scripts/2026-02-13/01-download-tts-models.ps1` 第 142-153 行

**修改前**:
```powershell
$paddleSpeechScript = @"
from paddlespeech.cli.tts import TTSExecutor
import os

print('  📥 初始化 PaddleSpeech TTS...')
tts = TTSExecutor()

print('  ✅ PaddleSpeech 模型下载完成')
print(f'  📂 模型位置: {os.path.expanduser(\"~/.paddlespeech\")}')
"@
```

**修改后**:
```powershell
# ✅ 2026-02-13 17:30 [Phase 7.46.8 修复]: 修复 Python 语法错误（转义字符问题）
$paddleSpeechScript = @"
from paddlespeech.cli.tts import TTSExecutor
import os

print('  📥 初始化 PaddleSpeech TTS...')
tts = TTSExecutor()

print('  ✅ PaddleSpeech 模型下载完成')
model_path = os.path.expanduser('~/.paddlespeech')
print(f'  📂 模型位置: {model_path}')
"@
```

**说明**:
- 使用变量存储路径，避免转义字符冲突
- 修复 f-string 语法错误
- 确保 Python 脚本可以正常执行

---

## 🧪 验证步骤

### 1. 重新运行下载脚本
```powershell
.\scripts\2026-02-13\01-download-tts-models.ps1
```

### 2. 检查模型是否下载
```powershell
# 检查 Windows 用户目录
ls $env:USERPROFILE\.paddlespeech

# 检查项目目录
ls E:\2025\3_gongkongji\belt_control_system\libs\tts_models\paddlespeech
```

### 3. 验证模型文件
```powershell
# 统计模型大小
$modelSize = (Get-ChildItem E:\2025\3_gongkongji\belt_control_system\libs\tts_models\paddlespeech -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "PaddleSpeech 模型大小: $([math]::Round($modelSize, 1)) MB"
```

**预期结果**:
- PaddleSpeech 模型约 200MB
- 包含 `tts/fastspeech2_csmsc/` 等目录
- 包含 `model.pdparams` 等模型文件

---

## 📋 修改文件清单

### 修改文件
1. `scripts/2026-02-13/01-download-tts-models.ps1` - 修复三个错误

### 新建文件
1. `docs/2026-02-13/20-Phase7.46.8修复-模型下载脚本错误修复.md` - 本文档

---

## 🔍 后续工作

### 1. MeloTTS 安装（可选）
如果需要 MeloTTS，可以尝试：
```powershell
# 方案 1: 从 GitHub 安装
pip install git+https://github.com/myshell-ai/MeloTTS.git

# 方案 2: 使用其他 TTS 引擎
# 暂时只使用 PaddleSpeech
```

### 2. 验证 PaddleSpeech 功能
```python
from paddlespeech.cli.tts import TTSExecutor

tts = TTSExecutor()
tts(text="你好，世界", output="test.wav")
```

### 3. 同步模型到设备
```powershell
.\scripts\2026-02-13\02-sync-tts-models.ps1 188
```

---

## ⚠️ 注意事项

### 1. editdistance 依赖
- `editdistance` 是 PaddleSpeech 的可选依赖
- 用于文本相似度计算
- 不影响 TTS 核心功能
- 如果需要，可以手动安装预编译的 wheel

### 2. MeloTTS 可用性
- PyPI 上可能没有 `melo-tts` 包
- 需要从 GitHub 安装
- 或者使用其他 TTS 引擎

### 3. 模型下载时间
- PaddleSpeech 模型约 200MB
- 首次下载可能需要几分钟
- 取决于网络速度

---

**状态**: ✅ 错误修复完成
**下一步**: 重新运行下载脚本，验证 PaddleSpeech 模型是否成功下载
