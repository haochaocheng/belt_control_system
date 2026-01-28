# GitLab 本地部署完整流程总结

**日期**: 2026-01-28
**目标**: 在本地部署 GitLab CE，建立 GitHub + GitLab 双重备份系统

---

## 📋 部署流程概览

### 阶段 1：环境准备
1. ✅ Docker Desktop 已安装并运行
2. ✅ 创建 GitLab 目录结构：`D:\gitlab`
3. ✅ 创建 docker-compose.yml 配置文件

### 阶段 2：GitLab 部署
1. ✅ 使用 Docker Compose 启动 GitLab
2. ✅ 等待初始化（5-10 分钟）
3. ✅ 访问 http://localhost:8080

### 阶段 3：问题诊断与解决
**遇到的主要问题**：HTTP 502 错误，GitLab 无法访问

**问题根源**：
- puma 服务同时绑定了 Unix socket 和 TCP 端口 8080
- 导致端口冲突，gitlab-workhorse 崩溃

**解决过程**：
1. 检查服务状态：`docker exec gitlab gitlab-ctl status`
2. 查看日志发现错误：`Address already in use - bind(2) for "127.0.0.1" port 8080`
3. 搜索 GitLab 官方文档和社区讨论
4. 发现关键：`external_url` 应该使用容器内部端口（80），而不是外部映射端口（8080）

**最终解决方案**：
```yaml
# docker-compose.yml
environment:
  GITLAB_OMNIBUS_CONFIG: |
    external_url 'http://gitlab.local:80'  # 容器内部使用 80
ports:
  - '8080:80'  # Docker 映射：主机 8080 → 容器 80
```

**手动修复 puma 配置**：
```bash
# 删除 TCP 绑定
docker exec gitlab bash -c "sed -i '/bind.*tcp.*8080/d' /var/opt/gitlab/gitlab-rails/etc/puma.rb"

# 重启服务
docker exec gitlab gitlab-ctl restart puma
docker exec gitlab gitlab-ctl restart gitlab-workhorse
```

### 阶段 4：首次登录配置
1. ✅ 获取初始密码：`docker exec gitlab cat /etc/gitlab/initial_root_password`
2. ✅ 登录 GitLab（用户名：root）
3. ✅ 修改密码（使用脚本或界面）

### 阶段 5：项目配置
1. ✅ 创建项目：belt-control-system
2. ✅ 配置 Git 远程仓库：`git remote add gitlab http://localhost:8080/root/belt-control-system.git`
3. ✅ 配置 Git 允许 HTTP：`git config --global credential.allowUnsafeRemotes true`
4. ✅ 推送所有分支：`git push gitlab --all`

---

## 🔧 关键配置文件

### docker-compose.yml
```yaml
version: '3.8'

services:
  gitlab:
    image: gitlab/gitlab-ce:16.11.0-ce.0
    container_name: gitlab
    restart: always
    hostname: 'gitlab.local'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://gitlab.local:80'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
        gitlab_rails['time_zone'] = 'Asia/Shanghai'

        # 日志轮转
        logging['logrotate_frequency'] = "daily"
        logging['logrotate_rotate'] = 7
        logging['logrotate_size'] = "500M"

        # 性能优化
        postgresql['max_connections'] = 200
        postgresql['shared_buffers'] = "256MB"
        redis['maxmemory'] = "512mb"
        sidekiq['concurrency'] = 10
        puma['worker_processes'] = 2

        # 禁用不需要的功能
        gitlab_rails['usage_ping_enabled'] = false
        gitlab_rails['sentry_enabled'] = false
    ports:
      - '8080:80'
      - '8443:443'
      - '2222:22'
    volumes:
      - 'D:/gitlab/config:/etc/gitlab'
      - 'D:/gitlab/data:/var/opt/gitlab'
      - 'D:/gitlab/logs:/var/log/gitlab'
    shm_size: '256m'
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G
```

---

## 🎯 核心经验教训

### 1. external_url 的正确理解
- ❌ 错误：`external_url 'http://localhost:8080'`（导致 puma 监听 8080）
- ✅ 正确：`external_url 'http://gitlab.local:80'`（puma 使用 Unix socket，nginx 监听 80）

### 2. Docker 端口映射
```
外部访问                Docker 映射              容器内部
http://localhost:8080 → 8080:80 → nginx:80 → puma (Unix socket)
```

### 3. 调试方法
1. 检查服务状态：`docker exec gitlab gitlab-ctl status`
2. 查看日志：`docker exec gitlab tail -50 /var/log/gitlab/puma/puma_stdout.log`
3. 检查配置：`docker exec gitlab cat /var/opt/gitlab/gitlab-rails/etc/puma.rb`
4. 搜索官方文档和社区讨论

### 4. 不要猜测配置
- 遇到问题时，先搜索官方文档
- 查看社区讨论中的实际案例
- 理解配置的工作原理，而不是盲目尝试

---

## 📚 参考资料

### 官方文档
- [GitLab Docker 配置](https://docs.gitlab.com/install/docker/configuration/)
- [GitLab 配置选项](https://docs.gitlab.com/omnibus/settings/configuration/)
- [GitLab Puma 配置](https://docs.gitlab.com/ee/administration/operations/puma.html)

### 关键社区讨论
- [GitLab Forum: external_url with custom port in Docker](https://forum.gitlab.com/t/whats-the-correct-value-of-external-url-with-custom-published-host-in-docker/119115)
- [GitLab Handbook: Puma configuration](https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/individual-ides/rubymine)

---

## 🛠️ 常用管理命令

### 启动/停止
```powershell
cd D:\gitlab
docker-compose up -d      # 启动
docker-compose down       # 停止
docker-compose restart    # 重启
```

### 查看状态
```powershell
docker exec gitlab gitlab-ctl status
docker-compose logs -f gitlab
```

### 管理脚本
```powershell
.\scripts\2026-01-28\06-gitlab-manager.ps1
```

---

## ⚠️ 已知问题和解决方案

### 问题：每次 reconfigure 后 puma 重新生成 TCP 绑定

**原因**：GitLab 16.11.0 的配置生成逻辑会根据 `external_url` 自动添加 TCP 绑定

**解决方案**：
```bash
docker exec gitlab bash -c "sed -i '/bind.*tcp.*8080/d' /var/opt/gitlab/gitlab-rails/etc/puma.rb && gitlab-ctl restart puma && gitlab-ctl restart gitlab-workhorse"
```

---

## ✅ 最终结果

- **GitLab 访问地址**: http://localhost:8080
- **所有服务正常运行**：nginx, puma, gitlab-workhorse, postgresql, redis, sidekiq, gitaly
- **双重备份系统建立**：GitHub（远程）+ GitLab（本地）
- **所有分支已同步**：main, feature/hardware-video-codec, dev-cpu-optimization

---

## 🎉 总结

通过搜索官方文档和社区讨论，找到了 GitLab 在 Docker 环境中的正确配置方法：
- `external_url` 控制容器内部端口
- Docker 端口映射处理外部访问
- puma 默认使用 Unix socket，不需要 TCP 绑定

**关键教训**：遇到问题时，先搜索文档，理解原理，而不是盲目猜测配置。
