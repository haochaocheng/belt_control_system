# 修复默认账户 URI 为空的问题

## 日期
2025-11-28

## 问题描述

用户在注册账户后,日志显示:
```
[DEBUG] SAVING DEFAULT ACCOUNT "sip:@"
```

这是一个**无效的 SIP URI**,用户名和域名都是空的。这会导致:
1. 应用重启后无法自动登录(URI 无效)
2. QSettings 中保存的默认账户信息无效
3. 可能导致后续 SIP 操作失败

## 根因分析

### 调用链追踪

1. **用户注册账户**
   - 调用 `SipPhoneManager::registerAccount("1000", "192.168.10.243", "password", 5060)`
   - 创建 SIP URI: `sip:1000@192.168.10.243`
   - 创建 `RisipAccount` 对象

2. **设置活动账户**
   - 调用 `RisipCallManager::setActiveAccount()` (line 419)
   - **注意**: 这个调用只是为了建立来电信号链,不影响默认账户

3. **保存设置**
   - 调用 `risip->saveSettings()` (line 433)
   - `saveSettings()` 内部调用 `defaultAccount()->configuration()->uri()` (risip.cpp:342)
   - **问题**: `defaultAccount()` 从未被设置,返回空账户
   - 结果: 保存的 URI 是 `sip:@`

### 关键代码位置

**[src/risip/core/risip.cpp:342](src/risip/core/risip.cpp#L342)**:
```cpp
if(defaultAccount()) {
    qDebug()<<"SAVING DEFAULT ACCOUNT " << defaultAccount()->configuration()->uri();
    settings.setValue(RisipSettingsParam::DefaultAccount, defaultAccount()->configuration()->uri());
}
```

**原始代码 [src/sip_phone/SipPhoneManager.cpp:416-433](src/sip_phone/SipPhoneManager.cpp#L416-L433)**:
```cpp
// Set as active account in RisipCallManager (CRITICAL for incoming calls!)
risip::RisipCallManager *callManager = risip::RisipCallManager::instance();
if (callManager) {
    callManager->setActiveAccount(d->currentAccount);
    qDebug() << "Set account as active in RisipCallManager";
}

// Start registration
d->currentAccount->login();

// Save account configuration to QSettings
qDebug() << "Saving account configuration to QSettings...";
if (d->risipInstance->saveSettings()) {  // ❌ 这里保存时 defaultAccount() 是空的!
    qDebug() << "Account configuration saved successfully";
}
```

### 问题原因总结

**关键区别**:
- `RisipCallManager::setActiveAccount()` - 用于设置来电处理的活动账户
- `Risip::setDefaultAccount()` - 用于设置持久化保存的默认账户

我们只调用了前者,没有调用后者,导致 `saveSettings()` 时无法获取正确的默认账户 URI。

## 修复方案

### 修复1: 设置默认账户URI

**文件**: [src/sip_phone/SipPhoneManager.cpp:423-426](src/sip_phone/SipPhoneManager.cpp#L423-L426)

**新增代码**:
```cpp
// Set as default account in Risip (CRITICAL for persistence!)
// This must be done BEFORE saveSettings() to ensure correct URI is saved
d->risipInstance->setDefaultAccount(sipUri);
qDebug() << "Set as default account:" << sipUri;
```

### 修复2: 启用自动登录

**文件**: [src/sip_phone/SipPhoneManager.cpp:395-397](src/sip_phone/SipPhoneManager.cpp#L395-L397)

**新增代码**:
```cpp
// Enable auto sign-in for automatic login on app restart
d->currentAccount->setAutoSignIn(true);
qDebug() << "Enabled auto sign-in for account";
```

**为什么需要这个修复?**

Risip 的 `readSettings()` 会读取 `AutoSignIn` 标志(risip.cpp:327):
```cpp
acc->setAutoSignIn(settings.value(RisipSettingsParam::AutoSignIn).toBool());
```

如果 `AutoSignIn` 为 `false` 或未设置,账户不会自动登录,即使配置正确。

**完整修复后的代码**:
```cpp
// Create and register account
d->currentAccount = d->risipInstance->createAccount(config);

if (!d->currentAccount) {
    qDebug() << "Failed to create account";
    emit errorOccurred("创建账户失败");
    delete config;
    return false;
}

// Enable auto sign-in for automatic login on app restart
d->currentAccount->setAutoSignIn(true);
qDebug() << "Enabled auto sign-in for account";

// ... Connect status signals ...

// Set as active account in RisipCallManager (CRITICAL for incoming calls!)
risip::RisipCallManager *callManager = risip::RisipCallManager::instance();
if (callManager) {
    callManager->setActiveAccount(d->currentAccount);
    qDebug() << "Set account as active in RisipCallManager";
}

// Set as default account in Risip (CRITICAL for persistence!)
// This must be done BEFORE saveSettings() to ensure correct URI is saved
d->risipInstance->setDefaultAccount(sipUri);
qDebug() << "Set as default account:" << sipUri;

// Start registration
d->currentAccount->login();

// Save account configuration to QSettings
qDebug() << "Saving account configuration to QSettings...";
if (d->risipInstance->saveSettings()) {
    qDebug() << "Account configuration saved successfully";
} else {
    qWarning() << "Failed to save account configuration";
}
```

### 修复要点

1. ✅ **创建账户后立即设置 `autoSignIn = true`**
2. ✅ **在 `saveSettings()` 之前调用 `setDefaultAccount()`**
3. ✅ **传入正确的 SIP URI** (`sip:1000@192.168.10.243`)
4. ✅ **确保调用顺序**: createAccount → setAutoSignIn → setActiveAccount → setDefaultAccount → login → saveSettings

### 调用顺序流程

```
注册账户 registerAccount()
  │
  ├─ 创建账户配置 (sipUri = "sip:1000@192.168.10.243")
  ├─ 创建 RisipAccount 对象
  │
  ├─ setAutoSignIn(true)  ← ✅ 新增:启用自动登录
  │     └─ 保存时写入 AutoSignIn = true
  │
  ├─ 连接状态信号
  │
  ├─ setActiveAccount(currentAccount)  ← 设置来电处理活动账户
  │     └─ 建立 RisipAccount::incomingCall → RisipCallManager 信号链
  │
  ├─ setDefaultAccount(sipUri)  ← ✅ 新增:设置默认账户 URI
  │     ├─ accountsModel->setDefaultAccountUri(sipUri)
  │     └─ 触发 defaultAccountChanged 信号
  │
  ├─ currentAccount->login()  ← 开始注册
  │
  └─ saveSettings()  ← 保存配置
        ├─ settings.setValue("DefaultAccount", "sip:1000@192.168.10.243") ✅
        └─ settings.setValue("AutoSignIn", true) ✅
```

## 测试计划

### 测试1: 验证保存的 URI 正确

**步骤**:
1. 删除旧的配置文件(清除 `sip:@` 的错误数据)
   - Windows 注册表: `HKEY_CURRENT_USER\Software\BeltControl\SipPhone`
   - 或清除 QSettings 缓存
2. 启动应用
3. 注册账户: `1000` @ `192.168.10.243`
4. 观察日志输出

**预期结果**:
```
[DEBUG] Enabled auto sign-in for account  ✅
[DEBUG] Set as default account: sip:1000@192.168.10.243
[DEBUG] SIP DEFAULT ACCOUNT sip:1000@192.168.10.243
[DEBUG] SAVING DEFAULT ACCOUNT "sip:1000@192.168.10.243"  ✅ 正确的 URI
[DEBUG] Account configuration saved successfully
```

### 测试2: 验证应用重启自动登录

**步骤**:
1. 完成测试1的账户注册
2. 关闭应用
3. 重新启动应用
4. 观察日志

**预期结果**:
```
[DEBUG] Found 1 accounts in settings
[DEBUG] Account 0 URI: sip:1000@192.168.10.243
[DEBUG] Auto-registering default account: sip:1000@192.168.10.243  ✅
[DEBUG] Set default account as active in RisipCallManager
...
Account status changed: 2 ("Registering...")
Account status changed: 3 ("Signed In")  ✅ 自动登录成功
```

### 测试3: 验证来电功能正常

**步骤**:
1. 确认账户已注册
2. 从其他分机(1006)呼叫本机(1000)
3. 观察本机 UI 和日志

**预期结果**:
- ✅ 显示来电界面
- ✅ 日志显示 "Incoming call from: ..."
- ✅ 可以正常接听

## 编译状态

✅ **编译成功**

```
[ 27%] Building CXX object src/sip_phone/CMakeFiles/sip_phone_module.dir/SipPhoneManager.cpp.obj
[ 28%] Linking CXX static library libsip_phone_module.a
[100%] Linking CXX executable ..\..\bin_windows\belt_control_system.exe
[100%] Built target belt_control_system
```

## 技术细节

### setActiveAccount vs setDefaultAccount

| 方法 | 用途 | 影响范围 |
|------|------|----------|
| `RisipCallManager::setActiveAccount()` | 设置来电处理的活动账户 | 仅影响来电信号路由 |
| `Risip::setDefaultAccount()` | 设置默认账户并持久化 | 影响 saveSettings() 和自动登录 |

**重要**: 两个方法都需要调用,缺一不可!

### Risip::setDefaultAccount() 内部实现

参考 [src/risip/core/risip.cpp:178-186](src/risip/core/risip.cpp#L178-L186):

```cpp
void Risip::setDefaultAccount(const QString &uri)
{
    m_data->accountsModel->setDefaultAccountUri(uri);
    RisipCallManager::instance()->setActiveAccount(m_data->accountsModel->defaultAccount());
    RisipContactManager::instance()->setActiveAccount(m_data->accountsModel->defaultAccount());

    qDebug()<<"SIP DEFAULT ACCOUNT " << uri;
    emit defaultAccountChanged(m_data->accountsModel->defaultAccount());
}
```

**注意**: `setDefaultAccount()` 内部也会调用 `RisipCallManager::setActiveAccount()`,但它是在设置了默认 URI 之后,确保账户模型已经正确配置。

### QSettings 保存位置

**Windows**:
- 注册表路径: `HKEY_CURRENT_USER\Software\BeltControl\SipPhone`
- 键值: `DefaultAccount` = `"sip:1000@192.168.10.243"`

**Linux**:
- 配置文件: `~/.config/BeltControl/SipPhone.conf`

## 相关文件

| 文件 | 修改内容 |
|------|----------|
| [SipPhoneManager.cpp:395-397](src/sip_phone/SipPhoneManager.cpp#L395-L397) | 新增 setAutoSignIn(true) 调用 |
| [SipPhoneManager.cpp:423-426](src/sip_phone/SipPhoneManager.cpp#L423-L426) | 新增 setDefaultAccount() 调用 |

## 参考文档

- [INCOMING_CALL_FIX.md](INCOMING_CALL_FIX.md) - 来电信号链修复
- [NULL_STATE_FIX.md](NULL_STATE_FIX.md) - Null 状态处理修复
- [CALL_STATE_FIXES.md](CALL_STATE_FIXES.md) - 通话状态修复

## 总结

✅ **根因已找到**:
1. `saveSettings()` 前没有调用 `setDefaultAccount()` - 导致保存 `sip:@`
2. 创建账户后没有设置 `autoSignIn = true` - 导致重启后不自动登录

✅ **修复已完成**:
1. 在 `saveSettings()` 前添加 `setDefaultAccount(sipUri)` 调用
2. 在创建账户后立即调用 `setAutoSignIn(true)`

✅ **编译成功**: 无编译错误

⏳ **待验证**: 需要用户测试账户注册和自动登录功能

---

**修复日期**: 2025-11-28
**状态**: ✅ 代码完成,待测试
**预期效果**:
- 注册时日志显示正确的 SIP URI: `sip:1000@192.168.10.243` ✅
- 注册时日志显示: `Enabled auto sign-in for account` ✅
- 应用重启后自动登录成功 ✅
- 来电功能正常工作 ✅
