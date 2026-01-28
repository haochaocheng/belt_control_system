# GitHub + GitLab 双重备份完整部署指南

**日期**: 2026-01-28 14:45
**目标**: 部署本地 GitLab + 配置 GitHub，实现双重备份
**优势**: 网络断开时也能在本地 GitLab 提交

---

## 🎯 方案优势

### 双重保护
1. **GitHub（远程）** - 云端备份，永久保存
2. **GitLab（本地）** - 本地备份，网络断开也能用

### 工作模式
- **网络正常**：同时推送到 GitHub + GitLab
- **网络断开**：至少推送到本地 GitLab
- **完全离线**：在本地 GitLab 提交，网络恢复后同步

---

## 📋 完整部署步骤

### 阶段 1：部署本地 GitLab（10 分钟）

#### 步骤 1.1：创建目录和配置文件

```powershell
# 运行部署脚本
cd E:\2025\3_gongkongji\belt_control_system
.\scripts\2026-01-28\03-deploy-gitlab.ps1
```

**脚本会自动**：
- ✅ 创建 D:\gitlab 目录结构
- ✅ 创建 docker-compose.yml
- ✅ 启动 GitLab 容器

#### 步骤 1.2：等待 GitLab 启动

```powershell
# 查看启动日志
cd D:\gitlab
docker-compose logs -f gitlab

# 看到以下信息表示启动成功：
# gitlab_1 | gitlab Reconfigured!
```

**首次启动需要 5-10 分钟**，请耐心等待。

#### 步骤 1.3：访问 GitLab 并设置密码

1. **打开浏览器**
   - 访问：http://localhost:8080

2. **设置管理员密码**
   - 首次访问会提示设置密码
   - 密码至少 8 位
   - 建议：`Belt2026!@#`（或其他强密码）

3. **登录**
   - 用户名：`root`
   - 密码：刚才设置的密码

#### 步骤 1.4：创建项目

1. 点击 "New project"
2. 选择 "Create blank project"
3. 填写信息：
   - Project name：`belt-control-system`
   - Visibility Level：`Private`
   - **不要**勾选 "Initialize repository with a README"
4. 点击 "Create project"
5. 复制仓库地址：
   ```
   http://localhost:8080/root/belt-control-system.git
   ```

---

### 阶段 2：配置双重同步（5 分钟）

#### 步骤 2.1：添加 GitLab 远程仓库

```powershell
# 进入项目目录
cd E:\2025\3_gongkongji\belt_control_system

# 添加 GitLab 远程仓库
git remote add gitlab http://localhost:8080/root/belt-control-system.git

# 查看远程仓库列表
git remote -v
```

**应该看到**：
```
github   https://github.com/yourusername/belt-control-system.git (fetch)
github   https://github.com/yourusername/belt-control-system.git (push)
gitlab   http://localhost:8080/root/belt-control-system.git (fetch)
gitlab   http://localhost:8080/root/belt-control-system.git (push)
origin   ... (原有的远程仓库)
```

#### 步骤 2.2：首次推送到 GitLab

```powershell
# 推送当前分支到 GitLab
git push gitlab main

# 首次推送会提示输入用户名和密码：
# Username: root
# Password: 刚才设置的 GitLab 密码
```

**验证**：
- 访问 http://localhost:8080/root/belt-control-system
- 应该能看到所有代码

#### 步骤 2.3：测试双重同步

```powershell
# 运行双重同步脚本
.\scripts\2026-01-28\04-dual-sync.ps1
```

**应该看到**：
```
✅ GitLab (本地): ✅ 成功
✅ GitHub (远程): ✅ 成功
✅ 双重同步成功：GitLab + GitHub
```

---

### 阶段 3：配置自动同步（2 分钟）

#### 步骤 3.1：配置每小时自动同步

```powershell
# 创建计划任务
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File E:\2025\3_gongkongji\belt_control_system\scripts\2026-01-28\04-dual-sync.ps1"

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable

Register-ScheduledTask -TaskName "DualSync-HourlyBackup" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "每小时同步到 GitHub 和 GitLab" `
    -Force

Write-Host "✅ 已创建计划任务：每小时双重同步" -ForegroundColor Green
```

#### 步骤 3.2：验证计划任务

```powershell
# 查看任务
Get-ScheduledTask -TaskName "DualSync-HourlyBackup"

# 手动运行任务（测试）
Start-ScheduledTask -TaskName "DualSync-HourlyBackup"

# 查看日志
Get-Content dual-sync-log.txt -Tail 20
```

---

## 🔄 日常使用

### 正常开发流程

1. **修改代码**
   - 正常开发和测试

2. **提交到本地 Git**
   ```powershell
   git add .
   git commit -m "描述你的更改"
   ```

3. **自动同步**
   - 每小时自动同步到 GitHub + GitLab
   - 无需手动操作

### 手动同步

```powershell
# 双重同步（推荐）
.\scripts\2026-01-28\04-dual-sync.ps1

# 或单独同步
git push github main  # 只推送到 GitHub
git push gitlab main  # 只推送到 GitLab
```

### 网络断开时

```powershell
# 只推送到本地 GitLab
git push gitlab main

# 网络恢复后，再推送到 GitHub
git push github main
```

---

## 🔍 验证和监控

### 验证 GitLab 运行状态

```powershell
# 查看 GitLab 容器状态
cd D:\gitlab
docker-compose ps

# 应该看到：
# Name      State    Ports
# gitlab    Up       0.0.0.0:8080->80/tcp, ...
```

### 查看同步日志

```powershell
# 查看最近 20 条日志
Get-Content dual-sync-log.txt -Tail 20

# 实时查看日志
Get-Content dual-sync-log.txt -Wait
```

### 访问 GitLab Web 界面

- 访问：http://localhost:8080
- 用户名：`root`
- 密码：您设置的密码

---

## 🛠️ 常用管理命令

### GitLab 管理

```powershell
cd D:\gitlab

# 启动 GitLab
docker-compose up -d

# 停止 GitLab
docker-compose down

# 重启 GitLab
docker-compose restart

# 查看日志
docker-compose logs -f gitlab

# 查看状态
docker-compose ps
```

### 备份 GitLab

```powershell
# 创建备份
docker-compose exec gitlab gitlab-backup create

# 备份文件位置
# D:\gitlab\data\backups\
```

### 恢复 GitLab

```powershell
# 停止 GitLab
docker-compose down

# 恢复数据（替换 BACKUP_ID）
docker-compose run --rm gitlab gitlab-backup restore BACKUP=<BACKUP_ID>

# 重启 GitLab
docker-compose up -d
```

---

## 📊 方案对比

| 场景 | GitHub | GitLab | 结果 |
|------|--------|--------|------|
| 网络正常 | ✅ 推送成功 | ✅ 推送成功 | ✅ 双重备份 |
| 网络断开 | ❌ 推送失败 | ✅ 推送成功 | ✅ 本地已备份 |
| GitLab 停止 | ✅ 推送成功 | ❌ 推送失败 | ✅ 远程已备份 |
| 完全离线 | ❌ 无法推送 | ✅ 可以提交 | ✅ 本地可用 |

---

## 🎯 优势总结

### 1. 双重保护
- ✅ GitHub：云端备份，永久保存
- ✅ GitLab：本地备份，快速访问

### 2. 网络容错
- ✅ 网络正常：双重同步
- ✅ 网络断开：本地 GitLab 可用
- ✅ 网络恢复：自动同步到 GitHub

### 3. 完全离线工作
- ✅ 可以在本地 GitLab 提交
- ✅ 可以查看完整历史
- ✅ 可以创建分支和合并

### 4. 自动化
- ✅ 每小时自动同步
- ✅ 无需手动操作
- ✅ 详细日志记录

---

## 🚨 故障恢复

### 场景 1：GitLab 无法启动

```powershell
# 查看日志
cd D:\gitlab
docker-compose logs gitlab

# 重新启动
docker-compose down
docker-compose up -d
```

### 场景 2：推送失败

```powershell
# 检查 GitLab 状态
docker-compose ps

# 检查网络连接
Test-NetConnection github.com -Port 443

# 手动推送
git push gitlab main
git push github main
```

### 场景 3：本地文件损坏

```powershell
# 从 GitLab 克隆
git clone http://localhost:8080/root/belt-control-system.git

# 或从 GitHub 克隆
git clone https://github.com/yourusername/belt-control-system.git
```

---

## 📝 总结

### 部署完成后，您拥有：

1. **本地 GitLab** ✅
   - 地址：http://localhost:8080
   - 数据：D:\gitlab\data
   - 完全离线可用

2. **远程 GitHub** ✅
   - 云端备份
   - 永久保存
   - 完整历史

3. **自动同步** ✅
   - 每小时自动执行
   - 双重备份
   - 网络容错

4. **安全保证** ✅
   - 本地 + 远程双重保护
   - 网络断开也能工作
   - 完整的灾难恢复能力

---

**从此不用担心代码丢失！** 🎉

**即使网络断开，也能在本地 GitLab 正常工作！** 🚀
