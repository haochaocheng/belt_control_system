# 简单的Docker镜像导入脚本
param(
    [string]$ImageFile = "ubuntu-24.04.tar"
)

Write-Host "Docker Image Import Script" -ForegroundColor Cyan

# 检查文件是否存在
if (Test-Path $ImageFile) {
    Write-Host "Found image file: $ImageFile" -ForegroundColor Green

    # 导入镜像
    Write-Host "Importing Docker image..." -ForegroundColor Yellow
    docker load -i $ImageFile

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Image imported successfully!" -ForegroundColor Green

        # 验证镜像
        docker images ubuntu:24.04
    } else {
        Write-Host "Import failed!" -ForegroundColor Red
    }
} else {
    Write-Host @"
Image file not found: $ImageFile

Please download ubuntu:24.04 Docker image:
1. From another computer: docker pull ubuntu:24.04 && docker save -o ubuntu-24.04.tar ubuntu:24.04
2. Copy ubuntu-24.04.tar to current directory
3. Run this script again
"@ -ForegroundColor Yellow
}