# Simple script to move old files
$archiveDir = "e:/2025/3_gongkongji/belt_control_system/docker/rk3588/_archive_old_versions"
$baseDir = "e:/2025/3_gongkongji/belt_control_system/docker/rk3588"

$oldFiles = @(
    "batch-deploy.ps1",
    "deploy-all.bat",
    "deploy-from-155-to-170.ps1",
    "deploy-on-device.ps1",
    "deploy-qt6-complete.ps1",
    "deploy-reliable.ps1",
    "deploy-simple.ps1",
    "deploy-ubuntu-final.ps1",
    "deploy-ubuntu-simple.ps1",
    "deploy-ubuntu.ps1",
    "deploy.sh",
    "deploy-to-rk3588.bat",
    "full-deploy.ps1",
    "simple-deploy.ps1",
    "test-deploy.bat",
    "quick-deploy-from-local-155.ps1",
    "build-all.ps1",
    "build-docker-image.ps1",
    "build-ffmpeg-sdl-fixed.sh",
    "build-ffmpeg.sh",
    "build-local.bat",
    "build-rk3588.bat",
    "build-runtime.bat",
    "Dockerfile.complete",
    "Dockerfile.device",
    "Dockerfile.minimal",
    "Dockerfile.runtime",
    "Dockerfile.runtime.simple",
    "Dockerfile.simple",
    "docker-compose.yml",
    "base-v1.1.tar",
    "belt-control-v2.tar"
)

$moved = 0
foreach ($file in $oldFiles) {
    $src = Join-Path $baseDir $file
    if (Test-Path $src) {
        $dst = Join-Path $archiveDir $file
        Move-Item -Path $src -Destination $dst -Force
        Write-Host "Moved: $file"
        $moved++
    }
}

Write-Host ""
Write-Host "Total files moved: $moved"
