# RK3588 Docker 部署 - 当前可用文件说明

## 目录已整理完成!

过时的文件已移动到 `_archive_old_versions/` 目录。

---

## ✅ 当前推荐使用的文件

### 1️⃣ 交叉编译环境 (Windows上构建ARM64)

#### Dockerfile 和配置
- **`Dockerfile`** - 交叉编译环境镜像 (Ubuntu 22.04 + 交叉编译工具链)
- **`entrypoint.sh`** - Docker容器入口脚本
- **`toolchain-rk3588.cmake`** - CMake交叉编译工具链配置

#### 使用方式
```bash
# 首次构建交叉编译环境镜像(5-10分钟)
cd docker/rk3588
docker build -t belt-control-rk3588:latest .

# 之后每次交叉编译(3-5分钟)
cd ../../
.\build-rk3588.ps1
```

---

### 2️⃣ 基础运行时镜像 (设备上使用)

这些Dockerfile用于在155/170设备上构建应用运行时镜像:

- **`Dockerfile.base-trixie-noglib`** ⭐推荐⭐
  - Debian Trixie (GLIBC 2.41)
  - 不包含系统GLib,使用bundled GLib 2.80
  - 解决GLib版本兼容问题
  - **155和170设备通用**

- **`Dockerfile.base-ubuntu20`**
  - Ubuntu 20.04 (GLIBC 2.31)
  - 较老的GLib,兼容性好
  - 备选方案

- **`Dockerfile.base-debian11`**
  - Debian 11 Bullseye
  - 匹配Qt6编译环境
  - 备选方案

- **`Dockerfile.base-prebuilt`**
  - 预构建的基础镜像
  - 用于快速测试

---

### 3️⃣ 部署脚本

#### Windows -> 设备部署
- **`deploy-local-to-155.ps1`** ⭐推荐⭐
  - 最新的部署脚本
  - 从Windows本地部署到155设备
  - 使用Trixie+GLib方案

- **`quick-deploy-from-local.ps1`**
  - 快速部署脚本
  - 适用于快速测试

#### V3.3 新脚本 (带屏幕旋转修复)
- **`build_and_deploy_v3.3.ps1`**
  - Windows上交叉编译 + 部署v3.3
  - 包含自动屏幕旋转修复

- **`build_on_device_v3.3.sh`**
  - 设备上本地编译v3.3
  - 需要先上传源代码

---

### 4️⃣ 预编译资源 (必需!)

这些目录包含Qt6和系统库,**交叉编译必需**:

- **`qt-raspi/`** - Qt6 ARM64交叉编译版本 (~75MB压缩包已解压)
- **`qt-host/`** - Qt6主机工具 (~65MB压缩包已解压)
- **`sysroot/`** - RK3588 sysroot + 系统库
- **`rk3588-libs/`** - RK3588特定库

**不要删除这些目录!** 它们是交叉编译的核心依赖。

---

### 5️⃣ 项目根目录脚本

- **`build-rk3588.ps1`** (项目根目录)
  - ⭐推荐使用⭐
  - 一键交叉编译ARM64版本
  - 自动检测Docker镜像
  - 包含v3.3旋转修复

---

### 6️⃣ 文档

- **`DOCKER_DEPLOYMENT_GUIDE.md`** - Docker部署完整指南
- **`DOCKER_DEPLOYMENT_STATUS.md`** - 当前部署状态和历史
- **`DEPENDENCIES.md`** - 依赖库说明
- **`VERSION_INFO.md`** - 版本信息
- **`README.md`** - 原始README
- **`QUICK_REFERENCE.md`** - 快速参考

---

## 📋 完整工作流程

### 方案A: 推荐流程 (Docker交叉编译)

```powershell
# 1. 首次构建交叉编译环境 (仅需一次,5-10分钟)
cd e:/2025/3_gongkongji/belt_control_system/docker/rk3588
docker build -t belt-control-rk3588:latest .

# 2. 修改代码后,交叉编译 (每次3-5分钟)
cd e:/2025/3_gongkongji/belt_control_system
.\build-rk3588.ps1

# 3. 部署到155设备
cd docker/rk3588
.\deploy-local-to-155.ps1

# 4. SSH到设备运行
ssh linaro@192.168.10.155
cd /home/linaro/belt-control-qt6
./run-v3.3.sh
```

### 方案B: 设备本地编译 (不推荐,慢)

```bash
# 1. 上传源代码到设备
scp -r e:/2025/3_gongkongji/belt_control_system linaro@192.168.10.155:/home/linaro/belt-control-source

# 2. SSH到设备本地编译
ssh linaro@192.168.10.155
bash /home/linaro/build_on_device_v3.3.sh
```

---

## 🗑️ 归档文件

所有过时的文件已移动到:
```
_archive_old_versions/
```

包括:
- 旧的部署脚本 (32个文件)
- 过时的Dockerfile
- 旧的tar包
- 过时的文档

**如果需要恢复某个文件,可以从归档目录复制回来。**

---

## ⚠️ 重要说明

1. **Qt6目录不要删除** - qt-raspi/, qt-host/, sysroot/, rk3588-libs/ 是交叉编译的核心依赖

2. **GLib兼容性方案** - 使用Dockerfile.base-trixie-noglib + bundled GLib 2.80 + LD_PRELOAD

3. **V3.3新特性** - 自动检测800x1280屏幕,应用270°旋转修正

4. **155和170通用** - 使用相同的Docker镜像和部署方式

---

## 📞 需要帮助?

查看文档:
- `DOCKER_DEPLOYMENT_GUIDE.md` - 完整部署指南
- `DOCKER_DEPLOYMENT_STATUS.md` - 当前状态和问题解决

---

**最后更新**: 2025-12-16
**版本**: V3.3 (with rotation fix)
