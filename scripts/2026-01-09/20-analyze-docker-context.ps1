# 检查 Docker 构建上下文大小
$contextDir = "e:\2025\3_gongkongji\belt_control_system\docker\rk3588\temp_build"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Docker 构建上下文分析" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 二进制文件
$binary = Get-Item "$contextDir\belt_control_system" -ErrorAction SilentlyContinue
if ($binary) {
    Write-Host "belt_control_system: $([math]::Round($binary.Length / 1MB, 2)) MB" -ForegroundColor White
}

# lib 目录
$libSize = (Get-ChildItem "$contextDir\lib" -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
$libCount = (Get-ChildItem "$contextDir\lib" -Recurse -File -ErrorAction SilentlyContinue).Count
Write-Host "lib/: $([math]::Round($libSize / 1MB, 2)) MB ($libCount files)" -ForegroundColor Yellow

# qt6 目录
$qt6Size = (Get-ChildItem "$contextDir\qt6" -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
$qt6Count = (Get-ChildItem "$contextDir\qt6" -Recurse -File -ErrorAction SilentlyContinue).Count
Write-Host "qt6/: $([math]::Round($qt6Size / 1MB, 2)) MB ($qt6Count files)" -ForegroundColor Yellow

# qt6 子目录
Get-ChildItem "$contextDir\qt6" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $subSize = (Get-ChildItem $_.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $subCount = (Get-ChildItem $_.FullName -Recurse -File).Count
    Write-Host "  qt6/$($_.Name): $([math]::Round($subSize / 1MB, 2)) MB ($subCount files)" -ForegroundColor Gray
}

# 总计
$totalSize = (Get-ChildItem $contextDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
$totalCount = (Get-ChildItem $contextDir -Recurse -File).Count
Write-Host ""
Write-Host "总计: $([math]::Round($totalSize / 1MB, 2)) MB ($totalCount files)" -ForegroundColor Green
Write-Host ""

# 检查是否有不必要的文件
Write-Host "检查不必要的文件..." -ForegroundColor Yellow
$largeFiles = Get-ChildItem $contextDir -Recurse -File | Where-Object { $_.Length -gt 10MB } | Sort-Object Length -Descending | Select-Object -First 10
if ($largeFiles) {
    Write-Host ""
    Write-Host "超过 10MB 的文件：" -ForegroundColor Red
    $largeFiles | ForEach-Object {
        Write-Host "  $([math]::Round($_.Length / 1MB, 2)) MB - $($_.FullName.Replace($contextDir, ''))" -ForegroundColor Gray
    }
}

Write-Host ""
