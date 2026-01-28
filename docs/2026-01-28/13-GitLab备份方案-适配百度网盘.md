# GitLab 备份方案 - 适配百度网盘

**日期**: 2026-01-28 13:30
**问题**: 百度网盘实时同步不适合 Git 仓库
**解决方案**: 使用压缩包备份 + 手动上传

---

## ⚠️ 百度网盘的问题

### 实时同步的问题
1. **文件锁定** - 百度网盘会锁定文件，导致 Git 无法操作
2. **不理解分支** - 百度网盘会覆盖所有文件，破坏 Git 结构
3. **频繁同步** - Git 仓库有大量小文件，会导致百度网盘频繁同步
4. **冲突风险** - 可能导致 Git 仓库损坏

### ❌ 不要这样做
```
❌ 将 D:\gitlab 直接放在百度网盘同步文件夹
❌ 开启百度网盘实时同步 Git 仓库
❌ 让百度网盘监控 GitLab 数据目录
```

---

## ✅ 推荐方案：压缩包备份

### 核心思路
1. **定时创建压缩包** - 将 GitLab 备份打包成单个文件
2. **手动上传百度网盘** - 或使用脚本自动上传
3. **避免文件锁定** - 压缩包不会被百度网盘锁定
4. **保留多个版本** - 可以保留多个历史备份

---

## 📦 方案 A：手动压缩包备份（推荐）

### 优点
- ✅ 简单可靠
- ✅ 不会被百度网盘锁定
- ✅ 可以保留多个版本
- ✅ 适合百度网盘

### 备份脚本

```powershell
# backup-to-baidu.ps1
# 创建 GitLab 备份压缩包，手动上传到百度网盘

param(
    [string]$baiduDir = "E:\百度网盘\GitLab_Backups"  # 百度网盘同步文件夹
)

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupDir = "D:\gitlab\data\backups"
$tempDir = "D:\gitlab\temp_backup"
$logFile = "D:\gitlab\backup-log.txt"

function Write-Log {
    param([string]$message)
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage
}

Write-Log "========== 开始创建备份压缩包 =========="

# 1. 创建临时目录
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# 2. 创建 GitLab 应用备份
Write-Log "步骤 1: 创建 GitLab 应用备份..."
try {
    docker-compose -f "D:\gitlab\docker-compose.yml" exec -T gitlab gitlab-backup create
    Write-Log "✅ GitLab 应用备份创建成功"
} catch {
    Write-Log "❌ GitLab 应用备份失败：$($_.Exception.Message)"
    exit 1
}

# 3. 获取最新备份文件
$latestBackup = Get-ChildItem -Path $backupDir -Filter "*.tar" |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

if (-not $latestBackup) {
    Write-Log "❌ 未找到备份文件"
    exit 1
}

Write-Log "最新备份文件：$($latestBackup.Name)"

# 4. 复制备份文件到临时目录
Write-Log "步骤 2: 准备备份文件..."
Copy-Item -Path $latestBackup.FullName -Destination "$tempDir\gitlab_backup.tar" -Force

# 5. 复制配置文件
Write-Log "步骤 3: 复制配置文件..."
Copy-Item -Path "D:\gitlab\config" -Destination "$tempDir\config" -Recurse -Force
Copy-Item -Path "D:\gitlab\docker-compose.yml" -Destination "$tempDir\" -Force

# 6. 创建恢复说明文件
$readme = @"
# GitLab 备份恢复说明

**备份时间**: $timestamp
**备份内容**:
- gitlab_backup.tar - GitLab 应用数据备份
- config/ - GitLab 配置文件
- docker-compose.yml - Docker Compose 配置

## 恢复步骤

1. 停止 GitLab
   docker-compose -f D:\gitlab\docker-compose.yml down

2. 恢复配置文件
   Copy-Item -Path "config" -Destination "D:\gitlab\config" -Recurse -Force
   Copy-Item -Path "docker-compose.yml" -Destination "D:\gitlab\" -Force

3. 复制备份文件
   Copy-Item -Path "gitlab_backup.tar" -Destination "D:\gitlab\data\backups\" -Force

4. 启动 GitLab
   docker-compose -f D:\gitlab\docker-compose.yml up -d

5. 等待 2 分钟后恢复数据
   docker-compose -f D:\gitlab\docker-compose.yml exec -T gitlab gitlab-backup restore BACKUP=<备份ID>

6. 重启 GitLab
   docker-compose -f D:\gitlab\docker-compose.yml restart

## 备份文件信息
- 备份大小: $([math]::Round($latestBackup.Length / 1MB, 2)) MB
- 备份时间: $timestamp
"@

Set-Content -Path "$tempDir\README.md" -Value $readme -Encoding UTF8

# 7. 创建压缩包
Write-Log "步骤 4: 创建压缩包..."
$zipFile = "D:\gitlab\GitLab_Backup_$timestamp.zip"
try {
    Compress-Archive -Path "$tempDir\*" -DestinationPath $zipFile -CompressionLevel Optimal -Force
    $zipSize = [math]::Round((Get-Item $zipFile).Length / 1MB, 2)
    Write-Log "✅ 压缩包创建成功：$zipFile ($zipSize MB)"
} catch {
    Write-Log "❌ 压缩包创建失败：$($_.Exception.Message)"
    exit 1
}

# 8. 复制到百度网盘文件夹（如果存在）
if (Test-Path $baiduDir) {
    Write-Log "步骤 5: 复制到百度网盘文件夹..."
    try {
        Copy-Item -Path $zipFile -Destination $baiduDir -Force
        Write-Log "✅ 已复制到百度网盘文件夹：$baiduDir"
        Write-Log "⚠️ 请手动确认百度网盘已上传完成"
    } catch {
        Write-Log "⚠️ 复制到百度网盘失败：$($_.Exception.Message)"
    }
} else {
    Write-Log "⚠️ 百度网盘文件夹不存在：$baiduDir"
    Write-Log "   请手动将压缩包上传到百度网盘"
}

# 9. 清理临时文件
Write-Log "步骤 6: 清理临时文件..."
Remove-Item -Path $tempDir -Recurse -Force

# 10. 清理旧压缩包（保留最近 3 个）
Write-Log "步骤 7: 清理旧压缩包..."
$oldZips = Get-ChildItem -Path "D:\gitlab" -Filter "GitLab_Backup_*.zip" |
           Sort-Object LastWriteTime -Descending |
           Select-Object -Skip 3

if ($oldZips) {
    foreach ($old in $oldZips) {
        Remove-Item -Path $old.FullName -Force
        Write-Log "🗑️ 已删除旧压缩包：$($old.Name)"
    }
}

Write-Log "========== 备份完成 =========="
Write-Log "压缩包位置：$zipFile"
Write-Log "压缩包大小：$zipSize MB"
Write-Log ""

# 显示摘要
Write-Host "`n========== 备份摘要 ==========" -ForegroundColor Cyan
Write-Host "✅ 备份文件：$zipFile" -ForegroundColor Green
Write-Host "✅ 文件大小：$zipSize MB" -ForegroundColor Green
if (Test-Path $baiduDir) {
    Write-Host "✅ 已复制到百度网盘文件夹" -ForegroundColor Green
    Write-Host "⚠️ 请打开百度网盘，确认文件已上传" -ForegroundColor Yellow
} else {
    Write-Host "⚠️ 请手动上传到百度网盘" -ForegroundColor Yellow
}
Write-Host "================================" -ForegroundColor Cyan
```

### 使用方法

1. **手动备份**
   ```powershell
   # 创建备份压缩包
   .\backup-to-baidu.ps1

   # 如果百度网盘文件夹路径不同，指定路径
   .\backup-to-baidu.ps1 -baiduDir "E:\BaiduNetdisk\GitLab_Backups"
   ```

2. **自动备份**（每天凌晨 2 点）
   ```powershell
   # 创建计划任务
   $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
       -Argument "-ExecutionPolicy Bypass -File D:\gitlab\backup-to-baidu.ps1"
   $trigger = New-ScheduledTaskTrigger -Daily -At "02:00"
   Register-ScheduledTask -TaskName "GitLab-BaiduBackup" `
       -Action $action `
       -Trigger $trigger `
       -Description "每天凌晨 2 点备份 GitLab 到百度网盘" `
       -Force
   ```

3. **验证备份**
   - 打开百度网盘客户端
   - 检查 `GitLab_Backups` 文件夹
   - 确认压缩包已上传完成

---

## 📦 方案 B：使用 E 盘作为备份位置

### 如果不想使用百度网盘

```powershell
# backup-to-e-drive.ps1
# 备份到 E 盘，避免 D 盘故障

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupDir = "E:\GitLab_Backups\$timestamp"

# 创建备份目录
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

# 创建 GitLab 备份
docker-compose -f "D:\gitlab\docker-compose.yml" exec -T gitlab gitlab-backup create

# 复制备份文件
$latestBackup = Get-ChildItem -Path "D:\gitlab\data\backups" -Filter "*.tar" |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

Copy-Item -Path $latestBackup.FullName -Destination "$backupDir\" -Force

# 备份配置文件
Copy-Item -Path "D:\gitlab\config" -Destination "$backupDir\config" -Recurse -Force
Copy-Item -Path "D:\gitlab\docker-compose.yml" -Destination "$backupDir\" -Force

Write-Host "✅ 备份完成：$backupDir" -ForegroundColor Green
```

---

## 🔄 GitHub 同步方案（不受百度网盘影响）

### 方案：使用 Git Mirror 同步

这个方案完全独立于百度网盘，不会有文件锁定问题。

```powershell
# sync-to-github.ps1
# 同步 GitLab 到 GitHub（不依赖百度网盘）

$gitlabUrl = "http://localhost:8080/root/belt-control-system.git"
$githubUrl = "https://github.com/yourusername/belt-control-system.git"
$mirrorDir = "D:\gitlab\mirrors\belt-control-system"

# 创建镜像目录
if (-not (Test-Path $mirrorDir)) {
    Write-Host "首次同步，创建镜像目录..." -ForegroundColor Cyan
    git clone --mirror $gitlabUrl $mirrorDir
}

# 进入镜像目录
cd $mirrorDir

# 从 GitLab 拉取最新代码
Write-Host "从 GitLab 拉取最新代码..." -ForegroundColor Cyan
git remote update

# 推送到 GitHub
Write-Host "推送到 GitHub..." -ForegroundColor Cyan
git push --mirror $githubUrl

Write-Host "✅ 同步完成：GitLab → GitHub" -ForegroundColor Green
```

### 配置 GitHub Token

1. **创建 GitHub Personal Access Token**
   - 访问：https://github.com/settings/tokens
   - 点击 "Generate new token (classic)"
   - 勾选 `repo` 权限
   - 生成并保存 Token

2. **配置 Git 凭据**
   ```powershell
   # 配置 GitHub 凭据（只需执行一次）
   git config --global credential.helper wincred

   # 首次推送时会提示输入用户名和 Token
   # 用户名：你的 GitHub 用户名
   # 密码：刚才生成的 Token
   ```

3. **测试同步**
   ```powershell
   .\sync-to-github.ps1
   ```

---

## 📋 完整的备份策略

### 三层备份保护

1. **本地备份**（D 盘）
   - GitLab 自动备份
   - 保留 7 天

2. **异地备份**（E 盘或百度网盘）
   - 压缩包备份
   - 每天自动创建
   - 保留 3 个版本

3. **远程备份**（GitHub）
   - 每小时自动同步
   - 完整的 Git 历史
   - 永久保存

### 自动化配置

```powershell
# setup-backup-tasks.ps1
# 配置所有备份任务

# 1. 每天凌晨 2 点：创建压缩包备份
$backupAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File D:\gitlab\backup-to-baidu.ps1"
$backupTrigger = New-ScheduledTaskTrigger -Daily -At "02:00"
Register-ScheduledTask -TaskName "GitLab-DailyBackup" `
    -Action $backupAction `
    -Trigger $backupTrigger `
    -Description "每天凌晨 2 点备份 GitLab" `
    -Force

Write-Host "✅ 已创建任务：GitLab-DailyBackup（每天 02:00）" -ForegroundColor Green

# 2. 每小时：同步到 GitHub
$syncAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File D:\gitlab\sync-to-github.ps1"
$syncTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName "GitLab-HourlySync" `
    -Action $syncAction `
    -Trigger $syncTrigger `
    -Description "每小时同步 GitLab 到 GitHub" `
    -Force

Write-Host "✅ 已创建任务：GitLab-HourlySync（每小时）" -ForegroundColor Green

Write-Host "`n========== 备份任务配置完成 ==========" -ForegroundColor Cyan
Write-Host "1. 每天 02:00 - 创建压缩包备份" -ForegroundColor Yellow
Write-Host "2. 每小时 - 同步到 GitHub" -ForegroundColor Yellow
Write-Host "3. 请手动确认百度网盘上传完成" -ForegroundColor Yellow
```

---

## 🔍 恢复流程

### 从压缩包恢复

```powershell
# restore-from-zip.ps1
# 从压缩包恢复 GitLab

param(
    [Parameter(Mandatory=$true)]
    [string]$zipFile
)

Write-Host "========== 从压缩包恢复 GitLab ==========" -ForegroundColor Red
Write-Host "压缩包：$zipFile" -ForegroundColor Cyan

$confirm = Read-Host "确认继续？(yes/no)"
if ($confirm -ne "yes") {
    Write-Host "已取消恢复" -ForegroundColor Yellow
    exit 0
}

# 1. 停止 GitLab
Write-Host "`n步骤 1: 停止 GitLab..." -ForegroundColor Cyan
docker-compose -f "D:\gitlab\docker-compose.yml" down

# 2. 解压备份文件
Write-Host "`n步骤 2: 解压备份文件..." -ForegroundColor Cyan
$tempDir = "D:\gitlab\temp_restore"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force

# 3. 恢复配置文件
Write-Host "`n步骤 3: 恢复配置文件..." -ForegroundColor Cyan
Copy-Item -Path "$tempDir\config\*" -Destination "D:\gitlab\config\" -Recurse -Force
Copy-Item -Path "$tempDir\docker-compose.yml" -Destination "D:\gitlab\" -Force

# 4. 复制备份文件
Write-Host "`n步骤 4: 复制备份文件..." -ForegroundColor Cyan
Copy-Item -Path "$tempDir\gitlab_backup.tar" -Destination "D:\gitlab\data\backups\" -Force

# 5. 启动 GitLab
Write-Host "`n步骤 5: 启动 GitLab..." -ForegroundColor Cyan
docker-compose -f "D:\gitlab\docker-compose.yml" up -d

# 等待启动
Write-Host "等待 GitLab 启动（约 2 分钟）..." -ForegroundColor Yellow
Start-Sleep -Seconds 120

# 6. 恢复数据
Write-Host "`n步骤 6: 恢复数据..." -ForegroundColor Cyan
$backupId = "gitlab_backup"
docker-compose -f "D:\gitlab\docker-compose.yml" exec -T gitlab gitlab-backup restore BACKUP=$backupId

# 7. 重启 GitLab
Write-Host "`n步骤 7: 重启 GitLab..." -ForegroundColor Cyan
docker-compose -f "D:\gitlab\docker-compose.yml" restart

# 8. 清理临时文件
Remove-Item -Path $tempDir -Recurse -Force

Write-Host "`n========== 恢复完成 ==========" -ForegroundColor Green
Write-Host "请访问 http://localhost:8080 验证恢复结果" -ForegroundColor Cyan
```

---

## 📊 方案对比

| 方案 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| 压缩包 + 百度网盘 | 简单、可靠、不锁定文件 | 需要手动确认上传 | ⭐⭐⭐⭐⭐ |
| E 盘备份 | 快速、自动 | 无异地保护 | ⭐⭐⭐⭐ |
| GitHub 同步 | 完整历史、永久保存 | 需要网络 | ⭐⭐⭐⭐⭐ |

---

## 🎯 最终建议

### 推荐配置

1. **每天凌晨 2 点**
   - 创建 GitLab 备份
   - 打包成压缩包
   - 自动复制到百度网盘文件夹
   - 百度网盘自动上传

2. **每小时**
   - 同步到 GitHub
   - 保持 GitHub 最新

3. **每周检查**
   - 验证百度网盘备份
   - 测试恢复流程

### 优势

- ✅ **不会被百度网盘锁定** - 使用压缩包
- ✅ **自动化程度高** - 无需手动操作
- ✅ **三层保护** - 本地 + 百度网盘 + GitHub
- ✅ **快速恢复** - 从任何一个备份恢复
- ✅ **成本低** - 只需要百度网盘

---

**文档版本**: 1.0
**最后更新**: 2026-01-28
**适用场景**: 只有百度网盘的用户
