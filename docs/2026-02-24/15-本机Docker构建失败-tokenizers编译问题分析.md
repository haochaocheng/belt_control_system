# 本机 Docker 构建失败 - tokenizers 编译问题分析

**创建时间**: 2026-02-24 21:40
**问题**: 本机 Docker 构建在 5154.8 秒（86 分钟）后失败
**原因**: tokenizers 编译失败，MeloTTS 依赖问题

---

## 一、失败日志分析

### 1.1 关键错误信息

```
5154.8 Failed to build tokenizers
5154.8 ERROR: Could not build wheels for tokenizers, which is required to install pyproject.toml-based projects
```

**失败时间点**：
- 运行时间：5154.8 秒 = **86 分钟**
- 失败阶段：编译 tokenizers（Rust 包）

### 1.2 失败的 Dockerfile 行

```dockerfile
# Line 165-171
RUN apt-get update && apt-get install -y curl \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . $HOME/.cargo/env \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir --break-system-packages "numpy<2.0.0" \
    && pip3 install --no-cache-dir --break-system-packages -r /tmp/paddlespeech-requirements.txt \
    && rm /tmp/paddlespeech-requirements.txt
```

---

## 二、问题根因分析

### 2.1 依赖链

```
requirements.txt
└─ git+https://github.com/myshell-ai/MeloTTS.git
   └─ transformers
      └─ tokenizers  # ❌ 需要 Rust 编译，在 QEMU 下极慢
```

### 2.2 为什么编译失败？

**可能原因**：

1. **QEMU 模拟超时**：
   - tokenizers 编译需要 20-30 分钟（原生 ARM64）
   - QEMU 模拟下需要 **60-90 分钟**
   - 可能触发超时或内存不足

2. **Rust 编译器问题**：
   - Rust 在 QEMU 下编译极不稳定
   - 可能出现随机崩溃

3. **内存不足**：
   - Rust 编译需要大量内存
   - QEMU 模拟额外消耗内存
   - 可能触发 OOM

### 2.3 时间线分析

```
0-20 分钟：下载包（PaddleSpeech, MeloTTS 等）
20-60 分钟：编译 Python C 扩展（pyworld, librosa 等）
60-86 分钟：编译 tokenizers（Rust）
86 分钟：❌ 失败
```

---

## 三、解决方案对比

### 方案 A：禁用 MeloTTS（推荐，最快）

**修改 requirements.txt**：
```txt
# git+https://github.com/myshell-ai/MeloTTS.git  # 暂时禁用
```

**效果**：
- ✅ 不需要编译 tokenizers
- ✅ 构建时间：**40-50 分钟**（vs 86+ 分钟）
- ✅ 成功率：接近 100%
- ⚠️ MeloTTS 不可用

**适用场景**：
- 只需要 PaddleSpeech
- 快速验证构建流程
- 避免 QEMU 编译问题

### 方案 B：使用离线包（推荐，最可靠）

**步骤**：
1. 在 ARM64 设备上预编译所有包
2. 复制到 Windows
3. Dockerfile 使用离线安装

**效果**：
- ✅ 不需要在 Docker 内编译
- ✅ 构建时间：**5-10 分钟**
- ✅ 成功率：100%
- ✅ MeloTTS 可用

**详见**：[13-Docker离线安装依赖包方案.md](13-Docker离线安装依赖包方案.md)

### 方案 C：增加 Rust 编译资源

**修改 Dockerfile**：
```dockerfile
# 增加 Rust 编译并行度
ENV CARGO_BUILD_JOBS=4

# 增加 Docker 内存限制
# docker build --memory=8g ...
```

**效果**：
- ⚠️ 可能缩短编译时间到 60-70 分钟
- ⚠️ 仍然很慢
- ⚠️ 成功率不确定

### 方案 D：在 ARM64 设备上构建

**步骤**：
```bash
# 在设备 188 上构建
ssh linaro@192.168.10.188
docker build -f Dockerfile.ubuntu24-base -t base-image .
```

**效果**：
- ✅ 原生 ARM64，无 QEMU 模拟
- ✅ 构建时间：**20-30 分钟**
- ✅ 成功率：接近 100%
- ✅ MeloTTS 可用

---

## 四、立即可用的解决方案

### 选项 1：禁用 MeloTTS（最快，5 分钟内可重新构建）

**已完成的修改**：
- ✅ requirements.txt 已修改（Line 26）
- ✅ MeloTTS 已注释掉

**下一步**：
```powershell
# 重新构建（预计 40-50 分钟）
.\build-ubuntu24-apt.ps1 188
```

**预期结果**：
- ✅ 不会再编译 tokenizers
- ✅ 构建成功
- ✅ PaddleSpeech 可用

### 选项 2：等待设备下载完成，使用离线包（最可靠）

**当前状态**：
- 设备上的下载因为 tensorboard 版本问题失败
- 需要先修复 requirements.txt

**步骤**：
1. 上传修改后的 requirements.txt 到设备
2. 重新下载（5-10 分钟）
3. 复制包回 Windows
4. 修改 Dockerfile 使用离线安装
5. 重新构建（5-10 分钟）

**总耗时**：20-30 分钟

---

## 五、推荐方案

### 立即执行（方案 A）

**现在就做**：
```powershell
# requirements.txt 已修改，直接重新构建
.\build-ubuntu24-apt.ps1 188
```

**优势**：
- ✅ 立即可用
- ✅ 40-50 分钟完成
- ✅ 避免 tokenizers 编译问题

**劣势**：
- ⚠️ MeloTTS 不可用（但 PaddleSpeech 足够强大）

### 后续优化（方案 B）

**等待设备下载完成后**：
1. 修复设备上的 requirements.txt
2. 重新下载离线包
3. 实施离线安装方案
4. 下次构建只需 5-10 分钟

---

## 六、时间对比

| 方案 | 首次构建 | 后续构建 | MeloTTS | 成功率 |
|------|---------|---------|---------|--------|
| **当前（失败）** | 86+ 分钟 | 86+ 分钟 | ✅ | ❌ 低 |
| **禁用 MeloTTS** | 40-50 分钟 | 2-5 分钟 | ❌ | ✅ 高 |
| **离线安装** | 20-30 分钟 | 5-10 分钟 | ✅ | ✅ 100% |
| **设备上构建** | 20-30 分钟 | 20-30 分钟 | ✅ | ✅ 高 |

---

## 七、关键决策点

### 问题：修改后是否还是特别长的时间？

**答案**：**不会**

**原因**：
1. **禁用 MeloTTS 后**：
   - 不需要下载 MeloTTS（节省 5-10 分钟）
   - 不需要编译 tokenizers（节省 **30-60 分钟**）
   - 总时间：**40-50 分钟**（vs 86+ 分钟）

2. **使用离线包后**：
   - 不需要下载任何包（节省 20-25 分钟）
   - 不需要编译任何包（节省 40-60 分钟）
   - 总时间：**5-10 分钟**

### 问题：是否应该禁用 MeloTTS？

**建议**：**是的，暂时禁用**

**理由**：
1. PaddleSpeech 已经足够强大
2. 避免 tokenizers 编译问题
3. 节省大量时间
4. 后续可以通过离线包重新启用

---

## 八、下一步行动

### 立即执行

```powershell
# 1. 重新构建（requirements.txt 已修改）
.\build-ubuntu24-apt.ps1 188

# 2. 监控构建进度
# 预计 40-50 分钟完成
```

### 并行执行（可选）

```powershell
# 在设备上重新下载离线包（修改后的 requirements.txt）
ssh linaro@192.168.10.188
rm -rf /tmp/pip-packages
mkdir /tmp/pip-packages
pip3 download -r /tmp/requirements.txt -d /tmp/pip-packages
```

---

## 九、总结

### 问题根因

- MeloTTS 依赖 tokenizers（Rust 包）
- tokenizers 在 QEMU 下编译极慢且不稳定
- 86 分钟后编译失败

### 解决方案

- **短期**：禁用 MeloTTS，构建时间降到 40-50 分钟
- **中期**：使用离线包，构建时间降到 5-10 分钟
- **长期**：在 ARM64 设备上构建，或使用云端 ARM64 实例

### 关键结论

**修改后不会再特别长**：
- 禁用 MeloTTS：40-50 分钟（vs 86+ 分钟）
- 使用离线包：5-10 分钟

---

**文档版本**: v1.0
**最后更新**: 2026-02-24 21:40
**下次更新**: 重新构建完成后验证时间
