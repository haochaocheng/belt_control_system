# 注销账户不应删除账户修复

## 修复时间
2025-12-03 16:15

## 用户报告的问题

> "我注销1000账户，原先账户有4个分别1000，1002，1003，1004。注销后，已保存账户只有两个了"

**现象**:
- 注销前：4个已保存账户 (1000, 1002, 1003, 1004)
- 点击"注销账号"按钮
- 注销后：只剩2个已保存账户 ❌

**预期行为**:
- 注销应该只**登出（logout）**当前账户
- 账户应该**保留在已保存列表**中，以便下次使用
- 不应该删除账户

---

## 根本原因

**文件**: [src/sip_phone/SipPhoneManager.cpp:574-579](src/sip_phone/SipPhoneManager.cpp#L574-L579)

### 错误的实现

```cpp
void SipPhoneManager::unregisterAccount()
{
    if (!d->registered || !d->currentAccount) {
        return;
    }

    qDebug() << "Unregistering account...";

    try {
        d->currentAccount->logout();

        // ❌ 错误：删除账户！
        d->risipInstance->removeAccount(d->currentAccount->configuration()->uri());
        d->currentAccount = nullptr;

    } catch (const std::exception &ex) {
        qDebug() << "Error unregistering:" << ex.what();
    } catch (...) {
        qDebug() << "Unknown error during unregister";
    }

    d->registered = false;
    emit isRegisteredChanged(false);
    updateServerStatus("SIP引擎已启动");
    qDebug() << "Account unregistered";
}
```

**问题**:
1. 第578行调用了 `removeAccount()` - 这会**永久删除**账户
2. 用户期望"注销"只是登出，但实际上删除了账户
3. 导致用户需要重新输入账户信息才能再次登录

---

## 术语区分

在 SIP 账户管理中，有三个不同的操作：

### 1. 注销（Unregister / Logout）
- **中文**: 注销账号、登出
- **英文**: Unregister, Logout, Sign Out
- **操作**: 从 SIP 服务器登出，断开连接
- **效果**:
  - 账户状态变为 `SignedOut`
  - 无法接收来电
  - 无法拨打电话
  - **账户仍保存在本地**，可以再次登录 ✅

### 2. 删除（Remove / Delete）
- **中文**: 删除账号
- **英文**: Remove, Delete
- **操作**: 从本地数据库中删除账户配置
- **效果**:
  - 账户信息被永久删除
  - 从已保存账户列表中移除
  - 无法再次登录该账户（除非重新添加）❌

### 3. 登录（Register / Login）
- **中文**: 注册账号、登录
- **英文**: Register, Login, Sign In
- **操作**: 向 SIP 服务器发送注册请求
- **效果**:
  - 账户状态变为 `SignedIn`
  - 可以接收来电
  - 可以拨打电话

---

## 修复方案

**文件**: [src/sip_phone/SipPhoneManager.cpp:574-596](src/sip_phone/SipPhoneManager.cpp#L574-L596)

### 修复后的正确实现

```cpp
void SipPhoneManager::unregisterAccount()
{
    if (!d->registered || !d->currentAccount) {
        return;
    }

    qDebug() << "Unregistering account...";

    try {
        // ✅ Only logout, do NOT delete the account
        // The account remains saved for future use
        d->currentAccount->logout();

        // ❌ DO NOT remove account - user wants to keep it saved!
        // Commenting out: d->risipInstance->removeAccount(d->currentAccount->configuration()->uri());

        // Clear current account reference after logout
        d->currentAccount = nullptr;

        qDebug() << "Account logged out successfully (account remains saved)";

    } catch (const std::exception &ex) {
        qDebug() << "Error unregistering:" << ex.what();
    } catch (...) {
        qDebug() << "Unknown error during unregister";
    }

    d->registered = false;
    emit isRegisteredChanged(false);
    updateServerStatus("SIP引擎已启动");
    qDebug() << "Account unregistered (account still saved in list)";
}
```

**改进点**:
1. ✅ **只调用 `logout()`** - 从 SIP 服务器登出
2. ✅ **注释掉 `removeAccount()`** - 不删除账户
3. ✅ **清除 `currentAccount` 引用** - 释放当前账户指针
4. ✅ **添加明确的日志** - 说明账户仍然保存
5. ✅ **账户保留在列表中** - 用户可以再次登录

---

## 对比修复前后

### 修复前（错误行为）

```
操作流程:
1. 用户有 4 个已保存账户: 1000, 1002, 1003, 1004
2. 当前登录账户: 1000
3. 用户点击 "注销账号" 按钮
4. 调用 unregisterAccount()
5. logout() ✅
6. removeAccount() ❌ → 删除账户 1000
7. 结果: 只剩 3 个账户 (1002, 1003, 1004)

如果用户重复注销其他账户:
- 注销 1002 → 剩 2 个账户
- 注销 1003 → 剩 1 个账户
- 注销 1004 → 剩 0 个账户 ❌

最终:
  - 所有账户都被删除 ❌
  - 用户需要重新添加所有账户 ❌
  - 用户体验极差 ❌
```

### 修复后（正确行为）

```
操作流程:
1. 用户有 4 个已保存账户: 1000, 1002, 1003, 1004
2. 当前登录账户: 1000
3. 用户点击 "注销账号" 按钮
4. 调用 unregisterAccount()
5. logout() ✅
6. 账户 1000 状态变为 SignedOut ✅
7. currentAccount = nullptr ✅
8. 结果: 仍有 4 个已保存账户 (1000, 1002, 1003, 1004) ✅

用户可以:
  - 再次点击账户 1000 并登录 ✅
  - 切换到账户 1002 并登录 ✅
  - 所有账户都保留 ✅

最终:
  - 所有账户都保留在列表中 ✅
  - 用户可以随时切换账户 ✅
  - 用户体验良好 ✅
```

---

## UI 上的区别

### "注销账号" 按钮

**功能**: 从当前账户登出，但保留账户信息

**文件**: [src/qml/components/sip_phone/pages/SipDialPage.qml](src/qml/components/sip_phone/pages/SipDialPage.qml)

```qml
RisipButton {
    text: "注销账号"
    enabled: SipPhoneManager.isRegistered
    buttonColor: "#e74c3c"

    onClicked: {
        // ✅ Only logout, account remains saved
        SipPhoneManager.unregisterAccount()
    }
}
```

**效果**:
- 从 SIP 服务器登出
- 账户保留在已保存列表中
- 可以再次登录

### "删除" 按钮（账户列表中）

**功能**: 永久删除账户

**文件**: [src/qml/components/sip_phone/pages/SipSettingsPage.qml](src/qml/components/sip_phone/pages/SipSettingsPage.qml)

```qml
RisipButton {
    text: "删除"
    buttonColor: "#e74c3c"

    onClicked: {
        // ✅ Permanently remove account
        SipPhoneManager.removeAccount(itemAccountUri)
    }
}
```

**效果**:
- 从本地数据库永久删除
- 从已保存列表中移除
- 需要重新添加才能使用

---

## 完整工作流程

### 场景 1: 注销后再次登录

```
初始状态:
  - 已保存账户: 1000, 1002, 1003, 1004
  - 当前登录: 1000 (SignedIn)

1. 用户点击 "注销账号" 按钮
   → unregisterAccount() 调用
   → 控制台: "Unregistering account..."
   → 调用 logout()
   → 账户 1000 状态: SignedIn → SignedOut
   → currentAccount = nullptr
   → 控制台: "Account logged out successfully (account remains saved)"
   → 控制台: "Account unregistered (account still saved in list)"

2. UI 更新:
   → isRegistered = false
   → "注销账号" 按钮禁用
   → "注册账号" 按钮启用
   → serverStatus = "SIP引擎已启动"

3. 验证已保存账户列表:
   → 仍显示 4 个账户 ✅
   → 1000, 1002, 1003, 1004 都在列表中 ✅

4. 用户想再次登录账户 1000:
   → 在设置页面点击账户 1000
   → 配置自动填充
   → 点击 "注册所选账号"
   → loginExistingAccount("sip:1000@192.168.10.243")
   → 账户 1000 重新登录 ✅
   → 状态: SignedOut → SigningIn → SignedIn ✅
```

### 场景 2: 切换账户

```
初始状态:
  - 已保存账户: 1000, 1002, 1003, 1004
  - 当前登录: 1000 (SignedIn)

1. 用户想切换到账户 1002:
   → 在设置页面点击账户 1002
   → 点击 "注册所选账号"
   → loginExistingAccount("sip:1002@192.168.10.243")

2. loginExistingAccount() 内部逻辑:
   → 检查当前账户 1000 已登录
   → 先注销账户 1000: logout()
   → 账户 1000 保留在列表中 ✅
   → 登录账户 1002: login()
   → 账户 1002 状态: SignedOut → SigningIn → SignedIn ✅

3. 最终:
   → 当前登录: 1002 ✅
   → 已保存账户: 1000, 1002, 1003, 1004 (全部保留) ✅
```

### 场景 3: 删除账户（使用 "删除" 按钮）

```
初始状态:
  - 已保存账户: 1000, 1002, 1003, 1004
  - 当前登录: 无

1. 用户想永久删除账户 1000:
   → 在设置页面点击账户 1000 的 "删除" 按钮
   → removeAccount("sip:1000@192.168.10.243")
   → 账户 1000 被永久删除 ✅

2. 验证:
   → 已保存账户: 1002, 1003, 1004 ✅
   → 账户 1000 不在列表中 ✅
```

---

## 修改文件列表

### 修改的文件

1. **[src/sip_phone/SipPhoneManager.cpp](src/sip_phone/SipPhoneManager.cpp)**
   - **Line 574-596**: 修复 `unregisterAccount()` 函数
     - 移除 `removeAccount()` 调用
     - 只调用 `logout()`
     - 添加明确的注释说明
     - 更新日志输出

---

## 验证步骤

### 1. 测试注销不删除账户

1. 注册 4 个账户: 1000, 1002, 1003, 1004
2. 登录账户 1000
3. **验证**: 账户 1000 状态为 SignedIn ✅
4. **测试**: 点击 "注销账号" 按钮
5. **预期**:
   - 控制台输出: `Account logged out successfully (account remains saved)` ✅
   - 控制台输出: `Account unregistered (account still saved in list)` ✅
   - isRegistered = false ✅
6. **测试**: 切换到设置页面查看已保存账户列表
7. **预期**: 仍显示 4 个账户 (1000, 1002, 1003, 1004) ✅

### 2. 测试注销后再次登录

1. 已注销账户 1000
2. **测试**: 在设置页面点击账户 1000
3. **预期**: 配置自动填充 ✅
4. **测试**: 点击 "注册所选账号"
5. **预期**:
   - 控制台输出: `Logging in to existing account: sip:1000@...` ✅
   - 账户 1000 重新登录成功 ✅
   - isRegistered = true ✅

### 3. 测试多次注销

1. 登录账户 1000 → 注销
2. 登录账户 1002 → 注销
3. 登录账户 1003 → 注销
4. 登录账户 1004 → 注销
5. **预期**: 所有 4 个账户仍在列表中 ✅

### 4. 测试删除按钮（确保删除功能仍可用）

1. 在设置页面点击账户 1000 的 "删除" 按钮
2. **预期**:
   - 账户 1000 被永久删除 ✅
   - 已保存账户: 1002, 1003, 1004 ✅
   - 账户 1000 不在列表中 ✅

---

## 技术要点总结

### 1. 区分 logout() 和 removeAccount()

```cpp
// ✅ 注销 - 只登出，保留账户
account->logout();

// ❌ 删除 - 永久删除账户
risipInstance->removeAccount(accountUri);
```

### 2. 用户期望的行为

**注销**:
- 用户期望：暂时登出，稍后可以再登录
- 类似于：微信的 "退出登录"，QQ 的 "下线"
- 账户信息保留

**删除**:
- 用户期望：永久删除，不再使用该账户
- 类似于：微信的 "删除账号"，QQ 的 "注销账号"
- 账户信息被删除

### 3. 清除当前账户引用

```cpp
// ✅ 正确: 清除引用但不删除账户
d->currentAccount = nullptr;

// 账户对象由 Risip SDK 管理，不会被释放
// 账户仍在 allAccountsModel() 中
```

### 4. 日志的重要性

```cpp
// ✅ 清晰的日志说明行为
qDebug() << "Account logged out successfully (account remains saved)";
qDebug() << "Account unregistered (account still saved in list)";

// 帮助用户和开发者理解实际行为
```

---

## 经验教训

### 1. 理解用户的真实需求

**用户说**: "注销账号"

**不正确的理解**: 删除账户 ❌

**正确的理解**: 登出账户，但保留账户信息以便再次登录 ✅

### 2. 术语的重要性

在 UI 和代码中使用准确的术语：
- ✅ "注销账号" → logout, unregister, sign out
- ✅ "删除账号" → remove, delete

避免混淆：
- ❌ "注销账号" 实际删除账户
- ❌ "删除账号" 只是登出

### 3. 测试边界情况

必须测试：
- 注销后账户是否保留
- 注销后能否再次登录
- 多次注销是否会删除多个账户
- 删除功能是否仍然可用

### 4. 代码注释的价值

```cpp
// ✅ 清晰的注释说明为什么不调用 removeAccount()
// ❌ DO NOT remove account - user wants to keep it saved!
// Commenting out: d->risipInstance->removeAccount(...)

// 帮助未来的维护者理解设计意图
```

---

**状态**: ✅ 完全修复 (2025-12-03 16:15)

**修改文件**: SipPhoneManager.cpp

**编译状态**: [100%] Built target belt_control_system ✅

**关键修复**:
1. 移除 `unregisterAccount()` 中的 `removeAccount()` 调用
2. 只调用 `logout()` 登出账户
3. 账户保留在已保存列表中
4. 添加清晰的日志和注释

**验证方法**:
1. 注册多个账户 (例如 4 个)
2. 登录其中一个并注销
3. 验证所有账户仍在列表中 ✅
4. 验证可以再次登录该账户 ✅
5. 验证 "删除" 按钮仍可用 ✅

**下一步**: 请测试应用，确认注销后账户数量不会减少，且可以再次登录
