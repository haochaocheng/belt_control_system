# GitLab 日常使用指南

**日期**: 2026-01-28
**目的**: 每天开关机后如何使用 GitLab

---

## 🔄 开机后的情况

### 自动启动（推荐配置）

GitLab 已配置为 `restart: always`，这意味着：

✅ **开机后自动启动** - Docker Desktop 启动后，GitLab 会自动启动
✅ **无需手动操作** - 等待 2-5 分钟即可使用
✅ **崩溃自动重启** - 如果 GitLab 崩溃，会自动重启

### 启动时间

- **首次启动**：5-10 分钟（需要初始化数据库）
- **重启**：2-5 分钟（已有数据，只需加载）
- **开机后**：2-5 分钟（Docker 启动 + GitLab 启动）

---

## 📋 每天开机后的操作

### 方案 1：什么都不做（推荐）

```
1. 开机
2. 等待 2-5 分钟
3. 访问 http://localhost:8080
4. 开始工作
```

### 方案 2：使用管理脚本

```powershell
# 运行管理脚本
cd E:\2025\3_gongkongji\belt_control_system
.\scripts\2026-01-28\06-gitlab-manager.ps1

# 选择 1 - 查看状态
# 选择 6 - 打开浏览器访问 GitLab
```

### 方案 3：手动检查

```powershell
# 查看 GitLab 状态
cd D:\gitlab
docker-compose ps

# 如果没有运行，手动启动
docker-compose up -d
```

---

## 🛠️ 常用命令

### 查看状态
```powershell
cd D:\gitlab
docker-compose ps
```

**正常状态**：
```
Name      State    Ports
gitlab    Up       0.0.0.0:8080->80/tcp, ...
```

### 启动 GitLab
```powershell
cd D:\gitlab
docker-compose up -d
```

### 停止 GitLab
```powershell
cd D:\gitlab
docker-compose down
```

### 重启 GitLab
```powershell
cd D:\gitlab
docker-compose restart
```

### 查看日志
```powershell
cd D:\gitlab
docker-compose logs -f gitlab
# 按 Ctrl+C 退出
```

### 访问 GitLab
- 浏览器访问：http://localhost:8080
- 用户名：`root`
- 密码：您设置的密码

---

## 🔍 故障排查

### 问题 1：开机后无法访问 GitLab

**检查步骤**：

1. **检查 Docker Desktop 是否运行**
   ```powershell
   docker --version
   ```
   如果报错，启动 Docker Desktop

2. **检查 GitLab 容器状态**
   ```powershell
   cd D:\gitlab
   docker-compose ps
   ```

3. **如果容器未运行，启动它**
   ```powershell
   docker-compose up -d
   ```

4. **等待 2-5 分钟后访问**
   http://localhost:8080

### 问题 2：GitLab 启动很慢

**原因**：
- 首次启动需要初始化数据库
- 电脑性能或内存不足
- 磁盘 I/O 慢

**解决**：
- 耐心等待 5-10 分钟
- 查看日志确认启动进度：
  ```powershell
  docker-compose logs -f gitlab
  ```

### 问题 3：显示 502 错误

**原因**：GitLab 还在启动中

**解决**：
- 等待 2-5 分钟
- 刷新页面
- 查看日志确认状态

### 问题 4：Docker Desktop 未启动

**解决**：
1. 点击开始菜单
2. 搜索 "Docker Desktop"
3. 启动 Docker Desktop
4. 等待 Docker 启动完成（任务栏图标变为正常）
5. GitLab 会自动启动

---

## 📊 日常工作流程

### 早上开机

```
1. 开机
2. Docker Desktop 自动启动
3. GitLab 自动启动（2-5 分钟）
4. 访问 http://localhost:8080
5. 开始工作
```

### 正常开发

```
1. 修改代码
2. git add .
3. git commit -m "描述"
4. 自动同步到 GitHub + GitLab（每小时）
```

### 晚上关机

```
1. 保存所有工作
2. 提交代码（如果有未提交的）
3. 直接关机（GitLab 会自动保存数据）
```

---

## 🎯 快速参考

### 管理脚本
```powershell
.\scripts\2026-01-28\06-gitlab-manager.ps1
```

### 访问地址
```
http://localhost:8080
```

### 登录信息
```
用户名: root
密码: 您设置的密码
```

### 仓库地址
```
http://localhost:8080/root/belt-control-system.git
```

### 常用命令
```powershell
# 查看状态
docker-compose -f D:\gitlab\docker-compose.yml ps

# 启动
docker-compose -f D:\gitlab\docker-compose.yml up -d

# 停止
docker-compose -f D:\gitlab\docker-compose.yml down

# 重启
docker-compose -f D:\gitlab\docker-compose.yml restart

# 查看日志
docker-compose -f D:\gitlab\docker-compose.yml logs -f
```

---

## ✅ 总结

### 正常情况（推荐）

**开机后**：
- ✅ Docker Desktop 自动启动
- ✅ GitLab 自动启动
- ✅ 等待 2-5 分钟
- ✅ 访问 http://localhost:8080
- ✅ 开始工作

**关机前**：
- ✅ 提交代码（如果有未提交的）
- ✅ 直接关机
- ✅ GitLab 数据自动保存

### 异常情况

**如果 GitLab 没有自动启动**：
```powershell
cd D:\gitlab
docker-compose up -d
```

**如果需要重启 GitLab**：
```powershell
cd D:\gitlab
docker-compose restart
```

**如果需要查看状态**：
```powershell
.\scripts\2026-01-28\06-gitlab-manager.ps1
```

---

**就这么简单！开机后等几分钟，GitLab 就能用了！** 🎉
