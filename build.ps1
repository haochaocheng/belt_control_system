# 皮带控制系统 - 构建脚本 (PowerShell版本)
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "皮带控制系统 - 构建脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 设置Qt路径 - 请修改为你的Qt安装路径
$QT_PATH = "C:\Qt\6.5.3\mingw_64"
$QT_TOOLS_PATH = "C:\Qt\Tools"
$env:CMAKE_PREFIX_PATH = $QT_PATH

# 检查Qt是否存在
if (-not (Test-Path "$QT_PATH\bin\qmake.exe")) {
    Write-Host "错误: 找不到Qt安装路径" -ForegroundColor Red
    Write-Host "请修改 build.ps1 中的 `$QT_PATH 变量" -ForegroundColor Yellow
    Write-Host "当前设置为: $QT_PATH" -ForegroundColor Yellow
    Read-Host "按Enter键退出"
    exit 1
}

Write-Host "找到Qt路径: $QT_PATH" -ForegroundColor Green
Write-Host ""

# 查找CMake（优先使用Qt自带的CMake）
$CMAKE_EXE = $null
$cmakePaths = @(
    "$QT_TOOLS_PATH\CMake_64\bin\cmake.exe",
    "$QT_TOOLS_PATH\CMake\bin\cmake.exe",
    "C:\Program Files\CMake\bin\cmake.exe",
    "C:\Program Files (x86)\CMake\bin\cmake.exe"
)

foreach ($path in $cmakePaths) {
    if (Test-Path $path) {
        $CMAKE_EXE = $path
        Write-Host "找到CMake: $CMAKE_EXE" -ForegroundColor Green
        break
    }
}

# 如果没找到本地CMake，检查PATH中是否有
if (-not $CMAKE_EXE) {
    $cmakeInPath = Get-Command cmake -ErrorAction SilentlyContinue
    if ($cmakeInPath) {
        $CMAKE_EXE = "cmake"
        Write-Host "找到CMake (系统PATH)" -ForegroundColor Green
    } else {
        Write-Host "错误: 找不到CMake" -ForegroundColor Red
        Write-Host "请安装CMake或确保Qt Tools中包含CMake" -ForegroundColor Yellow
        Read-Host "按Enter键退出"
        exit 1
    }
}

& $CMAKE_EXE --version
Write-Host ""

# 查找Ninja或使用MinGW Makefiles
$NINJA_EXE = $null
$ninjaPath = "$QT_TOOLS_PATH\Ninja\ninja.exe"
if (Test-Path $ninjaPath) {
    $NINJA_EXE = $ninjaPath
    $GENERATOR = "Ninja"
    Write-Host "找到Ninja构建工具" -ForegroundColor Green
} else {
    $GENERATOR = "MinGW Makefiles"
    Write-Host "使用MinGW Makefiles" -ForegroundColor Yellow
}

# 添加工具到PATH
$env:Path = "$QT_PATH\bin;$env:Path"
if (Test-Path "$QT_TOOLS_PATH\mingw1120_64\bin") {
    $env:Path = "$QT_TOOLS_PATH\mingw1120_64\bin;$env:Path"
}
if (Test-Path "$QT_TOOLS_PATH\mingw_64\bin") {
    $env:Path = "$QT_TOOLS_PATH\mingw_64\bin;$env:Path"
}
if ($NINJA_EXE) {
    $env:Path = "$QT_TOOLS_PATH\Ninja;$env:Path"
}
Write-Host ""

# 创建build目录
if (-not (Test-Path "build")) {
    New-Item -ItemType Directory -Path "build" | Out-Null
}
Set-Location build

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. 配置CMake..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
& $CMAKE_EXE -G $GENERATOR -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH="$env:CMAKE_PREFIX_PATH" ..
if ($LASTEXITCODE -ne 0) {
    Write-Host "CMake配置失败" -ForegroundColor Red
    Set-Location ..
    Read-Host "按Enter键退出"
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "2. 编译项目..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
& $CMAKE_EXE --build . --config Debug
if ($LASTEXITCODE -ne 0) {
    Write-Host "编译失败" -ForegroundColor Red
    Set-Location ..
    Read-Host "按Enter键退出"
    exit 1
}

Set-Location ..

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "构建成功!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "可执行文件位置: build\bin_windows\belt_control_system.exe" -ForegroundColor Yellow
Write-Host ""
Write-Host "运行程序请执行: .\run.ps1 或 .\run.bat" -ForegroundColor Yellow
Read-Host "按Enter键退出"
