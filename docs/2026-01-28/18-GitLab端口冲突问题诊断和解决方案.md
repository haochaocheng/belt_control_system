# GitLab 端口冲突问题诊断和解决方案

**日期**: 2026-01-28
**问题**: GitLab puma 服务无法启动，报错 "Address already in use - bind(2) for \"127.0.0.1\" port 8080"

---

## 问题分析

### 根本原因

GitLab 的 puma 配置中同时绑定了两个地址：
1. `bind 'unix:///var/opt/gitlab/gitlab-rails/sockets/gitlab.socket'` - Unix socket（正常）
2. `bind 'tcp://127.0.0.1:8080'` - TCP 端口（**导致冲突**）

### 为什么会有 TCP 绑定？

GitLab 的配置生成逻辑：
- 当 `external_url` 包含端口号时（如 `http://localhost:8080`），GitLab 会让 puma 直接监听该端口
- 但在 Docker 环境中，正确的做法是：
  - 容器内部：nginx 监听 80 端口，puma 只使用 Unix socket
  - 容器外部：Docker 端口映射 `8080:80`

### 尝试过的解决方案

1. **方案 1**：设置 `puma['listen'] = nil` 和 `puma['port'] = nil`
   - ❌ 失败：nil 值不会覆盖默认配置

2. **方案 2**：修改 `external_url` 为 `http://gitlab.local`（不含端口）
   - ❌ 失败：GitLab 仍然生成 8080 绑定

### 真正的问题

GitLab 的配置生成逻辑中，有多个地方会影响 puma 的端口绑定：
- `external_url` 的端口部分
- `gitlab_workhorse['auth_backend']` 默认值
- puma 的默认配置

---

## 解决方案

### 方案 A：使用 Unix Socket（推荐）

修改 `docker-compose.yml`，明确禁用 puma 的 TCP 监听：

```yaml
environment:
  GITLAB_OMNIBUS_CONFIG: |
    external_url 'http://gitlab.local'
    gitlab_rails['gitlab_shell_ssh_port'] = 2222

    # 强制 puma 只使用 Unix socket
    puma['enable'] = true
    puma['listen'] = nil
    puma['port'] = nil

    # 确保 workhorse 使用 Unix socket
    gitlab_workhorse['auth_backend'] = 'http://unix:/var/opt/gitlab/gitlab-rails/sockets/gitlab.socket'
```

### 方案 B：使用不同的端口

如果必须使用 TCP 监听，使用不同的端口：

```yaml
environment:
  GITLAB_OMNIBUS_CONFIG: |
    external_url 'http://gitlab.local'
    gitlab_rails['gitlab_shell_ssh_port'] = 2222

    # puma 监听 8081，nginx 监听 80
    puma['listen'] = '127.0.0.1'
    puma['port'] = 8081

    # workhorse 连接到 8081
    gitlab_workhorse['auth_backend'] = 'http://127.0.0.1:8081'
```

### 方案 C：完全禁用 nginx（不推荐）

让 puma 直接对外服务：

```yaml
environment:
  GITLAB_OMNIBUS_CONFIG: |
    external_url 'http://localhost:8080'

    # 禁用 nginx
    nginx['enable'] = false

    # puma 直接监听 8080
    puma['listen'] = '0.0.0.0'
    puma['port'] = 8080

ports:
  - '8080:8080'  # 直接映射 puma 端口
```

---

## 推荐配置

基于 Docker 最佳实践，推荐使用**方案 A**：

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
        external_url 'http://gitlab.local'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222

        # 时区设置
        gitlab_rails['time_zone'] = 'Asia/Shanghai'

        # Puma 配置 - 只使用 Unix socket
        puma['enable'] = true
        puma['listen'] = nil
        puma['port'] = nil
        puma['worker_processes'] = 2

        # Workhorse 使用 Unix socket 连接 puma
        gitlab_workhorse['auth_backend'] = 'http://unix:/var/opt/gitlab/gitlab-rails/sockets/gitlab.socket'

        # 日志轮转配置
        logging['logrotate_frequency'] = "daily"
        logging['logrotate_rotate'] = 7
        logging['logrotate_size'] = "500M"

        # PostgreSQL 配置
        postgresql['max_connections'] = 200
        postgresql['shared_buffers'] = "256MB"

        # Redis 配置
        redis['maxmemory'] = "512mb"
        redis['maxmemory_policy'] = "allkeys-lru"

        # 上传文件大小限制
        gitlab_rails['max_attachment_size'] = 100

        # Git 垃圾回收
        gitlab_rails['git_gc_schedule'] = "0 2 * * *"

        # 备份配置
        gitlab_rails['backup_keep_time'] = 604800

        # 性能优化
        sidekiq['concurrency'] = 10

        # 禁用不需要的功能
        gitlab_rails['usage_ping_enabled'] = false
        gitlab_rails['sentry_enabled'] = false
    ports:
      - '8080:80'    # nginx 监听 80，映射到主机 8080
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

## 应用配置

1. **停止现有容器**：
   ```powershell
   cd D:\gitlab
   docker-compose down
   ```

2. **更新 docker-compose.yml**（使用上面的推荐配置）

3. **启动容器**：
   ```powershell
   docker-compose up -d
   ```

4. **等待初始化**（5-10 分钟）：
   ```powershell
   docker-compose logs -f gitlab
   ```

5. **验证配置**：
   ```powershell
   # 检查 puma 配置
   docker exec gitlab cat /var/opt/gitlab/gitlab-rails/etc/puma.rb | Select-String -Pattern "bind"

   # 应该只看到 Unix socket 绑定：
   # bind 'unix:///var/opt/gitlab/gitlab-rails/sockets/gitlab.socket'
   ```

6. **测试访问**：
   - 浏览器访问：http://localhost:8080
   - 应该看到 GitLab 登录页面

---

## 验证成功的标志

✅ **puma 配置正确**：
```ruby
bind 'unix:///var/opt/gitlab/gitlab-rails/sockets/gitlab.socket'
# 没有 tcp://127.0.0.1:8080 这一行
```

✅ **服务状态正常**：
```
run: nginx: (pid xxx) xxxs
run: puma: (pid xxx) xxxs
```

✅ **Web 访问成功**：
- http://localhost:8080 显示 GitLab 登录页面
- 没有 502 错误
- 没有"未发送任何数据"错误

---

## 故障排查

### 如果还是看到 TCP 绑定

1. **确认环境变量**：
   ```powershell
   docker exec gitlab env | Select-String -Pattern "GITLAB_OMNIBUS_CONFIG"
   ```

2. **手动重新配置**：
   ```powershell
   docker exec gitlab gitlab-ctl reconfigure
   ```

3. **检查配置文件**：
   ```powershell
   docker exec gitlab cat /etc/gitlab/gitlab.rb | Select-String -Pattern "puma|workhorse"
   ```

### 如果 Web 服务不响应

1. **检查 nginx 日志**：
   ```powershell
   docker exec gitlab tail -50 /var/log/gitlab/nginx/gitlab_error.log
   ```

2. **检查 puma 日志**：
   ```powershell
   docker exec gitlab tail -50 /var/log/gitlab/puma/puma_stdout.log
   ```

3. **检查 workhorse 日志**：
   ```powershell
   docker exec gitlab tail -50 /var/log/gitlab/gitlab-workhorse/current
   ```

---

## 参考文档

- [GitLab Puma 配置文档](https://docs.gitlab.com/ee/administration/operations/puma.html)
- [GitLab Docker 安装指南](https://docs.gitlab.com/ee/install/docker.html)
- [GitLab Omnibus 配置](https://docs.gitlab.com/omnibus/settings/configuration.html)
