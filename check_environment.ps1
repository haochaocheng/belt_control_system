# 环境检查脚本
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "检查Qt开发环境" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$allOk = $true

# 检查Qt
Write-Host "[1/4] 检查Qt安装..." -ForegroundColor Yellow
$QT_PATH = "C:\Qt\6.5.3\mingw_64"
if (Test-Path "$QT_PATH\bin\qmake.exe") {
    Write-Host "  ✓ Qt已安装: $QT_PATH" -ForegroundColor Green
    $qtVersion = & "$QT_PATH\bin\qmake.exe" -query QT_VERSION
    Write-Host "    版本: $qtVersion" -ForegroundColor Gray
} else {
    Write-Host "  ✗ Qt未找到: $QT_PATH" -ForegroundColor Red
    $allOk = $false
}
Write-Host ""

# 检查CMake
Write-Host "[2/4] 检查CMake..." -ForegroundColor Yellow
$QT_TOOLS_PATH = "C:\Qt\Tools"
$CMAKE_EXE = $null

if (Test-Path "$QT_TOOLS_PATH\CMake_64\bin\cmake.exe") {
    $CMAKE_EXE = "$QT_TOOLS_PATH\CMake_64\bin\cmake.exe"
} elseif (Test-Path "$QT_TOOLS_PATH\CMake\bin\cmake.exe") {
    $CMAKE_EXE = "$QT_TOOLS_PATH\CMake\bin\cmake.exe"
}

if ($CMAKE_EXE) {
    Write-Host "  ✓ CMake已安装: $CMAKE_EXE" -ForegroundColor Green
    $cmakeVersion = & $CMAKE_EXE --version | Select-Object -First 1
    Write-Host "    $cmakeVersion" -ForegroundColor Gray
} else {
    $cmakeInPath = Get-Command cmake -ErrorAction SilentlyContinue
    if ($cmakeInPath) {
        Write-Host "  ✓ CMake已安装 (系统PATH)" -ForegroundColor Green
        cmake --version | Select-Object -First 1 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    } else {
        Write-Host "  ✗ CMake未找到" -ForegroundColor Red
        $allOk = $false
    }
}
Write-Host ""

# 检查MinGW编译器
Write-Host "[3/4] 检查MinGW编译器..." -ForegroundColor Yellow
$mingwPaths = @(
    "$QT_TOOLS_PATH\mingw1120_64\bin\g++.exe",
    "$QT_TOOLS_PATH\mingw_64\bin\g++.exe",
    "$QT_PATH\..\..\..\Tools\mingw1120_64\bin\g++.exe"
)

$foundMingw = $false
foreach ($path in $mingwPaths) {
    if (Test-Path $path) {
        Write-Host "  ✓ MinGW已安装: $path" -ForegroundColor Green
        $gccVersion = & $path --version | Select-Object -First 1
        Write-Host "    $gccVersion" -ForegroundColor Gray
        $foundMingw = $true
        break
    }
}

if (-not $foundMingw) {
    Write-Host "  ✗ MinGW未找到" -ForegroundColor Red
    $allOk = $false
}
Write-Host ""

# 检查Ninja
Write-Host "[4/4] 检查Ninja构建工具..." -ForegroundColor Yellow
if (Test-Path "$QT_TOOLS_PATH\Ninja\ninja.exe") {
    Write-Host "  ✓ Ninja已安装: $QT_TOOLS_PATH\Ninja\ninja.exe" -ForegroundColor Green
    $ninjaVersion = & "$QT_TOOLS_PATH\Ninja\ninja.exe" --version
    Write-Host "    版本: $ninjaVersion" -ForegroundColor Gray
} else {
    Write-Host "  ⚠ Ninja未找到 (将使用MinGW Makefiles)" -ForegroundColor Yellow
}
Write-Host ""

# 总结
Write-Host "========================================" -ForegroundColor Cyan
if ($allOk) {
    Write-Host "环境检查完成 - 一切正常！" -ForegroundColor Green
    Write-Host ""
    Write-Host "现在可以运行以下命令开始构建:" -ForegroundColor White
    Write-Host "  .\build.ps1" -ForegroundColor Cyan
} else {
    Write-Host "环境检查完成 - 发现问题" -ForegroundColor Red
    Write-Host ""
    Write-Host "请解决上述问题后再构建项目" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Read-Host "按Enter键退出"
