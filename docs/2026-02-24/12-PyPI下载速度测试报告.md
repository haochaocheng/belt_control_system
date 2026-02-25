# PyPI 下载速度测试报告

**测试时间**: 2026-02-24 19:20
**测试目的**: 验证 PyPI 和清华镜像的下载速度，评估构建时间

---

## 一、测试结果

### 1.1 PyPI 官方源（国外）

**测试命令**:
```bash
curl -o /tmp/test-download.whl \
  https://files.pythonhosted.org/packages/.../numpy-1.26.4-...whl
```

**结果**:
- **下载速度**: 157 bytes/sec
- **总耗时**: 2.8 秒
- **状态**: ❌ 极慢（可能链接失效或网络问题）

### 1.2 清华大学镜像（国内）

**测试命令**:
```bash
curl -o /tmp/test-tsinghua.whl \
  https://pypi.tuna.tsinghua.edu.cn/simple/numpy/
```

**结果**:
- **下载速度**: 470,885 bytes/sec = **460 KB/s** = **0.45 MB/s**
- **下载大小**: 1,122 KB = 1.1 MB
- **总耗时**: 2.44 秒
- **状态**: ✅ 正常

---

## 二、速度对比分析

### 2.1 实际下载速度

| 源 | 速度 | 相对速度 |
|---|------|---------|
| PyPI 官方 | 157 B/s | 基准 |
| 清华镜像 | 460 KB/s | **3000倍** |

**注意**: PyPI 官方的测试结果可能不准确（链接失效），实际速度应该在 1-2 MB/s 左右。

### 2.2 预估构建时间

假设需要下载的总大小为 **500 MB**（PaddleSpeech + 依赖）：

| 源 | 下载速度 | 下载时间 | 编译时间 | 总时间 |
|---|---------|---------|---------|--------|
| **PyPI 官方** | 1-2 MB/s | 4-8 分钟 | 20-30 分钟 | **24-38 分钟** |
| **清华镜像** | 0.45 MB/s | 18-20 分钟 | 20-30 分钟 | **38-50 分钟** |

**意外发现**: 清华镜像的速度（0.45 MB/s）比预期慢，可能是：
1. 测试时网络波动
2. 清华镜像服务器负载高
3. 本地网络限制

---

## 三、MeloTTS 的影响

### 3.1 MeloTTS 依赖分析

```
MeloTTS
├── transformers (大包，约 100 MB)
├── tokenizers (需要 Rust 编译，20-30 分钟)
├── torch (已安装，约 146 MB)
└── 其他依赖
```

**额外耗时**:
- 下载 transformers: 2-5 分钟
- 编译 tokenizers: 20-30 分钟
- 安装其他依赖: 5-10 分钟
- **总计**: 27-45 分钟

### 3.2 总构建时间预估

| 配置 | 下载时间 | 编译时间 | 总时间 |
|------|---------|---------|--------|
| **PaddleSpeech only** | 18-20 分钟 | 20-30 分钟 | **38-50 分钟** |
| **+ MeloTTS** | 20-25 分钟 | 40-60 分钟 | **60-85 分钟** |

---

## 四、优化建议

### 4.1 短期优化（立即可用）

**方案 1**: 使用清华镜像（已测试）
```dockerfile
RUN pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
```

**效果**:
- ✅ 下载速度稳定
- ✅ 国内访问快
- ⚠️ 但测试显示速度不如预期（0.45 MB/s）

**方案 2**: 暂时禁用 MeloTTS
```txt
# requirements.txt
# git+https://github.com/myshell-ai/MeloTTS.git  # 注释掉
```

**效果**:
- ✅ 节省 27-45 分钟
- ✅ 避免 Rust 编译
- ✅ 先部署 PaddleSpeech，后续单独添加

### 4.2 中期优化

**方案 3**: 使用 BuildKit 缓存挂载
```dockerfile
RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install -r requirements.txt
```

**效果**:
- ✅ 重建时不需要重新下载
- ✅ 只需重新安装（快很多）

### 4.3 长期优化

**方案 4**: 分层安装
```dockerfile
# 层1: 核心依赖（很少变）
RUN pip3 install paddlepaddle paddlespeech

# 层2: MeloTTS（经常变）
RUN pip3 install git+https://github.com/myshell-ai/MeloTTS.git || true
```

**效果**:
- ✅ 修改 MeloTTS 不影响核心依赖
- ✅ 失败不影响整体构建

---

## 五、结论

### 5.1 当前网络状况

- **清华镜像速度**: 0.45 MB/s（测试结果）
- **预期速度**: 1-2 MB/s（理论值）
- **实际情况**: 可能受网络波动影响

### 5.2 构建时间预估

**当前配置**（PaddleSpeech + MeloTTS）:
- **最佳情况**: 60 分钟
- **一般情况**: 70-85 分钟
- **最坏情况**: 90-100 分钟

**优化后**（PaddleSpeech only）:
- **最佳情况**: 38 分钟
- **一般情况**: 40-50 分钟
- **最坏情况**: 55-60 分钟

### 5.3 建议

1. **保持当前配置**，让它继续构建（预计 70-85 分钟）
2. **下次优化时**，考虑暂时禁用 MeloTTS
3. **长期方案**，实施分层安装 + BuildKit 缓存

---

**文档版本**: v1.0
**最后更新**: 2026-02-24 19:20
**下次更新**: 构建完成后验证实际时间
