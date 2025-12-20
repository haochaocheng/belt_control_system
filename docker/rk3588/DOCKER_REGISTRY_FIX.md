# Docker 镜像源配置问题修复指南

## 问题描述

Docker 部署时遇到以下错误:
```
failed to do request: Head "https://docker.mirrors.ustc.edu.cn/v2/arm64v8/debian/manifests/bookworm-slim?ns=docker.io":
dialing docker.mirrors.ustc.edu.cn:443 container via direct connection:
dial tcp: lookup docker.mirrors.ustc.edu.cn: no such host
```

**原因**: Docker Desktop 配置了无效的镜像源 `docker.mirrors.ustc.edu.cn`,导致无法拉取基础镜像。

---

## 解决方案

### 方案1: 移除无效镜像源(推荐)

#### 步骤:

1. **打开 Docker Desktop**

2. **进入设置**
   - 点击右上角的 ⚙️ (设置图标)

3. **打开 Docker Engine 配置**
   - 左侧菜单选择 "Docker Engine"

4. **修改配置**
   - 找到 `"registry-mirrors"` 配置项
   - 删除或注释掉无效的镜像源

   **修改前**:
   ```json
   {
     "builder": {
       "gc": {
         "defaultKeepStorage": "20GB",
         "enabled": true
       }
     },
     "experimental": false,
     "registry-mirrors": [
       "https://docker.mirrors.ustc.edu.cn"
     ]
   }
   ```

   **修改后** (直接使用 Docker Hub):
   ```json
   {
     "builder": {
       "gc": {
         "defaultKeepStorage": "20GB",
         "enabled": true
       }
     },
     "experimental": false
   }
   ```

5. **应用并重启**
   - 点击右下角 "Apply & restart" 按钮
   - 等待 Docker Desktop 重启(约30秒)

6. **验证配置**
   ```powershell
   docker info
   ```
   检查输出中不再包含无效的镜像源

---

### 方案2: 使用其他可用镜像源(可选)

如果您需要使用镜像源加速,可以配置其他可用的源:

```json
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "experimental": false,
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1panel.live",
    "https://dockerproxy.com",
    "https://docker.nju.edu.cn"
  ]
}
```

**注意**: 这些镜像源可能需要验证可用性。

---

## 修复后的操作

完成 Docker 配置修复后,运行以下命令继续部署:

```powershell
cd e:\2025\3_gongkongji\belt_control_system\docker\rk3588
powershell -ExecutionPolicy Bypass -File full-deploy.ps1
```

---

## 部署流程说明

完整的部署流程包括5个阶段:

1. **Phase 1**: 构建 Docker 镜像
   - 准备二进制文件和库文件
   - 构建 ARM64 Docker 镜像

2. **Phase 2**: 保存镜像为文件
   - 导出镜像为 tar 文件

3. **Phase 3**: 传输到工控机
   - 通过 SCP 传输镜像文件

4. **Phase 4**: 在工控机加载镜像
   - SSH 到工控机并加载镜像

5. **Phase 5**: 启动容器
   - 停止旧容器(如果存在)
   - 启动新容器

---

## 当前部署状态

- ✅ **二进制文件编译完成**: 8.14 MB
- ✅ **依赖库收集完成**: 106个文件,52.33 MB
- ✅ **Docker 构建文件准备完成**: 60.47 MB 总计
- ⏸️ **等待修复镜像源配置**
- ⏹️ **Docker 镜像构建**: 等待配置修复后继续
- ⏹️ **传输和部署**: 等待镜像构建完成

---

## 快速修复命令

运行以下 PowerShell 脚本查看详细修复步骤:

```powershell
powershell -ExecutionPolicy Bypass -File fix-docker-registry.ps1
```

---

## 常见问题

### Q: 为什么会配置无效的镜像源?
A: 可能之前为了加速 Docker 镜像下载而配置的中国镜像源,但该镜像源已失效或网络无法访问。

### Q: 移除镜像源会影响下载速度吗?
A: 直接使用 Docker Hub 官方源,速度取决于您的网络环境。对于生产环境,推荐配置企业内部的镜像仓库。

### Q: 修改后需要重启电脑吗?
A: 不需要,只需要重启 Docker Desktop 服务即可。

### Q: 还是无法拉取镜像怎么办?
A:
1. 检查网络连接是否正常
2. 检查防火墙是否阻止 Docker
3. 尝试使用方案2中的其他镜像源
4. 如果在企业环境,咨询 IT 部门是否有代理配置

---

## 联系支持

如果修复后仍然遇到问题,请提供以下信息:

```powershell
# Docker 版本和配置
docker version
docker info

# 网络测试
ping docker.io
Test-NetConnection -ComputerName registry-1.docker.io -Port 443

# 构建日志
cd e:\2025\3_gongkongji\belt_control_system\docker\rk3588
docker build -t belt-control-rk3588:runtime docker-build
```
