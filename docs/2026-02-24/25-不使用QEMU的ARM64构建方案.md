# 不使用 QEMU 的 ARM64 镜像构建方案

**创建时间**: 2026-02-24 23:55
**目的**: 避免 QEMU 模拟，实现快速构建
**核心思路**: 在原生 ARM64 环境中构建

---

## 一、方案对比总览

| 方案 | 构建时间 | 成本 | 难度 | 推荐度 |
|------|---------|------|------|--------|
| **方案 A：设备 188 上构建** | 20-35 分钟 | 免费 | ⭐ | ⭐⭐⭐⭐⭐ |
| **方案 B：Oracle Cloud ARM（免费）** | 20-30 分钟 | 免费 | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **方案 C：Docker Buildx 远程构建** | 20-35 分钟 | 免费 | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **方案 D：GitHub Actions ARM64** | 25-40 分钟 | 免费 | ⭐⭐ | ⭐⭐⭐⭐ |
| **方案 E：AWS Graviton** | 15-25 分钟 | 付费 | ⭐⭐ | ⭐⭐⭐ |
| **方案 F：Apple Silicon Mac** | 10-20 分钟 | 一次性 | ⭐ | ⭐⭐⭐⭐⭐ |

---

## 二、方案 A：在设备 188 上构建（最简单）

### 2.1 原理

直接在 RK3588 设备上运行 Docker 构建，完全原生 ARM64 环境。

### 2.2 步骤

#### 步骤 1：上传构建文件

```powershell
# 在 Windows 上执行
# 1. 上传 Dockerfile
scp Dockerfile.ubuntu24-base linaro@192.168.10.188:/tmp/

# 2. 上传依赖文件
scp -r docker/rk3588 linaro@192.168.10.188:/tmp/
```

#### 步骤 2：在设备上构建

```bash
# SSH 到设备
ssh linaro@192.168.10.188

# 构建镜像
cd /tmp
docker build -f Dockerfile.ubuntu24-base -t belt-control-base:latest .

# 查看镜像
docker images | grep belt-control-base
```

#### 步骤 3：导出镜像

```bash
# 在设备上导出
docker save belt-control-base:latest | gzip > belt-control-base.tar.gz

# 查看大小
ls -lh belt-control-base.tar.gz
```

#### 步骤 4：下载到 Windows

```powershell
# 在 Windows 上执行
scp linaro@192.168.10.188:/tmp/belt-control-base.tar.gz .

# 导入镜像
docker load -i belt-control-base.tar.gz

# 验证
docker images | Select-String "belt-control-base"
```

### 2.3 自动化脚本

我帮您创建自动化脚本：

```powershell
# 一键在设备上构建并下载
.\scripts\2026-02-24\08-build-on-device.ps1
```

### 2.4 优势

- ✅ 完全免费
- ✅ 原生 ARM64，无 QEMU
- ✅ 构建时间：**20-35 分钟**
- ✅ 设备已有，无需额外配置
- ✅ 可以重复使用

### 2.5 劣势

- ⚠️ 需要上传文件（几 MB）
- ⚠️ 需要下载镜像（~500 MB）
- ⚠️ 占用设备资源

---

## 三、方案 B：Oracle Cloud ARM 免费实例（最推荐）

### 3.1 原理

使用 Oracle Cloud 的永久免费 ARM64 实例构建。

### 3.2 免费额度

```
Ampere A1 实例（永久免费）:
- 4 核 ARM64 CPU
- 24 GB 内存
- 200 GB 存储
- 10 TB 出站流量/月
```

### 3.3 步骤

#### 步骤 1：注册 Oracle Cloud

1. 访问：https://www.oracle.com/cloud/free/
2. 注册账号（需要信用卡验证，但不会扣费）
3. 创建 ARM64 实例

#### 步骤 2：配置实例

```bash
# SSH 到实例
ssh ubuntu@<oracle-cloud-ip>

# 安装 Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu

# 重新登录
exit
ssh ubuntu@<oracle-cloud-ip>
```

#### 步骤 3：上传并构建

```powershell
# 在 Windows 上执行
# 1. 上传文件
scp Dockerfile.ubuntu24-base ubuntu@<oracle-cloud-ip>:/home/ubuntu/
scp -r docker/rk3588 ubuntu@<oracle-cloud-ip>:/home/ubuntu/

# 2. 远程构建
ssh ubuntu@<oracle-cloud-ip> "cd /home/ubuntu && docker build -f Dockerfile.ubuntu24-base -t belt-control-base:latest ."

# 3. 导出并下载
ssh ubuntu@<oracle-cloud-ip> "docker save belt-control-base:latest | gzip > belt-control-base.tar.gz"
scp ubuntu@<oracle-cloud-ip>:/home/ubuntu/belt-control-base.tar.gz .

# 4. 导入
docker load -i belt-control-base.tar.gz
```

### 3.4 优势

- ✅ 完全免费（永久）
- ✅ 性能强（4 核 24GB）
- ✅ 构建时间：**20-30 分钟**
- ✅ 网络带宽高
- ✅ 可以 24/7 运行
- ✅ 适合 CI/CD

### 3.5 劣势

- ⚠️ 需要注册账号
- ⚠️ 需要信用卡验证
- ⚠️ 首次配置需要时间

---

## 四、方案 C：Docker Buildx 远程构建

### 4.1 原理

配置 Docker Buildx 使用远程 ARM64 设备作为构建节点。

### 4.2 步骤

#### 步骤 1：在设备上启用 Docker API

```bash
# SSH 到设备 188
ssh linaro@192.168.10.188

# 编辑 Docker 配置
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375
EOF

# 重启 Docker
sudo systemctl daemon-reload
sudo systemctl restart docker

# 验证
curl http://localhost:2375/version
```

#### 步骤 2：在 Windows 上配置 Buildx

```powershell
# 创建远程构建器
docker buildx create `
  --name remote-arm64 `
  --driver docker-container `
  --platform linux/arm64 `
  --node remote-arm64-0 `
  tcp://192.168.10.188:2375

# 使用远程构建器
docker buildx use remote-arm64

# 验证
docker buildx inspect --bootstrap
```

#### 步骤 3：构建

```powershell
# 使用远程构建器构建
docker buildx build `
  --platform linux/arm64 `
  -f Dockerfile.ubuntu24-base `
  -t belt-control-base:latest `
  --load `
  .
```

### 4.3 优势

- ✅ 在 Windows 上执行命令
- ✅ 自动使用远程 ARM64 设备
- ✅ 构建时间：**20-35 分钟**
- ✅ 无需手动上传/下载

### 4.4 劣势

- ⚠️ 配置复杂
- ⚠️ 需要开放 Docker API（安全风险）
- ⚠️ 网络依赖

---

## 五、方案 D：GitHub Actions ARM64 Runner

### 5.1 原理

使用 GitHub Actions 的 ARM64 runner 自动构建。

### 5.2 步骤

#### 步骤 1：创建 GitHub Actions 工作流

```yaml
# .github/workflows/build-arm64.yml
name: Build ARM64 Base Image

on:
  push:
    paths:
      - 'Dockerfile.ubuntu24-base'
      - 'docker/rk3588/**'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v2

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Build ARM64 image
        uses: docker/build-push-action@v4
        with:
          context: .
          file: Dockerfile.ubuntu24-base
          platforms: linux/arm64
          tags: belt-control-base:latest
          outputs: type=docker,dest=/tmp/image.tar

      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: arm64-image
          path: /tmp/image.tar
```

#### 步骤 2：下载构建好的镜像

```powershell
# 从 GitHub Actions 下载 artifact
# 然后导入
docker load -i image.tar
```

### 5.3 优势

- ✅ 完全自动化
- ✅ 免费（公开仓库）
- ✅ 构建时间：**25-40 分钟**
- ✅ 可以定时构建
- ✅ 有构建历史

### 5.4 劣势

- ⚠️ 需要 GitHub 仓库
- ⚠️ 公开仓库才免费
- ⚠️ 仍然使用 QEMU（但在云端）

---

## 六、方案 E：AWS Graviton（付费，最快）

### 6.1 原理

使用 AWS Graviton 3/4 实例构建。

### 6.2 推荐实例

```
c7g.xlarge (Graviton 3):
- 4 vCPU
- 8 GB 内存
- 价格: ~$0.14/小时 (¥1/小时)
- 构建时间: 15-25 分钟
- 单次成本: ¥0.25-0.42
```

### 6.3 步骤

```bash
# 1. 启动实例
aws ec2 run-instances --instance-type c7g.xlarge ...

# 2. SSH 连接
ssh ubuntu@<instance-ip>

# 3. 安装 Docker
curl -fsSL https://get.docker.com | sh

# 4. 构建
docker build -f Dockerfile.ubuntu24-base -t belt-control-base:latest .

# 5. 导出
docker save belt-control-base:latest | gzip > image.tar.gz

# 6. 下载
scp ubuntu@<instance-ip>:image.tar.gz .

# 7. 终止实例（停止计费）
aws ec2 terminate-instances --instance-ids <instance-id>
```

### 6.4 优势

- ✅ 性能最强
- ✅ 构建时间：**15-25 分钟**
- ✅ 网络带宽极高
- ✅ 按需使用

### 6.5 劣势

- ⚠️ 需要付费（但很便宜）
- ⚠️ 需要 AWS 账号
- ⚠️ 需要配置

---

## 七、方案 F：Apple Silicon Mac（最快）

### 7.1 原理

在 M1/M2/M3/M4 Mac 上构建，原生 ARM64。

### 7.2 步骤

```bash
# 在 Mac 上直接构建
docker build -f Dockerfile.ubuntu24-base -t belt-control-base:latest .

# 导出
docker save belt-control-base:latest | gzip > image.tar.gz

# 传输到 Windows
# 使用网络共享或 USB
```

### 7.3 优势

- ✅ 性能最强（M 系列芯片）
- ✅ 构建时间：**10-20 分钟**
- ✅ 本地构建，无网络依赖
- ✅ 可以重复使用

### 7.4 劣势

- ⚠️ 需要购买 Mac（¥5,000+）
- ⚠️ 不是每个人都有

---

## 八、推荐方案

### 8.1 立即可用（今天）

**方案 A：在设备 188 上构建**

**理由**：
- ✅ 设备已有，无需额外配置
- ✅ 完全免费
- ✅ 20-35 分钟完成
- ✅ 我已经准备好自动化脚本

**执行**：
```powershell
.\scripts\2026-02-24\08-build-on-device.ps1
```

---

### 8.2 长期方案（推荐）

**方案 B：Oracle Cloud ARM 免费实例**

**理由**：
- ✅ 永久免费
- ✅ 性能强（4 核 24GB）
- ✅ 20-30 分钟完成
- ✅ 可以用于 CI/CD
- ✅ 24/7 可用

**执行**：
1. 注册 Oracle Cloud
2. 创建 ARM64 实例
3. 配置 Docker
4. 使用自动化脚本

---

### 8.3 如果有 Mac

**方案 F：Apple Silicon Mac**

**理由**：
- ✅ 性能最强
- ✅ 10-20 分钟完成
- ✅ 本地构建

---

## 九、自动化脚本

### 9.1 在设备 188 上构建

**文件**：`scripts/2026-02-24/08-build-on-device.ps1`

**功能**：
- 自动上传文件到设备
- 自动在设备上构建
- 自动下载镜像
- 自动导入到 Windows

### 9.2 使用 Oracle Cloud

**文件**：`scripts/2026-02-24/09-build-on-oracle-cloud.ps1`

**功能**：
- 自动上传文件到云端
- 自动构建
- 自动下载镜像

---

## 十、时间和成本对比

| 方案 | 首次构建 | 后续构建 | 成本 | 总评 |
|------|---------|---------|------|------|
| **QEMU（当前）** | 120-180 分钟 | 2-5 分钟 | 免费 | ⭐⭐ |
| **设备 188** | 20-35 分钟 | 20-35 分钟 | 免费 | ⭐⭐⭐⭐⭐ |
| **Oracle Cloud** | 20-30 分钟 | 20-30 分钟 | 免费 | ⭐⭐⭐⭐⭐ |
| **AWS Graviton** | 15-25 分钟 | 15-25 分钟 | ¥0.25-0.42/次 | ⭐⭐⭐⭐ |
| **Apple Mac** | 10-20 分钟 | 10-20 分钟 | ¥5,000+ | ⭐⭐⭐⭐⭐ |

---

## 十一、总结

### 11.1 核心思路

**避免 QEMU = 在原生 ARM64 环境构建**

### 11.2 最佳选择

**今天**：
- 使用设备 188（20-35 分钟）

**长期**：
- 注册 Oracle Cloud ARM（永久免费，20-30 分钟）

### 11.3 效果

**构建时间对比**：
```
QEMU: 120-180 分钟
原生 ARM64: 20-35 分钟

节省时间: 85-145 分钟 (70-80%)
```

---

**文档版本**: v1.0
**最后更新**: 2026-02-24 23:55
**推荐**: 方案 A（设备 188）或方案 B（Oracle Cloud）
