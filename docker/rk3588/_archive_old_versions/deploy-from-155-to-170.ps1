# 从155设备导出镜像并部署到170设备
# 155设备上已经成功构建了镜像: belt-control:complete

$ErrorActionPreference = "Stop"

Write-Host "=== 从155导出镜像并部署到170 ===`n" -ForegroundColor Green

# 设备配置
$Device155IP = "192.168.10.155"
$Device155User = "linaro"

$Device170IP = "192.168.10.170"
$Device170User = "pi"

$ImageName = "belt-control:complete"
$LocalTarPath = "$env:TEMP\belt-control-complete.tar"

# ===== 步骤 1: 在155上导出镜像 =====
Write-Host "步骤 1/4: 在155设备上导出镜像..." -ForegroundColor Yellow
ssh "${Device155User}@${Device155IP}" "docker save $ImageName -o /tmp/belt-control.tar"

if ($LASTEXITCODE -ne 0) {
    throw "镜像导出失败"
}

# 获取镜像信息
$ImageInfo = ssh "${Device155User}@${Device155IP}" "du -h /tmp/belt-control.tar | cut -f1"
Write-Host "✓ 镜像已导出: $ImageInfo" -ForegroundColor Green
Write-Host ""

# ===== 步骤 2: 从155下载到本地 =====
Write-Host "步骤 2/4: 从155下载镜像到本地..." -ForegroundColor Yellow
Write-Host "下载路径: $LocalTarPath" -ForegroundColor Gray

scp "${Device155User}@${Device155IP}:/tmp/belt-control.tar" $LocalTarPath

if ($LASTEXITCODE -ne 0) {
    throw "镜像下载失败"
}

$LocalSizeMB = [math]::Round((Get-Item $LocalTarPath).Length / 1MB, 2)
Write-Host "✓ 下载完成: $LocalSizeMB MB" -ForegroundColor Green
Write-Host ""

# ===== 步骤 3: 上传到170设备 =====
Write-Host "步骤 3/4: 上传镜像到170设备..." -ForegroundColor Yellow

scp $LocalTarPath "${Device170User}@${Device170IP}:/tmp/belt-control.tar"

if ($LASTEXITCODE -ne 0) {
    throw "镜像上传失败"
}

Write-Host "✓ 上传完成" -ForegroundColor Green
Write-Host ""

# ===== 步骤 4: 在170上加载并测试 =====
Write-Host "步骤 4/4: 在170设备上加载并测试..." -ForegroundColor Yellow

# 加载镜像
Write-Host "加载镜像..." -ForegroundColor Gray
ssh "${Device170User}@${Device170IP}" "docker load -i /tmp/belt-control.tar"

if ($LASTEXITCODE -ne 0) {
    throw "镜像加载失败"
}

# 测试运行
Write-Host "测试运行..." -ForegroundColor Gray
$TestOutput = ssh "${Device170User}@${Device170IP}" "docker run --rm --security-opt apparmor=unconfined $ImageName --version 2>&1"

Write-Host ""
Write-Host "=== 测试输出 ===" -ForegroundColor Cyan
Write-Host $TestOutput
Write-Host ""

# 清理
Write-Host "清理临时文件..." -ForegroundColor Gray
ssh "${Device155User}@${Device155IP}" "rm -f /tmp/belt-control.tar"
ssh "${Device170User}@${Device170IP}" "rm -f /tmp/belt-control.tar"
Remove-Item -Force $LocalTarPath

Write-Host ""
Write-Host "=== 部署完成 ===`n" -ForegroundColor Green

Write-Host "后续操作:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. 在170设备上运行应用:"
Write-Host "   ssh ${Device170User}@${Device170IP}"
Write-Host "   docker run --rm --security-opt apparmor=unconfined $ImageName"
Write-Host ""
Write-Host "2. 查看镜像详情:"
Write-Host "   docker images $ImageName"
Write-Host "   docker inspect $ImageName | grep -A 10 Config"
Write-Host ""
Write-Host "3. 持久化运行:"
Write-Host "   docker run -d --name belt-control-app \\"
Write-Host "     --restart unless-stopped \\"
Write-Host "     --security-opt apparmor=unconfined \\"
Write-Host "     -v /app/config:/app/config \\"
Write-Host "     -v /app/data:/app/data \\"
Write-Host "     $ImageName"
Write-Host ""
Write-Host "4. 停止和删除容器:"
Write-Host "   docker stop belt-control-app"
Write-Host "   docker rm belt-control-app"
Write-Host ""
