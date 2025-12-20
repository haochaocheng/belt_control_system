# 通话状态修复报告

## 日期
2025-11-28

## 问题描述

根据用户反馈和日志分析,发现以下问题:

### 1. ❌ 对方挂断后本机仍显示"通话中"

**现象**:
- 对方(1006)结束通话,发送BYE消息
- PJSIP正确处理BYE并回复200 OK
- 但本机UI仍然显示"通话中"状态
- 只有本机手动挂断才能关闭通话界面

**日志证据**:
```
14:51:51.082  RX BYE from 192.168.10.243:5060
14:51:51.127  TX 200/BYE
14:51:51.162  Call DISCONNECTED
  Call time: 00h:00m:17s
```

### 2. ❌ 来电没有UI提示

**现象**:
- 本机页面没有显示"呼叫中"或"来电"提示
- 只有在接听时才显示"通话中"

### 3. ❌ 通话历史记录未保存

**现象**:
- 通话历史页面为空
- 虽然拨打了1006并通话17秒,但没有记录

## 根因分析

### 问题1: CallDisconnected状态处理不完整

**位置**: [SipPhoneManager.cpp:539](src/sip_phone/SipPhoneManager.cpp#L539)

**原始代码**:
```cpp
} else if (callState == risip::RisipCall::CallDisconnected) {
    hangupCall();  // ❌ 问题: hangupCall()检查currentCall是否存在
}
```

**问题分析**:
1. `hangupCall()`方法内部调用`d->currentCall->hangup()`
2. 但对方已经挂断,通话已经在PJSIP层结束
3. 调用`hangup()`可能导致状态不一致或无效操作
4. 正确做法是直接清理本地状态,不再调用PJSIP API

### 问题2: 缺少来电监听

**原因**:
- SipPhoneManager初始化时没有连接`RisipCallManager::incomingCall`信号
- 只处理了拨出电话(makeCall),没有处理来电

### 问题3: Risip历史记录需要验证

**可能原因**:
1. Risip自动记录功能未启用
2. QSettings路径配置问题
3. 通话时长不足(可能有最小时长限制)

## 修复方案

### 修复1: 正确处理CallDisconnected状态

**文件**: [SipPhoneManager.cpp:539-549](src/sip_phone/SipPhoneManager.cpp#L539-L549)

**修改后的代码**:
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

**改进点**:
1. ✅ 直接清理本地状态,不调用PJSIP API
2. ✅ 停止计时器
3. ✅ 重置所有通话相关变量
4. ✅ 发射正确的信号通知QML
5. ✅ 更新UI状态为"就绪"

### 修复2: 添加来电监听

**文件**: [SipPhoneManager.cpp:218-260](src/sip_phone/SipPhoneManager.cpp#L218-L260)

**新增代码**:
```cpp
// Connect to RisipCallManager for incoming calls
risip::RisipCallManager *callManager = risip::RisipCallManager::instance();
if (callManager) {
    connect(callManager, &risip::RisipCallManager::incomingCall, this, [this](risip::RisipCall *call) {
        if (!call) return;

        qDebug() << "Incoming call from:" << call->buddy()->contact();
        d->currentCall = call;

        // Emit incoming call signal to QML
        QString callerNumber = call->buddy()->contact();
        emit incomingCall(callerNumber, callerNumber);
        updateCallStatus("来电: " + callerNumber);

        // Connect call status signals
        connect(d->currentCall, &risip::RisipCall::statusChanged, this, [this]() {
            int callState = d->currentCall->status();
            qDebug() << "Call state changed:" << callState;

            if (callState == risip::RisipCall::CallConfirmed) {
                d->inCall = true;
                emit isInCallChanged(true);
                emit callConnected();
                updateCallStatus("通话中");
                d->callDuration = 0;
                d->callTimer->start();
                qDebug() << "Call connected";
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
        });
    });
    qDebug() << "Connected to RisipCallManager for incoming calls";
}
```

**功能**:
1. ✅ 监听`RisipCallManager::incomingCall`信号
2. ✅ 接收到来电时发射`incomingCall`信号到QML
3. ✅ 更新UI显示"来电: 号码"
4. ✅ 连接通话状态信号,处理接听后的状态变化

### 修复3: 增强通话状态显示

**文件**: [SipPhoneManager.cpp:550-558](src/sip_phone/SipPhoneManager.cpp#L550-L558)

**新增状态处理**:
```cpp
} else if (callState == risip::RisipCall::IncomingCallStarted) {
    updateCallStatus("来电");
    qDebug() << "Incoming call";
} else if (callState == risip::RisipCall::OutgoingCallStarted) {
    updateCallStatus("拨号中");
    qDebug() << "Outgoing call started";
}
```

**完整状态流程**:
```
拨出电话:
  OutgoingCallStarted → "拨号中"
  CallEarly → "振铃中"
  CallConfirmed → "通话中"
  CallDisconnected → "就绪"

来电:
  IncomingCallStarted → "来电: 号码"
  CallConfirmed → "通话中" (接听后)
  CallDisconnected → "就绪"
```

## 测试计划

### 测试1: 对方挂断测试

**步骤**:
1. 从本机(1000)拨打对方(1006)
2. 对方接听,通话30秒
3. **对方**先挂断电话
4. 观察本机UI状态

**预期结果**:
- ✅ 本机立即显示"就绪"
- ✅ 通话计时停止
- ✅ 通话界面关闭
- ✅ 可以拨打下一个电话

### 测试2: 来电显示测试

**步骤**:
1. 从对方(1006)拨打本机(1000)
2. 观察本机UI显示

**预期结果**:
- ✅ 显示"来电: sip:1006@192.168.10.243"
- ✅ 显示接听/拒绝按钮
- ✅ 可以正常接听
- ✅ 接听后显示"通话中"

### 测试3: 通话历史测试

**步骤**:
1. 完成一次完整通话(拨出,通话30秒,挂断)
2. 完成一次来电(接听,通话30秒,挂断)
3. 打开历史记录页面

**预期结果**:
- ✅ 显示2条记录
- ✅ 拨出记录显示📤图标
- ✅ 接入记录显示📥图标
- ✅ 通话时长正确(约30秒)
- ✅ 时间戳正确

**如果历史记录仍然为空**:
需要检查Risip内部设置:
1. 查看QSettings路径: `HKEY_CURRENT_USER\Software\BeltControl\SipPhone`
2. 检查`CallHistory/sip:1000@192.168.10.243`键值
3. 验证Risip是否调用了`RisipCallHistoryModel::addCallRecord()`

## 已知问题

### Risip历史记录可能需要额外配置

**原因**: Risip示例代码显示历史记录需要显式模型绑定

**参考**: [risipapp CallPage.qml](F:\0\risipapp-master\risipapp-master\ui\base\callpages\CallPage.qml)

**可能需要的额外步骤**:
1. 确认Risip版本支持自动历史记录
2. 检查是否需要显式调用`writeSettings()`
3. 验证通话结束时`CallDisconnected`状态是否触发历史记录添加

## 编译状态

✅ **编译成功**

```
[ 27%] Building CXX object src/sip_phone/CMakeFiles/sip_phone_module.dir/SipPhoneManager.cpp.obj
[ 28%] Linking CXX static library libsip_phone_module.a
[100%] Linking CXX executable ..\..\bin_windows\belt_control_system.exe
[100%] Built target belt_control_system
```

## 修改的文件

| 文件 | 行号 | 修改内容 |
|------|------|---------|
| [SipPhoneManager.cpp](src/sip_phone/SipPhoneManager.cpp) | 218-260 | 新增来电监听 |
| [SipPhoneManager.cpp](src/sip_phone/SipPhoneManager.cpp) | 539-558 | 修复CallDisconnected状态处理 |

## 下一步

1. **立即测试**: 运行应用,测试对方挂断和来电功能
2. **验证历史**: 完成通话后检查历史记录是否保存
3. **如果历史记录仍为空**: 需要深入调试Risip历史记录机制

---

**修复日期**: 2025-11-28
**状态**: ✅ 代码修复完成,待测试验证
**预计解决问题**:
- 对方挂断后UI状态更新 ✅
- 来电显示 ✅
- 通话历史记录 ⏳ (待验证)
