# Belt Control System - Run Script
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Running Belt Control System" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set Qt path - modify this to match your Qt installation
$QT_PATH = "C:\Qt\6.5.3\mingw_64"

if (-not (Test-Path "build\bin_windows\belt_control_system.exe")) {
    Write-Host "Error: Executable not found" -ForegroundColor Red
    Write-Host "Please run build.ps1 first" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Add Qt DLLs to PATH
$env:Path = "$QT_PATH\bin;$env:Path"

# Set Qt plugin paths
$env:QT_PLUGIN_PATH = "$QT_PATH\plugins"
$env:QT_QPA_PLATFORM_PLUGIN_PATH = "$QT_PATH\plugins\platforms"

# Set QML import paths
$env:QML_IMPORT_PATH = "$PWD\src\qml;$QT_PATH\qml"
$env:QML2_IMPORT_PATH = "$PWD\src\qml;$QT_PATH\qml"

# Debug output (set to 1 to see plugin loading details)
$env:QT_DEBUG_PLUGINS = "0"

Write-Host "Starting application..." -ForegroundColor Green
Write-Host ""
& "build\bin_windows\belt_control_system.exe"

Read-Host "Press Enter to exit"
