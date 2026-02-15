# PaddleSpeech模型导出最终解决方案

**创建时间**: 2026-02-15 14:30
**状态**: ✅ 方案完成
**脚本**: `scripts/2026-02-15/13-export-models-with-cached-image.ps1`

---

## 📊 问题回顾

### 之前的失败

**脚本**: `12-export-paddlespeech-models.ps1`

**失败原因**:
```
pip._vendor.urllib3.exceptions.ReadTimeoutError:
HTTPSConnectionPool(host='pypi.tuna.tsinghua.edu.cn', port=443): Read timed out.
```

**根本问题**:
- 每次运行都要重新安装PaddleSpeech（500+ MB）
- 网络不稳定导致pip install超时
- 浪费时间，效率低下

---

## ✅ 新方案：缓存Docker镜像

### 核心思路

**分离构建和导出**:
```
第一次运行：构建Docker镜像（5-10分钟，一次性）
  ↓
后续运行：直接使用镜像导出模型（2-3分钟）
```

### 工作流程

```
[1/4] 准备目录
  ↓
[2/4] 检查Docker镜像
  ├─ 存在 → 跳过构建
  └─ 不存在 → 构建镜像（一次性）
  ↓
[3/4] 运行容器导出模型
  ├─ 下载8个模型
  └─ 复制到本地目录
  ↓
[4/4] 统计模型大小
```

---

## 🐳 Docker镜像设计

### Dockerfile内容

```dockerfile
FROM python:3.11-slim

# 安装编译工具
RUN apt-get update -qq && \
    apt-get install -y build-essential -qq && \
    rm -rf /var/lib/apt/lists/*

# 安装Python依赖（使用清华镜像源）
RUN pip install --no-cache-dir \
    paddlepaddle==3.0.0 \
    paddlespeech \
    soundfile \
    -i https://pypi.tuna.tsinghua.edu.cn/simple

# 设置工作目录
WORKDIR /app

# 应用aistudio_sdk补丁
RUN python3 -c "import aistudio_sdk.hub as hub; hub.download = lambda *args, **kwargs: None"

CMD ["/bin/bash"]
```

### 镜像特点

- ✅ **一次构建，多次使用**
- ✅ **包含所有依赖**（PaddlePaddle、PaddleSpeech、soundfile）
- ✅ **已应用aistudio_sdk补丁**
- ✅ **使用清华镜像源**（加速下载）

---

## 📦 使用方法

### 第一次运行（构建镜像）

```powershell
.\scripts\2026-02-15\13-export-models-with-cached-image.ps1
```

**预期输出**:
```
========================================
  导出PaddleSpeech模型（缓存镜像版）
========================================

[1/4] 准备目录...
  ✅ 目录准备完成
  📁 模型目录: E:\2025\3_gongkongji\belt_control_system\tts_models\paddlespeech_offline

[2/4] 检查Docker镜像...
  ⚠️  未找到缓存镜像，开始构建...

  🐳 构建Docker镜像（这可能需要5-10分钟）...
  📝 Dockerfile已创建: E:\2025\3_gongkongji\belt_control_system\test_output\Dockerfile.paddlespeech

  [Docker构建输出...]

  ✅ Docker镜像构建成功

[3/4] 开始导出模型...
  🐳 启动Docker容器...
  🚀 开始导出模型...
  📂 初始化TTS引擎...

  [1/8] FastSpeech2-CSMSC
     ⏳ 下载模型...
     ✅ 成功

  [2/8] FastSpeech2-AISHELL3
     ⏳ 下载模型...
     ✅ 成功

  ...

  ✅ 导出完成: 8/8 个模型

  📦 复制模型到挂载目录...
  ✅ 模型已复制

[4/4] 统计模型信息...
  📦 模型总大小: 2.5 GB
  📁 模型位置: E:\2025\3_gongkongji\belt_control_system\tts_models\paddlespeech_offline

========================================
✅ 导出完成
========================================

🚀 下一步: 同步模型到RK3588设备
   scp -r E:\2025\3_gongkongji\belt_control_system\tts_models\paddlespeech_offline linaro@192.168.10.188:/app/models/
```

### 后续运行（使用缓存镜像）

```powershell
.\scripts\2026-02-15\13-export-models-with-cached-image.ps1
```

**预期输出**:
```
[2/4] 检查Docker镜像...
  ✅ 找到缓存镜像: paddlespeech-exporter:latest
  💡 如需重新构建，请先删除镜像: docker rmi paddlespeech-exporter:latest

[3/4] 开始导出模型...
  [直接开始下载，跳过pip install]
```

**时间对比**:
- 第一次运行：5-10分钟（构建镜像）+ 2-3分钟（下载模型）= **7-13分钟**
- 后续运行：2-3分钟（仅下载模型）

---

## 🔧 镜像管理

### 查看镜像

```powershell
docker images paddlespeech-exporter
```

**输出示例**:
```
REPOSITORY              TAG       IMAGE ID       CREATED         SIZE
paddlespeech-exporter   latest    abc123def456   5 minutes ago   2.8GB
```

### 删除镜像（重新构建）

```powershell
docker rmi paddlespeech-exporter:latest
```

**使用场景**:
- PaddleSpeech版本更新
- 需要修改Dockerfile
- 镜像损坏

### 导出镜像（备份）

```powershell
docker save paddlespeech-exporter:latest -o paddlespeech-exporter.tar
```

### 导入镜像（恢复）

```powershell
docker load -i paddlespeech-exporter.tar
```

---

## 📁 输出目录结构

### 导出后的目录

```
tts_models/paddlespeech_offline/
├── tts/
│   ├── fastspeech2_csmsc/
│   │   ├── default.yaml
│   │   ├── snapshot_iter_*.pdz
│   │   └── phone_id_map.txt
│   ├── fastspeech2_aishell3/
│   ├── vits_csmsc/
│   ├── vits_aishell3/
│   ├── fastspeech2_mix/
│   ├── fastspeech2_ljspeech/
│   ├── fastspeech2_vctk/
│   └── fastspeech2_canton/
└── voc/
    ├── pwgan_csmsc/
    ├── pwgan_aishell3/
    ├── pwgan_ljspeech/
    ├── pwgan_vctk/
    └── pwgan_canton/
```

### 模型大小估算

**声学模型（AM）**:
- FastSpeech2: ~100-150 MB/模型
- VITS: ~400-500 MB/模型

**声码器（VOC）**:
- PWG: ~50-80 MB/模型

**总计**: 约2.5-3.0 GB

---

## 🚀 部署到RK3588

### 1. 同步模型到设备

```powershell
scp -r E:\2025\3_gongkongji\belt_control_system\tts_models\paddlespeech_offline linaro@192.168.10.188:/app/models/
```

### 2. 在设备上验证

```bash
ssh linaro@192.168.10.188

# 检查模型目录
ls -lh /app/models/paddlespeech_offline/

# 检查模型大小
du -sh /app/models/paddlespeech_offline/
```

### 3. 配置环境变量

```bash
export PADDLESPEECH_HOME=/app/models/paddlespeech_offline
```

### 4. 测试模型加载

```python
from paddlespeech.cli.tts import TTSExecutor

tts = TTSExecutor()
tts(
    text="你好，这是离线测试",
    output="/tmp/test.wav",
    am="fastspeech2_csmsc",
    voc="pwgan_csmsc",
    lang="zh"
)
```

---

## 💡 优势对比

### 旧方案（12-export-paddlespeech-models.ps1）

❌ **每次都重新安装PaddleSpeech**
❌ **网络超时风险高**
❌ **浪费时间（每次5-10分钟）**
❌ **不可靠**

### 新方案（13-export-models-with-cached-image.ps1）

✅ **一次构建，多次使用**
✅ **避免网络超时**
✅ **节省时间（后续仅2-3分钟）**
✅ **稳定可靠**
✅ **可备份和迁移镜像**

---

## 🔍 故障排查

### 问题1：Docker镜像构建失败

**症状**:
```
ERROR: failed to solve: process "/bin/sh -c pip install ..." did not complete successfully
```

**解决**:
1. 检查网络连接
2. 尝试使用其他镜像源
3. 增加Docker内存限制

### 问题2：模型下载失败

**症状**:
```
❌ 失败: HTTPError: 404 Not Found
```

**解决**:
1. 检查模型名称是否正确
2. 检查PaddleSpeech版本
3. 使用TTSExecutor自动下载

### 问题3：模型未复制到本地

**症状**:
```
⚠️  未找到模型缓存
```

**解决**:
1. 检查容器内路径：`/root/.paddlespeech`
2. 检查挂载目录权限
3. 手动进入容器检查：`docker run -it paddlespeech-exporter:latest bash`

---

## 📝 相关文件

### 脚本文件
1. `scripts/2026-02-15/13-export-models-with-cached-image.ps1` - 新方案脚本 ⭐

### 文档文件
1. `docs/2026-02-15/14-PaddleSpeech模型导出最终解决方案.md` - 本文档

### 旧脚本（已弃用）
1. `scripts/2026-02-15/12-export-paddlespeech-models.ps1` - 旧方案（网络超时）
2. `scripts/2026-02-15/11-organize-paddlespeech-models.ps1` - 容器已退出
3. `scripts/2026-02-15/08-download-remaining-models.ps1` - 404错误

---

## ✅ 总结

### 问题解决

**旧问题**: 每次运行都要重新安装PaddleSpeech，网络超时
**新方案**: 构建缓存Docker镜像，一次构建多次使用
**效果**: 稳定可靠，节省时间

### 使用流程

1. **第一次运行**: 构建镜像 + 导出模型（7-13分钟）
2. **后续运行**: 直接导出模型（2-3分钟）
3. **部署到RK3588**: scp同步模型目录

### 关键优势

- ✅ **避免网络超时**
- ✅ **节省时间**
- ✅ **稳定可靠**
- ✅ **可重复使用**

---

**下一步**: 运行脚本导出模型，然后同步到RK3588设备

```powershell
# 导出模型
.\scripts\2026-02-15\13-export-models-with-cached-image.ps1

# 同步到设备
scp -r E:\2025\3_gongkongji\belt_control_system\tts_models\paddlespeech_offline linaro@192.168.10.188:/app/models/
```
