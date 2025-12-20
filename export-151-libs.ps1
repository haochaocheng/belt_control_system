# 从设备151导出Docker镜像库文件
param(
    [string]$DeviceIP = "192.168.10.151",
    [string]$Username = "linaro",
    [string]$Password = "linaro",
    [string]$ImageName = "belt-control:v3.5-apt",
    [string]$OutputDir = "docker/rk3588/device151-libs"
)

Write-Host "正在从设备 $DeviceIP 导出Docker镜像库文件..." -ForegroundColor Green

# 创建输出目录
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# 使用docker save命令导出镜像，然后提取库文件
Write-Host "创建临时导出脚本..." -ForegroundColor Yellow
$exportScript = @"
#!/bin/bash
# 在设备上运行的导出脚本

echo "创建临时容器..."
docker create --name temp_export $ImageName /bin/true

echo "导出库文件..."
# 导出 /usr/lib/aarch64-linux-gnu 目录
docker cp temp_export:/usr/lib/aarch64-linux-gnu ./aarch64-linux-gnu-libs
# 导出 /lib/aarch64-linux-gnu 目录
docker cp temp_export:/lib/aarch64-linux-gnu ./lib-aarch64-linux-gnu
# 导出 /usr/lib 目录的重要文件
docker cp temp_export:/usr/lib/libpulse.so.0 ./libpulse.so.0 2>/dev/null || true
docker cp temp_export:/usr/lib/libSDL2-2.0.so ./libSDL2-2.0.so 2>/dev/null || true

echo "打包库文件..."
tar czf device151-libs.tar.gz aarch64-linux-gnu-libs lib-aarch64-linux-gnu *.so* 2>/dev/null

echo "清理临时容器..."
docker rm temp_export

echo "导出完成"
ls -lh device151-libs.tar.gz
"@

# 保存脚本到本地
$exportScript | Out-File -FilePath "$OutputDir\export-libs.sh" -Encoding UTF8

Write-Host "通过Docker容器执行远程命令..." -ForegroundColor Yellow

# 使用Docker容器运行sshpass
docker run --rm `
    -v "${pwd}/${OutputDir}:/workspace" `
    belt-control-rk3588:latest `
    bash -c "
        apt-get install -y sshpass openssh-client 2>/dev/null
        # 复制脚本到设备
        sshpass -p '$Password' scp -o StrictHostKeyChecking=no /workspace/export-libs.sh ${Username}@${DeviceIP}:~/
        # 在设备上执行脚本
        sshpass -p '$Password' ssh -o StrictHostKeyChecking=no ${Username}@${DeviceIP} 'chmod +x export-libs.sh && ./export-libs.sh'
        # 复制导出的文件回来
        sshpass -p '$Password' scp -o StrictHostKeyChecking=no ${Username}@${DeviceIP}:~/device151-libs.tar.gz /workspace/
        # 解压文件
        cd /workspace && tar xzf device151-libs.tar.gz
        echo '库文件导出成功'
    "

Write-Host "导出完成！库文件位于: $OutputDir" -ForegroundColor Green