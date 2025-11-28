# Quick build script with proper PATH
$env:PATH = "C:\Qt\Tools\mingw1120_64\bin;C:\Qt\6.5.3\mingw_64\bin;C:\Qt\Tools\CMake_64\bin;" + $env:PATH

cd e:\2025\3_gongkongji\belt_control_system

# Remove old build
if (Test-Path build) {
    Remove-Item -Recurse -Force build
}

# Create and configure
New-Item -ItemType Directory build | Out-Null
cd build

& cmake.exe -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=C:/Qt/6.5.3/mingw_64 -DCMAKE_MAKE_PROGRAM=C:/Qt/Tools/mingw1120_64/bin/mingw32-make.exe ..

if ($LASTEXITCODE -ne 0) {
    Write-Host "Configuration failed!" -ForegroundColor Red
    exit 1
}

Write-Host "=== Configuration complete ===" -ForegroundColor Green

# Build
& cmake.exe --build . --target belt_control_system -j4

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "=== Build complete ===" -ForegroundColor Green

# Check if executable exists
if (Test-Path bin_windows\belt_control_system.exe) {
    Write-Host "Executable created successfully at bin_windows\belt_control_system.exe" -ForegroundColor Green
} else {
    Write-Host "Warning: Executable not found at expected location" -ForegroundColor Yellow
}
