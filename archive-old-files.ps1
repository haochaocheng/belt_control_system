# 归档旧的交叉编译文件
$archiveDir = "e:/2025/3_gongkongji/belt_control_system/archive/2025-12-20-cross-compile"
New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null

Write-Host "开始归档旧文件..." -ForegroundColor Yellow

# 归档旧的构建目录
Get-ChildItem "e:/2025/3_gongkongji/belt_control_system" -Directory | Where-Object {
    $_.Name -match "^build_"
} | ForEach-Object {
    Move-Item $_.FullName $archiveDir -Force -ErrorAction SilentlyContinue
    Write-Host "  归档: $($_.Name)" -ForegroundColor Gray
}

# 归档Docker相关目录
$dockerDirs = @("rk3588", "fresh-build", "ubuntu24-fresh")
foreach ($dir in $dockerDirs) {
    $sourcePath = "e:/2025/3_gongkongji/belt_control_system/docker/$dir"
    if (Test-Path $sourcePath) {
        Move-Item $sourcePath $archiveDir -Force -ErrorAction SilentlyContinue
        Write-Host "  归档: docker/$dir" -ForegroundColor Gray
    }
}

# 归档构建脚本
$scriptPatterns = @("build-*.ps1", "copy-*.ps1", "deploy-*.ps1", "export-*.ps1")
foreach ($pattern in $scriptPatterns) {
    Get-ChildItem "e:/2025/3_gongkongji/belt_control_system" -Filter $pattern | ForEach-Object {
        Move-Item $_.FullName $archiveDir -Force -ErrorAction SilentlyContinue
        Write-Host "  归档: $($_.Name)" -ForegroundColor Gray
    }
}

Write-Host "`n✓ 归档完成！" -ForegroundColor Green
Write-Host "归档位置: $archiveDir" -ForegroundColor Cyan