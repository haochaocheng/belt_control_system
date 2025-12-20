# Extract Qt6 Runtime Files from Docker Container
# Run this once to extract Qt6 lib, plugins, qml folders to build_rk3588
# This avoids re-extracting every build

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Extract Qt6 Runtime Files" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = "e:\2025\3_gongkongji\belt_control_system"
$BuildDir = "$ProjectRoot\build_rk3588"

# Create build directory if needed
if (-not (Test-Path $BuildDir)) {
    Write-Host "Creating build directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
    Write-Host "  Created: $BuildDir" -ForegroundColor Green
}

# Check if Qt6 files already exist
$filesExist = $true
$qtFolders = @("lib", "plugins", "qml")
foreach ($folder in $qtFolders) {
    if (-not (Test-Path "$BuildDir\$folder")) {
        $filesExist = $false
        break
    }
}

if ($filesExist) {
    Write-Host "Qt6 runtime files already exist in build_rk3588" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Folders found:" -ForegroundColor White
    foreach ($folder in $qtFolders) {
        $path = "$BuildDir\$folder"
        $count = (Get-ChildItem -Path $path -Recurse -File).Count
        Write-Host "  $folder`: $count files" -ForegroundColor Gray
    }
    Write-Host ""
    $response = Read-Host "Re-extract anyway? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "Skipping extraction" -ForegroundColor Green
        exit 0
    }
    Write-Host ""
}

# Extract Qt6 runtime files from Docker container
Write-Host "Extracting Qt6 runtime files from Docker container..." -ForegroundColor Yellow
Write-Host "  Source: belt-control-rk3588:latest" -ForegroundColor White
Write-Host "  Destination: $BuildDir" -ForegroundColor White
Write-Host "  This may take 2-3 minutes..." -ForegroundColor Gray
Write-Host ""

$startTime = Get-Date

docker run --rm `
    -v "${ProjectRoot}:/workspace" `
    -v "${ProjectRoot}/docker/rk3588/qt-host:/opt/qt-host:ro" `
    -v "${ProjectRoot}/docker/rk3588/qt-raspi:/opt/qt-raspi:ro" `
    -v "${ProjectRoot}/docker/rk3588/sysroot:/opt/sysroot:ro" `
    belt-control-rk3588:latest `
    bash -c 'cp -r /opt/qt-raspi/lib /workspace/build_rk3588/ && cp -r /opt/qt-raspi/plugins /workspace/build_rk3588/ && cp -r /opt/qt-raspi/qml /workspace/build_rk3588/ && echo "Qt6 runtime files copied successfully"'

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Failed to extract Qt6 files" -ForegroundColor Red
    exit 1
}

$elapsed = (Get-Date) - $startTime

Write-Host ""
Write-Host "Extraction complete! [$([math]::Round($elapsed.TotalSeconds, 1))s]" -ForegroundColor Green
Write-Host ""

# Show summary
Write-Host "Extracted folders:" -ForegroundColor White
foreach ($folder in $qtFolders) {
    $path = "$BuildDir\$folder"
    $count = (Get-ChildItem -Path $path -Recurse -File).Count
    $size = [math]::Round((Get-ChildItem -Path $path -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
    Write-Host "  $folder`: $count files ($size MB)" -ForegroundColor Gray
}

# Copy AUDIO folder from project root
Write-Host ""
Write-Host "Copying AUDIO folder..." -ForegroundColor Yellow
if (Test-Path "$ProjectRoot\AUDIO") {
    if (-not (Test-Path "$BuildDir\AUDIO")) {
        New-Item -ItemType Directory -Path "$BuildDir\AUDIO" | Out-Null
    }
    Copy-Item -Path "$ProjectRoot\AUDIO\*" -Destination "$BuildDir\AUDIO\" -Recurse -Force
    $audioCount = (Get-ChildItem -Path "$BuildDir\AUDIO" -Recurse -File).Count
    $audioSize = [math]::Round((Get-ChildItem -Path "$BuildDir\AUDIO" -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
    Write-Host "  AUDIO: $audioCount files ($audioSize MB)" -ForegroundColor Gray
} else {
    Write-Host "  AUDIO folder not found in project root, skipping" -ForegroundColor Gray
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Extraction Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "You can now run build-rk3588.ps1 without re-extracting these files." -ForegroundColor White
Write-Host "The build script will preserve these folders across builds." -ForegroundColor White
Write-Host ""
