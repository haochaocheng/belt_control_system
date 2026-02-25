# Docker 基础镜像构建优化工作日志

**日期**: 2026-02-25
**Phase**: 7.46.59

---

## 一、问题背景

基础镜像构建耗时过长（2+ 小时），每次添加一个小包都需要重建整个镜像，严重影响开发效率。

---

## 二、今日工作内容

### 1. 修复 Dockerfile Rust 安装失败 (Phase 7.46.57)

**问题**: Dockerfile 中 Rust 安装时 TLS 握手失败
```
error: tls handshake eof
```

**原因**: MeloTTS 已在 Phase 7.46.54 彻底禁用，不再需要 Rust 编译 tokenizers

**解决**: 注释掉 Rust 安装代码（Dockerfile.ubuntu24-base 第 164-169 行）

---

### 2. 修复 QDS VoiceManagement 空白屏幕 (Phase 7.46.58)

**问题**: VoiceManagement.qml 在 QDS 预览模式下显示空白
```
module "com.belt.control" is not installed
```

**原因**: VoiceManagement.qml 导入了 C++ 模块 `com.belt.control`（TTSConfig 单例），QDS 预览模式下不可用

**解决**: 创建 QML mock 模块
- 创建目录: `src/qml/com/belt/control/`
- 创建 `qmldir` 文件声明模块
- 创建 `TTSConfig.qml` 模拟 C++ 单例

**注意**: QML 属性名必须小写（camelCase），不能用大写开头

---

### 3. 设备构建脚本开发

#### 3.1 脚本编码问题

**问题**: PowerShell 脚本中文乱码
```
TerminatorExpectedAtEndOfString
```

**解决**:
- 移除特殊字符（emoji）
- 使用 `Write-Host ""` 替代 `` `n ``

#### 3.2 plink/pscp 未安装

**问题**:
```
The term 'plink' is not recognized
```

**解决**: 改用 ssh/scp 命令

#### 3.3 设备 Docker 镜像源无法访问

**问题**: 设备 185 无法访问中科大镜像源
```
dial tcp: lookup docker.mirrors.ustc.edu.cn: i/o timeout
```

**解决**: 从 Windows 导出 ubuntu:24.04 镜像上传到设备
```bash
# Windows 导出
docker save ubuntu:24.04 -o /c/Temp/ubuntu24.tar

# 上传到设备
scp /c/Temp/ubuntu24.tar linaro@192.168.10.185:/tmp/

# 设备导入
docker load -i /tmp/ubuntu24.tar
```

---

### 4. 构建慢原因分析

#### 4.1 确认问题

通过 `wsl -d docker-desktop top` 查看进程：
```
{pip3} /usr/bin/qemu-aarch64 /usr/bin/python3 /usr/bin/pip3 install ...
```

**发现**:
1. **QEMU 模拟**: pip3 通过 qemu-aarch64 运行，模拟 ARM64
2. **CPU 使用率只有 3%**: 只用了 1 个核心
3. **没有并行编译**: MAKEFLAGS 未设置

#### 4.2 根本原因

| 因素 | 影响 |
|------|------|
| QEMU ARM64 模拟 | 慢 10-15 倍 |
| 单核编译 | 浪费 31 个核心 |
| 总计 | 慢 100+ 倍 |

---

### 5. 优化措施

#### 5.1 添加并行编译配置

修改 `Dockerfile.ubuntu24-base`:
```dockerfile
# ✅ 2026-02-25 10:30: 启用并行编译加速 pip install
ENV MAKEFLAGS="-j8"
ENV CMAKE_BUILD_PARALLEL_LEVEL=8
ENV PIP_NO_BUILD_ISOLATION=0
```

#### 5.2 添加清华镜像源

```dockerfile
# ✅ 2026-02-25 10:10: 使用清华镜像源加速 pip 安装
ARG PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
ARG PIP_TRUSTED_HOST=pypi.tuna.tsinghua.edu.cn

RUN pip3 install --break-system-packages \
    -i ${PIP_INDEX_URL} --trusted-host ${PIP_TRUSTED_HOST} \
    "numpy<2.0.0"
```

#### 5.3 添加 BuildKit 缓存

```dockerfile
# ✅ 2026-02-25 10:20: 添加 BuildKit 缓存
RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install ...
```

---

### 6. ARM64 预编译 wheel 调研

**搜索结果**:

| 来源 | 状态 | 说明 |
|------|------|------|
| PaddlePaddle 官方 | ❌ 不支持 ARM64 | 只支持 x86_64 |
| piwheels | ❌ 不支持 aarch64 | 只支持 32-bit ARM |
| PyPI 官方 | ❌ 不支持 | 不接受 ARM wheels 上传 |
| conda-forge | ✅ 支持 | 可用 miniforge |

**结论**: ARM64 + PaddleSpeech 没有预编译包，必须从源码编译

---

## 三、当前构建状态

- **构建时间**: 111+ 分钟
- **当前步骤**: [4/6] pip3 install paddlespeech requirements
- **状态**: 正在进行中

---

## 四、后续优化方案

### 方案1: 并行编译（已实施）
- 效果: 下次构建快 2-4 倍
- 状态: 已添加到 Dockerfile

### 方案2: 设备原生构建
- 效果: 快 5-8 倍
- 问题: 设备 185 网络不通

### 方案3: 基础镜像常驻 + 增量更新（推荐）
```bash
# 启动现有镜像
docker run -it --name temp-base belt-control-base:latest bash

# 安装缺失的包
apt install -y libwayland-server0

# 保存为新镜像
docker commit temp-base belt-control-base:latest
```

### 方案4: 使用 Miniforge + conda-forge
- 效果: 使用预编译的 aarch64 包
- 复杂度: 需要修改 Dockerfile 架构

---

## 五、文件变更清单

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| Dockerfile.ubuntu24-base | 修改 | 添加并行编译、清华镜像源、BuildKit 缓存 |
| src/qml/com/belt/control/TTSConfig.qml | 新增 | QDS mock 单例 |
| src/qml/com/belt/control/qmldir | 新增 | 模块声明 |
| scripts/2026-02-25/01-test-device-base-image-build.ps1 | 新增 | 设备构建测试脚本 |
| scripts/2026-02-25/02-simple-device-build.ps1 | 新增 | 简化版设备构建脚本 |

---

## 六、关键发现

1. **QEMU 模拟是瓶颈**: Windows 上构建 ARM64 镜像，pip install 通过 QEMU 模拟运行，极慢
2. **默认单核编译**: 即使有 32 核心可用，pip 默认只用 1 核
3. **ARM64 预编译包缺失**: PaddlePaddle/PaddleSpeech 没有 ARM64 预编译包
4. **Docker 层缓存机制**: 修改任何一行都会导致整层重建

---

## 七、经验教训

1. **基础镜像要稳定**: 构建一次，长期使用，增量更新
2. **并行编译很重要**: MAKEFLAGS 可以显著加速编译
3. **设备原生构建更快**: 如果可能，在目标设备上构建
4. **镜像源要可靠**: 国内环境需要配置清华/阿里镜像源

---

## 八、问题修复记录

### 8.1 并行编译配置破坏 apt-get 缓存 (12:00)

**问题**: 添加 MAKEFLAGS 等 ENV 指令在 apt-get 之前，导致 Docker 层缓存失效，重新安装所有系统包

**原因**: Docker 缓存按顺序，前面的层变了，后面所有层都要重建

**解决**: 将并行编译配置移到 apt-get 之后、pip install 之前

```dockerfile
# 修改前（错误）
ENV MAKEFLAGS="-j8"  # 在 apt-get 之前
RUN apt-get update && apt-get install -y ...

# 修改后（正确）
RUN apt-get update && apt-get install -y ...
ENV MAKEFLAGS="-j8"  # 在 apt-get 之后
RUN pip3 install ...
```

### 8.2 BatchSynthesisDialog.qml Qt 版本不兼容 (11:45)

**问题**: 设备运行报错 `BatchSynthesisDialog is not a type`，导致 `ERROR: No root objects loaded!`

**原因**: BatchSynthesisDialog.qml 使用 Qt 5 风格导入（2.15），项目使用 Qt 6（6.5）

**解决**:
1. 修改 BatchSynthesisDialog.qml 导入版本为 6.5
2. 在 VoiceManagement.qml 添加 `import "."` 导入当前目录

### 8.3 BatchSynthesisDialog.qml 布局溢出问题 (13:00-13:50)

**问题**: 批量合成对话框布局问题：
1. "沿线点位范围" 行的 SpinBox 被截断
2. 底部按钮区域布局错乱
3. "选项" GroupBox 导致左侧内容超出弹窗高度
4. 弹窗尺寸超出父容器

**原因**:
1. Popup 初始宽度不足（800px）
2. SpinBox 使用 `implicitWidth` 在 GridLayout 中不生效
3. 左侧有3个 GroupBox（选择分类、生成范围、选项）导致高度超出
4. "生成范围" 使用2列布局占用太多垂直空间

**解决**:
1. 调整 Popup 尺寸为 800x580，边距减小到 15px
2. 将 SpinBox 的 `implicitWidth` 改为 `Layout.preferredWidth`
3. 将"选项"从左侧 GroupBox 移到右侧日志区下方的 RowLayout
4. 将"生成范围"从2列改为4列布局（5行→3行）
5. 为底部按钮添加 `Layout.preferredWidth` 和 `Layout.preferredHeight`

**最终布局**:
- 左侧：选择分类（7个CheckBox）+ 生成范围（4列3行）
- 右侧：统计信息 + 进度 + 日志 + 选项（2个CheckBox）
- 底部：预览清单 | 开始生成 停止 关闭

**修改文件**: `src/qml/pages/BatchSynthesisDialog.qml`

### 8.4 pyworld/opencc 编译失败 (14:10)

**问题**: Docker 构建失败，`pyworld` 和 `opencc` 在 ARM64 上编译失败

**原因**: 这两个包在 ARM64 上没有预编译 wheel，需要从源码编译，但缺少编译工具

**解决**: 在 Dockerfile.ubuntu24-base 的 apt-get 中添加编译工具：
```dockerfile
build-essential \
cmake \
swig \
libffi-dev \
libopencc-dev \
```

**修改文件**: `Dockerfile.ubuntu24-base`

### 8.5 BatchSynthesisDialog SpinBox 数值不可见 (14:30)

**问题**: "生成范围" 区域的 SpinBox 数值被截断，看不到数字

**原因**: SpinBox 宽度太小（80px）

**解决**:
1. 增加弹窗尺寸 1.3 倍：800x580 → 1040x750
2. 增加 SpinBox 宽度：80 → 110

**修改文件**: `src/qml/pages/BatchSynthesisDialog.qml`

### 8.6 BatchSynthesisDialog 自动弹出问题 (14:45)

**问题**: 没有点击"批量合成"按钮，弹窗就自动弹出

**原因**: 为了 QDS 设计预览，将 Popup 改成了 Rectangle，Rectangle 默认可见

**解决**: 恢复为 Popup，删除多余的 close() 函数

**修改文件**: `src/qml/pages/BatchSynthesisDialog.qml`

### 8.7 BatchSynthesisDialog 左右两侧顶部未对齐 (14:50)

**问题**: "选择分类"和"统计信息"顶部没有对齐

**原因**: ColumnLayout 默认垂直居中

**解决**: 为左右两侧的 ColumnLayout 添加 `Layout.alignment: Qt.AlignTop`

**修改文件**: `src/qml/pages/BatchSynthesisDialog.qml`

### 8.8 设备 Docker Hub 访问超时 (15:10)

**问题**: 设备构建时卡在 `load metadata for docker.io/library/ubuntu:24.04`

**原因**: 设备网络无法访问 Docker Hub

**解决**:
1. 配置 Docker 镜像加速器（脚本：`scripts/2026-02-25/03-setup-device-docker-mirror.ps1`）
2. 构建时添加 `--pull=never` 使用本地镜像
3. 构建时添加 `--network=host` 使用宿主机网络

**修改文件**: `scripts/2026-02-25/02-simple-device-build.ps1`

### 8.9 实施分层镜像方案 (15:40)

**目的**: 减少基础镜像重建时间，避免每次修改 apt-get 层都要重新安装 Python 依赖

**方案**: 将单个 Dockerfile 拆分为两层

**架构**:
```
Dockerfile.ubuntu24-system  ← 第一层：只有 apt-get（约10分钟）
    ↓
Dockerfile.ubuntu24-python  ← 第二层：基于第一层，只有 pip install（约30-60分钟）
```

**新增文件**:
- `Dockerfile.ubuntu24-system` - 系统包层
- `Dockerfile.ubuntu24-python` - Python 依赖层

**镜像标签**:
| 镜像名 | 用途 |
|--------|------|
| `belt-control-base:stable-20260225` | 稳定版本（回退用） |
| `belt-control-system:latest` | 第一层：系统包 |
| `belt-control-base:ubuntu24` | 当前使用的基础镜像 |

**使用方式**:
1. 修改 apt-get 层 → 重建 system 层 → 重建 python 层
2. 修改 pip 层 → 只重建 python 层（节省时间）
3. 出问题 → 回退到 `belt-control-base:stable-20260225`

---

**文档版本**: v1.6
**最后更新**: 2026-02-25 15:50
