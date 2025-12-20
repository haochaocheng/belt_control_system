# Risip SDK 通话历史记录机制分析

## 日期
2025-12-09

## 概述

通过分析 Risip SDK 官方源码和官方 UI 应用，我发现了 Risip SDK 通话历史记录的完整工作机制。

---

## 关键发现 ⭐

### 1. **记录添加时机**

Risip SDK 在 **通话发起时** 就立即添加记录，而不是在通话结束时：

#### 拨出通话（Line 194）
```cpp
// risipcallmanager.cpp:182-198
RisipCall *RisipCallManager::callBuddy(RisipBuddy *buddy)
{
    RisipCall *call = new RisipCall(this);
    call->setBuddy(buddy);
    call->setAccount(m_data->m_activeAccount);
    call->call();
    emit outgoingCall(call);

    //adding call record for the active account.  <-- ⭐ 通话刚开始就添加
    qobject_cast<RisipCallHistoryModel *>(m_data->m_activeCallHistoryModel)->addCallRecord(call);
    setActiveCall(call);

    return call;
}
```

#### 拨出 SIP URI（Line 222）
```cpp
// risipcallmanager.cpp:213-226
RisipCall *RisipCallManager::callExternalSIP(const QString &uri)
{
    RisipCall * call = new RisipCall(this);
    call->setAccount(m_data->m_activeAccount);
    call->invite(uri);

    emit outgoingCall(call);

    //adding call record for the active account.  <-- ⭐ 通话刚开始就添加
    qobject_cast<RisipCallHistoryModel *>(m_data->m_activeCallHistoryModel)->addCallRecord(call);
    setActiveCall(call);

    return call;
}
```

#### 接入通话（Line 288）
```cpp
// risipcallmanager.cpp:275-291
void RisipCallManager::onIncomingCall(const OnIncomingCallParam &prm)
{
    // ...
    call->initiateIncomingCall();
    call->setBuddy(buddy);
    emit incomingCall(call);

    qobject_cast<RisipCallHistoryModel *>(m_data->m_activeCallHistoryModel)->addCallRecord(call);  <-- ⭐ 来电时立即添加
    setActiveCall(call);
}
```

### 2. **通话时长获取方式**

通话时长是从 PJSIP 的 `connectDuration` 动态获取的：

```cpp
// risipcall.cpp:247-253
long RisipCall::callDuration() const
{
    if(!m_data->pjsipCall)
        return 0.0;

    return m_data->pjsipCall->getInfo().connectDuration.msec;  // ⭐ 实时获取
}
```

**关键**: `connectDuration.msec` 是 PJSIP 实时维护的，只要 `pjsipCall` 对象存在就能获取。

### 3. **Model 数据结构**

```cpp
// risipcallhistorymodel.h
enum CallDataRole {
    CallContactRole = Qt::UserRole + 1,  // "callContact"
    CallDirectionRole,                    // "callDirection"
    CallDurationRole,                     // "callDuration" - 动态获取
    CallTimestampRole                     // "callTimestamp"
};

// risipcallhistorymodel.cpp:87-88
case CallDurationRole:
    return (qlonglong)call->callDuration();  // ⭐ 每次访问都调用 callDuration()
```

`callDuration` 不是静态存储的值，而是每次访问时实时从 PJSIP 获取。

---

## 我们的实现对比

### ✅ 我们做对的地方

1. 使用了正确的 role 名称（`callContact`, `callDirection`, `callDuration`, `callTimestamp`）
2. Model 绑定正确（通过 `historyCallModelForAccount()` 获取）
3. QML UI 实现正确

### ❌ 问题所在

#### 问题 1: 拨出通话没有记录

**原因**: 我们调用的是 `makeCall(number)` 方法，而不是 Risip SDK 的标准 API。

让我检查我们的 `makeCall()` 实现：

**文件**: [SipPhoneManager.cpp](src/sip_phone/SipPhoneManager.cpp)

我们的代码应该调用 Risip 的 API：
- `RisipCallManager::callPhone(number)` - 用于拨打电话号码
- `RisipCallManager::callBuddy(buddy)` - 用于拨打联系人
- `RisipCallManager::callExternalSIP(uri)` - 用于拨打 SIP URI

这些方法会自动添加通话记录。

#### 问题 2: 通话时长不显示

**可能原因**:

1. **通话对象已被销毁**: 如果 `RisipCall` 对象在通话结束后被销毁，`callDuration()` 返回 0
2. **connectDuration 未更新**: 通话连接失败或时长未被 PJSIP 正确记录

---

## 测试验证方案

### 验证 1: 检查我们的 makeCall() 实现

需要查看我们的 `SipPhoneManager::makeCall()` 是否正确调用 Risip API。

**预期**:
```cpp
void SipPhoneManager::makeCall(const QString &number)
{
    risip::RisipCallManager *callManager = risip::RisipCallManager::instance();
    if (!callManager) return;

    // ✅ 应该调用 Risip 的 API，它会自动添加记录
    callManager->callPhone(number);
}
```

**可能的错误**:
```cpp
void SipPhoneManager::makeCall(const QString &number)
{
    // ❌ 如果我们自己创建 RisipCall 对象，可能不会添加记录
    RisipCall *call = new RisipCall();
    call->invite(number);
}
```

### 验证 2: 检查通话时长获取

在 QML 的 `Component.onCompleted` 中，应该输出：

```
📝 Call history item #0:
   callContact: "1001" (type: string)
   callDirection: 0 (type: number)
   callDuration: 0 (type: number)  <-- ⚠️ 如果是 0，说明通话对象已销毁
   callTimestamp: "2025-12-09 14:30:00" (type: object)
```

如果 `callDuration` 始终为 0，说明 `RisipCall` 对象的 `pjsipCall` 为 null。

---

## 修复方案

### 方案 A: 确保使用 Risip 标准 API（推荐）✅

检查并修复 `SipPhoneManager::makeCall()` 实现：

```cpp
void SipPhoneManager::makeCall(const QString &number, bool videoCall)
{
    qDebug() << "📞 SipPhoneManager: Making call to" << number << "video:" << videoCall;

    risip::RisipCallManager *callManager = risip::RisipCallManager::instance();
    if (!callManager) {
        qWarning() << "❌ Call manager not available";
        return;
    }

    // ✅ 使用 Risip 标准 API，会自动添加通话记录
    risip::RisipCall *call = callManager->callPhone(number);

    if (!call) {
        qWarning() << "❌ Failed to create call";
        return;
    }

    // 如果是视频通话，添加视频
    if (videoCall && call) {
        qDebug() << "📹 Adding video to call...";
        // 添加视频逻辑...
    }
}
```

### 方案 B: 保存通话时长到本地变量

如果 Risip Call 对象在通话结束后被销毁，可以在 Model 中保存静态时长：

```cpp
// 不推荐：这需要修改 Risip SDK 源码
class RisipCallHistoryRecord {
    QString contact;
    int direction;
    long duration;       // 保存静态时长
    QDateTime timestamp;
};
```

但这需要修改 Risip SDK，不推荐。

---

## 下一步行动

### 立即检查

1. **查看 `SipPhoneManager::makeCall()` 的实现**
   - 文件: [SipPhoneManager.cpp](src/sip_phone/SipPhoneManager.cpp)
   - 搜索: `void SipPhoneManager::makeCall`

2. **运行测试，查看调试输出**
   - 拨打电话后，查看 `callDuration` 的实际值
   - 检查是否有 `addCallRecord` 相关日志

### 如果 makeCall() 实现不正确

需要修改为调用 Risip 标准 API：
- `callManager->callPhone(number)` - 用于普通电话号码
- `callManager->callExternalSIP(uri)` - 用于完整 SIP URI

---

## 总结

### Risip SDK 的设计

1. **即时记录**: 通话在发起时就添加到历史记录
2. **动态时长**: 时长从 PJSIP 实时获取，不是静态存储
3. **自动管理**: 使用标准 API 就会自动添加记录

### 我们的问题

1. ❌ **拨出通话不记录**: 可能没有调用 Risip 标准 API
2. ❌ **时长显示为 0**: `RisipCall` 对象可能已被销毁或 `pjsipCall` 为 null

### 解决方向

✅ **确保调用 Risip 标准 API**（`callPhone()`, `callExternalSIP()`）
✅ **检查 Call 对象生命周期**

---

## 相关文件

### Risip SDK 源码
- [risipcallmanager.cpp:182-226](F:/0/risip-master/risip-master/src/risipsdk/risipcallmanager.cpp#L182-L226) - 拨出通话记录添加
- [risipcallmanager.cpp:275-291](F:/0/risip-master/risip-master/src/risipsdk/risipcallmanager.cpp#L275-L291) - 接入通话记录添加
- [risipcall.cpp:247-253](F:/0/risip-master/risip-master/src/risipsdk/risipcall.cpp#L247-L253) - 通话时长获取
- [risipcallhistorymodel.cpp:87-88](F:/0/risip-master/risip-master/src/risipsdk/models/risipcallhistorymodel.cpp#L87-L88) - Model 数据返回

### 官方 UI 应用
- [CallHistoryListView.qml](F:/0/risipapp-master/risipapp-master/ui/base/callpages/CallHistoryListView.qml) - 历史列表
- [CallHistoryListViewDelegate.qml](F:/0/risipapp-master/risipapp-master/ui/base/callpages/CallHistoryListViewDelegate.qml) - 列表项

### 我们的代码
- [SipPhoneManager.cpp](src/sip_phone/SipPhoneManager.cpp) - **需要检查 makeCall() 实现**
- [SipHistoryPage.qml](src/qml/components/sip_phone/pages/SipHistoryPage.qml) - UI 实现

---

**分析日期**: 2025-12-09
**状态**: ⚠️ 需要检查 `makeCall()` 实现并修复
