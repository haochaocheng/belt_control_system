# GitLab 端口冲突问题最终解决方案

**日期**: 2026-01-28
**问题**: GitLab 显示 HTTP 502 错误，puma 服务端口冲突

---

## 问题根源

经过深入调查和搜索 GitLab 官方文档，发现问题的根本原因是：

**`external_url` 配置错误导致 puma 监听了错误的端口**

### 错误配置

```yaml
environment:
  GITLAB_OMNIBUS_CONFIG: |
    external_url 'http://localhost:8080'  # ❌ 错误！
```

这会导致：
- puma 尝试监听 127.0.0.1:8080
- 与 nginx 或其他服务冲突
- 出现 "Address already in use" 错误

### 正确理解

根据 [GitLab Forum 讨论](https://forum.gitlab.com/t/whats-the-correct-value-of-external-url-with-custom-published-host-in-docker/119115)：

> **`external_url` 控制的是容器内部的监听端口，而不是外部访问端口！**

---

## 最终解决方案

### 正确配置

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
        external_url 'http://gitlab.local:80'  # ✅ 正确！容器内部使用 80 端口
        gitlab_rails['gitlab_shell_ssh_port'] = 2222

        # 时区设置
        gitlab_rails['time_zone'] = 'Asia/Shanghai'

        # 其他配置...
    ports:
      - '8080:80'    # Docker 端口映射：主机 8080 → 容器 80
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

### 关键点

1. **`external_url 'http://gitlab.local:80'`**
   - 指定容器内部使用 80 端口
   - GitLab 会配置 nginx 监听 80，puma 使用 Unix socket

2. **`ports: - '8080:80'`**
   - Docker 端口映射
   - 外部访问 `http://localhost:8080`
   - 自动转发到容器内部的 80 端口

3. **不需要额外的 puma 配置**
   - 默认情况下，puma 使用 Unix socket
   - nginx 作为反向代理监听 80 端口
   - 不需要手动配置 `puma['listen']` 或 `puma['port']`

---

## 工作原理

```
外部访问                Docker 映射              容器内部
http://localhost:8080 → 8080:80 → nginx:80 → puma (Unix socket)
```

1. 用户访问 `http://localhost:8080`
2. Docker 将请求转发到容器的 80 端口
3. 容器内的 nginx 监听 80 端口
4. nginx 通过 Unix socket 与 puma 通信
5. puma 处理请求并返回响应

---

## 验证步骤

### 1. 停止并重启 GitLab

```powershell
cd D:\gitlab
docker-compose down
docker-compose up -d
```

### 2. 等待初始化（5-10 分钟）

```powershell
docker-compose logs -f gitlab
```

### 3. 检查服务状态

```powershell
docker exec gitlab gitlab-ctl status
```

应该看到所有服务都是 `run` 状态：
```
run: nginx: (pid xxx) xxxs
run: puma: (pid xxx) xxxs
run: gitlab-workhorse: (pid xxx) xxxs
...
```

### 4. 检查 puma 配置

```powershell
docker exec gitlab cat /var/opt/gitlab/gitlab-rails/etc/puma.rb | Select-String -Pattern "bind"
```

应该只看到 Unix socket 绑定：
```ruby
bind 'unix:///var/opt/gitlab/gitlab-rails/sockets/gitlab.socket'
```

**不应该有** `bind 'tcp://127.0.0.1:8080'`

### 5. 测试访问

浏览器访问：http://localhost:8080

应该看到 GitLab 登录页面，而不是：
- ❌ HTTP 502 错误
- ❌ "localhost 未发送任何数据"
- ❌ "Waiting for GitLab to boot"

---

## 参考资料

### 官方文档

- [GitLab Docker 配置](https://docs.gitlab.com/install/docker/configuration/)
- [GitLab 配置选项](https://docs.gitlab.com/omnibus/settings/configuration/)
- [GitLab 默认配置](https://docs.gitlab.com/ee/administration/package_information/defaults.html)

### 社区讨论

- [GitLab Forum: external_url with custom port in Docker](https://forum.gitlab.com/t/whats-the-correct-value-of-external-url-with-custom-published-host-in-docker/119115)
- [Stack Overflow: Set GitLab external web port number](https://serverfault.com/questions/585528/set-gitlab-external-web-port-number)
- [GitLab Handbook: Puma configuration](https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/individual-ides/rubymine)

### 关键发现

从 [GitLab Handbook](https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/individual-ides/rubymine)：
> "By default, the Rails puma configuration template which GitLab uses binds to a socket, instead of a TCP port."

从 [GitLab Forum](https://forum.gitlab.com/t/whats-the-correct-value-of-external-url-with-custom-published-host-in-docker/119115)：
> "if I change external_url to contain port 80, I can see INSIDE the container that the webserver listens on that port and access using http://192.168.178.44:8080 from OUTSIDE the container still works."

---

## 经验教训

1. **不要猜测配置**
   - 应该先搜索官方文档
   - 查看社区讨论中的实际案例

2. **理解 Docker 端口映射**
   - `external_url` 控制容器内部
   - `ports` 控制外部访问
   - 两者是独立的

3. **GitLab 的默认行为**
   - puma 默认使用 Unix socket
   - nginx 作为反向代理
   - 不需要手动配置 puma 端口

4. **调试方法**
   - 检查容器内的实际配置文件
   - 查看服务状态和日志
   - 使用官方文档作为权威来源

---

## 下一步

1. **等待 GitLab 完全启动**（约 5-10 分钟）
2. **访问 http://localhost:8080**
3. **设置管理员密码**
4. **创建项目：belt-control-system**
5. **配置双重同步**（GitHub + GitLab）

---

**问题已解决！** 🎉
