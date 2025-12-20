# Risip SDK 完全重构完成 - 最终版

## 日期
2025-12-09 14:50

## 重构状态
✅ **完全重构成功，编译通过，等待测试**

---

## 重构策略

### 用户要求
"不要保守策略，任务对长期使用有保证的方案执行"

### 实施方案
**完全统一架构** - 视频和语音通话都使用 Risip 统一 API，不再有两套代码路径。

---

## 重构内容

### 阶段 1: 扩展 Risip SDK ✅

#### 1.1 添加 enableVideo 属性

**文件**: [src/risip/core/risipcall.h](src/risip/core/risipcall.h), [src/risip/core/risipcall.cpp](src/risip/core/risipcall.cpp)

```cpp
class RisipCall {
    Q_PROPERTY(bool enableVideo READ enableVideo WRITE setEnableVideo NOTIFY enableVideoChanged)

    bool enableVideo() const;
    void setEnableVideo(bool enable);
};
```

#### 1.2 修改 call() 和 invite() 支持视频

**关键修复**: 使用正确的 PJSUA2 API 字段名

**文件**: [src/risip/core/risipcall.cpp:368-374](src/risip/core/risipcall.cpp#L368-L374)

```cpp
void RisipCall::call()
{
    // ...
    CallOpParam prm(true);

    if (m_data->enableVideo) {
        prm.opt.videoCount = 1;  // ✅ PJSUA2 API（不是 vid_cnt）
        prm.opt.audioCount = 1;  // 同时启用音频
        prm.opt.flag |= PJSUA_CALL_INCLUDE_DISABLED_MEDIA;
        qDebug() << "✅ RisipCall: Enabling video for outgoing call";
    }

    try {
        m_data->pjsipCall->makeCall(m_data->buddy->uri().toStdString(), prm);
    } catch (Error err) {
        setError(err);
    }
}
```

**重要**: PJSUA (C API) 使用 `vid_cnt`，PJSUA2 (C++ API) 使用 `videoCount`。

#### 1.3 添加统一 API

**文件**: [src/risip/core/risipcallmanager.h](src/risip/core/risipcallmanager.h)

```cpp
// ⭐ 新增：视频通话 API (统一架构，支持视频+语音)
Q_INVOKABLE risip::RisipCall *callPhoneWithVideo(const QString &number, bool enableVideo = false);
Q_INVOKABLE risip::RisipCall *callBuddyWithVideo(RisipBuddy *buddy, bool enableVideo = false);
```

**文件**: [src/risip/core/risipcallmanager.cpp:241-282](src/risip/core/risipcallmanager.cpp#L241-L282)

```cpp
RisipCall *RisipCallManager::callPhoneWithVideo(const QString &number, bool enableVideo)
{
    if(number.isNull())
        return NULL;

    RisipBuddy *buddy = new RisipBuddy(this);
    buddy->setAccount(activeAccount());
    buddy->setContact(number);
    buddy->setType(RisipBuddy::Pstn);

    return callBuddyWithVideo(buddy, enableVideo);
}

RisipCall *RisipCallManager::callBuddyWithVideo(RisipBuddy *buddy, bool enableVideo)
{
    if(!buddy || !m_data->m_activeAccount)
        return new RisipCall(this);

    RisipCall *call = new RisipCall(this);
    call->setBuddy(buddy);
    call->setAccount(m_data->m_activeAccount);
    call->setEnableVideo(enableVideo);  // ⭐ 必须在 call() 之前
    call->call();  // 此时会根据 enableVideo 设置 CallOpParam
    emit outgoingCall(call);

    // ✅ 自动添加历史记录
    qobject_cast<RisipCallHistoryModel *>(m_data->m_activeCallHistoryModel)->addCallRecord(call);
    setActiveCall(call);

    qDebug() << "✅ RisipCallManager: Call initiated via unified API, video =" << enableVideo;

    return call;
}
```

### 阶段 2: 完全重构 SipPhoneManager ✅

#### 2.1 代码对比

**之前** (~200 行，两套代码路径):
```cpp
void SipPhoneManager::makeCall(const QString &number, bool enableVideo)
{
    // 检查状态...

    if (enableVideo) {
        // ❌ 100+ 行直接使用 PJSIP C API
        pjsua_acc_id acc_id = ...;
        pjsua_call_make_call(acc_id, &uri, &call_opt, NULL, NULL, &call_id);

        // 手动创建 Buddy
        // 手动创建 RisipCall
        // 手动设置 callDirection
        // 手动添加历史记录
        // ...
    } else {
        // ✅ 使用 Risip API
        d->currentCall = callManager->callPhone(number);
    }
}
```

**之后** (~70 行，单一代码路径):
```cpp
void SipPhoneManager::makeCall(const QString &number, bool enableVideo)
{
    // 检查状态...

    // 配置视频设备（仅视频通话）
    if (enableVideo) {
        configureAccountVideoDevice(accountUri);
    }

    // ⭐ 统一使用 Risip API（视频 + 语音）
    d->currentCall = callManager->callPhoneWithVideo(number, enableVideo);

    // ✅ 历史记录自动添加
    // ✅ callDirection 自动设置
    // ✅ 信号连接
    connect(d->currentCall, &risip::RisipCall::statusChanged, this, [this, enableVideo]() {
        handleCallStatusChange(enableVideo);
    });

    qDebug() << "✅ Call initiated via unified Risip API, video =" << enableVideo;
}
```

#### 2.2 删除的代码（~130 行）

- ❌ 获取 PJSIP account ID 的代码（~20 行）
- ❌ 构建 SIP URI 的代码（~10 行）
- ❌ 直接调用 `pjsua_call_make_call` 的代码（~10 行）
- ❌ 手动创建 Buddy 对象的代码（~5 行）
- ❌ 手动创建 RisipCall 对象的代码（~5 行）
- ❌ 手动设置 callDirection 的代码（~3 行）
- ❌ 手动添加历史记录的代码（~20 行）
- ❌ 异常处理和回退逻辑（~30 行）
- ❌ 重复的状态更新代码（~10 行）

#### 2.3 保留的关键功能

✅ **视频设备配置** - `configureAccountVideoDevice()` 在视频通话前调用
✅ **视频编码器自动启动** - PJSIP 的 `vid_out_auto_transmit = PJ_TRUE` 机制
✅ **音频端口自动连接** - `onCallMediaStateCallback()` 机制
✅ **通话状态管理** - `handleCallStatusChange()` 完全保留
✅ **通话时长缓存** - CallDisconnected 和 Null 状态的时长缓存

---

## 修改的文件总结

### Risip SDK（扩展，不是修改）

1. **src/risip/core/risipcall.h** (+3 行)
   - 添加 `enableVideo` 属性
   - 添加 getter/setter 声明
   - 添加 signal

2. **src/risip/core/risipcall.cpp** (+40 行)
   - Private 数据添加 `bool enableVideo`
   - 实现 getter/setter
   - 修改 `call()` 和 `invite()` 支持视频

3. **src/risip/core/risipcallmanager.h** (+3 行)
   - 添加 `callPhoneWithVideo()` 声明
   - 添加 `callBuddyWithVideo()` 声明

4. **src/risip/core/risipcallmanager.cpp** (+51 行)
   - 实现两个新 API

### SipPhoneManager（大幅简化）

5. **src/sip_phone/SipPhoneManager.cpp** (-130 行净减少)
   - 删除所有直接 PJSIP 调用代码
   - 统一使用 `callPhoneWithVideo()`
   - 保留视频设备配置逻辑

---

## 备份文件

### 可用的备份

```bash
# Risip SDK 重构前
src/risip/core/risipcall.h.backup_refactor_20251209
src/risip/core/risipcall.cpp.backup_refactor_20251209
src/risip/core/risipcallmanager.h.backup_refactor_20251209
src/risip/core/risipcallmanager.cpp.backup_refactor_20251209

# SipPhoneManager 重构前（保守策略版本）
src/sip_phone/SipPhoneManager.cpp.backup_before_refactor
src/sip_phone/SipPhoneManager.h.backup_before_refactor

# SipPhoneManager 完全重构前（如果需要）
src/sip_phone/SipPhoneManager.cpp.backup_20251209
src/sip_phone/SipPhoneManager.h.backup_20251209
```

---

## 架构优势

### ✅ 单一代码路径

**之前**:
- 视频通话：使用直接 PJSIP C API（~100 行）
- 语音通话：使用 Risip C++ API（~20 行）
- 两套完全不同的代码逻辑

**之后**:
- 所有通话：统一使用 Risip C++ API（~5 行）
- 单一、清晰的代码路径

### ✅ 自动管理

所有通话（视频 + 语音）都自动享受：
- ✅ 历史记录自动添加
- ✅ callDirection 自动设置（0=Outgoing）
- ✅ callTimestamp 自动创建
- ✅ callDuration 动态获取（+ 缓存机制）

### ✅ 易于维护

- 代码量减少 60%（~300 行 → ~120 行）
- 消除重复代码
- 单一责任原则
- 统一错误处理

### ✅ 易于扩展

可以轻松添加新功能：

1. **从联系人列表发起视频通话**
   ```cpp
   callManager->callBuddyWithVideo(selectedBuddy, true);
   ```

2. **通话记录重拨（保留通话类型）**
   ```cpp
   bool wasVideoCall = historyItem->property("isVideoCall").toBool();
   callManager->callPhoneWithVideo(number, wasVideoCall);
   ```

3. **联系人搜索 + 呼叫**
   ```cpp
   RisipBuddy *foundBuddy = searchBuddy(searchText);
   callManager->callBuddyWithVideo(foundBuddy, enableVideo);
   ```

---

## 关键技术点

### 1. PJSUA vs PJSUA2 API 差异

**PJSUA (C API)**:
```c
pjsua_call_setting call_opt;
call_opt.vid_cnt = 1;  // C API 字段名
```

**PJSUA2 (C++ API)**:
```cpp
CallOpParam prm(true);
prm.opt.videoCount = 1;  // ✅ C++ API 字段名
prm.opt.audioCount = 1;
```

这是编译错误 `'struct pj::CallSetting' has no member named 'vid_cnt'` 的根本原因。

### 2. 设置顺序很重要

```cpp
RisipCall *call = new RisipCall(this);
call->setAccount(account);
call->setBuddy(buddy);
call->setEnableVideo(enableVideo);  // ⭐ 必须在 call() 之前
call->call();  // ← 此时才会根据 enableVideo 设置 CallOpParam
```

### 3. 视频设备配置时机

```cpp
// ✅ CRITICAL: 在创建通话前配置视频设备
if (enableVideo) {
    configureAccountVideoDevice(accountUri);  // 设置摄像头
}

d->currentCall = callManager->callPhoneWithVideo(number, enableVideo);
```

这确保 PJSIP 使用正确的摄像头设备（跳过 colorbar 虚拟设备）。

### 4. 通话时长缓存

```cpp
// 在 CallDisconnected 和 Null 状态缓存时长
if (d->currentCall) {
    long duration = d->currentCall->callDuration();
    if (duration > 0) {
        d->currentCall->setProperty("cachedDuration", QVariant::fromValue(duration));
        qDebug() << "✅ 通话结束，缓存时长:" << duration << "ms";
    }
}
```

因为 PJSIP 会话销毁后 `callDuration()` 会返回 0，所以需要缓存。

---

## 测试步骤

### 1. 测试语音通话 ⭐

1. 拨打语音通话
2. 通话至少 5 秒后挂断
3. 切换到历史记录页面

**预期结果**:
- ✅ 显示语音通话记录
- ✅ callDirection = 0 (Outgoing)
- ✅ callDuration 显示实际秒数
- ✅ callTimestamp 显示正确时间

**预期日志**:
```
📞 Creating call using unified Risip API, video = false
✅ RisipCallManager: Call initiated via unified API, video = false
🔍 通话创建后 callDirection = 0 (0=Outgoing, 1=Incoming, 2=Unknown), video = false
✅ Call initiated via unified Risip API, video = false
```

### 2. 测试视频通话 ⭐⭐

**关键测试** - 验证 Risip API 能否正确支持视频通话

1. 拨打视频通话
2. 检查视频画面是否正常
3. 检查音频是否正常
4. 通话至少 5 秒后挂断
5. 切换到历史记录页面

**预期结果**:
- ✅ 视频通话功能完全正常（画面 + 音频）
- ✅ 显示视频通话记录
- ✅ callDirection = 0 (Outgoing)
- ✅ callDuration 显示实际秒数

**预期日志**:
```
✅ Refreshing video device configuration before call
✅ Account configured with capture device: X
📞 Creating call using unified Risip API, video = true
✅ RisipCall: Enabling video for outgoing call to sip:1006@...
✅ RisipCallManager: Call initiated via unified API, video = true
🔍 通话创建后 callDirection = 0, video = true
✅ Call initiated via unified Risip API, video = true
```

### 3. 测试接入通话

1. 拨打接入语音通话
2. 拨打接入视频通话
3. 查看历史记录

**预期结果**:
- ✅ callDirection = 1 (Incoming)
- ✅ 其他字段正常

### 4. 压力测试

1. 连续拨打多个视频通话
2. 连续拨打多个语音通话
3. 交替拨打视频和语音通话

**预期结果**:
- ✅ 所有通话都正常工作
- ✅ 历史记录全部显示
- ✅ 无崩溃、无泄漏

---

## 潜在风险与缓解

### ⚠️ 风险 1: Risip API 可能不支持 video in initial INVITE

**症状**: 视频通话建立，但没有视频流

**原因**: Risip 的 `makeCall()` 可能会先建立音频，然后通过 re-INVITE 添加视频

**缓解**:
1. 测试验证：拨打视频通话，检查 SDP 是否包含视频
2. 如果不支持：需要在 Risip SDK 中修改 `PjsipCall::makeCall()` 实现
3. 最坏情况：回滚到备份版本

### ⚠️ 风险 2: 视频设备配置时机问题

**症状**: 视频通话使用错误的摄像头（colorbar 或其他）

**原因**: `configureAccountVideoDevice()` 调用时机不正确

**缓解**:
- 已确保在 `callPhoneWithVideo()` 之前调用
- 如果仍有问题，需要在 Risip SDK 内部调用

### ⚠️ 风险 3: PJSIP 回调机制

**症状**: 视频编码器没有自动启动，或音频端口没有连接

**原因**: Risip 的回调机制与直接 PJSIP 调用略有不同

**缓解**:
- 保留了 `onCallMediaStateCallback()` 机制
- 如果有问题，可以在回调中添加额外逻辑

---

## 回滚策略

### 如果视频通话完全失败

```bash
# 回滚到保守策略版本（视频通话使用直接 PJSIP，语音使用 Risip）
cp src/sip_phone/SipPhoneManager.cpp.backup_before_refactor src/sip_phone/SipPhoneManager.cpp
```

### 如果 Risip SDK 修改导致问题

```bash
# 回滚 Risip SDK
cp src/risip/core/risipcall.h.backup_refactor_20251209 src/risip/core/risipcall.h
cp src/risip/core/risipcall.cpp.backup_refactor_20251209 src/risip/core/risipcall.cpp
cp src/risip/core/risipcallmanager.h.backup_refactor_20251209 src/risip/core/risipcallmanager.h
cp src/risip/core/risipcallmanager.cpp.backup_refactor_20251209 src/risip/core/risipcallmanager.cpp

# 回滚 SipPhoneManager 到原始版本
cp src/sip_phone/SipPhoneManager.cpp.backup_20251209 src/sip_phone/SipPhoneManager.cpp
```

---

## 下一步行动

### 立即测试（高优先级）⭐⭐⭐

1. ✅ 运行应用程序
2. ✅ **测试视频通话**（最关键！验证 Risip API 是否支持视频）
3. ✅ 测试语音通话
4. ✅ 查看历史记录
5. ✅ 检查控制台调试输出

### 如果测试成功

**成功标准**:
- ✅ 视频通话画面和音频正常
- ✅ 语音通话正常
- ✅ 历史记录全部显示
- ✅ callDirection 正确（0 或 1）
- ✅ callDuration 正确显示

**后续行动**:
1. 删除所有备份文件
2. 更新文档
3. 提交 git commit

### 如果测试失败

**失败场景 1: 视频通话没有画面**
- 检查 SDP 是否包含视频
- 检查视频设备配置
- 可能需要修改 Risip SDK 的 `makeCall()` 实现

**失败场景 2: 视频通话有画面但使用错误摄像头**
- 检查 `configureAccountVideoDevice()` 调用时机
- 检查 `videoCallManager->getCaptureDeviceId()` 返回值

**失败场景 3: 通话建立失败**
- 检查 Risip 的错误日志
- 回滚到保守策略版本

---

## 总结

### ✅ 重构完成

- Risip SDK 已扩展支持视频通话
- SipPhoneManager 完全统一使用 Risip API
- 代码量减少 60%
- 架构清晰、易于维护

### ⚠️ 等待验证

- 需要测试视频通话功能
- 需要确认 Risip API 是否完全支持 video in initial INVITE
- 需要验证历史记录和 callDirection

### 📁 完整备份

- 所有文件都有备份
- 可以快速回滚到任何版本

### 🎯 测试优先级

1. **视频通话**（最高优先级）- 验证核心功能
2. 语音通话 - 应该没问题，但需要确认
3. 历史记录 - 验证自动记录机制
4. 接入通话 - 验证 callDirection

---

**重构日期**: 2025-12-09 14:50
**编译状态**: ✅ 成功
**测试状态**: ⏳ **等待用户测试视频通话**
**可执行文件**: build/bin_windows/belt_control_system.exe (22MB)
**策略**: 完全统一架构（非保守策略）
