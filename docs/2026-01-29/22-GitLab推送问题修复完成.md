# GitLab 推送问题修复完成

**日期**: 2026-01-29
**状态**: ✅ 已解决

---

## 🐛 问题描述

**错误信息**：
```
fatal: unable to update url base from redirection:
  asked for: http://localhost:8080/root/belt-control-system.git/info/refs?service=git-receive-pack
   redirect: http://localhost:8080/index.html
```

**用户报告**：
- GitHub 推送成功 ✅
- GitLab 推送失败 ❌
- 8080 端口和 minisipserver 冲突

---

## 🔍 根因分析

### 1. 端口冲突

**检查端口占用**：
```bash
$ netstat -ano | findstr :8080
TCP    0.0.0.0:8080           0.0.0.0:0              LISTENING       26584  # Docker
TCP    0.0.0.0:8080           0.0.0.0:0              LISTENING       74840  # minisipserver
```

**进程信息**：
- PID 26584: `com.docker.backend.exe` (Docker Desktop)
- PID 74840: `minisipserver.exe` (SIP 服务器)

**冲突原因**：
- GitLab 容器映射到 8080 端口
- minisipserver 也监听 8080 端口
- 导致 GitLab HTTP 服务无法正常工作

### 2. 认证问题

**初始密码**：`YOXpbjPILs08GPH37qgRWlusFl1JOziP+YjpYsLdCvg=`

**用户修改后的密码**：`hao0305750218`

**问题**：
- 两个密码都无法登录
- 可能是密码修改过程中出现问题
- 需要重置密码

---

## ✅ 解决方案

### 步骤 1：修改 GitLab 端口

**停止并删除旧容器**：
```bash
docker stop gitlab
docker rm gitlab
```

**创建新容器（使用 8081 端口）**：
```bash
docker run -d --name gitlab \
  --hostname localhost \
  -p 8081:80 \
  -p 8443:443 \
  -p 2222:22 \
  -v gitlab-config:/etc/gitlab \
  -v gitlab-logs:/var/log/gitlab \
  -v gitlab-data:/var/opt/gitlab \
  --restart always \
  gitlab/gitlab-ce:16.11.0-ce.0
```

**结果**：
- ✅ GitLab 现在使用 8081 端口
- ✅ 不再与 minisipserver 冲突
- ✅ 容器状态：healthy

### 步骤 2：更新 Git 远程仓库配置

**修改 GitLab URL**：
```bash
git remote set-url gitlab http://localhost:8081/root/belt-control-system.git
```

**验证配置**：
```bash
$ git remote -v
gitlab  http://localhost:8081/root/belt-control-system.git (fetch)
gitlab  http://localhost:8081/root/belt-control-system.git (push)
origin  https://github.com/haochaocheng/belt_control_system.git (fetch)
origin  https://github.com/haochaocheng/belt_control_system.git (push)
```

### 步骤 3：重置 GitLab root 密码

**创建 Ruby 脚本**（`reset_password.rb`）：
```ruby
user = User.find_by(username: 'root')
if user
  user.password = 'hao0305750218'
  user.password_confirmation = 'hao0305750218'
  user.save!
  puts 'Password reset successfully!'
else
  puts 'User not found!'
  exit 1
end
```

**执行脚本**：
```bash
cat scripts/2026-01-29/reset_password.rb | docker exec -i gitlab gitlab-rails runner -
```

**结果**：
```
Password reset successfully!
```

### 步骤 4：推送代码到 GitLab

**配置凭据存储**：
```bash
git config --global credential.helper store
```

**推送代码**：
```bash
git push gitlab feature/hardware-video-codec
```

**结果**：
```
remote: The private project root/belt-control-system was successfully created.
To http://localhost:8081/root/belt-control-system.git
 * [new branch]  feature/hardware-video-codec -> feature/hardware-video-codec
```

---

## 📊 修复后状态

### GitLab 配置

- **URL**: http://localhost:8081
- **用户名**: root
- **密码**: hao0305750218
- **仓库**: http://localhost:8081/root/belt-control-system
- **状态**: ✅ 健康运行

### Git 远程仓库

```bash
$ git remote -v
gitlab  http://localhost:8081/root/belt-control-system.git (fetch)
gitlab  http://localhost:8081/root/belt-control-system.git (push)
origin  https://github.com/haochaocheng/belt_control_system.git (fetch)
origin  https://github.com/haochaocheng/belt_control_system.git (push)
```

### 最近提交

```bash
$ git log --oneline -3
c4e38262 docs: 视频通话失败修复完成总结
e83e20c7 fix: 构建脚本自动复制 libmpp_ext.so 库
26ad314a docs: 视频通话失败根因分析 - 缺少 libmpp_ext.so 库
```

**推送状态**：
- ✅ GitHub: 已推送
- ✅ GitLab: 已推送

---

## 🔧 后续维护

### 访问 GitLab

**Web 界面**：
- URL: http://localhost:8081
- 用户名: root
- 密码: hao0305750218

### 推送代码

**推送到两个远程仓库**：
```bash
# 推送到 GitHub
git push origin feature/hardware-video-codec

# 推送到 GitLab
git push gitlab feature/hardware-video-codec
```

**或使用批量推送**：
```bash
git push origin feature/hardware-video-codec && \
git push gitlab feature/hardware-video-codec
```

### 如果再次遇到认证问题

**重置密码**：
```bash
cat scripts/2026-01-29/reset_password.rb | docker exec -i gitlab gitlab-rails runner -
```

**清除凭据缓存**：
```bash
# Windows
cmdkey /delete:LegacyGeneric:target=git:http://localhost:8081

# 或删除凭据文件
rm ~/.git-credentials
```

---

## 🎓 经验教训

### 1. 端口冲突管理

**问题**：
- 多个服务使用相同端口
- 导致服务无法正常工作

**解决**：
- 使用不同端口避免冲突
- GitLab: 8081
- minisipserver: 8080

**最佳实践**：
- 记录所有服务的端口使用情况
- 使用非标准端口避免冲突
- 在文档中明确说明端口分配

### 2. GitLab 密码管理

**问题**：
- 初始密码复杂且难以记忆
- 修改密码后可能出现问题

**解决**：
- 使用 gitlab-rails runner 重置密码
- 使用简单易记的密码（开发环境）
- 记录密码在安全的地方

**最佳实践**：
- 开发环境使用简单密码
- 生产环境使用强密码
- 定期备份 GitLab 数据

### 3. Git 凭据管理

**问题**：
- 每次推送都需要输入用户名和密码
- 凭据可能过期或失效

**解决**：
- 使用 `git config --global credential.helper store`
- 凭据存储在 `~/.git-credentials`
- 自动记住用户名和密码

**最佳实践**：
- 使用 SSH 密钥（更安全）
- 或使用 Personal Access Token
- 避免在脚本中硬编码密码

---

## 📝 相关文件

- **密码重置脚本**: [scripts/2026-01-29/reset_password.rb](../../scripts/2026-01-29/reset_password.rb)
- **GitLab 管理脚本**: [scripts/2026-01-28/06-gitlab-manager.ps1](../../scripts/2026-01-28/06-gitlab-manager.ps1)
- **批量推送脚本**: [scripts/2026-01-28/10-push-all-to-gitlab.ps1](../../scripts/2026-01-28/10-push-all-to-gitlab.ps1)

---

## 🎯 总结

**问题**：
1. GitLab 8080 端口与 minisipserver 冲突
2. GitLab 密码无法登录

**解决**：
1. ✅ 修改 GitLab 端口为 8081
2. ✅ 重置 root 密码为 hao0305750218
3. ✅ 更新 Git 远程仓库配置
4. ✅ 成功推送代码到 GitLab

**结果**：
- ✅ GitHub 和 GitLab 双重备份正常工作
- ✅ 代码已同步到两个远程仓库
- ✅ 不再有端口冲突问题

**状态**：问题已完全解决 ✅
