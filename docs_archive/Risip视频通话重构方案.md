# Risip SDK 视频通话重构方案

## 日期
2025-12-09

## 目标
重构视频通话使用 Risip API，实现架构统一，支持后续功能扩展：
- ✅ 统一的通话历史记录
- ✅ 从联系人列表发起视频通话
- ✅ 联系人搜索功能
- ✅ 完整的通话记录管理

---

## 当前状态分析

### ❌ 现有问题

1. **架构不统一**
   - 视频通话：直接使用 PJSIP API (`pjsua_call_make_call`)
   - 语音通话：使用 Risip API (`callPhone`)
   - 导致代码重复、维护困难

2. **功能缺失**
   - 视频通话历史记录需要手动添加
   - 无法从联系人列表发起视频通话
   - 视频通话不能使用 Risip 的完整功能

3. **Risip SDK 现状**
   - ❌ **不支持视频通话**
   - `call()` 和 `invite()` 使用默认 `CallOpParam`，没有设置 `vid_cnt`

---

## 解决方案：扩展 Risip SDK

### 方案概述

在我们的项目中扩展 Risip SDK，添加视频通话支持。不修改官方 Risip SDK，而是在我们的 risip_sdk 模块中添加扩展。

### 实施步骤

#### 步骤 1: 为 RisipCall 添加视频属性

**文件**: `src/risip/core/risipcall.h`

添加：
```cpp
class RisipCall : public QObject
{
    Q_OBJECT

    // 添加新属性
    Q_PROPERTY(bool enableVideo READ enableVideo WRITE setEnableVideo NOTIFY enableVideoChanged)

public:
    // 添加 getter/setter
    bool enableVideo() const;
    void setEnableVideo(bool enable);

signals:
    void enableVideoChanged(bool enable);

private:
    bool m_enableVideo = false;  // 添加成员变量
};
```

#### 步骤 2: 修改 call() 和 invite() 方法支持视频

**文件**: `src/risip/core/risipcall.cpp`

修改 `call()` 方法：
```cpp
void RisipCall::call()
{
    if(m_data->callType == Undefined
            || !m_data->account
            || !m_data->buddy)
        return;

    if(m_data->account->status() != RisipAccount::SignedIn)
        return;

    setCallDirection(RisipCall::Outgoing);
    createTimestamp();
    setPjsipCall(new PjsipCall(*m_data->account->pjsipAccount()));

    // ✅ 修改：根据 enableVideo 设置 CallOpParam
    CallOpParam prm(true);
    if (m_enableVideo) {
        prm.opt.vid_cnt = 1;  // 启用 1 个视频流
        prm.opt.flag |= PJSUA_CALL_INCLUDE_DISABLED_MEDIA;  // 包含视频在 SDP 中
        qDebug() << "✅ RisipCall: Enabling video for call";
    }

    try {
        m_data->pjsipCall->makeCall(m_data->buddy->uri().toStdString(), prm);
    } catch (Error err) {
        setError(err);
    }
}
```

同样修改 `invite()` 方法。

#### 步骤 3: 扩展 RisipCallManager 添加视频通话 API

**文件**: `src/risip/core/risipcallmanager.h`

添加：
```cpp
class RisipCallManager : public QObject
{
    Q_OBJECT

public:
    // 添加视频通话 API
    Q_INVOKABLE RisipCall *callPhoneWithVideo(const QString &number, bool enableVideo = false);
    Q_INVOKABLE RisipCall *callBuddyWithVideo(RisipBuddy *buddy, bool enableVideo = false);
};
```

**文件**: `src/risip/core/risipcallmanager.cpp`

实现：
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
    call->setEnableVideo(enableVideo);  // ⭐ 设置视频标志
    call->call();
    emit outgoingCall(call);

    // 自动添加通话记录
    qobject_cast<RisipCallHistoryModel *>(m_data->m_activeCallHistoryModel)->addCallRecord(call);
    setActiveCall(call);

    return call;
}
```

#### 步骤 4: 重构 SipPhoneManager 使用新 API

**文件**: `src/sip_phone/SipPhoneManager.cpp`

重构 `makeCall()` 方法：

**之前**:
```cpp
// ❌ 视频通话使用直接 PJSIP API
status = pjsua_call_make_call(acc_id, &uri, &call_opt, NULL, NULL, &call_id);

// ✅ 语音通话使用 Risip API
d->currentCall = callManager->callPhone(number);
```

**之后**:
```cpp
// ✅ 统一使用 Risip API（视频 + 语音）
d->currentCall = callManager->callPhoneWithVideo(number, enableVideo);

if (!d->currentCall) {
    qDebug() << "❌ Failed to create call";
    emit callFailed("创建呼叫失败");
    return;
}

// ✅ 调试：检查 callDirection
int direction = d->currentCall->callDirection();
qDebug() << "🔍 通话创建后 callDirection =" << direction
         << "enableVideo =" << enableVideo;

setCurrentNumber(number);
updateCallStatus(enableVideo ? "视频拨号中" : "拨号中");

// 连接通话状态信号
connect(d->currentCall, &risip::RisipCall::statusChanged, this, [this, enableVideo]() {
    handleCallStatusChange(enableVideo);
});

qDebug() << "✅ Call initiated via Risip API";
```

---

## 优势分析

### ✅ 架构统一

- 所有通话（视频 + 语音）都使用 Risip API
- 通话历史记录自动管理
- callDirection 自动设置正确

### ✅ 代码简化

**之前**:
- makeCall() 方法 ~100 行
- 手动创建 Buddy、RisipCall 对象
- 手动添加历史记录
- 手动设置 callDirection

**之后**:
- makeCall() 方法 ~20 行
- 一行代码创建通话：`callManager->callPhoneWithVideo(number, enableVideo)`
- 自动管理历史记录
- 自动设置 callDirection

### ✅ 功能扩展

可以轻松添加：
1. **联系人视频通话**
   ```cpp
   callManager->callBuddyWithVideo(selectedBuddy, true);
   ```

2. **通话记录重拨**
   ```cpp
   QString number = historyItem->contact();
   bool wasVideoCall = historyItem->property("isVideoCall").toBool();
   callManager->callPhoneWithVideo(number, wasVideoCall);
   ```

3. **联系人搜索 + 呼叫**
   ```cpp
   RisipBuddy *foundBuddy = searchBuddy(searchText);
   callManager->callBuddyWithVideo(foundBuddy, enableVideo);
   ```

---

## 实施计划

### 阶段 1: 扩展 Risip SDK（1-2 小时）

1. ✅ 添加 `RisipCall::enableVideo` 属性
2. ✅ 修改 `call()` 和 `invite()` 方法
3. ✅ 添加 `callPhoneWithVideo()` 和 `callBuddyWithVideo()` API
4. ✅ 测试编译

### 阶段 2: 重构 SipPhoneManager（30 分钟）

1. ✅ 简化 `makeCall()` 方法
2. ✅ 删除手动历史记录代码
3. ✅ 删除手动 callDirection 设置
4. ✅ 测试编译

### 阶段 3: 测试验证（30 分钟）

1. ✅ 测试语音通话
2. ✅ 测试视频通话
3. ✅ 测试通话历史记录
4. ✅ 测试 callDirection
5. ✅ 测试 callDuration

### 阶段 4: 清理代码（15 分钟）

1. ✅ 删除旧的手动历史记录代码
2. ✅ 更新注释
3. ✅ 创建总结文档

---

## 风险评估

### ⚠️ 中等风险

1. **修改 Risip SDK**
   - 风险：可能影响其他功能
   - 缓解：只添加新功能，不修改现有代码

2. **重构 makeCall()**
   - 风险：可能破坏现有视频通话
   - 缓解：充分测试，保留备份

### ✅ 低风险原因

1. 添加的是**新 API**，不影响现有 `callPhone()`
2. 使用标准 PJSIP `CallOpParam`，与现有代码一致
3. 有完整备份，可快速回滚

---

## 替代方案对比

### 方案 A: 当前手动记录方案（已实施）

**优点**:
- ✅ 最小改动
- ✅ 不修改 Risip SDK
- ✅ 风险最低

**缺点**:
- ❌ 代码重复
- ❌ 维护困难
- ❌ 后续功能扩展困难

### 方案 B: Risip 重构方案（推荐）⭐

**优点**:
- ✅ 架构统一
- ✅ 代码简洁
- ✅ 易于扩展
- ✅ 支持联系人、搜索等功能

**缺点**:
- ⚠️ 需要修改 Risip SDK
- ⚠️ 工作量较大（~2-3 小时）

---

## 下一步

你希望：
1. **保持当前方案**（已编译成功，等待测试）
2. **实施 Risip 重构**（更长远，架构更好）

我的建议：
- **先测试当前方案**，确认功能正常
- **然后逐步重构为 Risip API**，分步骤进行

或者，如果你希望立即重构，我可以：
1. 先备份所有文件
2. 实施 Risip SDK 扩展
3. 重构 SipPhoneManager
4. 测试验证

你决定！😊

---

**方案作者**: Claude
**创建日期**: 2025-12-09
**状态**: 等待用户决定
