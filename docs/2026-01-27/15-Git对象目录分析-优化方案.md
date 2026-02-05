# Git 对象目录分析 - .git/objects 占用 4.5GB

**日期**: 2026-01-27 19:05
**问题**: .git/objects 目录占用 4.5GB 空间

## 📊 分析结果

### 总体统计

```
松散对象 (loose objects): 2,982 个，占用 1.53 GB
打包对象 (packed objects): 33,289 个，占用 2.51 GB
打包文件数量: 16 个
总大小: 约 4.04 GB
```

### 🔍 占用空间最大的文件

| 大小 (MB) | 文件路径 | 说明 |
|----------|---------|------|
| 11.67 MB | libs/pjsip/libpjsua2-x86_64-w64-mingw32.a | PJSIP 静态库 (MinGW) |
| 11.07 MB | libs/pjsip/libpjsua2-x86_64-pc-mingw32.a | PJSIP 静态库 (MinGW) |
| 10.44 MB | src/tts_service/build-msvc/Release/onnxruntime.dll | TTS 运行时 DLL |
| 3.60 MB | src/tts_service/build-msvc/Release/sherpa-onnx-c-api.dll | TTS API DLL |
| 1.69 MB | libs/pjsip/libyuv-x86_64-pc-mingw32.a | YUV 库 |
| 1.27 MB | src/qml/Input1/Input1Content/images/path_background.png | 背景图片 |

### 📁 文件类型统计

| 扩展名 | 数量 | 总大小 (MB) | 说明 |
|-------|------|------------|------|
| .a | 42 | 33.09 MB | 静态库文件 |
| .dll | 5 | 14.37 MB | 动态链接库 |
| .md | 458 | 4.75 MB | 文档文件 |
| .cpp | 152 | 4.31 MB | C++ 源码 |
| .qml | 279 | 3.54 MB | QML 界面文件 |
| .png | 26 | 3.05 MB | 图片文件 |
| .ps1 | 116 | 1.87 MB | PowerShell 脚本 |

## 🔍 问题分析

### 1. 为什么 .git/objects 这么大？

**.git/objects** 目录存储了：
- **所有提交历史**：每次 `git commit` 都会创建新对象
- **所有文件版本**：修改过的文件的所有历史版本
- **大文件历史**：即使删除了大文件，历史记录仍然保留

### 2. 主要占用空间的原因

#### 原因 1: 大型二进制文件被提交到 Git

**问题文件**：
- `libpjsua2-*.a` (11-12 MB) - PJSIP 静态库
- `onnxruntime.dll` (10 MB) - TTS 运行时
- `sherpa-onnx-c-api.dll` (3.6 MB) - TTS API

**影响**：
- 这些文件每次修改都会创建新版本
- 所有历史版本都保存在 .git/objects 中
- 导致仓库体积快速增长

#### 原因 2: 多次提交和修改

**统计数据**：
- 33,289 个打包对象
- 2,982 个松散对象
- 16 个打包文件

**说明**：
- 大量的提交历史（您提到有 121 个提交）
- 每次提交都会保存文件快照
- 多次修改大文件会成倍增加空间占用

#### 原因 3: 未优化的 Git 存储

**问题**：
- 16 个打包文件（正常应该只有 1-2 个）
- 2,982 个松散对象（应该定期打包）

**原因**：
- 没有运行 `git gc`（垃圾回收）
- 没有优化存储结构

## 💡 优化方案

### 方案 1: 运行 Git 垃圾回收（推荐，安全）

```powershell
# 清理松散对象，优化打包文件
git gc --aggressive --prune=now
```

**效果**：
- 合并多个打包文件为 1 个
- 删除不可达的对象
- 优化存储结构
- **预计减少 20-30% 空间**

**优点**：
- ✅ 安全，不会丢失数据
- ✅ 简单，一条命令
- ✅ 保留所有历史

**缺点**：
- ❌ 不会移除大文件历史
- ❌ 空间减少有限

### 方案 2: 使用 .gitignore 防止提交大文件（预防）

**创建/更新 .gitignore**：
```gitignore
# 静态库文件
*.a
*.lib

# 动态链接库
*.dll
*.so
*.dylib

# 编译产物
*.obj
*.o
build-msvc/
build_rk3588/

# 大型资源文件
*.tar
*.gz
*.zip
*.7z
```

**效果**：
- 防止将来提交大文件
- 不影响已提交的文件

### 方案 3: 移除大文件历史（高级，需谨慎）

⚠️ **警告**：此操作会重写 Git 历史，需要所有协作者重新克隆仓库！

#### 步骤 1: 安装 git-filter-repo

```powershell
# 使用 pip 安装
pip install git-filter-repo
```

#### 步骤 2: 移除大文件

```powershell
# 移除 PJSIP 静态库历史
git filter-repo --path libs/pjsip/libpjsua2-x86_64-w64-mingw32.a --invert-paths
git filter-repo --path libs/pjsip/libpjsua2-x86_64-pc-mingw32.a --invert-paths

# 移除 TTS DLL 历史
git filter-repo --path src/tts_service/build-msvc/Release/onnxruntime.dll --invert-paths
git filter-repo --path src/tts_service/build-msvc/Release/sherpa-onnx-c-api.dll --invert-paths
```

#### 步骤 3: 强制推送

```powershell
git push origin --force --all
```

**效果**：
- **预计减少 50-70% 空间**
- 移除大文件的所有历史版本

**优点**：
- ✅ 大幅减少仓库体积
- ✅ 彻底解决问题

**缺点**：
- ❌ 重写历史，需要协作者重新克隆
- ❌ 丢失大文件的历史记录
- ❌ 操作复杂，有风险

### 方案 4: 使用 Git LFS 管理大文件（最佳实践）

**Git LFS** (Large File Storage) 专门用于管理大文件。

#### 步骤 1: 安装 Git LFS

```powershell
# 下载并安装 Git LFS
# https://git-lfs.github.com/

# 初始化
git lfs install
```

#### 步骤 2: 配置 LFS 跟踪大文件

```powershell
# 跟踪静态库
git lfs track "*.a"
git lfs track "*.lib"

# 跟踪动态库
git lfs track "*.dll"
git lfs track "*.so"

# 跟踪大图片
git lfs track "*.png" --lockable
```

#### 步骤 3: 提交 .gitattributes

```powershell
git add .gitattributes
git commit -m "chore: 配置 Git LFS 管理大文件"
```

**效果**：
- 大文件存储在 LFS 服务器
- 本地仓库只保存指针文件（几 KB）
- **仓库体积减少 90%+**

**优点**：
- ✅ 最佳实践
- ✅ 大幅减少仓库体积
- ✅ 保留所有历史
- ✅ 支持大文件版本管理

**缺点**：
- ❌ 需要 LFS 服务器支持
- ❌ 需要迁移现有大文件

## 📋 推荐操作步骤

### 立即执行（安全）

```powershell
# Step 1: 运行垃圾回收
git gc --aggressive --prune=now

# Step 2: 查看效果
git count-objects -vH
```

### 短期优化（预防）

```powershell
# Step 1: 更新 .gitignore
# 添加 *.a, *.dll, build-msvc/ 等

# Step 2: 移除已跟踪的大文件
git rm --cached libs/pjsip/*.a
git rm --cached src/tts_service/build-msvc/Release/*.dll

# Step 3: 提交
git commit -m "chore: 移除大文件，添加到 .gitignore"
```

### 长期方案（最佳）

```powershell
# 使用 Git LFS 管理大文件
# 参考方案 4
```

## ⚠️ 注意事项

### 1. 备份重要数据

在执行任何清理操作前：
```powershell
# 备份整个仓库
Copy-Item "e:\2025\3_gongkongji\belt_control_system" "e:\2025\3_gongkongji\belt_control_system_backup" -Recurse
```

### 2. 协作者影响

如果使用方案 3（移除历史）：
- 所有协作者需要重新克隆仓库
- 提前通知团队成员
- 确保所有人都推送了未提交的工作

### 3. 远程仓库

如果使用方案 3：
- 需要强制推送 (`git push --force`)
- 可能需要联系仓库管理员
- 确保有权限执行强制推送

## 📊 预期效果

| 方案 | 空间减少 | 风险 | 难度 | 推荐度 |
|-----|---------|------|------|--------|
| 方案 1: git gc | 20-30% | 低 | 低 | ⭐⭐⭐⭐⭐ |
| 方案 2: .gitignore | 0% (预防) | 低 | 低 | ⭐⭐⭐⭐⭐ |
| 方案 3: filter-repo | 50-70% | 高 | 高 | ⭐⭐⭐ |
| 方案 4: Git LFS | 90%+ | 中 | 中 | ⭐⭐⭐⭐ |

## 🎯 建议

### 当前情况

您的仓库：
- 总大小：4.5 GB
- 主要问题：大型二进制文件（静态库、DLL）
- 提交数量：121 个

### 推荐方案

**立即执行**：
1. ✅ 运行 `git gc --aggressive --prune=now`（方案 1）
2. ✅ 更新 `.gitignore`，排除大文件（方案 2）

**短期优化**：
3. ✅ 移除已跟踪的大文件（`git rm --cached`）
4. ✅ 将大文件移到外部存储（如 J 盘备份）

**长期方案**：
5. ⭐ 考虑使用 Git LFS 管理大文件（方案 4）

### 不推荐

- ❌ 暂时不使用方案 3（移除历史）
- 原因：风险高，需要重写历史

## 📝 相关文档

- Git 垃圾回收：https://git-scm.com/docs/git-gc
- Git LFS：https://git-lfs.github.com/
- git-filter-repo：https://github.com/newren/git-filter-repo

## 🔧 分析脚本

已创建分析脚本：[scripts/2026-01-27/01-analyze-git-objects.ps1](../../scripts/2026-01-27/01-analyze-git-objects.ps1)

**使用方法**：
```powershell
.\scripts\2026-01-27\01-analyze-git-objects.ps1
```

## 总结

**.git/objects 目录占用 4.5GB 是正常的**，因为：
1. 存储了所有提交历史（121 个提交）
2. 包含大型二进制文件的所有版本
3. 未进行存储优化

**建议立即执行**：
```powershell
# 优化存储，减少 20-30% 空间
git gc --aggressive --prune=now
```

**长期方案**：
- 使用 `.gitignore` 排除大文件
- 考虑使用 Git LFS 管理二进制文件
