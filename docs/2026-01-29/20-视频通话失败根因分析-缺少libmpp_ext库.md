# 视频通话失败根因分析 - 缺少 libmpp_ext.so 库

**日期**: 2026-01-29
**状态**: 🔍 根因已确认
**优先级**: ⚠️ 高（视频功能完全失效）

---

## 🐛 问题描述

**用户报告**：
- 本机能显示本机的画面，不能显示对方的画面
- 对方也只能显示本机的画面，不能显示工控机的画面
- 日志显示：`#1 video deactivated`

**错误信息**：
```
07:35:21.030 pjsua_media.c  ......video channel_update failed for call_id 0 media 1:
                                   Codec internal creation error (PJMEDIA_CODEC_EFAILED)
```

---

## 🔍 根因分析

### 1. 错误追踪

**日志 Line 1835**：
```
video channel_update failed for call_id 0 media 1:
Codec internal creation error (PJMEDIA_CODEC_EFAILED)
```

**日志 Line 1828**：
```
🔍 [FIX 100.66 DIAG] dec_ctx=(nil), enc_ctx=(nil)
```

**关键发现**：编解码器上下文根本没有被创建！

### 2. RKMPP 解码器初始化失败

**日志 Line 1739-1741**：
```
mpp[1]: mpp_info: mpp version: b13eb80 author: Herman Chen
        2026-01-08 feat[mpp_ext]: Move parsers to libmpp_ext.so
mpp[1]: mpp_dec: mpp_parser_init parser h264 is not registered
mpp[1]: mpp_dec: mpp_dec_init could not init parser
```

**根本原因**：
1. **MPP 库更新**（2026-01-08）：H.264 解析器被移动到独立的 `libmpp_ext.so` 库
2. **部署缺失**：当前部署缺少 `libmpp_ext.so` 库
3. **初始化失败**：H.264 解析器无法注册，导致解码器初始化失败
4. **编解码器创建失败**：PJSIP 无法创建视频编解码器上下文

### 3. 库文件检查

**设备上的库**（容器内）：
```bash
$ docker exec belt-control-app ls -la /app/lib/libmpp*
# 未找到 libmpp 库

$ docker exec belt-control-app ls -la /app/lib/*mpp*
/app/lib/librockchip_mpp.so
/app/lib/librockchip_mpp.so.0
/app/lib/librockchip_mpp.so.1
# ❌ 缺少 libmpp_ext.so
```

**本地库文件**（rk3588-libs）：
```bash
$ find docker/rk3588/rk3588-libs -name "*mpp*"
docker/rk3588/rk3588-libs/lib/libmpp_ext.so          ✅ 存在
docker/rk3588/rk3588-libs/lib/libmpp_ext.so.0        ✅ 存在
docker/rk3588/rk3588-libs/lib/libmpp_ext.so.1        ✅ 存在
docker/rk3588/rk3588-libs/lib/librockchip_mpp.so     ✅ 存在
docker/rk3588/rk3588-libs/lib/librockchip_mpp.so.0   ✅ 存在
docker/rk3588/rk3588-libs/lib/librockchip_mpp.so.1   ✅ 存在
```

**部署目录**（device-build/libs）：
```bash
$ ls -la docker/rk3588/device-build/libs/ | grep -i mpp
# ❌ 没有任何 MPP 库文件
```

### 4. 问题链条

```
GitHub 回滚 → 重新部署
    ↓
device-build/libs/ 缺少 MPP 库
    ↓
Docker 镜像缺少 libmpp_ext.so
    ↓
RKMPP 解析器无法注册
    ↓
H.264 解码器初始化失败
    ↓
编解码器上下文创建失败 (dec_ctx=nil, enc_ctx=nil)
    ↓
视频通道更新失败 (PJMEDIA_CODEC_EFAILED)
    ↓
视频流被销毁，只有音频
```

---

## ✅ 解决方案

### 方案 1：复制 MPP 库到部署目录（推荐）

**步骤**：
```powershell
# 1. 复制 MPP 库到部署目录
Copy-Item "docker\rk3588\rk3588-libs\lib\libmpp_ext.so*" `
          "docker\rk3588\device-build\libs\" -Force

Copy-Item "docker\rk3588\rk3588-libs\lib\librockchip_mpp.so*" `
          "docker\rk3588\device-build\libs\" -Force

# 2. 验证复制结果
ls docker\rk3588\device-build\libs\*mpp*

# 3. 重新构建和部署
.\build-ubuntu24-apt.ps1 188
```

**预期结果**：
- `libmpp_ext.so` 被包含在 Docker 镜像中
- RKMPP 解析器成功注册
- H.264 解码器正常初始化
- 视频通话恢复正常

### 方案 2：修改 Dockerfile 自动复制（长期方案）

**修改 `docker/rk3588/device-build/Dockerfile`**：
```dockerfile
# Copy runtime libraries
COPY libs/*.so* /opt/app/lib/

# ✅ 2026-01-29 [FIX 视频通话失败] 添加 MPP 库
# 原因：2026-01-08 MPP 更新将解析器移到 libmpp_ext.so
# 缺少此库导致 H.264 解析器无法注册，视频通话失败
COPY rk3588-libs/lib/libmpp_ext.so* /opt/app/lib/
COPY rk3588-libs/lib/librockchip_mpp.so* /opt/app/lib/
```

**优点**：
- 自动化，不会遗漏
- 每次构建都包含最新的 MPP 库

---

## 📊 技术细节

### MPP 库架构变化

**旧版本**（2026-01-08 之前）：
```
librockchip_mpp.so
  ├── 编码器
  ├── 解码器
  └── 解析器（内置）
```

**新版本**（2026-01-08 之后）：
```
librockchip_mpp.so
  ├── 编码器
  └── 解码器

libmpp_ext.so（新增）
  └── 解析器（H.264, H.265, VP8, VP9）
```

### 依赖关系

```
libavcodec.so.60
  └── librockchip_mpp.so.1
      └── libmpp_ext.so.1  ← ❌ 缺失导致解析器无法加载
```

### 错误代码

- **PJMEDIA_CODEC_EFAILED** = 220081
- **含义**：编解码器内部创建错误
- **原因**：RKMPP 解码器初始化失败（解析器未注册）

---

## 🧪 验证步骤

### 1. 修复前验证（确认问题）

```bash
# 检查容器内的库
ssh linaro@192.168.10.188 "docker exec belt-control-app ls -la /app/lib/*mpp*"

# 预期：只有 librockchip_mpp.so，没有 libmpp_ext.so
```

### 2. 修复后验证（确认修复）

```bash
# 检查容器内的库
ssh linaro@192.168.10.188 "docker exec belt-control-app ls -la /app/lib/*mpp*"

# 预期：
# librockchip_mpp.so
# librockchip_mpp.so.0
# librockchip_mpp.so.1
# libmpp_ext.so          ← ✅ 新增
# libmpp_ext.so.0        ← ✅ 新增
# libmpp_ext.so.1        ← ✅ 新增
```

### 3. 功能验证

```bash
# 查看日志，确认解析器注册成功
ssh linaro@192.168.10.188 "docker logs belt-control-app 2>&1 | grep -i 'mpp_parser_init'"

# 预期：不再出现 "parser h264 is not registered" 错误
```

### 4. 视频通话测试

1. 启动应用
2. 拨打视频通话
3. 观察日志：
   - ✅ 不再出现 "PJMEDIA_CODEC_EFAILED"
   - ✅ 视频流创建成功
   - ✅ 双方都能看到对方的视频

---

## 📝 相关文档

- **MPP 版本信息**：b13eb80 (2026-01-08)
- **变更说明**：feat[mpp_ext]: Move parsers to libmpp_ext.so
- **影响范围**：所有使用 RKMPP 硬件解码的视频通话

---

## 🎯 总结

**问题**：视频通话失败，双方只能看到自己的画面

**根因**：
1. GitHub 回滚后重新部署
2. 部署脚本未包含 MPP 库文件
3. 缺少 `libmpp_ext.so` 导致 H.264 解析器无法注册
4. RKMPP 解码器初始化失败
5. 编解码器上下文创建失败

**解决**：
- ✅ 复制 `libmpp_ext.so*` 到 `device-build/libs/`
- ✅ 复制 `librockchip_mpp.so*` 到 `device-build/libs/`
- ✅ 重新构建和部署

**预防**：
- 修改 Dockerfile 自动复制 MPP 库
- 添加部署前检查脚本，验证必要的库文件

---

## 🔄 下一步行动

1. **立即修复**：复制 MPP 库到部署目录
2. **重新部署**：运行 `.\build-ubuntu24-apt.ps1 188`
3. **功能验证**：测试视频通话
4. **长期优化**：修改 Dockerfile 自动化处理
5. **文档更新**：更新部署文档，说明 MPP 库的重要性
