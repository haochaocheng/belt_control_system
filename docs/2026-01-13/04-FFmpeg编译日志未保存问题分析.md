# FFmpeg 编译日志未保存问题分析

**日期**: 2026-01-13 09:30（北京时间）
**问题**: FFmpeg 编译日志留在容器内，未保存到主机系统

---

## 📋 问题描述

### 现状

**FFmpeg 编译流程**：
1. 在 Docker 容器 `ffmpeg-builder-ubuntu24` 内编译
2. 日志保存在容器内：
   - `/tmp/configure.log` - 配置日志
   - `/tmp/make.log` - 编译日志（最重要）
   - `/tmp/install.log` - 安装日志
   - `/tmp/incremental_compile.log` - 增量编译日志
   - `/tmp/link.log` - 链接日志

**问题**：
- ❌ 编译成功后，日志留在容器内，无法方便查看
- ❌ 容器重启/删除后，日志丢失
- ❌ 无法归档到项目的日志管理系统

**影响**：
- 无法追溯编译过程
- 无法分析编译警告/错误
- 不符合项目日志管理规范

---

## 🔍 根本原因

### 脚本分析

#### 1. `compile-ffmpeg60-in-container.ps1`（完整编译）

**Line 343-364**：编译过程
```bash
make -j8 2>&1 | tee /tmp/make.log &
```
- ✅ 日志正确保存到容器内 `/tmp/make.log`
- ❌ 没有复制到主机系统

**Line 375-379**：安装过程
```bash
make install DESTDIR=/output 2>&1 | tee /tmp/install.log
```
- ✅ 日志正确保存到容器内 `/tmp/install.log`
- ❌ 没有复制到主机系统

**Line 417-419**：失败时提示
```powershell
Write-Host "    docker exec $ContainerName cat /tmp/make.log" -ForegroundColor Gray
```
- ⚠️ 只有失败时才提示查看日志
- ⚠️ 成功时日志被忽略

#### 2. `incremental-compile-rkmppenc.ps1`（增量编译）

**Line 89-98**：增量编译
```bash
make libavcodec/rkmppenc.o 2>&1 | tee /tmp/incremental_compile.log
```

**Line 110-119**：链接
```bash
make libavcodec/libavcodec.so 2>&1 | tee /tmp/link.log
```

**Line 171-175**：失败时提示
```powershell
Write-Host "    docker exec $ContainerName cat /tmp/incremental_compile.log"
Write-Host "    docker exec $ContainerName cat /tmp/link.log"
```

**结论**：两个脚本都只关注失败情况，成功时日志被忽略。

---

## ✅ 解决方案

### 方案设计

**自动保存日志到主机系统**：
```
容器内日志                  →  主机日志目录
/tmp/configure.log         →  logs/ffmpeg-compile-YYYYMMDD-HHmmss-configure.log
/tmp/make.log              →  logs/ffmpeg-compile-YYYYMMDD-HHmmss-make.log
/tmp/install.log           →  logs/ffmpeg-compile-YYYYMMDD-HHmmss-install.log
/tmp/incremental_compile.log → logs/ffmpeg-incremental-YYYYMMDD-HHmmss-compile.log
/tmp/link.log              →  logs/ffmpeg-incremental-YYYYMMDD-HHmmss-link.log
```

**日志文件命名规范**：
```
ffmpeg-[类型]-[时间戳]-[阶段].log

类型：
  - compile: 完整编译
  - incremental: 增量编译

阶段：
  - configure: FFmpeg 配置
  - make: 编译
  - link: 链接
  - install: 安装
```

---

## 📝 实施方案

### Fix 100.82：自动保存 FFmpeg 编译日志

#### 修改 1：`compile-ffmpeg60-in-container.ps1`

**在编译成功后添加日志保存步骤**（Line 420 之后）：

```powershell
# ⚠️ 2026-01-13 Fix 100.82: 保存编译日志到主机系统
Write-Host ""
Write-Host "Step 5: 保存编译日志..." -ForegroundColor Yellow

$LogsDir = "$ProjectRoot\logs"
if (-not (Test-Path $LogsDir)) {
    New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogPrefix = "ffmpeg-compile-$Timestamp"

# 保存配置日志
Write-Host "  保存 configure.log ..." -ForegroundColor Gray
docker exec $ContainerName test -f /tmp/configure.log
if ($LASTEXITCODE -eq 0) {
    docker cp "${ContainerName}:/tmp/configure.log" "$LogsDir\$LogPrefix-configure.log"
    Write-Host "    ✅ $LogsDir\$LogPrefix-configure.log" -ForegroundColor Green
}

# 保存编译日志（最重要）
Write-Host "  保存 make.log ..." -ForegroundColor Gray
docker exec $ContainerName test -f /tmp/make.log
if ($LASTEXITCODE -eq 0) {
    docker cp "${ContainerName}:/tmp/make.log" "$LogsDir\$LogPrefix-make.log"
    $logSize = [math]::Round((Get-Item "$LogsDir\$LogPrefix-make.log").Length / 1KB, 2)
    Write-Host "    ✅ $LogsDir\$LogPrefix-make.log ($logSize KB)" -ForegroundColor Green
}

# 保存安装日志
Write-Host "  保存 install.log ..." -ForegroundColor Gray
docker exec $ContainerName test -f /tmp/install.log
if ($LASTEXITCODE -eq 0) {
    docker cp "${ContainerName}:/tmp/install.log" "$LogsDir\$LogPrefix-install.log"
    Write-Host "    ✅ $LogsDir\$LogPrefix-install.log" -ForegroundColor Green
}

Write-Host ""
Write-Host "  ✅ 编译日志已保存到: $LogsDir" -ForegroundColor Green
Write-Host ""
```

#### 修改 2：`incremental-compile-rkmppenc.ps1`

**在增量编译成功后添加日志保存步骤**（Line 180 之后）：

```powershell
# ⚠️ 2026-01-13 Fix 100.82: 保存增量编译日志到主机系统
Write-Host ""
Write-Host "Step 4.5: 保存增量编译日志..." -ForegroundColor Yellow

$LogsDir = "$ProjectRoot\logs"
if (-not (Test-Path $LogsDir)) {
    New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogPrefix = "ffmpeg-incremental-$Timestamp"

# 保存编译日志
Write-Host "  保存 incremental_compile.log ..." -ForegroundColor Gray
docker exec $ContainerName test -f /tmp/incremental_compile.log
if ($LASTEXITCODE -eq 0) {
    docker cp "${ContainerName}:/tmp/incremental_compile.log" "$LogsDir\$LogPrefix-compile.log"
    Write-Host "    ✅ $LogsDir\$LogPrefix-compile.log" -ForegroundColor Green
}

# 保存链接日志
Write-Host "  保存 link.log ..." -ForegroundColor Gray
docker exec $ContainerName test -f /tmp/link.log
if ($LASTEXITCODE -eq 0) {
    docker cp "${ContainerName}:/tmp/link.log" "$LogsDir\$LogPrefix-link.log"
    Write-Host "    ✅ $LogsDir\$LogPrefix-link.log" -ForegroundColor Green
}

# 保存安装日志
Write-Host "  保存 install.log ..." -ForegroundColor Gray
docker exec $ContainerName test -f /tmp/install.log
if ($LASTEXITCODE -eq 0) {
    docker cp "${ContainerName}:/tmp/install.log" "$LogsDir\$LogPrefix-install.log"
    Write-Host "    ✅ $LogsDir\$LogPrefix-install.log" -ForegroundColor Green
}

Write-Host ""
Write-Host "  ✅ 增量编译日志已保存到: $LogsDir" -ForegroundColor Green
Write-Host ""
```

---

## 🔧 实施步骤

### Step 1: 备份原脚本

```powershell
$BackupTime = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item "scripts\2026-01-02\compile-ffmpeg60-in-container.ps1" "scripts\2026-01-02\compile-ffmpeg60-in-container.ps1.backup-$BackupTime"
Copy-Item "scripts\2026-01-13\incremental-compile-rkmppenc.ps1" "scripts\2026-01-13\incremental-compile-rkmppenc.ps1.backup-$BackupTime"
```

### Step 2: 修改脚本

使用 VS Code 编辑器打开两个脚本文件，按照上面的方案添加日志保存代码。

### Step 3: 测试

```powershell
# 测试增量编译（快速测试）
.\scripts\2026-01-13\incremental-compile-rkmppenc.ps1

# 检查日志是否生成
ls logs\ffmpeg-incremental-*.log
```

---

## 📊 验证点

### 1. 日志文件生成

**检查 logs/ 目录**：
```powershell
Get-ChildItem logs\ -Filter "ffmpeg-*.log" | Select-Object Name, Length, LastWriteTime
```

**预期**：
- ✅ `ffmpeg-compile-YYYYMMDD-HHmmss-configure.log`
- ✅ `ffmpeg-compile-YYYYMMDD-HHmmss-make.log`
- ✅ `ffmpeg-compile-YYYYMMDD-HHmmss-install.log`
- ✅ `ffmpeg-incremental-YYYYMMDD-HHmmss-compile.log`
- ✅ `ffmpeg-incremental-YYYYMMDD-HHmmss-link.log`
- ✅ `ffmpeg-incremental-YYYYMMDD-HHmmss-install.log`

### 2. 日志内容完整性

**查看日志**：
```powershell
# 查看最新的编译日志
Get-Content logs\ffmpeg-incremental-*-compile.log | Select-Object -Last 20
```

**预期**：
- ✅ 显示编译输出
- ✅ 包含成功/失败信息
- ✅ UTF-8 编码正确

### 3. 容器日志清理（可选）

**编译完成后清理容器内旧日志**：
```bash
docker exec ffmpeg-builder-ubuntu24 rm -f /tmp/*.log
```

---

## 💡 额外优化

### 1. 日志压缩（大文件）

如果 make.log 太大（>10MB），可以自动压缩：
```powershell
$logFile = "$LogsDir\$LogPrefix-make.log"
if ((Get-Item $logFile).Length -gt 10MB) {
    Compress-Archive -Path $logFile -DestinationPath "$logFile.zip" -Force
    Remove-Item $logFile
    Write-Host "    📦 日志已压缩: $logFile.zip" -ForegroundColor Cyan
}
```

### 2. 旧日志清理（保留最近 10 次）

```powershell
Get-ChildItem $LogsDir -Filter "ffmpeg-*.log" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -Skip 30 |
    Remove-Item -Force
```

### 3. 日志摘要生成

编译成功后自动生成摘要：
```powershell
# 提取编译统计信息
$makeLog = Get-Content "$LogsDir\$LogPrefix-make.log"
$warnings = ($makeLog | Select-String "warning:").Count
$errors = ($makeLog | Select-String "error:").Count

Write-Host "  📊 编译统计:" -ForegroundColor White
Write-Host "     警告: $warnings" -ForegroundColor $(if ($warnings -gt 0) { "Yellow" } else { "Green" })
Write-Host "     错误: $errors" -ForegroundColor $(if ($errors -gt 0) { "Red" } else { "Green" })
```

---

## 📚 参考

- 完整编译脚本：`scripts/2026-01-02/compile-ffmpeg60-in-container.ps1`
- 增量编译脚本：`scripts/2026-01-13/incremental-compile-rkmppenc.ps1`
- 日志目录：`logs/`
- 项目规范：`CLAUDE.md` - 文档和脚本存放规则

---

## 🎯 预期效果

实施 Fix 100.82 后：

✅ **编译成功时自动保存日志**
✅ **日志归档到 logs/ 目录**
✅ **时间戳命名便于追溯**
✅ **容器重启不影响日志保存**
✅ **符合项目日志管理规范**

---

**立即实施 Fix 100.82，建立完善的日志归档系统！** 🚀
