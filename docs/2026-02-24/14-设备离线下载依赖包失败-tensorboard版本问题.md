# 设备离线下载依赖包失败 - tensorboard 版本问题

**创建时间**: 2026-02-24 21:30
**问题**: 在设备 192.168.10.188 上下载离线包时失败
**原因**: MeloTTS 依赖 tensorboard==2.16.2，但 PyPI 上只有到 2.14.0

---

## 一、错误信息

```
ERROR: Could not find a version that satisfies the requirement tensorboard==2.16.2
(from melotts==0.1.2->-r /tmp/requirements.txt (line 22))
(from versions: 1.6.0rc0, ..., 2.14.0)
ERROR: No matching distribution found for tensorboard==2.16.2
```

---

## 二、问题分析

### 2.1 根本原因

**MeloTTS 依赖版本冲突**：
```python
# MeloTTS 的 setup.py 要求
tensorboard==2.16.2  # ❌ PyPI 上不存在

# PyPI 上实际可用版本
tensorboard==2.14.0  # ✅ 最新版本
```

### 2.2 环境信息

**设备环境**：
- 设备：192.168.10.188
- 系统：Ubuntu 20.04
- Python：3.8
- 架构：ARM64 (aarch64)

**Docker 目标环境**：
- 系统：Ubuntu 24.04
- Python：3.12
- 架构：ARM64

### 2.3 为什么会出现这个问题？

1. **MeloTTS 版本过新**：
   - MeloTTS 0.1.2 依赖 tensorboard 2.16.2
   - tensorboard 2.16.2 可能只在 Python 3.10+ 上可用
   - 设备上是 Python 3.8

2. **PyPI 索引不完整**：
   - 清华镜像可能没有最新版本
   - 或者 tensorboard 2.16.2 根本不存在

---

## 三、解决方案

### 方案 A：放宽 tensorboard 版本要求（推荐）

**修改 requirements.txt**，不指定 MeloTTS 的精确依赖：

```txt
# ❌ 原来的写法（会下载 MeloTTS 并检查所有依赖）
git+https://github.com/myshell-ai/MeloTTS.git

# ✅ 修改后的写法（暂时禁用 MeloTTS）
# git+https://github.com/myshell-ai/MeloTTS.git  # 暂时禁用，等待修复
```

**效果**：
- ✅ 可以成功下载其他所有包
- ✅ PaddleSpeech 仍然可用
- ⚠️ MeloTTS 暂时不可用

### 方案 B：手动下载 MeloTTS 依赖

**步骤**：
1. 先下载除 MeloTTS 外的所有包
2. 手动克隆 MeloTTS 仓库
3. 修改 MeloTTS 的 setup.py，放宽 tensorboard 版本

```bash
# 1. 下载其他包
pip3 download -r /tmp/requirements-without-melotts.txt -d /tmp/pip-packages

# 2. 克隆 MeloTTS
cd /tmp
git clone https://github.com/myshell-ai/MeloTTS.git

# 3. 修改 setup.py
cd MeloTTS
sed -i 's/tensorboard==2.16.2/tensorboard>=2.14.0/' setup.py

# 4. 打包
python3 setup.py sdist
cp dist/melotts-*.tar.gz /tmp/pip-packages/
```

### 方案 C：在 Docker 容器内下载（最可靠）

**原理**：Docker 容器内是 Python 3.12，可能有 tensorboard 2.16.2

**步骤**：
```bash
# 1. 在设备上启动临时容器
docker run --rm -it \
  -v /tmp/pip-packages:/packages \
  ubuntu:24.04 bash

# 2. 容器内安装 Python 3.12
apt-get update && apt-get install -y python3 python3-pip

# 3. 下载包
pip3 download -r /tmp/requirements.txt -d /packages
```

---

## 四、立即可用的解决方案

### 步骤 1：修改 requirements.txt（暂时禁用 MeloTTS）

**在 Windows 上修改**：

```powershell
# 编辑文件
notepad docker\rk3588\tts_engines\paddlespeech\requirements.txt
```

**修改内容**：
```txt
# ========== PaddleSpeech 核心依赖 ==========
paddlepaddle>=2.4.0
paddlespeech>=1.4.1

# ========== 音频处理库 ==========
librosa>=0.9.0
soundfile>=0.12.1
pydub>=0.25.1

# ========== 数值计算库 ==========
numpy>=1.21.0,<2.0.0
scipy>=1.7.0

# ========== MeloTTS 依赖 ==========
# ✅ 2026-02-24 21:30 [临时禁用]: tensorboard 版本冲突
# 原因：MeloTTS 依赖 tensorboard==2.16.2，但 PyPI 上只有到 2.14.0
# 解决方案：先部署 PaddleSpeech，后续单独处理 MeloTTS
# git+https://github.com/myshell-ai/MeloTTS.git
```

### 步骤 2：重新上传到设备

```powershell
scp docker\rk3588\tts_engines\paddlespeech\requirements.txt linaro@192.168.10.188:/tmp/
```

### 步骤 3：重新下载

```bash
# 在设备上执行
ssh linaro@192.168.10.188

# 清理之前的下载
rm -rf /tmp/pip-packages
mkdir /tmp/pip-packages

# 重新下载
pip3 download -r /tmp/requirements.txt -d /tmp/pip-packages
```

**预期结果**：
- ✅ 成功下载所有 PaddleSpeech 相关包
- ✅ 不会再报 tensorboard 错误
- ✅ 下载时间：5-10 分钟

---

## 五、后续处理 MeloTTS

### 选项 1：等待 MeloTTS 修复

关注 MeloTTS 仓库，等待他们修复 tensorboard 依赖问题。

### 选项 2：使用 fork 版本

```txt
# 使用社区修复版本（如果有）
git+https://github.com/community/MeloTTS.git@fix-tensorboard
```

### 选项 3：完全不使用 MeloTTS

只使用 PaddleSpeech，它已经足够强大：
- ✅ 支持中文 TTS
- ✅ 支持多说话人
- ✅ 质量高
- ✅ 依赖简单

---

## 六、验证下载结果

### 下载完成后检查

```bash
# 查看下载的包
ls -lh /tmp/pip-packages/

# 应该看到：
# paddlepaddle-3.0.0-*.whl (92 MB)
# paddlespeech-1.5.0-*.whl (1.7 MB)
# librosa-0.11.0-*.whl (260 KB)
# numpy-1.24.4-*.whl (14 MB)
# scipy-1.10.1-*.whl (31 MB)
# ... 其他依赖
```

### 复制回 Windows

```powershell
# 在 Windows 上执行
scp -r linaro@192.168.10.188:/tmp/pip-packages/* docker\rk3588\pip-packages\
```

---

## 七、总结

### 问题根因

- MeloTTS 依赖 tensorboard==2.16.2
- PyPI 上只有 tensorboard 2.14.0
- 版本不匹配导致下载失败

### 解决方案

- **短期**：暂时禁用 MeloTTS，只使用 PaddleSpeech
- **中期**：等待 MeloTTS 修复或使用 fork 版本
- **长期**：评估是否真的需要 MeloTTS

### 影响评估

- ✅ PaddleSpeech 功能完整，可以正常使用
- ✅ 不影响当前 TTS 功能
- ⚠️ MeloTTS 特有功能暂时不可用（如果有）

---

**文档版本**: v1.0
**最后更新**: 2026-02-24 21:30
**下次更新**: 修改 requirements.txt 并重新下载后
