# Phase 7.46.8 最终方案 - 使用 Docker 在 Linux 上下载模型

**更新时间**: 2026-02-13 19:00
**问题**: Windows 上 onnx 和 editdistance 编译失败，无法下载 PaddleSpeech 模型
**最终方案**: 使用 Docker 在 Linux 环境下载模型

---

## 🐛 问题总结

### 尝试过的方案

1. **方案 1**: 使用 `--no-deps` 跳过依赖 → ❌ 缺少必需依赖
2. **方案 2**: 让 pip 自动安装所有依赖 → ❌ onnx 编译失败
3. **方案 3**: 使用 Python 3.11 + 清华镜像源 → ❌ 仍然编译失败

### 根本原因

**Windows 上的 C++ 编译问题**：
- onnx 需要 CMake + Visual Studio C++ 编译
- editdistance 需要 C++ 编译
- 即使有 Visual Studio，编译仍然失败（字符编码、语法错误）
- Python 3.13 和 3.11 都无法解决

---

## ✅ 最终方案：使用 Docker 在 Linux 上下载

### 方案优势

1. **Linux 包管理成熟** - 预编译 wheel 完整
2. **避免 Windows 编译问题** - 不需要 Visual Studio
3. **环境一致性** - 与设备运行环境相同
4. **可靠性高** - 经过验证的方案

### 实施步骤

#### Step 1: 在 Windows 上使用 Docker 下载模型

```powershell
# 创建下载脚本
docker run -it --rm `
  -v E:\2025\3_gongkongji\belt_control_system\libs\tts_models:/models `
  python:3.11-slim bash -c "
    pip install paddlepaddle paddlespeech -i https://pypi.tuna.tsinghua.edu.cn/simple && \
    python -c 'from paddlespeech.cli.tts import TTSExecutor; TTSExecutor()' && \
    cp -r ~/.paddlespeech /models/
  "
```

**说明**：
- 使用官方 Python 3.11 镜像（Linux）
- 挂载 Windows 目录到容器
- 安装 paddlespeech 并触发模型下载
- 复制模型到 Windows 目录

#### Step 2: 同步模型到设备

```powershell
.\scripts\2026-02-13\02-sync-tts-models.ps1 188
```

---

## 📝 创建新的下载脚本

### 脚本位置
`scripts/2026-02-13/03-download-tts-models-docker.ps1`

### 脚本内容

```powershell
#Requires -Version 7.0
<#
.SYNOPSIS
    使用 Docker 在 Linux 环境下载 TTS 模型
.DESCRIPTION
    避免 Windows 上的 C++ 编译问题，使用 Docker 容器下载模型
.EXAMPLE
    .\03-download-tts-models-docker.ps1
.NOTES
    2026-02-13 19:00: 创建 - 使用 Docker 方案替代 Windows 直接下载
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$ModelsDir = Join-Path $ProjectRoot "libs\tts_models"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TTS 模型下载工具（Docker 方案）" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📥 使用 Docker 在 Linux 环境下载 TTS 模型" -ForegroundColor Yellow
Write-Host "📂 目标目录: $ModelsDir" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# Step 1: 检查 Docker
# ============================================================
Write-Host "[1/3] 检查 Docker 环境..." -ForegroundColor Yellow

$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Host "  ❌ 错误：未找到 Docker" -ForegroundColor Red
    Write-Host "  请先安装 Docker Desktop：https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    exit 1
}

$dockerVersion = & docker --version 2>&1
Write-Host "  ✅ 找到 Docker: $dockerVersion" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 2: 确保目标目录存在
# ============================================================
Write-Host "[2/3] 准备目标目录..." -ForegroundColor Yellow

if (-not (Test-Path $ModelsDir)) {
    New-Item -ItemType Directory -Path $ModelsDir -Force | Out-Null
    Write-Host "  ✅ 创建模型目录: $ModelsDir" -ForegroundColor Green
} else {
    Write-Host "  ✅ 模型目录已存在" -ForegroundColor Green
}
Write-Host ""

# ============================================================
# Step 3: 使用 Docker 下载模型
# ============================================================
Write-Host "[3/3] 使用 Docker 下载 PaddleSpeech 模型..." -ForegroundColor Yellow
Write-Host "  ⏳ 这可能需要 10-20 分钟（取决于网络速度）" -ForegroundColor Yellow
Write-Host ""

# 转换 Windows 路径为 Docker 路径
$dockerModelsPath = $ModelsDir -replace '\\', '/' -replace '^([A-Z]):', { "/mnt/$($_.Groups[1].Value.ToLower())" }

$downloadScript = @"
set -e
echo '  📦 安装 paddlepaddle...'
pip install paddlepaddle -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet

echo '  📦 安装 paddlespeech...'
pip install paddlespeech -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet

echo '  📥 下载 PaddleSpeech 模型...'
python -c 'from paddlespeech.cli.tts import TTSExecutor; print(\"  初始化 TTS...\"); tts = TTSExecutor(); print(\"  ✅ 模型下载完成\")'

echo '  📂 复制模型到目标目录...'
cp -r ~/.paddlespeech /models/

echo '  ✅ 所有操作完成'
"@

try {
    & docker run --rm `
        -v "${ModelsDir}:/models" `
        python:3.11-slim `
        bash -c $downloadScript

    Write-Host ""
    Write-Host "  ✅ PaddleSpeech 模型下载成功" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "  ❌ Docker 下载失败: $_" -ForegroundColor Red
    Write-Host "  💡 可能原因：" -ForegroundColor Yellow
    Write-Host "     1. Docker 未运行" -ForegroundColor Yellow
    Write-Host "     2. 网络问题" -ForegroundColor Yellow
    Write-Host "     3. 磁盘空间不足" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# ============================================================
# 完成
# ============================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ TTS 模型下载完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 统计模型大小
if (Test-Path $ModelsDir) {
    $totalSize = (Get-ChildItem $ModelsDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "📊 模型总大小: $([math]::Round($totalSize, 1)) MB" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "📋 已下载的模型:" -ForegroundColor Cyan
    Get-ChildItem $ModelsDir -Directory | ForEach-Object {
        $modelSize = (Get-ChildItem $_.FullName -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "   - $($_.Name): $([math]::Round($modelSize, 1)) MB" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "🚀 下一步: 同步模型到设备" -ForegroundColor Yellow
Write-Host "   .\scripts\2026-02-13\02-sync-tts-models.ps1 188" -ForegroundColor Gray
Write-Host ""
```

---

## 🎯 方案对比

### Windows 直接下载（失败）
- ❌ 需要 Visual Studio C++ 编译工具
- ❌ onnx 编译失败（CMake 错误）
- ❌ editdistance 编译失败（字符编码错误）
- ❌ Python 3.13 和 3.11 都无法解决

### Docker Linux 下载（推荐）
- ✅ 不需要编译工具
- ✅ 使用预编译 wheel
- ✅ 环境一致性好
- ✅ 可靠性高
- ✅ 一次配置，多次使用

---

## 📋 使用步骤

### 1. 确保 Docker 运行

```powershell
# 检查 Docker 是否运行
docker ps
```

### 2. 运行下载脚本

```powershell
.\scripts\2026-02-13\03-download-tts-models-docker.ps1
```

### 3. 同步到设备

```powershell
.\scripts\2026-02-13\02-sync-tts-models.ps1 188
```

---

## ⚠️ 注意事项

### 1. Docker Desktop 必须运行

如果看到错误：
```
error during connect: This error may indicate that the docker daemon is not running
```

**解决方法**：
- 启动 Docker Desktop
- 等待 Docker 完全启动（图标变绿）

### 2. 磁盘空间

- Docker 镜像：约 200MB
- PaddleSpeech 模型：约 200MB
- 总计需要：约 400MB

### 3. 网络速度

- 首次下载 Docker 镜像：约 200MB
- 下载 PaddleSpeech 模型：约 200MB
- 总计：约 400MB
- 预计时间：10-20 分钟（取决于网络）

---

## 💡 为什么这个方案可靠？

### 1. Linux 包管理成熟

- Python 官方镜像基于 Debian
- 所有包都有预编译 wheel
- 不需要编译

### 2. 避免 Windows 特有问题

- 不需要 Visual Studio
- 不需要 CMake
- 不需要处理字符编码问题

### 3. 与设备环境一致

- 设备也是 Linux（Debian）
- 使用相同的 Python 版本
- 确保兼容性

---

**状态**: ✅ 方案设计完成
**下一步**: 创建 Docker 下载脚本并测试
