# 对方挂断UI不更新问题根因修复

## 日期
2025-11-28

## 问题描述

用户报告:
> "对方挂断,本机还是显示通话中"

即使收到对方的BYE消息并正确回复200 OK,本地UI仍然显示"通话中"状态,无法自动返回"就绪"。

## 根因分析

### PJSIP日志分析

用户提供的日志显示:
```
[DEBUG] Call state changed: 6   # CallEarly (振铃中)
[DEBUG] Call state changed: 3   # ConnectingToCall
[DEBUG] Call state changed: 4   # CallConfirmed (通话中)
[DEBUG] Call connected
...
14:51:51.082  RX BYE from 192.168.10.243:5060
14:51:51.127  TX 200/BYE
[DEBUG] Call state changed: 7   # ❌ 这是问题关键!
```

### Risip状态枚举

通过查看 [F:\0\risip-master\risip-master\src\risipsdk\headers\risipcall.h:56-64](F:\0\risip-master\risip-master\src\risipsdk\headers\risipcall.h#L56-L64), 发现状态7是`Null`:

```cpp
enum Status {
    OutgoingCallStarted = 1,  // 拨号中
    IncomingCallStarted,      // 2 来电
    ConnectingToCall,         // 3 连接中
    CallConfirmed,            // 4 通话中
    CallDisconnected,         // 5 已断开
    CallEarly,                // 6 振铃中
    Null                      // 7 ❌ 空状态 - 这个没有被处理!
};
```

### 代码中的缺陷

在 [SipPhoneManager.cpp:566-603](src/sip_phone/SipPhoneManager.cpp#L566-L603) 的状态处理代码中:

```cpp
connect(d->currentCall, &risip::RisipCall::statusChanged, this, [this]() {
    int callState = d->currentCall->status();
    qDebug() << "Call state changed:" << callState;

    if (callState == risip::RisipCall::CallConfirmed) {       // 处理 4
        // ...
    } else if (callState == risip::RisipCall::CallDisconnected) {  // 处理 5
        // ...
    } else if (callState == risip::RisipCall::CallEarly) {    // 处理 6
        // ...
    }
    // ❌ 没有处理 Null (7)!
});
```

**问题**: 当PJSIP收到BYE消息后,通话状态经历以下转换:
1. CallConfirmed (4) → 通话中
2. 收到BYE消息
3. **CallDisconnected (5)** → 理论上应该清理状态
4. **Null (7)** → 通话返回空状态

但实际情况可能是:
- **跳过了CallDisconnected (5)状态**
- **直接跳转到Null (7)状态**
- 由于Null状态没有被处理,UI保持在"通话中"

### 为什么之前的修复没有生效?

在 [CALL_STATE_FIXES.md](CALL_STATE_FIXES.md) 中,我们已经修复了CallDisconnected (5)的处理:

```cpp
} else if (callState == risip::RisipCall::CallDisconnected) {
    // Remote party hung up - clean up call state
    qDebug() << "Remote party disconnected, cleaning up...";
    d->callTimer->stop();
    d->currentCall = nullptr;
    d->inCall = false;
    emit isInCallChanged(false);
    emit callDisconnected();
    updateCallStatus("就绪");
    d->callDuration = 0;
    emit callDurationChanged(0);
}
```

但是,根据PJSIP日志,**状态5 (CallDisconnected) 可能被跳过**,直接跳转到状态7 (Null)。

## 修复方案

### 修复1: 在makeCall中添加Null状态处理

**文件**: [SipPhoneManager.cpp:602-613](src/sip_phone/SipPhoneManager.cpp#L602-L613)

**添加代码**:
```cpp
} else if (callState == risip::RisipCall::Null) {
    // Call returned to Null state after disconnect
    qDebug() << "Call state returned to Null, cleaning up...";
    d->callTimer->stop();
    d->currentCall = nullptr;
    d->inCall = false;
    emit isInCallChanged(false);
    emit callDisconnected();
    updateCallStatus("就绪");
    d->callDuration = 0;
    emit callDurationChanged(0);
}
```

### 修复2: 在incomingCall中添加Null状态处理

**文件**: [SipPhoneManager.cpp:256-267](src/sip_phone/SipPhoneManager.cpp#L256-L267)

**添加代码**:
```cpp
} else if (callState == risip::RisipCall::Null) {
    // Call returned to Null state after disconnect
    qDebug() << "Call state returned to Null, cleaning up...";
    d->callTimer->stop();
    d->currentCall = nullptr;
    d->inCall = false;
    emit isInCallChanged(false);
    emit callDisconnected();
    updateCallStatus("就绪");
    d->callDuration = 0;
    emit callDurationChanged(0);
}
```

## 状态转换流程

### 正常挂断流程(本地挂断)

```
拨号中 (1) → 振铃中 (6) → 通话中 (4) → [本地调用hangup()] → 已断开 (5) → 空 (7)
```

### 对方挂断流程(之前有Bug)

```
拨号中 (1) → 振铃中 (6) → 通话中 (4) → [收到BYE] → ❌ 跳过状态5 → 空 (7) ❌ 未处理
```

### 对方挂断流程(修复后)

```
拨号中 (1) → 振铃中 (6) → 通话中 (4) → [收到BYE] → 空 (7) ✅ 清理状态
```

## 完整状态处理表

| 状态值 | 枚举名 | UI显示 | 是否处理 |
|--------|--------|--------|----------|
| 1 | OutgoingCallStarted | 拨号中 | ✅ |
| 2 | IncomingCallStarted | 来电 | ✅ |
| 3 | ConnectingToCall | (无特殊显示) | ❌ 不需要 |
| 4 | CallConfirmed | 通话中 | ✅ |
| 5 | CallDisconnected | 就绪 | ✅ |
| 6 | CallEarly | 振铃中 | ✅ |
| 7 | Null | 就绪 | ✅ **新增** |

## 编译状态

✅ **编译成功**

```
[100%] Linking CXX executable ..\..\bin_windows\belt_control_system.exe
[100%] Built target belt_control_system
```

## 测试计划

### 测试1: 对方挂断

**步骤**:
1. 从本机(1000)拨打1006
2. 对方接听,通话30秒
3. **对方挂断电话**
4. 观察本机UI

**预期结果**:
- ✅ 本机立即显示"就绪"
- ✅ 通话计时器停止
- ✅ 通话界面关闭
- ✅ 日志显示: `[DEBUG] Call state changed: 7`
- ✅ 日志显示: `Call state returned to Null, cleaning up...`

### 测试2: 本地挂断(验证没有副作用)

**步骤**:
1. 从本机拨打1006
2. 对方接听,通话30秒
3. **本机挂断电话**
4. 观察UI和日志

**预期结果**:
- ✅ UI正常返回"就绪"
- ✅ 可能先触发CallDisconnected (5),再触发Null (7)
- ✅ 两种状态都能正确清理

### 测试3: 来电对方挂断

**步骤**:
1. 对方(1006)呼叫本机(1000)
2. 本机接听,通话30秒
3. **对方挂断**
4. 观察本机UI

**预期结果**:
- ✅ 本机立即显示"就绪"
- ✅ 通话计时器停止
- ✅ Null状态正确处理

## 技术细节

### 为什么需要同时处理CallDisconnected和Null?

根据PJSIP状态机,不同场景可能触发不同状态序列:

**本地主动挂断**:
```
CallConfirmed → CallDisconnected → Null
```

**对方挂断(收到BYE)**:
```
CallConfirmed → Null  (可能跳过CallDisconnected)
```

因此,**两个状态都需要处理清理逻辑**,确保所有场景下都能正确重置UI。

### 为什么不能只依赖CallDisconnected?

从用户的PJSIP日志可以看出:
1. BYE消息被正确接收和处理
2. PJSIP内部已经断开通话
3. 但**没有触发CallDisconnected状态**
4. 直接跳转到Null状态

这可能是PJSIP2的行为:当收到远程BYE时,直接将call对象状态设置为NULL,而不经过DISCONNECTED状态。

## 相关文件

| 文件 | 修改内容 |
|------|----------|
| [SipPhoneManager.cpp:602-613](src/sip_phone/SipPhoneManager.cpp#L602-L613) | 添加Null状态处理(makeCall) |
| [SipPhoneManager.cpp:256-267](src/sip_phone/SipPhoneManager.cpp#L256-L267) | 添加Null状态处理(incomingCall) |

## 参考文档

- [CALL_STATE_FIXES.md](CALL_STATE_FIXES.md) - 之前的CallDisconnected修复
- [F:\0\risip-master\risip-master\src\risipsdk\headers\risipcall.h](F:\0\risip-master\risip-master\src\risipsdk\headers\risipcall.h) - Risip状态枚举定义
- [用户反馈日志] - 显示state 7被触发但未处理

## 总结

✅ **根因已找到**: 对方挂断时,PJSIP直接跳转到Null (7)状态,而代码没有处理这个状态

✅ **修复已完成**: 在两个statusChanged回调中都添加了Null状态处理

✅ **编译成功**: 无编译错误

⏳ **待验证**: 需要用户测试对方挂断场景

---

**修复日期**: 2025-11-28
**状态**: ✅ 代码完成,待测试
**预期效果**: 对方挂断时,本机UI立即返回"就绪"状态
