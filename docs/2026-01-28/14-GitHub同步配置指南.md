# GitHub 同步配置指南

**日期**: 2026-01-28 14:00
**目的**: 安全地将本地代码同步到 GitHub，绝对不破坏本地文件
**原则**: 只推送（push），不拉取（pull），不修改本地文件

---

## 🔒 安全保证

### 核心原则
1. **只推送，不拉取** - 永远不会从 GitHub 拉取代码覆盖本地
2. **只读本地** - 脚本只读取本地文件，不修改
3. **手动确认** - 有未提交更改时会提示确认
4. **详细日志** - 所有操作都记录到日志文件

### 不会做的事情
- ❌ 不会执行 `git pull`（拉取）
- ❌ 不会执行 `git fetch`（获取）
- ❌ 不会执行 `git reset`（重置）
- ❌ 不会执行 `git checkout`（切换）
- ❌ 不会修改任何本地文件
- ❌ 不会删除任何本地文件

### 只会做的事情
- ✅ 只执行 `git push`（推送）
- ✅ 只读取本地 Git 状态
- ✅ 只添加 GitHub 远程仓库（如果不存在）
- ✅ 只记录日志

---

## 📋 前置准备

### 1. 创建 GitHub 仓库

1. **登录 GitHub**
   - 访问：https://github.com

2. **创建新仓库**
   - 点击右上角 "+" → "New repository"
   - 仓库名称：`belt-control-system`（或其他名称）
   - 可见性：Private（私有，推荐）或 Public（公开）
   - **不要**勾选 "Initialize this repository with a README"
   - 点击 "Create repository"

3. **复制仓库地址**
   - 复制 HTTPS 地址，例如：
     ```
     https://github.com/yourusername/belt-control-system.git
     ```

### 2. 创建 GitHub Personal Access Token

**为什么需要 Token？**
- GitHub 已不再支持密码认证
- Token 更安全，可以设置权限和过期时间

**创建步骤**：

1. **访问 Token 设置页面**
   - 登录 GitHub
   - 点击右上角头像 → Settings
   - 左侧菜单 → Developer settings
   - Personal access tokens → Tokens (classic)
   - 点击 "Generate new token (classic)"

2. **配置 Token**
   - Note（备注）：`Belt Control System Sync`
   - Expiration（过期时间）：`No expiration`（不过期）或选择一个时间
   - 勾选权限：
     - ✅ `repo`（完整的仓库访问权限）
       - ✅ repo:status
       - ✅ repo_deployment
       - ✅ public_repo
       - ✅ repo:invite
       - ✅ security_events

3. **生成并保存 Token**
   - 点击 "Generate token"
   - **立即复制 Token**（只显示一次！）
   - 保存到安全的地方，例如：
     ```
     ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
     ```

### 3. 配置 Git 凭据

**方法 A：使用 Windows 凭据管理器（推荐）**

```powershell
# 配置 Git 使用 Windows 凭据管理器
git config --global credential.helper wincred

# 首次推送时会提示输入：
# 用户名：你的 GitHub 用户名
# 密码：刚才生成的 Token（不是 GitHub 密码！）
```

**方法 B：使用 Git Credential Manager**

```powershell
# 下载并安装 Git Credential Manager
# https://github.com/git-ecosystem/git-credential-manager/releases

# 安装后会自动配置
```

---

## 🚀 使用步骤

### 步骤 1：修改脚本配置

打开脚本文件：`scripts\2026-01-28\01-safe-github-sync.ps1`

修改以下配置：

```powershell
# 修改这两行
$localRepo = "E:\2025\3_gongkongji\belt_control_system"  # 本地仓库路径（已正确）
$githubUrl = "https://github.com/yourusername/belt-control-system.git"  # 替换为您的 GitHub 仓库地址
```

**示例**：
```powershell
$githubUrl = "https://github.com/zhangsan/belt-control-system.git"
```

### 步骤 2：首次同步

```powershell
# 进入项目目录
cd E:\2025\3_gongkongji\belt_control_system

# 运行同步脚本
.\scripts\2026-01-28\01-safe-github-sync.ps1
```

**首次运行会提示输入凭据**：
```
Username for 'https://github.com': 你的GitHub用户名
Password for 'https://你的用户名@github.com': 粘贴Token（不是密码！）
```

**输入后会自动保存**，以后不需要再输入。

### 步骤 3：验证同步结果

1. **查看日志**
   ```powershell
   Get-Content sync-log.txt -Tail 20
   ```

2. **访问 GitHub 仓库**
   - 打开浏览器
   - 访问您的 GitHub 仓库
   - 确认代码已上传

3. **检查本地文件**
   ```powershell
   # 确认本地文件未被修改
   git status
   ```

---

## ⏰ 自动化同步

### 方案 A：每小时自动同步（推荐）

```powershell
# 创建计划任务
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File E:\2025\3_gongkongji\belt_control_system\scripts\2026-01-28\01-safe-github-sync.ps1"

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)

Register-ScheduledTask -TaskName "GitHub-HourlySync" `
    -Action $action `
    -Trigger $trigger `
    -Description "每小时同步代码到 GitHub" `
    -Force

Write-Host "✅ 已创建计划任务：每小时同步到 GitHub" -ForegroundColor Green
```

### 方案 B：每天同步

```powershell
# 创建计划任务（每天凌晨 2 点）
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-ExecutionPolicy Bypass -File E:\2025\3_gongkongji\belt_control_system\scripts\2026-01-28\01-safe-github-sync.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At "02:00"

Register-ScheduledTask -TaskName "GitHub-DailySync" `
    -Action $action `
    -Trigger $trigger `
    -Description "每天凌晨 2 点同步代码到 GitHub" `
    -Force

Write-Host "✅ 已创建计划任务：每天 02:00 同步到 GitHub" -ForegroundColor Green
```

### 查看和管理计划任务

```powershell
# 查看任务
Get-ScheduledTask | Where-Object {$_.TaskName -like "*GitHub*"}

# 手动运行任务
Start-ScheduledTask -TaskName "GitHub-HourlySync"

# 禁用任务
Disable-ScheduledTask -TaskName "GitHub-HourlySync"

# 启用任务
Enable-ScheduledTask -TaskName "GitHub-HourlySync"

# 删除任务
Unregister-ScheduledTask -TaskName "GitHub-HourlySync" -Confirm:$false
```

---

## 🔍 常见问题

### 问题 1：推送失败 - 认证失败

**错误信息**：
```
remote: Support for password authentication was removed on August 13, 2021.
fatal: Authentication failed
```

**原因**：使用了 GitHub 密码而不是 Token

**解决**：
1. 重新生成 Token（参考前面的步骤）
2. 清除旧凭据：
   ```powershell
   # 打开凭据管理器
   control /name Microsoft.CredentialManager

   # 删除 git:https://github.com 相关凭据
   ```
3. 重新运行脚本，输入 Token

### 问题 2：推送失败 - 仓库不存在

**错误信息**：
```
remote: Repository not found.
fatal: repository 'https://github.com/...' not found
```

**原因**：
- GitHub 仓库地址错误
- 仓库不存在
- 没有访问权限

**解决**：
1. 检查仓库地址是否正确
2. 确认仓库已创建
3. 确认 Token 有 `repo` 权限

### 问题 3：推送失败 - 远程有新提交

**错误信息**：
```
! [rejected]        main -> main (fetch first)
error: failed to push some refs
```

**原因**：GitHub 上有本地没有的提交

**解决**：
```powershell
# 方案 A：强制推送（谨慎使用）
git push github main --force

# 方案 B：先拉取再推送（会修改本地文件，不推荐）
# 不要使用这个方案！
```

**推荐**：如果是首次同步，使用强制推送：
```powershell
git push github main --force
```

### 问题 4：有未提交的更改

**提示信息**：
```
⚠️ 发现未提交的更改
是否继续同步？(yes/no)
```

**建议**：
1. 先提交更改：
   ```powershell
   git add .
   git commit -m "描述你的更改"
   ```
2. 然后再运行同步脚本

---

## 📊 同步策略

### 推荐策略：每小时自动同步

**优点**：
- ✅ 代码始终保持最新
- ✅ 即使本地出问题，最多丢失 1 小时的工作
- ✅ 完全自动化，无需手动操作

**配置**：
```powershell
# 运行自动化配置脚本（稍后创建）
.\scripts\2026-01-28\02-setup-auto-sync.ps1
```

### 备选策略：手动同步

**适用场景**：
- 完成一个功能后
- 下班前
- 重要修改后

**使用**：
```powershell
.\scripts\2026-01-28\01-safe-github-sync.ps1
```

---

## 🎯 完整工作流程

### 日常开发流程

1. **正常开发**
   - 修改代码
   - 测试功能

2. **提交到本地 Git**
   ```powershell
   git add .
   git commit -m "描述你的更改"
   ```

3. **自动同步到 GitHub**
   - 每小时自动执行
   - 或手动运行脚本

4. **验证同步**
   - 查看日志：`Get-Content sync-log.txt -Tail 10`
   - 访问 GitHub 确认

### 紧急恢复流程

**如果本地文件损坏**：

1. **从 GitHub 克隆**
   ```powershell
   # 备份当前目录
   Rename-Item "E:\2025\3_gongkongji\belt_control_system" "belt_control_system_backup"

   # 从 GitHub 克隆
   cd E:\2025\3_gongkongji
   git clone https://github.com/yourusername/belt-control-system.git
   ```

2. **恢复工作**
   - 代码已恢复
   - 继续开发

---

## 📝 总结

### 安全保证
- ✅ **只推送，不拉取** - 绝对不会修改本地文件
- ✅ **详细日志** - 所有操作都有记录
- ✅ **手动确认** - 有未提交更改时会提示

### 使用步骤
1. ✅ 创建 GitHub 仓库
2. ✅ 创建 Personal Access Token
3. ✅ 修改脚本配置
4. ✅ 首次手动同步
5. ✅ 配置自动同步（可选）

### 日常使用
- ✅ 正常开发和提交
- ✅ 自动同步到 GitHub（每小时）
- ✅ 偶尔查看日志确认

### 紧急恢复
- ✅ 从 GitHub 克隆代码
- ✅ 最多丢失 1 小时的工作

---

**文档版本**: 1.0
**最后更新**: 2026-01-28
**脚本位置**: `scripts\2026-01-28\01-safe-github-sync.ps1`
