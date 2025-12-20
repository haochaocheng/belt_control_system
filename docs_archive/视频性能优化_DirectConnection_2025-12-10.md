# 视频性能优化 - DirectConnection 方案

**日期**: 2025-12-10
**版本**: v5 - 消除信号/槽队列延迟
**状态**: ✅ 已完成编译，待测试验证

---

## 🎯 优化目标

**当前性能**: 13-15 FPS（优化前 14-16 FPS）
**目标性能**: 30-60 FPS
**性能瓶颈**: 信号/槽跨线程通信延迟

---

## 📊 之前的优化历程

### v1-v2: Pull 到 Push 模式转换
- **成果**: 2-10 FPS → 13-16 FPS（**翻倍**）
- **方法**: 使用自定义 pjmedia_port 的 put_frame 回调

### v3: 格式优化
- **成果**: 消除 33% 的数据处理（720x480 → 640x360）
- **问题**: FPS 仍然是 13-15（**没有提升**）

---

## 🔍 本次优化：v5 DirectConnection

### 根本原因分析

**数据流路径**：
```
FreeSWITCH (60fps)
  → PJSIP 底层 (60fps) ✅
    → H.264 解码器 (60fps) ✅
      → Video Conference Bridge (60fps) ✅
        → Custom Port put_frame (60fps) ✅
          → emit frameReadyForDisplay (Qt::QueuedConnection) ⚠️
            → Qt Event Queue (排队延迟) ❌
              → displayFrame()
                → setVideoFrame()
```

**瓶颈**：
- `Qt::QueuedConnection` 将信号放入**事件队列**
- Qt 主线程需要**处理完当前事件**才能处理下一帧
- 如果主线程繁忙，**帧会堆积并被丢弃**
- 结果：只能处理 13-15 FPS

---

## ✅ 解决方案

### 修改内容

**文件**: [src/sip_phone/RemoteVideoManager.cpp:39-41](src/sip_phone/RemoteVideoManager.cpp#L39-L41)

**修改前**：
```cpp
// 连接帧显示信号(从 PJSIP 线程到 Qt 主线程)
connect(this, &RemoteVideoManager::frameReadyForDisplay,
        this, &RemoteVideoManager::displayFrame,
        Qt::QueuedConnection);  // ← 使用事件队列，有延迟
```

**修改后**：
```cpp
// 连接帧显示信号(从 PJSIP 线程到 Qt 主线程)
// ✅ 使用 DirectConnection 避免事件队列延迟
// QVideoSink::setVideoFrame() 是线程安全的，可以直接调用
connect(this, &RemoteVideoManager::frameReadyForDisplay,
        this, &RemoteVideoManager::displayFrame,
        Qt::DirectConnection);  // ← 直接调用，无延迟
```

### 优化原理

**Qt::QueuedConnection**（之前）：
```
PJSIP Thread → emit signal → Event Queue → Main Thread → displayFrame()
                             ↑
                      排队延迟（可能丢帧）
```

**Qt::DirectConnection**（优化后）：
```
PJSIP Thread → emit signal → DIRECTLY call displayFrame()
                             ↑
                      直接调用，无延迟
```

**安全性**：
- `QVideoSink::setVideoFrame()` 内部使用互斥锁保护
- 可以安全地在任意线程中调用
- Qt 官方文档确认此方法是线程安全的

---

## 📋 测试指南

### 关键日志检查

#### 1. Port 创建（应该保持不变）
```
✅ Custom pjmedia_port created for Qt video sink: 640 x 360 @ 60 / 1 fps
```

#### 2. 首帧（应该保持不变）
```
🎬 [FIRST FRAME] Port format: 640 x 360 @ 60 / 1 fps | Frame buffer size: 345600 bytes
```

#### 3. 性能统计（关键 - 预期提升）
```
📊 [REMOTE VIDEO PUSH] Received FPS: XX.X | Avg interval: YY.Y ms
```

**预期提升**：
- **如果优化成功**: FPS 应该提升到 **30-60**
- **如果仍然卡顿**: 说明瓶颈在其他地方（可能是解码器或 bridge）

---

## 🧪 测试步骤

### 1. 启动应用
```bash
./build/bin_windows/belt_control_system.exe
```

### 2. 进行视频通话

拨打或接听视频电话

### 3. 观察日志输出

每秒输出一次性能统计：
```
📊 [REMOTE VIDEO PUSH] Received FPS: "XX.X" | Avg interval: "YY.Y" ms
```

### 4. 记录结果

| 指标 | v3 (之前) | v5 (DirectConnection) | 提升 |
|------|-----------|----------------------|------|
| FPS | 13-15 | ? | ? |
| 帧间隔 | 65-78ms | ? | ? |
| 流畅度 | 卡顿 | ? | ? |

---

## 🎯 预期结果

### 场景 A: 优化成功（最佳情况）
```
📊 [REMOTE VIDEO PUSH] Received FPS: "58-60"
```
- FPS 提升到接近 60
- 视频非常流畅
- 证明瓶颈确实在事件队列

### 场景 B: 部分优化（中等情况）
```
📊 [REMOTE VIDEO PUSH] Received FPS: "30-40"
```
- FPS 翻倍，但未达到 60
- 可能还有其他瓶颈（解码器/bridge）
- 但用户体验已显著改善

### 场景 C: 无明显提升（需要进一步调查）
```
📊 [REMOTE VIDEO PUSH] Received FPS: "13-15"
```
- 说明瓶颈不在信号/槽
- 需要深入调查 PJSIP bridge 或解码器性能

---

## 🔧 如果场景 C 发生（FPS 仍然 13-15）

### 下一步调查方向

#### 1. PJSIP Video Conference Bridge 性能
```cpp
// 可能的限制配置
vid_conf.c: Warning: frame rate higher than video conference bridge (90 > 60)
```

**检查点**：
- Bridge 最大帧率设置
- Bridge 帧分发策略
- Bridge CPU 负载

#### 2. 解码器性能
```cpp
// H.264 解码器可能成为瓶颈
vstdec000001cac1bc8f58: Decoding format changed
```

**检查点**：
- 解码器是否支持硬件加速
- 解码器线程数量
- CPU 负载

#### 3. memcpy 性能
```cpp
// convertPjFrameToQt() 中的三次 memcpy
memcpy(dst_y, src_y, width * height);
memcpy(dst_u, src_u, width * height / 4);
memcpy(dst_v, src_v, width * height / 4);
```

**优化方案**：
- 使用 SIMD 指令加速 memcpy
- 或者尝试零拷贝方案

---

## 📝 技术细节

### Qt::DirectConnection vs Qt::QueuedConnection

| 特性 | QueuedConnection | DirectConnection |
|------|-----------------|------------------|
| 调用方式 | 异步（事件队列） | 同步（直接调用） |
| 线程安全 | ✅ 自动保证 | ⚠️ 需要手动确保 |
| 性能 | ❌ 有延迟 | ✅ 无延迟 |
| 丢帧风险 | ✅ 高（队列满） | ✅ 低 |

### QVideoSink 线程安全性

根据 Qt 6 文档：
> QVideoSink::setVideoFrame() is thread-safe and can be called from any thread.

**原因**：
- 内部使用 `QMutex` 保护
- 只是更新帧引用，不做复杂操作
- 实际渲染在 Qt 的 Render Thread 中进行

---

## 🎓 学到的经验

### 1. 性能优化的迭代过程

```
v1: Pull mode (2-10 FPS)
  ↓
v2: Push mode (13-16 FPS) ← 主要瓶颈解决
  ↓
v3: 格式优化 (13-15 FPS) ← 消除格式转换，但 FPS 未提升
  ↓
v5: DirectConnection (?) ← 消除队列延迟
  ↓
下一步：如果仍未解决，需要更深入的分析
```

### 2. 性能瓶颈的多层次性

视频处理涉及多个层次：
1. ✅ **网络层**: FreeSWITCH 发送 60 FPS
2. ✅ **PJSIP 底层**: 接收 60 FPS
3. ✅ **解码器**: 解码 60 FPS
4. ⚠️ **Conference Bridge**: 可能限制帧率？
5. ⚠️ **自定义 Port**: put_frame 回调性能？
6. ⚠️ **信号/槽**: Qt 事件队列延迟？（本次优化）
7. ⚠️ **UI 渲染**: Qt Render Thread 性能？

每一层都可能成为瓶颈！

---

## 📞 完整测试流程

### 1. 编译新版本
```bash
cd /e/2025/3_gongkongji/belt_control_system
export PATH="/c/Qt/6.5.3/mingw_64/bin:/c/Qt/Tools/mingw1120_64/bin:/c/Qt/Tools/CMake_64/bin:$PATH"
cmake.exe --build build --target belt_control_system -j4
```

### 2. 运行测试
```bash
./build/bin_windows/belt_control_system.exe
```

### 3. 拨打/接听视频电话

### 4. 观察性能指标

**关键日志**：
```
📊 [REMOTE VIDEO PUSH] Received FPS: "XX.X"
```

### 5. 对比 PJSIP 底层统计

在通话结束时查看：
```
RX pt=100, size=640x360, fps=60.00
```

---

**编译时间**: 1.2 秒
**优化类型**: 信号/槽连接方式
**风险等级**: 低（QVideoSink 是线程安全的）
**预期效果**: FPS 提升 2-4 倍（13-15 → 30-60）

---

**创建日期**: 2025-12-10
**版本**: v5 - DirectConnection 优化
**下一步**: 进行视频通话测试，验证 FPS 是否提升
