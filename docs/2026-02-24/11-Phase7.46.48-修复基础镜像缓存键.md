# Phase 7.46.48 - 修复基础镜像缓存键

**创建时间**: 2026-02-24 18:50
**问题**: `build-ubuntu24-apt.ps1` 只检查 Dockerfile 变化，不检查 requirements.txt 变化
**解决方案**: 将 requirements.txt 纳入基础镜像缓存键

---

## 一、问题描述

### 1.1 Codex 审查发现

根据 `.codex/08-Docker镜像构建缓存优化方案-审查.md` 的审查结论：

**[阻断] 文档的核心前提与当前构建脚本不一致**

- **文档描述**: 修改 `requirements.txt` 会触发基础镜像重建并耗时 80+ 分钟
- **当前实现**: `build-ubuntu24-apt.ps1` 仅根据 `Dockerfile.ubuntu24-base` 哈希判断是否重建基础镜像
- **影响**: 仅修改 `requirements.txt` 时，脚本可能直接跳过基础镜像构建，导致变更未生效

### 1.2 根本原因

**原代码逻辑**（Line 1059-1077）：

```powershell
# 只检查 Dockerfile.ubuntu24-base 的哈希
$baseDockerfilePath = "$ProjectRoot\Dockerfile.ubuntu24-base"
$currentBaseHash = (Get-FileHash -Path $baseDockerfilePath -Algorithm MD5).Hash

if ($previousBaseHash -ne $currentBaseHash) {
    $needBuildBase = $true
}
```

**问题**：
- ❌ 只计算 `Dockerfile.ubuntu24-base` 的哈希
- ❌ 不包括 `requirements.txt` 的哈希
- ❌ 修改 `requirements.txt` 不会触发重建

### 1.3 实际影响

**场景 1**：新增 Python 包
```powershell
# 1. 修改 requirements.txt，新增 melotts
# 2. 运行 build-ubuntu24-apt.ps1
# 3. 脚本检测到 Dockerfile 没变，跳过基础镜像构建
# 4. 应用镜像使用旧的基础镜像（没有 melotts）
# 5. 应用启动失败：ModuleNotFoundError: No module named 'melotts'
```

**场景 2**：修改包版本
```powershell
# 1. 修改 requirements.txt，升级 paddlespeech 版本
# 2. 运行 build-ubuntu24-apt.ps1
# 3. 脚本跳过基础镜像构建
# 4. 应用使用旧版本 paddlespeech
# 5. 可能出现兼容性问题或 bug
```

---

## 二、解决方案

### 2.1 修改内容

**文件**: `build-ubuntu24-apt.ps1`

**修改位置**: Line 1055-1092

**修改前**:
```powershell
# Check if Dockerfile.ubuntu24-base changed
$baseDockerfilePath = "$ProjectRoot\Dockerfile.ubuntu24-base"
if (Test-Path $baseDockerfilePath) {
    $currentBaseHash = (Get-FileHash -Path $baseDockerfilePath -Algorithm MD5).Hash

    if (Test-Path $BaseCacheFile) {
        $cacheData = Get-Content $BaseCacheFile | ConvertFrom-Json
        $previousBaseHash = $cacheData.hash

        if ($previousBaseHash -ne $currentBaseHash) {
            Write-Host "  [!] Base Dockerfile changed - rebuild required" -ForegroundColor Yellow
            $needBuildBase = $true
        }
    }
}
```

**修改后**:
```powershell
# ✅ 2026-02-24 18:50 [Phase 7.46.48]: 修复基础镜像缓存键
# 原因：只检查 Dockerfile 变化，不检查 requirements.txt 变化
# 效果：修改 requirements.txt 会触发基础镜像重建
# 方案：计算 Dockerfile + requirements.txt 的联合哈希

# Check if Dockerfile.ubuntu24-base or requirements.txt changed
$baseDockerfilePath = "$ProjectRoot\Dockerfile.ubuntu24-base"
$requirementsPath = "$ProjectRoot\docker\rk3588\tts_engines\paddlespeech\requirements.txt"

if (Test-Path $baseDockerfilePath) {
    # 计算联合哈希：Dockerfile + requirements.txt
    $dockerfileHash = (Get-FileHash -Path $baseDockerfilePath -Algorithm MD5).Hash

    if (Test-Path $requirementsPath) {
        $requirementsHash = (Get-FileHash -Path $requirementsPath -Algorithm MD5).Hash
        $currentBaseHash = "$dockerfileHash-$requirementsHash"
    } else {
        $currentBaseHash = $dockerfileHash
    }

    if (Test-Path $BaseCacheFile) {
        $cacheData = Get-Content $BaseCacheFile | ConvertFrom-Json
        $previousBaseHash = $cacheData.hash

        if ($previousBaseHash -ne $currentBaseHash) {
            Write-Host "  [!] Base Dockerfile or requirements.txt changed - rebuild required" -ForegroundColor Yellow
            $needBuildBase = $true
        }
    } else {
        # No cache file, assume need rebuild
        $needBuildBase = $true
    }
}
```

### 2.2 关键改动

1. **新增 requirements.txt 路径**：
   ```powershell
   $requirementsPath = "$ProjectRoot\docker\rk3588\tts_engines\paddlespeech\requirements.txt"
   ```

2. **计算联合哈希**：
   ```powershell
   $dockerfileHash = (Get-FileHash -Path $baseDockerfilePath -Algorithm MD5).Hash
   $requirementsHash = (Get-FileHash -Path $requirementsPath -Algorithm MD5).Hash
   $currentBaseHash = "$dockerfileHash-$requirementsHash"
   ```

3. **更新提示信息**：
   ```powershell
   Write-Host "  [!] Base Dockerfile or requirements.txt changed - rebuild required"
   ```

---

## 三、技术细节

### 3.1 联合哈希计算

**方法**：将两个文件的 MD5 哈希拼接

```powershell
# Dockerfile 哈希: a1b2c3d4e5f6...
# requirements.txt 哈希: 1a2b3c4d5e6f...
# 联合哈希: a1b2c3d4e5f6...-1a2b3c4d5e6f...
```

**优点**：
- ✅ 任一文件变化都会导致联合哈希变化
- ✅ 简单可靠，不需要复杂的依赖分析
- ✅ 性能开销小（只计算两个文件的哈希）

### 3.2 缓存文件格式

**缓存文件**: `.docker_base_cache.json`

**格式**:
```json
{
  "hash": "a1b2c3d4e5f6...-1a2b3c4d5e6f...",
  "timestamp": "2026-02-24T18:50:00Z"
}
```

**存储位置**: 项目根目录

### 3.3 触发条件

| 变化类型 | 是否触发重建 | 说明 |
|---------|------------|------|
| 修改 Dockerfile.ubuntu24-base | ✅ 是 | Dockerfile 哈希变化 |
| 修改 requirements.txt | ✅ 是 | requirements.txt 哈希变化 |
| 修改应用代码 | ❌ 否 | 不影响基础镜像 |
| 修改 Dockerfile.ubuntu24-apt | ❌ 否 | 只影响应用镜像 |

---

## 四、验证方法

### 4.1 测试场景 1：修改 requirements.txt

```powershell
# 1. 修改 requirements.txt，新增一个包
echo "pytest==7.4.0" >> docker\rk3588\tts_engines\paddlespeech\requirements.txt

# 2. 运行构建脚本
.\build-ubuntu24-apt.ps1 185

# 3. 预期输出
# [!] Base Dockerfile or requirements.txt changed - rebuild required
# Building base image (this happens ONCE)...
```

### 4.2 测试场景 2：不修改任何文件

```powershell
# 1. 不修改任何文件
# 2. 运行构建脚本
.\build-ubuntu24-apt.ps1 185

# 3. 预期输出
# [✓] Base image is up to date
# Skipping base image build...
```

### 4.3 测试场景 3：只修改 Dockerfile

```powershell
# 1. 修改 Dockerfile.ubuntu24-base，添加注释
# 2. 运行构建脚本
.\build-ubuntu24-apt.ps1 185

# 3. 预期输出
# [!] Base Dockerfile or requirements.txt changed - rebuild required
# Building base image (this happens ONCE)...
```

---

## 五、影响分析

### 5.1 正面影响

1. **修复关键 bug**：
   - ✅ 修改 requirements.txt 会正确触发重建
   - ✅ 避免应用因缺少依赖而失败
   - ✅ 确保依赖版本与 requirements.txt 一致

2. **提高可靠性**：
   - ✅ 缓存键更准确
   - ✅ 减少人为错误（忘记手动重建）
   - ✅ 构建结果更可预测

3. **改善开发体验**：
   - ✅ 开发者只需修改 requirements.txt
   - ✅ 脚本自动检测并重建
   - ✅ 不需要手动清理缓存

### 5.2 负面影响

1. **构建频率增加**：
   - ⚠️ 修改 requirements.txt 会触发 80-90 分钟的重建
   - ⚠️ 但这是**必要的**，否则依赖不会更新

2. **缓存失效更频繁**：
   - ⚠️ 之前可能"侥幸"跳过重建的情况，现在会正确重建
   - ⚠️ 但这是**正确的行为**

### 5.3 缓解措施

如果觉得重建时间太长，可以：

1. **使用 BuildKit 缓存挂载**（推荐）：
   - 修改 Dockerfile，使用 `--mount=type=cache`
   - 去掉 `--no-cache-dir`
   - 重建时只需 20-30 分钟

2. **分层安装依赖**：
   - 拆分 requirements.txt 为多个文件
   - 核心依赖很少变，不会触发重建
   - 只有新增的依赖会触发重建

详见：[09-Docker镜像构建断点续传机制.md](09-Docker镜像构建断点续传机制.md)

---

## 六、后续优化建议

### 6.1 短期优化（可选）

如果需要进一步优化，可以：

1. **更细粒度的缓存键**：
   ```powershell
   # 只包含实际使用的 requirements 文件
   $requirementsFiles = @(
       "docker\rk3588\tts_engines\paddlespeech\requirements.txt",
       "docker\rk3588\tts_engines\paddlespeech\requirements-extra.txt"
   )
   ```

2. **缓存键版本化**：
   ```powershell
   # 添加版本号，方便强制重建
   $currentBaseHash = "v2-$dockerfileHash-$requirementsHash"
   ```

### 6.2 中期优化（推荐）

实施 BuildKit 缓存挂载：
1. 修改 Dockerfile，使用 `--mount=type=cache`
2. 去掉 `--no-cache-dir`
3. 启用 BuildKit：`$env:DOCKER_BUILDKIT=1`

**效果**：
- ✅ 重建时间从 80-90 分钟降到 20-30 分钟
- ✅ 即使缓存失效，也能复用下载的包

### 6.3 长期优化（最优）

实施完整的分层安装方案：
1. 拆分 requirements.txt 为多个文件
2. 每个文件对应一个 Docker 层
3. 修改一层不影响其他层

**效果**：
- ✅ 修改 MeloTTS 不影响 PaddleSpeech
- ✅ 失败不影响前面的层
- ✅ 最大化缓存复用

---

## 七、相关文档

- **Codex 审查**: [.codex/08-Docker镜像构建缓存优化方案-审查.md](.codex/08-Docker镜像构建缓存优化方案-审查.md)
- **缓存优化方案**: [08-Docker镜像构建缓存优化方案.md](08-Docker镜像构建缓存优化方案.md)
- **断点续传机制**: [09-Docker镜像构建断点续传机制.md](09-Docker镜像构建断点续传机制.md)
- **tokenizers 修复**: [10-Phase7.46.47-修复tokenizers编译失败.md](10-Phase7.46.47-修复tokenizers编译失败.md)

---

## 八、总结

### 8.1 问题根因

- `build-ubuntu24-apt.ps1` 只检查 Dockerfile 变化
- 不检查 requirements.txt 变化
- 修改 requirements.txt 不会触发重建

### 8.2 解决方案

- 计算 Dockerfile + requirements.txt 的联合哈希
- 任一文件变化都会触发重建
- 确保依赖与 requirements.txt 一致

### 8.3 效果

- ✅ 修复关键 bug，避免依赖缺失
- ✅ 提高构建可靠性和可预测性
- ✅ 改善开发体验，自动检测变化
- ⚠️ 构建频率增加，但这是必要的

### 8.4 下一步

1. 提交代码修改
2. 重新构建基础镜像（这次会正确触发）
3. 验证 requirements.txt 变化会触发重建

---

**文档版本**: v1.0
**最后更新**: 2026-02-24 18:50
**下次更新**: 验证修复效果后
