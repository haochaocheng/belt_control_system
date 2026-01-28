# GitHub 同步 - 快速开始

**5 分钟完成配置，永久保护代码**

---

## 🚀 快速开始（5 步）

### 步骤 1：创建 GitHub 仓库（2 分钟）

1. 访问：https://github.com/new
2. 仓库名称：`belt-control-system`
3. 可见性：**Private**（私有，推荐）
4. **不要**勾选任何初始化选项
5. 点击 "Create repository"
6. **复制仓库地址**（类似）：
   ```
   https://github.com/你的用户名/belt-control-system.git
   ```

### 步骤 2：创建 Token（2 分钟）

1. 访问：https://github.com/settings/tokens
2. 点击 "Generate new token (classic)"
3. Note：`Belt Control System`
4. Expiration：`No expiration`
5. 勾选：`repo`（完整仓库权限）
6. 点击 "Generate token"
7. **立即复制 Token**（只显示一次！）

### 步骤 3：修改脚本配置（30 秒）

打开文件：`scripts\2026-01-28\01-safe-github-sync.ps1`

修改第 10 行：
```powershell
$githubUrl = "https://github.com/你的用户名/belt-control-system.git"
```

**示例**：
```powershell
$githubUrl = "https://github.com/zhangsan/belt-control-system.git"
```

保存文件。

### 步骤 4：首次同步（30 秒）

```powershell
# 进入项目目录
cd E:\2025\3_gongkongji\belt_control_system

# 运行同步脚本
.\scripts\2026-01-28\01-safe-github-sync.ps1
```

**首次会提示输入**：
- Username：你的 GitHub 用户名
- Password：粘贴刚才的 Token（不是密码！）

输入后会自动保存，以后不需要再输入。

### 步骤 5：配置自动同步（30 秒）

```powershell
# 运行自动化配置脚本
.\scripts\2026-01-28\02-setup-auto-sync.ps1

# 选择 1（每小时同步）
# 输入 yes（立即测试）
```

---

## ✅ 完成！

### 现在您拥有：

1. **自动备份** ✅
   - 每小时自动同步到 GitHub
   - 无需手动操作

2. **安全保护** ✅
   - 只推送，不拉取
   - 绝对不会修改本地文件

3. **永久保存** ✅
   - GitHub 永久保存代码
   - 完整的 Git 历史

### 日常使用：

**什么都不用做！**
- 正常开发
- 正常提交
- 自动同步到 GitHub

### 验证同步：

```powershell
# 查看日志
Get-Content sync-log.txt -Tail 10

# 访问 GitHub
# 打开浏览器，访问您的仓库
```

---

## 📋 常用命令

### 手动同步
```powershell
.\scripts\2026-01-28\01-safe-github-sync.ps1
```

### 查看任务
```powershell
Get-ScheduledTask | Where-Object {$_.TaskName -like '*GitHub*'}
```

### 手动运行任务
```powershell
Start-ScheduledTask -TaskName 'GitHub-HourlySync'
```

### 查看日志
```powershell
Get-Content sync-log.txt -Tail 20
```

---

## 🔒 安全保证

### 脚本只会：
- ✅ 推送代码到 GitHub
- ✅ 读取本地 Git 状态
- ✅ 记录日志

### 脚本不会：
- ❌ 拉取代码（不会覆盖本地）
- ❌ 修改本地文件
- ❌ 删除本地文件
- ❌ 切换分支
- ❌ 重置代码

---

## 🎯 工作流程

### 日常开发
```
1. 修改代码
2. 测试功能
3. git add .
4. git commit -m "描述"
5. 自动同步到 GitHub（每小时）
```

### 紧急恢复
```
如果本地文件损坏：
1. 从 GitHub 克隆代码
2. 最多丢失 1 小时的工作
3. 继续开发
```

---

## 📞 需要帮助？

### 查看完整文档
- [GitHub 同步配置指南](../docs/2026-01-28/14-GitHub同步配置指南.md)

### 常见问题
1. **推送失败 - 认证失败**
   - 检查 Token 是否正确
   - 重新生成 Token

2. **推送失败 - 仓库不存在**
   - 检查仓库地址是否正确
   - 确认仓库已创建

3. **有未提交的更改**
   - 先提交更改：`git add . && git commit -m "描述"`
   - 然后再同步

---

**配置完成！您的代码现在受到三重保护：**
1. ✅ 本地 Git 仓库
2. ✅ GitHub 远程仓库
3. ✅ 每小时自动备份

**从此不用担心代码丢失！** 🎉
