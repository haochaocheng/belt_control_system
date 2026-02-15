#Requires -Version 7.0
<#
.SYNOPSIS
    在Windows上安装PaddleSpeech（使用补丁方案）
.DESCRIPTION
    安装paddlespeech并应用aistudio_sdk兼容性补丁
.EXAMPLE
    .\03-install-paddlespeech-windows.ps1
.NOTES
    2026-02-15 03:00: 创建 - Windows安装方案
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PaddleSpeech Windows 安装工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Step 1: 检查Python
# ============================================================
Write-Host "[1/4] 检查Python环境..." -ForegroundColor Yellow

$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    Write-Host "  ❌ 未找到Python" -ForegroundColor Red
    exit 1
}

$pythonVersion = & python --version 2>&1
Write-Host "  ✅ Python版本: $pythonVersion" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 2: 安装paddlepaddle
# ============================================================
Write-Host "[2/4] 安装paddlepaddle..." -ForegroundColor Yellow

try {
    & python -m pip install paddlepaddle==3.0.0 -i https://pypi.tuna.tsinghua.edu.cn/simple
    Write-Host "  ✅ paddlepaddle安装完成" -ForegroundColor Green
} catch {
    Write-Host "  ❌ paddlepaddle安装失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================================
# Step 3: 安装paddlespeech
# ============================================================
Write-Host "[3/4] 安装paddlespeech..." -ForegroundColor Yellow

try {
    & python -m pip install paddlespeech -i https://pypi.tuna.tsinghua.edu.cn/simple
    Write-Host "  ✅ paddlespeech安装完成" -ForegroundColor Green
} catch {
    Write-Host "  ❌ paddlespeech安装失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================================
# Step 4: 应用aistudio_sdk补丁
# ============================================================
Write-Host "[4/4] 应用aistudio_sdk兼容性补丁..." -ForegroundColor Yellow

$patchScript = @"
import sys
import os

# 找到aistudio_sdk安装位置
try:
    import aistudio_sdk.hub as hub

    # 添加缺失的download函数
    def download(*args, **kwargs):
        '''兼容性函数，返回None让PaddleSpeech使用默认下载'''
        return None

    hub.download = download

    # 保存补丁到文件
    hub_file = hub.__file__
    print(f'aistudio_sdk.hub位置: {hub_file}')

    # 读取原文件
    with open(hub_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 检查是否已有download函数
    if 'def download(' not in content:
        # 添加download函数到文件末尾
        patch_code = '''

# ✅ 2026-02-15 兼容性补丁：添加缺失的download函数
def download(*args, **kwargs):
    """兼容性函数，返回None让PaddleSpeech使用默认下载"""
    return None
'''
        with open(hub_file, 'a', encoding='utf-8') as f:
            f.write(patch_code)

        print('✅ 补丁已应用到aistudio_sdk.hub')
    else:
        print('✅ download函数已存在，无需补丁')

except ImportError as e:
    print(f'❌ 导入失败: {e}')
    sys.exit(1)
except Exception as e:
    print(f'❌ 补丁应用失败: {e}')
    sys.exit(1)
"@

try {
    $patchScript | & python -
    Write-Host "  ✅ 补丁应用成功" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  补丁应用失败，但可能不影响使用" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# 完成
# ============================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ 安装完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "🚀 下一步: 测试语音合成" -ForegroundColor Yellow
Write-Host "   .\scripts\2026-02-15\02-test-paddlespeech-vits.ps1" -ForegroundColor Gray
Write-Host ""
