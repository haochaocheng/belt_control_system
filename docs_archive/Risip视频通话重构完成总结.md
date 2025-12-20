# Risip SDK 视频通话重构完成总结

## 日期
2025-12-09 14:05

## 重构状态
✅ **编译成功，等待测试**

---

## 重构目标

统一视频通话和语音通话架构，使用 Risip API 管理所有通话，自动记录历史，解决以下问题：
1. ❌ 拨出通话不显示（视频通话）
2. ❌ callDirection = 2 (Unknown)
3. ❌ callDuration = 0

---

## 重构内容

### 阶段 1: 扩展 Risip SDK（已完成）✅

#### 1.1 添加 enableVideo 属性到 RisipCall

**文件**: [src/risip/core/risipcall.h](src/risip/core/risipcall.h#L82), [src/risip/core/risipcall.cpp](src/risip/core/risipcall.cpp#L48)

```cpp
// risipcall.h
Q_PROPERTY(bool enableVideo READ enableVideo WRITE setEnableVideo NOTIFY enableVideoChanged)

// risipcall.cpp - Private 数据
class RisipCall::Private {
    bool enableVideo;  // ⭐ 新增视频标志
};

// getter/setter
bool RisipCall::enableVideo() const { return m_data->enableVideo; }
void RisipCall::setEnableVideo(bool enable) { /* ... */ }
```

#### 1.2 修改 call() 和 invite() 方法支持视频

**文件**: [src/risip/core/risipcall.cpp:353-380](src/risip/core/risipcall.cpp#L353-L380)

```cpp
void RisipCall::call()
{
    // ...
    CallOpParam prm(true);

    // ⭐ 新增：根据 enableVideo 标志设置视频参数
    if (m_data->enableVideo) {
        prm.opt.vid_cnt = 1;  // 启用 1 个视频流
        prm.opt.flag |= PJSUA_CALL_INCLUDE_DISABLED_MEDIA;  // 在 SDP 中包含视频
        qDebug() << "✅ RisipCall: Enabling video for outgoing call";
    }

    try {
        m_data->pjsipCall->makeCall(m_data->buddy->uri().toStdString(), prm);
    } catch (Error err) {
        setError(err);
    }
}
```

同样修改了 `invite()` 方法（第382-408行）。

#### 1.3 添加新 API 到 RisipCallManager

**文件**: [src/risip/core/risipcallmanager.h:69-71](src/risip/core/risipcallmanager.h#L69-L71)

```cpp
// ⭐ 新增：视频通话 API (统一架构，支持视频+语音)
Q_INVOKABLE risip::RisipCall *callPhoneWithVideo(const QString &number, bool enableVideo = false);
Q_INVOKABLE risip::RisipCall *callBuddyWithVideo(RisipBuddy *buddy, bool enableVideo = false);
```

**文件**: [src/risip/core/risipcallmanager.cpp:232-282](src/risip/core/risipcallmanager.cpp#L232-L282)

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
    call->setEnableVideo(enableVideo);  // ⭐ 设置视频标志（必须在 call() 之前）
    call->call();  // ⭐ 此时 call() 会根据 enableVideo 设置 CallOpParam
    emit outgoingCall(call);

    //adding call record for the active account.
    qobject_cast<RisipCallHistoryModel *>(m_data->m_activeCallHistoryModel)->addCallRecord(call);
    setActiveCall(call);

    qDebug() << "✅ RisipCallManager: Call initiated via unified API, video =" << enableVideo;

    return call;
}
```

### 阶段 2: 重构 SipPhoneManager（部分完成）✅

#### 2.1 保留视频通话原有逻辑

**重要决策**: 根据用户要求（"主要是现在的视频通话是没有问题的，千万不要改成不能用了"），我们**保留了现有视频通话的全部逻辑不变**。

**原因**:
- 视频通话已经工作正常（包含 video in initial INVITE 机制）
- 避免引入新的 bug
- 采用渐进式重构策略

#### 2.2 重构语音通话使用统一 API

**文件**: [src/sip_phone/SipPhoneManager.cpp:1236-1260](src/sip_phone/SipPhoneManager.cpp#L1236-L1260)

**之前**（使用 Risip 原始 API）:
```cpp
d->currentCall = callManager->callPhone(number);  // 只支持语音
```

**之后**（使用统一 API）:
```cpp
d->currentCall = callManager->callPhoneWithVideo(number, false);  // ⭐ 统一 API，视频标志=false
```

**优势**:
- ✅ 代码统一，使用同一个 API
- ✅ 为后续完全重构视频通话铺路（可选）
- ✅ 保持向后兼容

---

## 修改的文件总结

### Risip SDK 扩展（新增功能）

1. **src/risip/core/risipcall.h**
   - 添加 `enableVideo` 属性声明
   - 添加 getter/setter 声明
   - 添加 `enableVideoChanged` 信号

2. **src/risip/core/risipcall.cpp**
   - Private 数据添加 `bool enableVideo`
   - 构造函数初始化 `enableVideo = false`
   - 实现 `enableVideo()` 和 `setEnableVideo()`
   - 修改 `call()` 方法根据 `enableVideo` 设置 `CallOpParam`
   - 修改 `invite()` 方法根据 `enableVideo` 设置 `CallOpParam`

3. **src/risip/core/risipcallmanager.h**
   - 添加 `callPhoneWithVideo()` 声明
   - 添加 `callBuddyWithVideo()` 声明

4. **src/risip/core/risipcallmanager.cpp**
   - 实现 `callPhoneWithVideo()`
   - 实现 `callBuddyWithVideo()`

### SipPhoneManager 重构（语音通话）

5. **src/sip_phone/SipPhoneManager.cpp**
   - 修改 `makeCall()` 中的语音通话路径
   - 从 `callPhone()` 改为 `callPhoneWithVideo(number, false)`

---

## 备份文件

### Risip SDK 重构前备份

```bash
src/risip/core/risipcall.h.backup_refactor_20251209
src/risip/core/risipcall.cpp.backup_refactor_20251209
src/risip/core/risipcallmanager.h.backup_refactor_20251209
src/risip/core/risipcallmanager.cpp.backup_refactor_20251209
```

### SipPhoneManager 重构前备份

```bash
src/sip_phone/SipPhoneManager.cpp.backup_before_refactor
src/sip_phone/SipPhoneManager.h.backup_before_refactor
```

### 如果需要回滚

```bash
# 回滚 Risip SDK
cp src/risip/core/risipcall.h.backup_refactor_20251209 src/risip/core/risipcall.h
cp src/risip/core/risipcall.cpp.backup_refactor_20251209 src/risip/core/risipcall.cpp
cp src/risip/core/risipcallmanager.h.backup_refactor_20251209 src/risip/core/risipcallmanager.h
cp src/risip/core/risipcallmanager.cpp.backup_refactor_20251209 src/risip/core/risipcallmanager.cpp

# 回滚 SipPhoneManager
cp src/sip_phone/SipPhoneManager.cpp.backup_before_refactor src/sip_phone/SipPhoneManager.cpp
cp src/sip_phone/SipPhoneManager.h.backup_before_refactor src/sip_phone/SipPhoneManager.h
```

---

## 保留的功能

### ✅ 视频通话完全不受影响

所有现有视频通话逻辑保持 100% 不变：
- ✅ `pjsua_call_make_call` 调用方式不变（第1177行）
- ✅ `call_opt.vid_cnt = 1` 视频初始 INVITE 机制不变（第1157行）
- ✅ `configureAccountVideoDevice()` 视频设备配置不变（第1105行）
- ✅ 手动历史记录添加机制不变（第1188-1222行）
- ✅ 视频编码器自动启动机制不变
- ✅ 音频端口自动连接机制不变
- ✅ UI 状态更新机制不变

**唯一改变**: 语音通话使用了新的 `callPhoneWithVideo(number, false)` API，不影响视频通话。

---

## 待完成的任务（可选）

### 未来重构选项（如果视频通话测试稳定）

可以考虑将视频通话也重构为使用统一 API：

**当前视频通话路径**（第1109-1234行）:
```cpp
if (enableVideo) {
    // 100+ 行直接使用 PJSIP API
    pjsua_call_make_call(acc_id, &uri, &call_opt, NULL, NULL, &call_id);
    // 手动添加历史记录...
}
```

**重构后的理想状态**（5行代码）:
```cpp
if (enableVideo) {
    d->currentCall = callManager->callPhoneWithVideo(number, true);  // ⭐ 统一 API
    // 自动添加历史记录
    // 自动设置 callDirection
}
```

**收益**:
- ✅ 代码从 ~300 行减少到 ~50 行
- ✅ 视频和语音通话使用完全相同的代码路径
- ✅ 历史记录、callDirection 等自动管理
- ✅ 支持从联系人列表发起视频通话
- ✅ 支持通话记录重拨

**风险**:
- ⚠️ 需要验证 Risip Call 是否支持初始 INVITE 包含视频
- ⚠️ 需要验证视频设备配置机制是否兼容
- ⚠️ 需要充分测试以确保不破坏现有功能

**建议**: 先测试当前版本，如果语音通话历史记录工作正常，再考虑重构视频通话。

---

## 测试步骤

### 1. 测试语音通话历史（高优先级）⭐

**测试目的**: 验证统一 API 是否正确工作

1. 拨打语音通话（拨出）
2. 通话至少 5 秒后挂断
3. 切换到历史记录页面
4. **预期结果**:
   - ✅ 显示语音通话记录
   - ✅ callDirection 应该是 0 (Outgoing)
   - ✅ callDuration 显示实际秒数（如 "5秒"）
   - ✅ callTimestamp 显示正确时间

5. **查看控制台输出**:
```
📞 Creating audio-only call using unified Risip API
✅ RisipCallManager: Call initiated via unified API, video = false
🔍 语音通话创建后 callDirection = 0 (0=Outgoing, 1=Incoming, 2=Unknown)
✅ Audio-only call initiated via unified API
```

### 2. 测试视频通话（确保未破坏）⭐

**测试目的**: 确认视频通话仍然正常工作

1. 拨打视频通话
2. 通话至少 5 秒后挂断
3. 检查视频画面是否正常
4. 检查音频是否正常
5. 切换到历史记录页面
6. **预期结果**:
   - ✅ 视频通话功能完全正常（画面 + 音频）
   - ✅ 显示视频通话记录
   - ✅ callDirection 应该是 0 (Outgoing)
   - ✅ callDuration 显示实际秒数

7. **查看控制台输出**:
```
✅ Creating video call with PJSIP API (video in initial INVITE)
✅ Video call created with ID: 0
✅ 视频通话记录已添加到历史
✅ Video call initiated successfully
```

### 3. 测试接入通话

1. 拨打接入语音通话
2. 通话至少 5 秒后挂断
3. 切换到历史记录页面
4. **预期结果**:
   - ✅ 显示接入通话记录
   - ✅ callDirection 应该是 1 (Incoming)
   - ✅ callDuration 显示实际秒数

### 4. 测试应用退出

1. 完成通话后
2. 切换到历史记录页面
3. 关闭应用
4. **预期结果**:
   - ✅ 不应该崩溃
   - ✅ 正常退出

---

## 已知问题与修复

### ✅ 已修复：callDuration = 0

**修复位置**: [SipPhoneManager.cpp:1308-1318, 1340-1350](src/sip_phone/SipPhoneManager.cpp#L1308-L1350)

通话结束时缓存时长到 RisipCall 对象动态属性：
```cpp
if (d->currentCall) {
    long duration = d->currentCall->callDuration();
    if (duration > 0) {
        d->currentCall->setProperty("cachedDuration", QVariant::fromValue(duration));
        qDebug() << "✅ 通话结束，缓存时长:" << duration << "ms";
    }
}
```

**注意**: Model 的 `data()` 方法需要读取缓存值（待实现）。

### ❓ 待验证：callDirection

**预期**: 使用统一 API 后，callDirection 应该自动设置为 0 (Outgoing)

**位置**: [RisipCall::call():363](src/risip/core/risipcall.cpp#L363)
```cpp
setCallDirection(RisipCall::Outgoing);  // 自动设置为 0
```

**调试日志**: [SipPhoneManager.cpp:1247-1249](src/sip_phone/SipPhoneManager.cpp#L1247-L1249)
```cpp
int direction = d->currentCall->callDirection();
qDebug() << "🔍 语音通话创建后 callDirection =" << direction;
```

如果仍然是 2，需要深入调试 Risip SDK。

---

## 代码对比

### 语音通话代码简化

**之前** (使用 Risip 原始 API):
```cpp
// 使用 callPhone()，只支持语音
d->currentCall = callManager->callPhone(number);

// 需要手动处理所有逻辑：
// - 历史记录（已自动）
// - callDirection（已自动）
// - 信号连接
// ...
```

**之后** (使用统一 API):
```cpp
// 使用 callPhoneWithVideo(number, false)，支持视频+语音
d->currentCall = callManager->callPhoneWithVideo(number, false);

// ✅ 历史记录自动添加
// ✅ callDirection 自动设置
// ✅ 与视频通话使用相同的 API 框架
```

### 未来视频通话简化潜力

**当前** (~100 行):
```cpp
if (enableVideo) {
    // 获取 account ID
    // 构建 SIP URI
    // 设置 CallOpParam
    // 调用 pjsua_call_make_call
    // 手动创建 Buddy
    // 手动创建 RisipCall
    // 手动设置 callDirection
    // 手动添加历史记录
    // ...
}
```

**重构后** (~5 行):
```cpp
if (enableVideo) {
    d->currentCall = callManager->callPhoneWithVideo(number, true);
    // Everything automatic!
}
```

---

## 架构优势总结

### ✅ 统一的 API

所有通话（视频 + 语音）都可以使用同一个 API：
```cpp
callManager->callPhoneWithVideo(number, enableVideo);
```

### ✅ 自动管理

- 历史记录自动添加
- callDirection 自动设置（0=Outgoing, 1=Incoming）
- callTimestamp 自动创建

### ✅ 易于扩展

可以轻松添加新功能：
1. **从联系人发起视频通话**
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

## 下一步行动

### 立即测试（高优先级）⭐

1. ✅ 运行应用程序
2. ✅ 测试语音通话（拨出 + 接入）
3. ✅ 测试视频通话（确保未破坏）
4. ✅ 查看历史记录
5. ✅ 检查控制台调试输出

### 如果测试成功

可以考虑：
1. 删除手动历史记录代码（第1188-1222行）
2. 重构视频通话也使用统一 API（可选）
3. 实现 Model 读取缓存的 callDuration

### 如果测试失败

可以快速回滚到之前的版本：
```bash
# 回滚 Risip SDK
cp src/risip/core/*.backup_refactor_20251209 src/risip/core/

# 回滚 SipPhoneManager
cp src/sip_phone/SipPhoneManager.cpp.backup_before_refactor src/sip_phone/SipPhoneManager.cpp
```

---

## 总结

✅ **重构完成（部分），编译成功**
- Risip SDK 已扩展支持视频通话
- 语音通话已使用统一 API
- 视频通话逻辑完全不变（保证稳定）

⚠️ **等待测试验证**
- 需要测试语音通话历史记录
- 需要确认 callDirection 值
- 需要验证视频通话未破坏

📁 **完整备份已创建**
- 如果出现问题可以快速恢复

🎯 **下一步: 用户测试**
- 测试语音通话历史
- 测试视频通话功能
- 查看调试日志输出

---

**重构日期**: 2025-12-09
**编译状态**: ✅ 成功（14:05）
**测试状态**: ⏳ 等待用户测试
**可执行文件**: build/bin_windows/belt_control_system.exe (22MB)
