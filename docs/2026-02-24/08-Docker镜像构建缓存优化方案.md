# Docker镜像构建缓存优化方案

**创建时间**: 2026-02-24 18:00
**问题**: 修改 `requirements.txt` 导致基础镜像重新构建，耗时 80+ 分钟
**目标**: 优化Docker层缓存策略，避免不必要的重复构建

---

## 一、问题根因分析

### 1.1 Docker层缓存机制

Docker构建镜像时，每条指令创建一个**层（Layer）**：

```
Dockerfile指令 → 层1 → 层2 → 层3 → 层4 → 最终镜像
```

**缓存规则**：
- ✅ 如果某层的**输入**（指令内容+上下文文件）没变 → 使用缓存
- ❌ 如果某层失效 → **后续所有层全部失效**（级联失效）

### 1.2 当前Dockerfile的问题

查看 `Dockerfile.ubuntu24-base`（Line 155-160）：

```dockerfile
# 层1: 安装apt包（Line 16-147）- 稳定，很少变化
RUN apt-get update && apt-get install -y \
    libc6 libstdc++6 ... (100多个包)

# 层2: COPY requirements.txt（Line 155）- ⚠️ 缓存破坏点！
COPY docker/rk3588/tts_engines/paddlespeech/requirements.txt /tmp/

# 层3: 安装Python依赖（Line 156-160）- 耗时80分钟
RUN pip3 install --no-cache-dir --break-system-packages \
    "numpy<2.0.0" \
    && pip3 install -r /tmp/paddlespeech-requirements.txt
```

**问题链条**：

```
修改requirements.txt（新增1个包）
  ↓
COPY层检测到文件哈希变化 → 缓存失效
  ↓
后续所有层失效（包括pip install）
  ↓
重新安装所有Python包（80分钟）
  ↓
即使99%的包没变，也要全部重新安装
```

### 1.3 为什么会级联失效？

**Docker缓存判断逻辑**：

```python
# 伪代码
def should_use_cache(layer):
    if previous_layer.cache_invalid:
        return False  # 上一层失效，当前层也失效

    if layer.type == "COPY":
        if file_hash_changed(layer.source):
            return False  # 文件变化，缓存失效

    if layer.type == "RUN":
        if layer.command != cached_layer.command:
            return False  # 命令变化，缓存失效

    return True  # 使用缓存
```

**关键点**：
- Docker的层是**不可变的**（Immutable）
- 不能"修改"已有的层
- 只能"重新创建"整个层

### 1.4 实际影响

**当前情况**：
- 修改 `requirements.txt`（新增 `melotts==0.1.2`）
- Docker检测到文件哈希变化
- COPY层失效
- pip install层失效
- **重新安装50个包（80分钟）**

**期望情况**：
- 修改 `requirements.txt`
- 只安装新增的1个包（2分钟）
- 其他49个包使用缓存

---

## 二、解决方案

### 方案1：分离稳定依赖和易变依赖（推荐）

**核心思想**：将很少变化的依赖写死在Dockerfile里，经常变化的放在单独的文件

#### 2.1.1 修改后的Dockerfile结构

```dockerfile
# ============================================================
# 层1: 安装apt包（稳定，很少变化）
# ============================================================
RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-dev git libmecab-dev \
    ... (其他apt包)

# ============================================================
# 层2: 安装核心Python包（稳定，写死在Dockerfile）
# ============================================================
RUN pip3 install --no-cache-dir --break-system-packages \
    "numpy<2.0.0" \
    "paddlepaddle==2.6.0" \
    "paddlespeech==1.4.1" \
    "librosa==0.10.1" \
    "soundfile==0.12.1" \
    "resampy==0.4.2" \
    "scipy==1.11.4" \
    "pandas==2.1.4" \
    "praatio==6.2.0" \
    "timer==0.2.2" \
    "visualdl==2.5.3" \
    "yacs==0.1.8" \
    "pyyaml==6.0.1" \
    "jieba==0.42.1" \
    "g2p_en==2.1.0" \
    "pypinyin==0.50.0" \
    "inflect==7.0.0" \
    "zhon==2.0.2" \
    "cn2an==0.5.22" \
    "unidecode==1.3.8" \
    "tqdm==4.66.1" \
    "colorlog==6.8.0" \
    "colorama==0.4.6" \
    "typeguard==4.1.5" \
    "cached_path==1.6.2" \
    "requests==2.31.0" \
    "filelock==3.13.1" \
    "boto3==1.34.34" \
    "google-cloud-storage<4.0,>=1.32.0" \
    "huggingface-hub>=0.20.0,<1.0" \
    "pydantic>=2.0,<3.0" \
    "python-dotenv>=1.0.0,<2.0.0"

# ============================================================
# 层3: 安装MeloTTS（稳定，写死在Dockerfile）
# ============================================================
RUN pip3 install --no-cache-dir --break-system-packages \
    git+https://github.com/myshell-ai/MeloTTS.git

# ============================================================
# 层4: COPY项目特定依赖（易变）
# ============================================================
COPY docker/rk3588/tts_engines/requirements-extra.txt /tmp/

# ============================================================
# 层5: 安装项目依赖（易变，但很少）
# ============================================================
RUN pip3 install --no-cache-dir --break-system-packages \
    -r /tmp/requirements-extra.txt \
    && rm /tmp/requirements-extra.txt
```

#### 2.1.2 创建 requirements-extra.txt

```bash
# requirements-extra.txt（项目特定依赖，经常变化）
# 这个文件只包含项目特定的、经常变化的包
# 核心依赖已经写死在Dockerfile里

# 示例：项目特定的包
# my-custom-package==1.0.0
```

#### 2.1.3 效果对比

**修改前**：
```
修改requirements.txt → 重新安装50个包 → 80分钟
```

**修改后**：
```
修改requirements-extra.txt → 只安装新增的1个包 → 2分钟
层1-3保持缓存（80分钟的安装不用重复）
```

---

### 方案2：使用多个requirements文件

**核心思想**：按依赖的稳定性分层

#### 2.2.1 拆分requirements文件

```
requirements-base.txt          # 核心依赖（numpy, pandas等）
requirements-paddlespeech.txt  # PaddleSpeech依赖
requirements-melotts.txt       # MeloTTS依赖
requirements-project.txt       # 项目依赖（经常变）
```

#### 2.2.2 修改后的Dockerfile

```dockerfile
# 层1: 基础依赖（很少变）
COPY requirements-base.txt /tmp/
RUN pip3 install --no-cache-dir -r /tmp/requirements-base.txt

# 层2: PaddleSpeech依赖（偶尔变）
COPY requirements-paddlespeech.txt /tmp/
RUN pip3 install --no-cache-dir -r /tmp/requirements-paddlespeech.txt

# 层3: MeloTTS依赖（偶尔变）
COPY requirements-melotts.txt /tmp/
RUN pip3 install --no-cache-dir -r /tmp/requirements-melotts.txt

# 层4: 项目依赖（经常变）
COPY requirements-project.txt /tmp/
RUN pip3 install --no-cache-dir -r /tmp/requirements-project.txt
```

#### 2.2.3 效果

**修改 requirements-project.txt**：
- 只重新安装层4（2分钟）
- 层1-3保持缓存（80分钟）

**修改 requirements-melotts.txt**：
- 重新安装层3-4（10分钟）
- 层1-2保持缓存（70分钟）

---

### 方案3：使用BuildKit缓存挂载（最先进）

**核心思想**：即使层失效，也保留pip的下载缓存

#### 2.3.1 启用BuildKit

```powershell
# 设置环境变量
$env:DOCKER_BUILDKIT=1

# 或在docker build时指定
docker buildx build --platform linux/arm64 ...
```

#### 2.3.2 修改Dockerfile

```dockerfile
# 使用BuildKit缓存挂载
RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install --no-cache-dir --break-system-packages \
    -r /tmp/paddlespeech-requirements.txt
```

#### 2.3.3 效果

**即使层失效**：
- pip的下载缓存在构建之间保持
- 不用重新下载包（节省网络时间）
- 只需重新安装（快很多）

**时间对比**：
- 无缓存：80分钟（下载60分钟 + 安装20分钟）
- 有缓存：20分钟（只需安装）

---

## 三、临时缓解措施（不修改Dockerfile）

### 3.1 保存中间镜像

```powershell
# 方法1: 在apt安装完成后，手动commit
# 1. 找到apt安装完成的容器ID
docker ps -a

# 2. 保存为中间镜像
docker commit <container-id> belt-control-base:apt-only

# 3. 修改Dockerfile，从这个镜像开始
# FROM belt-control-base:apt-only
# COPY requirements.txt /tmp/
# RUN pip3 install -r /tmp/requirements.txt
```

### 3.2 使用 --cache-from

```powershell
# 使用之前的镜像作为缓存源
docker build --cache-from belt-control-base:ubuntu24 \
    -t belt-control-base:ubuntu24 \
    -f Dockerfile.ubuntu24-base .
```

### 3.3 不修改requirements.txt

**当前最快的方法**：
- 不要在 `requirements.txt` 中新增包
- 直接在Dockerfile的RUN中写死包名

```dockerfile
# 不要修改requirements.txt
# 直接在这里加新包
RUN pip3 install --no-cache-dir --break-system-packages \
    "numpy<2.0.0" \
    "新包名==版本号" \
    && pip3 install -r /tmp/paddlespeech-requirements.txt
```

**效果**：
- 修改Dockerfile的RUN指令
- Docker检测到指令变化
- 重新执行pip install
- **但是apt层保持缓存**（节省10分钟）

---

## 四、推荐实施方案

### 4.1 短期方案（立即可用）

**方案3.3**：直接在Dockerfile中添加新包

```dockerfile
# Line 156-160 修改为：
RUN pip3 install --no-cache-dir --break-system-packages \
    "numpy<2.0.0" \
    "melotts==0.1.2" \
    && pip3 install -r /tmp/paddlespeech-requirements.txt
```

**优点**：
- 不需要重构Dockerfile
- 立即可用
- apt层保持缓存

**缺点**：
- 仍需重新安装所有pip包（80分钟）
- 但比完全重建快（节省apt安装的10分钟）

### 4.2 中期方案（推荐）

**方案1**：分离稳定依赖和易变依赖

**实施步骤**：

1. **提取核心依赖到Dockerfile**（一次性工作）
   ```powershell
   # 从requirements.txt提取核心包
   # 写入Dockerfile的RUN指令
   ```

2. **创建 requirements-extra.txt**
   ```bash
   # 只包含项目特定的包
   # 初始为空或很少
   ```

3. **修改Dockerfile**
   ```dockerfile
   # 核心依赖写死
   RUN pip3 install ... (50个核心包)

   # 项目依赖从文件读取
   COPY requirements-extra.txt /tmp/
   RUN pip3 install -r /tmp/requirements-extra.txt
   ```

**优点**：
- 新增包只需2分钟
- 核心依赖永久缓存
- 结构清晰

**缺点**：
- 需要一次性重构
- 首次构建仍需80分钟

### 4.3 长期方案（最优）

**方案3**：使用BuildKit缓存挂载

**实施步骤**：

1. **启用BuildKit**
   ```powershell
   $env:DOCKER_BUILDKIT=1
   ```

2. **修改Dockerfile**
   ```dockerfile
   RUN --mount=type=cache,target=/root/.cache/pip \
       pip3 install -r /tmp/requirements.txt
   ```

3. **修改构建脚本**
   ```powershell
   # build-ubuntu24-apt.ps1
   $env:DOCKER_BUILDKIT=1
   docker buildx build --platform linux/arm64 ...
   ```

**优点**：
- 即使层失效，也保留下载缓存
- 重建时间从80分钟降到20分钟
- 最先进的方案

**缺点**：
- 需要Docker 18.09+
- 需要启用BuildKit

---

## 五、实施建议

### 5.1 当前状态

您的基础镜像正在构建中（已70分钟），建议：

1. ✅ **让它继续完成**（不要中断）
2. ✅ **构建完成后保存镜像**（作为缓存）
3. ✅ **下次优化Dockerfile结构**（避免重复）

### 5.2 实施顺序

**第一步**（立即）：
- 等待当前构建完成
- 保存镜像：`belt-control-base:ubuntu24`

**第二步**（下次新增包时）：
- 使用方案3.3（直接在Dockerfile中添加）
- 避免修改 `requirements.txt`

**第三步**（有时间时）：
- 实施方案1（分离稳定依赖）
- 一次性重构，长期受益

**第四步**（可选）：
- 实施方案3（BuildKit缓存）
- 进一步优化

### 5.3 注意事项

1. **不要在构建过程中修改Dockerfile**
   - 会导致缓存失效
   - 重新开始构建

2. **保存成功的镜像**
   ```powershell
   # 构建成功后，立即保存
   docker tag belt-control-base:ubuntu24 belt-control-base:ubuntu24-backup
   ```

3. **记录构建时间**
   - 优化前：80分钟
   - 优化后：2-20分钟
   - 验证优化效果

---

## 六、技术原理深入

### 6.1 Docker层的存储结构

```
镜像 = 层1 + 层2 + 层3 + 层4
每层 = 文件系统快照（只读）
容器 = 镜像 + 可写层
```

**层的特性**：
- **不可变**：一旦创建，永不改变
- **共享**：多个镜像可以共享同一层
- **增量**：每层只存储与上一层的差异

### 6.2 缓存判断算法

```python
def calculate_layer_hash(layer):
    if layer.type == "COPY":
        # 计算文件内容的哈希
        return hash(file_content)

    if layer.type == "RUN":
        # 计算指令文本的哈希
        return hash(command_text)

    if layer.type == "FROM":
        # 使用基础镜像的ID
        return base_image_id

def should_use_cache(layer, previous_layer):
    # 上一层失效，当前层也失效
    if not previous_layer.cached:
        return False

    # 计算当前层的哈希
    current_hash = calculate_layer_hash(layer)

    # 查找缓存
    cached_layer = find_cached_layer(current_hash)

    return cached_layer is not None
```

### 6.3 为什么COPY会破坏缓存？

```dockerfile
COPY requirements.txt /tmp/
```

**Docker的处理**：
1. 计算 `requirements.txt` 的SHA256哈希
2. 查找缓存：是否有相同哈希的层？
3. 如果文件内容变化 → 哈希不同 → 缓存失效
4. 后续所有层失效（级联效应）

**关键点**：
- Docker比较的是**文件内容**，不是文件名
- 即使只改1个字符，哈希也完全不同
- 无法"部分缓存"

---

## 七、参考资料

### 7.1 相关文档

- Docker官方文档：[Best practices for writing Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- BuildKit文档：[Build cache](https://docs.docker.com/build/cache/)

### 7.2 相关文件

- `Dockerfile.ubuntu24-base`（Line 155-160）
- `docker/rk3588/tts_engines/paddlespeech/requirements.txt`
- `build-ubuntu24-apt.ps1`（Line 1099-1122）

### 7.3 相关问题

- Issue: 修改requirements.txt导致80分钟重建
- 根因: Docker层缓存级联失效
- 解决: 分离稳定依赖和易变依赖

---

**文档版本**: v1.0
**最后更新**: 2026-02-24 18:00
**下次更新**: 实施优化方案后
